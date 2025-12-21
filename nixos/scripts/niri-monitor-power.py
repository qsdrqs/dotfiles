#!/usr/bin/env python3
import os
import pathlib
import re
import sys
import time
from typing import Iterable

CONFIG_DIR = pathlib.Path.home() / ".config" / "niri"
MONITOR_PATH = pathlib.Path(os.environ.get("NIRI_MONITOR_PATH", CONFIG_DIR / "monitor.kdl"))
STATE_PATH = pathlib.Path(
    os.environ.get("XDG_STATE_HOME", pathlib.Path.home() / ".local" / "state")
) / "niri-monitor-power" / "state"
POLL_SECONDS = float(os.environ.get("NIRI_MONITOR_POWER_INTERVAL", "10"))
BATTERY_REFRESH = os.environ.get("NIRI_POWER_REFRESH_BAT", "60.001").strip()
AC_REFRESH = os.environ.get("NIRI_POWER_REFRESH_AC", "120.000").strip()
TARGET_OUTPUTS = {
    name.strip()
    for name in os.environ.get("NIRI_POWER_OUTPUTS", "eDP-1,eDP-2").split(",")
    if name.strip()
}

MODE_RE = re.compile(r'^(\s*mode\s+\")(.*?)(\"\s*)$')
OUTPUT_START_RE = re.compile(r'^\s*output\s+\"([^\"]+)\"\s*\{\s*$')


def log(message: str) -> None:
    print(f"[niri-monitor-power] {message}", file=sys.stderr)


def read_power_state() -> str:
    """Return 'ac' if AC power is online, otherwise 'battery'."""
    power_supply = pathlib.Path("/sys/class/power_supply")
    for entry in power_supply.glob("AC*/online"):
        if entry.read_text().strip() == "1":
            return "ac"
    for entry in power_supply.glob("ADP*/online"):
        if entry.read_text().strip() == "1":
            return "ac"
    acad = power_supply / "ACAD" / "online"
    if acad.exists() and acad.read_text().strip() == "1":
        return "ac"
    return "battery"


def load_last_state() -> str:
    try:
        return STATE_PATH.read_text().strip()
    except FileNotFoundError:
        return ""


def remember_state(mode: str) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(mode)


def rewrite_refresh(lines: Iterable[str], refresh: str) -> list[str]:
    current_output = ""
    result: list[str] = []

    for raw_line in lines:
        stripped = raw_line.strip()
        start_match = OUTPUT_START_RE.match(stripped)
        if start_match:
            current_output = start_match.group(1)
            result.append(raw_line)
            continue

        if stripped == "}":
            current_output = ""
            result.append(raw_line)
            continue

        if current_output in TARGET_OUTPUTS:
            mode_match = MODE_RE.match(raw_line)
            if mode_match:
                mode_value = mode_match.group(2)
                if "@" in mode_value:
                    base, _ = mode_value.split("@", 1)
                    new_mode = f"{base}@{refresh}"
                    raw_line = f"{mode_match.group(1)}{new_mode}{mode_match.group(3)}"
        result.append(raw_line)

    return result


def update_active_config(mode: str) -> None:
    if not MONITOR_PATH.exists():
        raise FileNotFoundError(f"Monitor config not found: {MONITOR_PATH}")
    template_lines = MONITOR_PATH.read_text().splitlines()
    refresh = BATTERY_REFRESH if mode == "battery" else AC_REFRESH
    updated_lines = rewrite_refresh(template_lines, refresh)

    content = "\n".join(updated_lines) + "\n"
    if MONITOR_PATH.exists() and MONITOR_PATH.read_text() == content:
        return
    MONITOR_PATH.parent.mkdir(parents=True, exist_ok=True)
    MONITOR_PATH.write_text(content)


def main() -> None:
    last_state = load_last_state()
    pending_state = ""

    while True:
        state = read_power_state()
        if state != last_state:
            if pending_state != state:
                try:
                    update_active_config(state)
                except Exception as exc:
                    log(str(exc))
                    sys.exit(1)
                pending_state = state

            remember_state(state)
            last_state = state
            pending_state = ""
            log(f"Power source changed to {state}; updated {MONITOR_PATH}")
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
