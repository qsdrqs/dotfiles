#!/usr/bin/env python3
import os
import pathlib
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from typing import Iterable


@dataclass(frozen=True)
class TargetRule:
    text: str
    comment_in: frozenset[str]

    def desired_line(self, mode: str) -> str:
        return f"# {self.text}" if mode in self.comment_in else self.text


TARGET_RULES = [
    # Enable powersave config only on battery; comment when on AC.
    TargetRule(
        text="source = ~/.config/hypr/hyprpowersave.conf",
        comment_in=frozenset({"ac"}),
    ),
    # Comment the default high-refresh eDP-1 line on battery; hyprpowersave.conf provides a low-refresh eDP config there.
    TargetRule(
        text="monitor=eDP-1,2880x1800@120, 0x0,2",
        comment_in=frozenset({"battery"}),
    ),
]

CONFIG_PATH = pathlib.Path.home() / ".config" / "hypr-monitor.conf"
STATE_PATH = pathlib.Path(
    os.environ.get("XDG_STATE_HOME", pathlib.Path.home() / ".local" / "state")
) / "hypr-monitor-power" / "state"
POLL_SECONDS = float(os.environ.get("HYPR_MONITOR_POWER_INTERVAL", "10"))


def log(message: str) -> None:
    print(f"[hypr-monitor-power] {message}", file=sys.stderr)


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


def update_config(mode: str) -> None:
    """Ensure CONFIG_PATH contains the correct line for the current mode."""
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    if CONFIG_PATH.exists():
        lines = CONFIG_PATH.read_text().splitlines()
    else:
        lines = []

    def replace(lines_iter: Iterable[str]) -> list[str]:
        seen: set[str] = set()
        result = []
        for raw_line in lines_iter:
            stripped = raw_line.strip()
            matched = False
            for rule in TARGET_RULES:
                if stripped in (rule.text, f"# {rule.text}"):
                    result.append(rule.desired_line(mode))
                    seen.add(rule.text)
                    matched = True
                    break
            if not matched:
                result.append(raw_line)

        for rule in TARGET_RULES:
            if rule.text not in seen:
                result.append(rule.desired_line(mode))
        return result

    updated_lines = replace(lines)
    CONFIG_PATH.write_text("\n".join(updated_lines) + "\n")


def remember_state(mode: str) -> None:
    STATE_PATH.parent.mkdir(parents=True, exist_ok=True)
    STATE_PATH.write_text(mode)


def load_last_state() -> str:
    try:
        return STATE_PATH.read_text().strip()
    except FileNotFoundError:
        return ""


def main():
    last_state = load_last_state()
    while True:
        state = read_power_state()
        if state != last_state:
            update_config(state)
            remember_state(state)
            log(f"Power source changed to {state}; updated {CONFIG_PATH}")
            last_state = state
        time.sleep(POLL_SECONDS)


if __name__ == "__main__":
    main()
