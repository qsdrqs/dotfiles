#!/usr/bin/env python3
'''
Copyright (C) 2026 qsdrqs

Author: qsdrqs <qsdrqs@gmail.com>
All Right Reserved

This file attempts to reload rtw88 driver if firmware crash is detected.
'''

import sys
import subprocess
import os
import time

last_reload_time = 0
MIN_RELOAD_INTERVAL = 60  # seconds

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

def check_health(wifi_interface):
    # --- Detection Strategy 1: Check recent kernel logs for firmware crashes ---
    # --since "40 seconds ago" covers our sleep(30) interval to ensure no errors are missed
    try:
        cmd = [
            "journalctl",
            "--no-pager",
            "-q",
            "-k",
            "--since", "40 seconds ago",
            "--grep", "failed to get tx report"
        ]
        result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        stdout = result.stdout.strip()
        stderr = result.stderr.strip()

        # journalctl returns exit 0 when matching entries are found; when no matches are
        # found it typically returns 1 (and without -q prints "-- No entries --").
        if result.returncode == 0 and stdout:
            log(f"Detected firmware crash log: {stdout.splitlines()[0]}...")
            reload_driver(wifi_interface)
            return # Already fixed once, skip subsequent checks, wait for next round
        if (result.returncode not in (0, 1) or stderr) and (stderr or stdout):
            log(f"Warning: journalctl returned {result.returncode}: {(stderr or stdout).splitlines()[0]}")

    except Exception as e:
        log(f"Error checking logs: {e}")

    # # --- Detection Strategy 2: Check if interface is completely DOWN ---
    # # Use ip link show to check for state DOWN
    # try:
    #     result = subprocess.run(
    #         ["ip", "link", "show", wifi_interface],
    #         stdout=subprocess.PIPE,
    #         stderr=subprocess.PIPE,
    #         text=True
    #     )
    #     if "state DOWN" in result.stdout:
    #          log(f"Interface {wifi_interface} is administratively DOWN.")
    #          reload_driver(wifi_interface)
    # except Exception as e:
    #     log(f"Error checking interface state: {e}")

def main():
    # check root
    if not os.geteuid() == 0:
        sys.exit('Script must be run as root')

    if len(sys.argv) < 2:
        sys.exit("Usage: python3 rpi-wifi-watchdog.py <wifi_interface>")
    else:
        wifi_interface = sys.argv[1]

    log(f"Starting WiFi Watchdog for {wifi_interface}...")
    log("Monitoring for 'failed to get tx report' errors...")

    while True:
        check_health(wifi_interface)
        time.sleep(30)

if __name__ == '__main__':
    main()
