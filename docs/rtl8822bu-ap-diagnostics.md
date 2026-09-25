# RTL8822BU AP Streaming and USB Transmit Failure

Diagnostics recorded on 2026-09-24. Times below use local time (UTC-05:00).
This report separates the observed failure from candidate preventive repairs.
It does not claim that WireGuard or a USB power-management quirk fixed the AP.

## Findings

The direct-LAN outage was a persistent failure of the AP's RTL8822BU USB
bulk OUT endpoint `0x06`. In the captured bad state, all 141 sampled
completions on that endpoint returned `-71` (`EPROTO`) and transferred zero
bytes. Endpoint `0x08` completed 330 sampled requests successfully. The
adapter maps video/voice (VI/VO) traffic to `0x06` and best-effort/background
(BE/BK) traffic to `0x08`. A low-rate packet test reproduced the split even
for traffic originating on the AP itself.

The pinned `rtw88_usb` completion path ignores `urb->status` and synthesizes
successful ACK status for ordinary data frames. Thus the AP's increasing TX
counters and zero reported failures were not evidence of delivery. An xHCI
trace independently recorded `USB Transaction Error` for the same endpoint.

An adapter/driver reload restored service, but the initiating cause of the
first USB transaction error remains unknown. No preventive repair was
installed or validated. A separate operational problem is that whole-radio
watchdog reloads disconnect the laptop even when video is actually routed
through WireGuard.

## Setup and paths

| Component | Relevant configuration |
| --- | --- |
| AP | RaspNix, Linux 6.18.42, RTL8822BU `0bda:b812`, `rtw88_8822bu`, USB SuperSpeed 5000M, device path `4-1` during capture |
| AP Wi-Fi | `wlu1` AP at `192.168.12.1/24`; `wld0` associated as a station to the same SSID at `192.168.12.11/24` |
| AP management | `enu1u3c2` at `192.168.100.1/24` |
| DESKSERVER | `wlan0` `192.168.12.8/24`, `eth0` `192.168.100.2/24`, `wg0` `10.100.0.2/24` |
| Laptop | `wlo1` `192.168.12.14/24`, `wg0` `10.100.0.6/24` |
| Streaming | Two Sunshine instances at bases `31089` and `31189`; video UDP source ports `31098` and `31198` |
| Displays | Two 2880x1800@60 virtual outputs on DESKSERVER, viewed on laptop `eDP-1` and `eDP-2` |
| Client request | Moonlight Qt 6.1.0, HEVC, 2880x1800 at 60 FPS, 30000 Kbps per stream |

The normal direct path is `DESKSERVER wlan0 -> AP wlu1 -> laptop wlo1`.
The AP uses the Raspberry Pi kernel source revision
`8c0da7c3bb97a2e0aaa0d405d3052786c1469b35` from package
`6.18.42-unstable_20260806`. Driver line references below refer to this
revision, not necessarily to newer upstream kernels.

## Timeline and measured trials

| Time | Event and interpretation |
| --- | --- |
| Before 18:00 | Direct-LAN SSH completed TCP handshakes but lost the laptop's SSH banner; Sunshine video packets left DESKSERVER but did not arrive at the laptop. |
| 18:00:18-18:00:38 | The existing AP watchdog reloaded the adapter after a TX-report warning, clearing that bad state before the next reproduction. This was not an AP reboot. |
| 18:03-18:05 | Healthy direct-LAN single and dual short trials were intentionally stopped after approximately 50 and 105 seconds. |
| 18:13:57-18:18:33 | A direct-LAN dual trial failed organically after approximately 277 seconds. The bad state was retained for packet, queue, USB, and xHCI capture. |
| 18:31-18:32 | A device-specific runtime NO_LPM quirk was set and the adapter reloaded for a controlled trial. |
| 18:40:12-18:50:49 | Dual LAN with that runtime quirk showed no observed dropout for approximately 637 seconds; the clients were stopped intentionally. Effective LPM suppression was not established. |
| 18:51 | The original USB quirk setting was restored and the adapter reloaded. |
| 18:54:42-19:13:48 | Restored-default LAN dual trial failed organically after approximately 1146 seconds. A first-error monitor caught the transition at 19:13:38.905959. |
| 19:16 | Disabling U1/U2 permission on the already-broken USB port did not restore VI/VO delivery; original port policy was restored. |
| 20:14:15-20:18:14 | A packet-verified dual-WG trial failed when the AP watchdog reloaded the whole wireless driver and the laptop lost Wi-Fi association. |
| 20:23:05-20:27:43 | A second packet-verified dual-WG trial ended during another AP watchdog reload. |
| 20:53 onward | The operational dual-screen service started and was verified on the correct physical outputs; despite its name and host argument, packet captures showed this service was using LAN, not WG. |
| 21:20 onward | A replacement operational service used a restricted paired profile. Both streams selected WG RTSP URLs and received video on laptop `wg0`. This is a startup/path verification, not a long-duration stability result. |

The first-error monitor time is the receiving machine's wall-clock time;
cross-machine sub-millisecond clock synchronization was not established.
The planned interruption between diagnostic runs is excluded from uptime
and organic-failure measurements.

### Stream statistics

Durations were calculated from journal timestamps with Python. Each pair
lists `eDP-1 / eDP-2`. Moonlight's drop percentages are *frame* metrics,
not independently measured UDP packet-loss rates; FEC can mask packet loss.

| Trial | End condition | Seconds to termination | Incoming FPS | Network frame drops | Reported network latency |
| --- | --- | --- | --- | --- | --- |
| LAN dual short | Intentional | Approximately 105 | 60.04 / 60.03 | 0.00% / 0.00% | 2 / 2 ms |
| LAN dual long | Organic | 276.823 / 276.803 | 60.01 / 60.01 | 0.00% / 0.00% | 4 / 3 ms |
| LAN restored default | Organic | 1146.310 / 1146.279 | 60.00 / 60.01 | 0.00% / 0.00% | 3 / 3 ms |
| Verified WG dual 1 | AP watchdog reload | 239.405 / 239.081 | 60.03 / 60.00 | 0.00% / 0.02% | 76 / 75 ms |
| Verified WG dual 2 | AP watchdog reload | 278.621 / 278.614 | 59.84 / 59.83 | 0.29% / 0.34% | 15 / 15 ms |

The CLI requested 30000 Kbps per stream; Sunshine logged a post-connection
target of 22988000 bit/s per stream. Actual traffic varied with desktop
content. A short earlier single-WG control received video promptly and was
intentionally stopped after an approximately 34-second encoder-activity
window. Its exact first-video-to-stop duration was not retained; it is not
a dual-WG stability result. The runtime-NO_LPM observation has no retained
complete end-of-session FPS statistics.

## Evidence for the failure mechanism

### Traffic class, not simply port or client isolation

In a direct-LAN SSH test, SYN/SYN-ACK/ACK reached both hosts, but the laptop's
22-byte banner and retransmissions did not reach DESKSERVER. The successful
handshake used IP DS field `0x00`; the lost banner used `0xb8` (EF). Sunshine
video used `0xa0` (CS5). The two interfaces and the AP route to the laptop
were checked. `ap_isolate=0`.

A probe sent 20 UDP datagrams of 1200 bytes for each DS-field value to the
*same* destination port. All three directions - DESKSERVER to laptop,
laptop to DESKSERVER, and AP to laptop - produced the same bad-state result:

| DS-field values | Traffic class | Delivered per value |
| --- | --- | --- |
| `0x00`, `0x10`, `0x20`, `0x40` | BE/BK | 20/20 |
| `0x60`, `0x80`, `0x88`, `0xa0` | VI | 0/20 |
| `0xb8`, `0xc0`, `0xe0` | VO | 0/20 |

After an adapter reload, all tested values delivered 20/20. AP-originated
failure excludes a client-to-client forwarding rule as a sufficient cause.

### USB and driver evidence

In the initial live bad-state `usbmon` sample, OUT endpoint `0x06` had 141
completions at `-71 / EPROTO` with zero actual bytes on every request.
OUT endpoint `0x08` had 330 successful completions. Python analysis of the
failed requests gave submission-to-completion delays of 152 us minimum,
158 us median, and 209 us maximum. The xHCI trace said:

```text
status 'USB Transaction Error' ... slot 1 ep 12
```

xHCI endpoint ID 12 here denotes USB OUT endpoint `0x06`, not USB endpoint
address `0x0c`. The later bounded first-error trace followed 135495
successful `0x06` completions and recorded an `EPROTO` completion for a
4582-byte request, with 1024 actual bytes, 514 us after submission.
Subsequent requests failed persistently while `0x08` continued succeeding.
Nonzero actual bytes on a failed USB request do not establish wireless
packet delivery.

In the pinned source:

- `net/wireless/util.c:1010-1068` classifies CS5 to TID 5 and EF to TID 6.
- `drivers/net/wireless/realtek/rtw88/rtw8822b.c:2108-2131` maps VI/VO
  to NORMAL DMA and BE/BK to LOW DMA.
- `drivers/net/wireless/realtek/rtw88/usb.c:222-314` maps those queues to
  USB OUT `0x06` and `0x08`, respectively, for this adapter.
- `drivers/net/wireless/realtek/rtw88/usb.c:319-351` does not check the
  completion's `urb->status` before setting ACK for ordinary data frames.
- `drivers/net/wireless/realtek/rtw88/tx.c:179-189` produces the firmware
  TX-report timeout warning. That warning is not proof of a firmware crash.

These facts explain both the selective black hole and why station TX
counters, zero retries, and zero reported failures were misleading.

## WireGuard path classification

Specifying `MOONLIGHT_HOST=10.100.0.2` alone does **not** force the actual
stream path. Moonlight can choose a saved or discovered address. An initial
nominal WG setup and the later operational `moonlight-wg-dual.service`
selected LAN RTSP URLs `192.168.12.8:31110` and `:31210`, detected `wlo1`,
and received video from `192.168.12.8` to `192.168.12.14` on UDP ports
`31098` and `31198`. A three-second operational metadata sample counted
896 and 1481 video packets from those source ports. Those intervals must
not be counted as WG evidence.

The two *verified* diagnostic WG trials used a private temporary Moonlight
profile retaining the existing pairing identity while disabling mDNS and
limiting the selected hosts' candidate IPv4 addresses to `10.100.0.2`.
Their launch responses used WG RTSP addresses, detected `wg0`, and packet
captures on both `wg0` interfaces confirmed the video path. Their inner
video and outer encrypted packets had DSCP 0 rather than direct video DS
field `0xa0`. The observed inner traffic also indicated an intermediary
WG address; the hub's exact NAT/forwarding rules were not inspected.

Both verified WG trials failed when the AP watchdog stopped hostapd and
reloaded the wireless driver. The laptop lost its *physical* Wi-Fi link,
which WG still depended on. Therefore WG did not demonstrate long-running
dual-stream stability or provide a permanent fix. It changed route, packet
sizing, QoS class, and overhead, so even a successful short control could
not isolate one of those differences as the trigger.

## What remains unproven

- The initiating cause of the first `EPROTO`: firmware, host controller,
  USB link power management, signal integrity, port, and power remain
  candidates. `EPROTO` alone does not identify a defective power supply.
- The AP's same-subnet station, earlier station power-save/SMPS changes,
  or RF load as a causal trigger. The topology also worked while healthy.
- NO_LPM as prevention. A runtime `usbcore.quirks=0bda:b812:k` trial ran
  for approximately 637 seconds after a reset, but the restored-default
  run survived longer before failing. Effective host-initiated U1/U2
  suppression in the runtime trial was not established.
- NO_LPM as recovery. Explicitly disabling U1/U2 permission in an already
  broken state did not restore VI/VO; the original policy was restored.
- An SSH-port firewall, AP client isolation, niri, or Sunshine as a
  sufficient explanation for the measured USB-class failure.

The watchdog's description of a "firmware crash" is its own classification,
not independent evidence of a firmware crash. Its full-radio reload can
restore a stuck device but can also disrupt a properly routed WG stream.

## Repair candidates and validation

1. **Fix failed-completion reporting and recovery in `rtw88_usb`.** Check
   USB completion status before reporting ACK, retain endpoint/status/
   requested/actual-length diagnostics, and arrange appropriate recovery
   from a sleepable context for persistent failure. `EPROTO` is not an
   `EPIPE` stall: do not blindly clear a halt in a completion callback.
   A driver change must be tested for successful delivery and truthful TX
   status, without reset storms or repeated whole-AP disconnects. Beacon/
   reserved-page failures may need separate investigation. An unmerged
   upstream candidate, `lwfinger/rtw88` PR 455, was not installed and has
   not been tied causally to this selective endpoint fault.

2. **Evaluate device-specific NO_LPM only as a controlled A/B candidate.**
   Start both arms from equivalent healthy adapter states, use the same
   reset procedure and workload, verify *effective* U1/U2 state rather
   than only a parameter string, and repeat runs beyond the longest
   observed default-LAN interval. Only if prevention is demonstrated,
   consider adding `"usbcore.quirks=0bda:b812:k"` to the AP's existing
   `boot.kernelParams`. Preserve other parameters and recheck behavior
   after kernel updates. Remove the candidate and return to the prior
   generation if it harms association or fails controlled validation.

3. **Compare the USB path one factor at a time.** A different adapter,
   suitable port/controller, cable or extension (if used), and available
   voltage telemetry can distinguish hardware-path problems. USB 2 versus
   USB 3 also changes bandwidth and must not be treated as an isolated
   power-management test. Do not reset a controller that also carries
   wired management Ethernet. Restore the preceding arrangement between
   comparisons.

4. **Treat the watchdog as operational recovery, not prevention.** It
   recovered some stuck states by resetting the adapter, but may miss a
   VI/VO-only blackout while BE traffic remains healthy, and its reload
   disconnects all clients. Record endpoint and association evidence
   before recovery; measure detection coverage, false positives, recovery
   time, and collateral outages before changing its policy. Simply
   increasing restart frequency is not a fix.

For any candidate, use repeated comparable dual-stream runs, the low-rate
QoS probe, and USB completion status on both endpoints. Include runs longer
than the approximately 19-minute restored-default LAN observation. Roll
back changes that cause association regressions, repeated resets, or more
loss. Use wired AP management for controlled adapter resets.

## Reproduction during a maintenance interval

Do not start duplicate Moonlight clients or reset the AP while the
operational laptop displays are being used. Before changing state, record
the watchdog journal: an automatic reload may have already erased the
selective bad state.

On DESKSERVER, use the existing SSH multiplexers or establish them via:

```bash
AP="$USER@192.168.100.1"
LAPTOP="$USER@10.100.0.6"

for target in "$AP" "$LAPTOP"; do
    ssh -O check "$target" ||
        ssh -f -N -M -o ControlPersist=2h -o ConnectTimeout=10 "$target"
done

ssh "$AP" 'sudo -n journalctl -u wifi-watchdog -u hostapd \
    --since "15 minutes ago" --no-pager'
```

To distinguish TCP connection from banner delivery:

```bash
python3 - <<'PY'
import socket
import time

start = time.monotonic()
with socket.create_connection(("192.168.12.14", 22), timeout=3) as conn:
    print("TCP connection seconds:", time.monotonic() - start)
    conn.settimeout(3)
    try:
        print("SSH banner:", conn.recv(256))
    except TimeoutError:
        print("SSH banner timeout")
PY
```

Run synchronized header-only captures on both hosts around this probe:

```bash
tshark -n -i wlan0 -f 'host 192.168.12.14 and tcp port 22' \
    -a duration:10 -T fields \
    -e frame.time_relative -e ip.src -e ip.dst -e ip.dsfield \
    -e tcp.flags -e tcp.len -e tcp.analysis.retransmission

ssh "$LAPTOP" "tshark -n -i wlo1 \
    -f 'host 192.168.12.8 and tcp port 22' \
    -a duration:10 -T fields \
    -e frame.time_relative -e ip.src -e ip.dst -e ip.dsfield \
    -e tcp.flags -e tcp.len -e tcp.analysis.retransmission"
```

The following self-contained probe recreates the low-rate QoS test on
DESKSERVER without depending on the retained temporary artifact. It listens
for a bounded interval, records the received IP_TOS ancillary value, and
prints counts for each DS-field value:

```bash
cat > /tmp/opencode/qos-matrix.py <<'PY'
#!/usr/bin/env python3
import json
import shlex
import subprocess
import sys

TOS = [0x00, 0x10, 0x20, 0x40, 0x60, 0x80,
       0x88, 0xA0, 0xB8, 0xC0, 0xE0]
PORT = 32001
COUNT = 20

CODE = r'''
import collections, json, socket, sys, time

mode, ip, port, values, count = sys.argv[1:]
port, values, count = int(port), json.loads(values), int(count)
s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

if mode == "recv":
    s.bind((ip, port))
    s.setsockopt(socket.IPPROTO_IP, socket.IP_RECVTOS, 1)
    s.settimeout(0.3)
    found = collections.Counter()
    headers = collections.defaultdict(set)
    print("READY", flush=True)
    end = time.monotonic() + 7

    while time.monotonic() < end:
        try:
            data, ancillary, _, address = s.recvmsg(4096, 128)
        except TimeoutError:
            continue
        if not data.startswith(b"QOS_DIAGNOSTIC "):
            continue
        tos, seq = map(int, data.split()[1:3])
        found[tos] += 1
        for level, kind, value in ancillary:
            if level == socket.IPPROTO_IP and kind == socket.IP_TOS:
                headers[tos].add(value[0])

    print(json.dumps({
        f"0x{t:02x}": {
            "received": found[t],
            "expected": count,
            "received_tos": sorted(headers[t])
        } for t in values
    }), flush=True)
else:
    for seq in range(count):
        for tos in values:
            s.setsockopt(socket.IPPROTO_IP, socket.IP_TOS, tos)
            data = f"QOS_DIAGNOSTIC {tos} {seq} ".encode()
            s.sendto(data.ljust(1200, b"."), (ip, port))
            time.sleep(0.004)
    print("SENT", flush=True)
'''

def command(host, arguments):
    argv = ["python3", "-u", "-c", CODE, *arguments]
    return argv if host == "local" else ["ssh", host, shlex.join(argv)]

sender, receiver, address = sys.argv[1:]
common = [address, str(PORT), json.dumps(TOS), str(COUNT)]
process = subprocess.Popen(
    command(receiver, ["recv", *common]),
    stdout=subprocess.PIPE,
    text=True,
)
try:
    ready = process.stdout.readline().strip()
    if ready != "READY":
        raise RuntimeError(f"Receiver not ready: {ready}")
    subprocess.run(command(sender, ["send", *common]), check=True)
    print(process.communicate(timeout=12)[0])
finally:
    if process.poll() is None:
        process.terminate()
        process.wait()
PY
```

Run its three paths:

```bash
python3 /tmp/opencode/qos-matrix.py local "$LAPTOP" 192.168.12.14
python3 /tmp/opencode/qos-matrix.py "$LAPTOP" local 192.168.12.8
python3 /tmp/opencode/qos-matrix.py "$AP" "$LAPTOP" 192.168.12.14
```

The script sends 20 1200-byte packets per DS value on one UDP port
(`32001`) and exits automatically. Do not interpret only the sender's
success as delivery.

For USB metadata on the AP, check the *current* device path and bus/device
numbers before filtering. The recorded path `4-1` may change on reload:

```bash
ssh "$AP" 'lsusb -t; readlink -f /sys/class/net/wlu1/device'

ssh "$AP" '
USBDEV=/sys/bus/usb/devices/4-1
BUS="$(cat "$USBDEV/busnum")"
DEV="$(printf "%03d" "$(cat "$USBDEV/devnum")")"
sudo -n modprobe usbmon
sudo -n timeout 15 awk \
    -v ep6="Bo:$BUS:$DEV:6" -v ep8="Bo:$BUS:$DEV:8" \
    '\''$4 == ep6 || $4 == ep8 {
        print $1, $2, $3, $4, $5, $6;
        fflush();
    }'\'' "/sys/kernel/debug/usb/usbmon/${BUS}u"
'
```

`S` marks submission and `C` completion; a submission's `-115` status
means pending. Judge failures by completion status and actual length.
After the test and all diagnostic readers have exited, unload diagnostic
`usbmon` with `sudo -n modprobe -r usbmon` on the AP. See
`/tmp/opencode/oracle-live-xhci-events.txt` for the captured xHCI event
format; an isolated tracefs instance is preferable to global tracing.

For a future WG comparison, first isolate Moonlight's saved host
configuration in a permission-restricted temporary `XDG_CONFIG_HOME`,
retain its paired identity locally without printing keys, disable
discovery, and restrict the candidate addresses to `10.100.0.2`.
The temporary profile helper from this investigation is
`/tmp/opencode/oracle-prepare-wg-profile.py`, if still present; temporary
credential-bearing profile directories were deleted. Verify a *new*
trial using all three independent signals: RTSP URLs at `10.100.0.2`,
Moonlight's detected `wg0` interface, and received video packet headers
on laptop `wg0`. A host argument or service name alone is insufficient.

```bash
tshark -n -i wg0 \
    -f 'host 10.100.0.2 and (udp port 31098 or udp port 31198)' \
    -a duration:10 -T fields \
    -e frame.time_epoch -e ip.src -e ip.dst -e ip.dsfield \
    -e udp.srcport -e udp.dstport -e udp.length
```

Run that packet check on the laptop. A true WG trial is still vulnerable
to a watchdog reload of the laptop's Wi-Fi AP.

## Last observed operational state and evidence

At the 20:57 read-only verification, the laptop's
`moonlight-wg-dual.service` had windows on `eDP-1` and `eDP-2`.
**Despite its name, it used LAN.** That unit later exited.

At 21:20, the operational launcher `niri/moonlight-extend.py` started
`moonlight-extend.service` with `MOONLIGHT_HOST=10.100.0.2`. It used a
permission-restricted temporary paired profile, selected WG RTSP URLs
`10.100.0.2:31110` and `:31210`, detected `wg0`, received first video,
and placed its windows on `eDP-1` and `eDP-2`. A four-second header
capture on laptop `wg0` counted 4793 packets from video port `31098`
and 2391 from `31198`, sourced at `10.100.0.2` and addressed to
`10.100.0.6`. This establishes the path at startup, not durability.
Leave the operational service running during normal display use. No
`oracle-*` diagnostic units, passive watchers, or rollback timers
remained; AP USB quirks and U1/U2 port policy had been restored to defaults.

Non-sensitive evidence under `/tmp/opencode` on DESKSERVER included:

```text
oracle-live-qos.txt
oracle-live-ssh-desk.tsv
oracle-live-ssh-laptop.tsv
oracle-live-usbmon.tsv
oracle-live-xhci-events.txt
oracle-live-usb-regs.json
oracle-first-error-long.tsv
oracle-first-error-qos.txt
oracle-first-error-live-usbmon.tsv
oracle-nolpm-usbmon.tsv
oracle-wg-start-desk.tsv
oracle-wg-start-laptop.tsv
oracle-wg-second-desk-inner.tsv
oracle-wg-second-laptop-inner.tsv
oracle-wg-second-desk-outer.tsv
oracle-wg-second-laptop-outer.tsv
oracle-qos-matrix.py
oracle-prepare-wg-profile.py
```

Temporary files are not durable evidence storage. The observations and
method above are intended to remain useful after `/tmp` is cleaned.

References: [Linux USB error codes](https://www.kernel.org/doc/html/latest/driver-api/usb/error-codes.html),
[pinned Raspberry Pi kernel source](https://github.com/raspberrypi/linux/tree/8c0da7c3bb97a2e0aaa0d405d3052786c1469b35),
[Moonlight Qt 6.1.0 address selection](https://github.com/moonlight-stream/moonlight-qt/blob/v6.1.0/app/backend/nvcomputer.cpp).
