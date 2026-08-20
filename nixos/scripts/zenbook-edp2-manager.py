#!/usr/bin/env python3
import json
import os
import pathlib
import queue
import socket
import subprocess
import sys
import threading
import time


USB_VENDOR = "0b05"
USB_PRODUCT = "1bf2"
DEBOUNCE_SECONDS = 0.25


def keyboard_present(sysfs_root: pathlib.Path) -> bool:
    for device in sysfs_root.iterdir():
        try:
            vendor = (device / "idVendor").read_text().strip().lower()
            product = (device / "idProduct").read_text().strip().lower()
        except (FileNotFoundError, NotADirectoryError, PermissionError, OSError):
            continue
        if vendor == USB_VENDOR and product == USB_PRODUCT:
            return True
    return False


def is_niri_config_loaded(line: str) -> bool:
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        return False
    config_loaded = event.get("ConfigLoaded") if isinstance(event, dict) else None
    return isinstance(config_loaded, dict) and config_loaded.get("failed") is False


class LogindParser:
    def __init__(self) -> None:
        self.prepare_for_sleep = False

    def feed(self, line: str) -> bool:
        if "member=PrepareForSleep" in line:
            self.prepare_for_sleep = True
            return False
        if self.prepare_for_sleep and line.strip() == "boolean false":
            self.prepare_for_sleep = False
            return True
        if self.prepare_for_sleep and line.strip() == "boolean true":
            self.prepare_for_sleep = False
        return False


def should_apply(previous: bool | None, present: bool, force: bool) -> bool:
    return force or previous != present


def select_compositor(environment: dict[str, str]) -> str:
    desktop = environment.get("XDG_CURRENT_DESKTOP", "").lower()
    if "niri" in desktop:
        return "niri"
    if "hyprland" in desktop:
        return "hyprland"
    if environment.get("NIRI_SOCKET"):
        return "niri"
    if environment.get("HYPRLAND_INSTANCE_SIGNATURE"):
        return "hyprland"
    raise RuntimeError("unable to determine the current compositor")


def hyprland_event_socket(environment: dict[str, str]) -> pathlib.Path:
    signature = environment.get("HYPRLAND_INSTANCE_SIGNATURE")
    if not signature:
        raise RuntimeError("HYPRLAND_INSTANCE_SIGNATURE is not set")
    runtime_dir = environment.get("XDG_RUNTIME_DIR")
    candidates = []
    if runtime_dir:
        candidates.append(pathlib.Path(runtime_dir) / "hypr" / signature / ".socket2.sock")
    candidates.append(pathlib.Path("/tmp/hypr") / signature / ".socket2.sock")
    for candidate in candidates:
        if candidate.exists():
            return candidate
    raise RuntimeError(f"Hyprland event socket not found: {candidates[0]}")


class Manager:
    def __init__(
        self,
        sysfs_root: pathlib.Path,
        environment: dict[str, str] | None = None,
        command_runner=subprocess.run,
    ) -> None:
        self.sysfs_root = sysfs_root
        self.environment = dict(os.environ if environment is None else environment)
        self.command_runner = command_runner
        self.compositor = select_compositor(self.environment)
        self.events: queue.Queue[tuple[str, str | None]] = queue.Queue()
        self.processes: list[subprocess.Popen[str]] = []
        self.last_present: bool | None = None
        self.pending_deadline: float | None = None
        self.pending_force = False
        self.logind_parser = LogindParser()

    def apply(self, present: bool) -> None:
        if self.compositor == "niri":
            command = ["niri", "msg", "output", "eDP-2", "off" if present else "on"]
        elif present:
            command = ["hyprctl", "keyword", "monitor", "eDP-2, disabled"]
        else:
            command = ["hyprctl", "keyword", "monitor", "eDP-2, 2880x1800@120, 0x900, 2"]
        self.command_runner(command, check=True)

    def schedule_scan(self, force: bool) -> None:
        self.pending_deadline = time.monotonic() + DEBOUNCE_SECONDS
        self.pending_force = self.pending_force or force

    def scan_and_apply(self, force: bool) -> None:
        present = keyboard_present(self.sysfs_root)
        if should_apply(self.last_present, present, force):
            self.apply(present)
            self.last_present = present

    def start_process_source(self, name: str, command: list[str]) -> None:
        process = subprocess.Popen(
            command,
            stdout=subprocess.PIPE,
            stderr=None,
            text=True,
            bufsize=1,
            env=self.environment,
        )
        if process.stdout is None:
            raise RuntimeError(f"{name} event source has no stdout")
        self.processes.append(process)

        def read_lines() -> None:
            try:
                for line in process.stdout:
                    self.events.put((name, line.rstrip("\n")))
            finally:
                self.events.put(("source-exit", name))

        threading.Thread(target=read_lines, daemon=True).start()

    def start_hyprland_source(self) -> None:
        event_socket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        event_socket.connect(str(hyprland_event_socket(self.environment)))

        def read_events() -> None:
            buffer = ""
            try:
                while data := event_socket.recv(4096):
                    buffer += data.decode()
                    while "\n" in buffer:
                        line, buffer = buffer.split("\n", 1)
                        self.events.put(("hyprland", line))
            finally:
                event_socket.close()
                self.events.put(("source-exit", "hyprland"))

        threading.Thread(target=read_events, daemon=True).start()

    def start_sources(self) -> None:
        self.start_process_source(
            "udev",
            ["udevadm", "monitor", "--udev", "--subsystem-match=usb"],
        )
        self.start_process_source(
            "logind",
            [
                "dbus-monitor",
                "--system",
                "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'",
            ],
        )
        if self.compositor == "niri":
            self.start_process_source("niri", ["niri", "msg", "--json", "event-stream"])
        else:
            self.start_hyprland_source()

    def handle_event(self, source: str, line: str | None) -> None:
        if source == "source-exit":
            raise RuntimeError(f"{line} event source exited")
        if source == "udev":
            self.schedule_scan(force=False)
        elif source == "logind" and line is not None and self.logind_parser.feed(line):
            self.schedule_scan(force=True)
        elif source == "niri" and line is not None and is_niri_config_loaded(line):
            self.schedule_scan(force=True)
        elif source == "hyprland" and line == "configreloaded>>":
            self.schedule_scan(force=True)

    def run(self) -> None:
        self.start_sources()
        self.scan_and_apply(force=True)
        while True:
            timeout = None
            if self.pending_deadline is not None:
                timeout = max(0.0, self.pending_deadline - time.monotonic())
            try:
                source, line = self.events.get(timeout=timeout)
            except queue.Empty:
                force = self.pending_force
                self.pending_deadline = None
                self.pending_force = False
                self.scan_and_apply(force=force)
            else:
                self.handle_event(source, line)


def main() -> None:
    sysfs_root = pathlib.Path(
        os.environ.get("ZENBOOK_EDP2_SYSFS_ROOT", "/sys/bus/usb/devices")
    )
    try:
        Manager(sysfs_root).run()
    except Exception as error:
        print(f"zenbook-edp2-manager: {error}", file=sys.stderr)
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
