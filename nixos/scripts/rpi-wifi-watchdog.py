#!/usr/bin/env python3
'''
Copyright (C) 2026 qsdrqs

Author: qsdrqs <qsdrqs@gmail.com>
All Right Reserved

Reload rtw88 after firmware errors or repeated client-side connectivity failures.
Usage: rpi-wifi-watchdog.py <ap_interface> <probe_interface>
'''

import sys
import subprocess
import os
import time
import json
from ipaddress import IPv4Interface

last_reload_time = 0
probe_failures = 0
MIN_RELOAD_INTERVAL = 60  # seconds
CHECK_INTERVAL = 30  # seconds
PROBE_FAILURE_THRESHOLD = 3
COMMAND_TIMEOUT = 5  # seconds

def log(msg):
    print(f"[{time.strftime('%Y-%m-%d %H:%M:%S')}] {msg}", flush=True)

def run_cmd(cmd, description):
    """Execute command and log failures."""
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        log(f"Warning: {description} failed (exit {result.returncode}): {result.stderr.strip()}")
    return result

def is_service_active(service):
    """Check if systemd service is active."""
    result = subprocess.run(
        ["systemctl", "is-active", service],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )
    return result.stdout.strip() == "active"

def reload_driver(interface):
    global last_reload_time
    now = time.time()

    # Check cooldown period
    if now - last_reload_time < MIN_RELOAD_INTERVAL:
        log(f"Skipping reload (last reload was {int(now - last_reload_time)}s ago, minimum interval: {MIN_RELOAD_INTERVAL}s)")
        return

    last_reload_time = now
    log(f"Triggering driver reload for {interface}...")

    # 1. Stop hostapd to prevent it from occupying the device
    if is_service_active("hostapd"):
        run_cmd(["systemctl", "stop", "hostapd"], "Stop hostapd")
    else:
        log("hostapd is not running, skipping stop.")

    # 2. Unload driver modules (order matters: unload specific ones first, then core)
    # rtw88_8822bu is the chip driver, rtw88_core is the core library
    log("Unloading kernel modules...")
    run_cmd(["modprobe", "-r", "rtw88_8822bu"], "Unload rtw88_8822bu")
    run_cmd(["modprobe", "-r", "rtw88_usb"], "Unload rtw88_usb")
    run_cmd(["modprobe", "-r", "rtw88_core"], "Unload rtw88_core")

    time.sleep(2)

    # 3. Reload driver
    log("Reloading kernel modules...")
    run_cmd(["modprobe", "rtw88_8822bu"], "Load rtw88_8822bu")

    time.sleep(3)

    # 4. Restart hostapd
    run_cmd(["systemctl", "start", "hostapd"], "Start hostapd")
    log("Driver reload sequence completed.")

def probe_failure(wifi_interface, probe_interface):
    """Return a connectivity failure reason, or None on a successful probe.

    Command errors and unavailable probe interfaces raise instead of counting
    as AP failures. The probe must already be configured to autoconnect.
    """
    result = subprocess.run(
        ["ip", "-j", "address", "show"],
        capture_output=True, text=True, check=True, timeout=COMMAND_TIMEOUT
    )
    addresses = json.loads(result.stdout)
    if not addresses:
        raise ValueError("ip returned no interface data")
    interfaces = {item["ifname"]: item for item in addresses}
    if probe_interface not in interfaces:
        raise ValueError(f"Probe interface {probe_interface} is missing")
    probe = interfaces[probe_interface]
    if "UP" not in probe["flags"]:
        raise ValueError(f"Probe interface {probe_interface} is administratively down")
    if wifi_interface not in interfaces:
        return f"AP interface {wifi_interface} is missing"
    ap = interfaces[wifi_interface]

    result = subprocess.run(
        ["iw", "dev", probe_interface, "link"],
        capture_output=True, text=True, check=True, timeout=COMMAND_TIMEOUT
    )
    link = result.stdout.strip()
    if link == "Not connected.":
        return f"{probe_interface} is not associated with the AP"
    if not link.startswith("Connected to "):
        raise ValueError(f"Unexpected iw link output: {link!r}")
    bssid = link.split()[2].lower()
    if bssid != ap["address"].lower():
        raise ValueError(f"{probe_interface} is associated with another AP ({bssid})")

    ap_addresses = [
        IPv4Interface(f"{addr['local']}/{addr['prefixlen']}")
        for addr in ap["addr_info"]
        if addr["family"] == "inet" and addr["scope"] == "global"
    ]
    probe_addresses = [
        IPv4Interface(f"{addr['local']}/{addr['prefixlen']}")
        for addr in probe["addr_info"]
        if addr["family"] == "inet" and addr["scope"] == "global"
    ]
    if not ap_addresses:
        return f"AP interface {wifi_interface} has no IPv4 address"
    if not probe_addresses:
        return f"{probe_interface} is associated but has no IPv4 address"
    target = next((
        ap_addr.ip
        for ap_addr in ap_addresses
        for probe_addr in probe_addresses
        if probe_addr.ip in ap_addr.network and ap_addr.ip in probe_addr.network
    ), None)
    if target is None:
        return f"{probe_interface} has no IPv4 address in the AP subnet"

    # DAD uses source 0.0.0.0; a local source IP is rejected on this same-host
    # wireless path. In DAD mode, exit 1 means a reply and exit 0 means silence.
    cmd = ["arping", "-D", "-q", "-I", probe_interface, "-c", "3", "-w", "3", str(target)]
    result = subprocess.run(cmd, capture_output=True, text=True, timeout=COMMAND_TIMEOUT)
    if result.returncode == 1:
        return None
    if result.returncode == 0:
        return f"No ARP reply from {target} through {probe_interface}"
    raise subprocess.CalledProcessError(
        result.returncode, cmd, output=result.stdout, stderr=result.stderr
    )

def check_health(wifi_interface, probe_interface):
    global probe_failures
    # --- Detection Strategy 1: Check recent kernel logs for firmware crashes ---
    # The lookback overlaps the 30-second polling interval.
    try:
        cmd = [
            "journalctl",
            "--no-pager",
            "-q",
            "-k",
            "--since", "40 seconds ago",
            "--grep", "failed to get tx report"
        ]
        result = subprocess.run(
            cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, timeout=COMMAND_TIMEOUT
        )
        stdout = result.stdout.strip()
        stderr = result.stderr.strip()

        # journalctl returns exit 0 when matching entries are found; when no matches are
        # found it typically returns 1 (and without -q prints "-- No entries --").
        if result.returncode == 0 and stdout:
            log(f"Detected firmware crash log: {stdout.splitlines()[0]}...")
            probe_failures = 0
            reload_driver(wifi_interface)
            return # Already fixed once, skip subsequent checks, wait for next round
        if (result.returncode not in (0, 1) or stderr) and (stderr or stdout):
            log(f"Warning: journalctl returned {result.returncode}: {(stderr or stdout).splitlines()[0]}")

    except Exception as e:
        log(f"Error checking logs: {e}")

    # --- Detection Strategy 2: Check the AP through a dedicated Wi-Fi client ---
    try:
        failure = probe_failure(wifi_interface, probe_interface)
    except (OSError, subprocess.SubprocessError, ValueError, KeyError, TypeError) as e:
        probe_failures = 0
        log(f"Error checking client probe: {getattr(e, 'stderr', None) or e}")
        return

    if failure is None:
        if probe_failures:
            log(f"Client probe {probe_interface} recovered.")
        probe_failures = 0
        return

    probe_failures += 1
    log(f"Client probe failed ({probe_failures}/{PROBE_FAILURE_THRESHOLD}): {failure}")
    if probe_failures >= PROBE_FAILURE_THRESHOLD:
        probe_failures = 0
        reload_driver(wifi_interface)

def main():
    # check root
    if not os.geteuid() == 0:
        sys.exit('Script must be run as root')

    if len(sys.argv) != 3:
        sys.exit("Usage: python3 rpi-wifi-watchdog.py <ap_interface> <probe_interface>")
    else:
        wifi_interface, probe_interface = sys.argv[1:]
    if wifi_interface == probe_interface:
        sys.exit("AP and probe interfaces must be different")

    log(f"Starting WiFi Watchdog for {wifi_interface}...")
    log("Monitoring for 'failed to get tx report' errors...")
    log(f"Probing AP connectivity through {probe_interface}; reload after {PROBE_FAILURE_THRESHOLD} failed checks.")

    while True:
        started = time.monotonic()
        check_health(wifi_interface, probe_interface)
        time.sleep(max(0, CHECK_INTERVAL - (time.monotonic() - started)))

if __name__ == '__main__':
    main()
