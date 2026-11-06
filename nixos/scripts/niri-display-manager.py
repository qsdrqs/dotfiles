#!/usr/bin/env python3
"""Manage the ASUS Zenbook Duo panels (eDP-1 and eDP-2) for niri.

The service reads the eDP output blocks from monitor.kdl, combines them with
the current hardware state, and writes complete eDP output blocks to
$RUNTIME_DIRECTORY/panels.kdl. monitor.kdl includes that file before its own
eDP blocks:

    include optional=true "/run/user/1000/niri-display/panels.kdl"

niri uses the first output block that matches a connector, so the generated
blocks apply while the service runs. When the service stops, systemd removes
the runtime directory and the blocks in monitor.kdl apply unchanged.

Automatic behavior:
  - Lid closed: both panels off.
  - Detachable keyboard (USB 0b05:1bf2) attached: eDP-2 off, no rotation.
  - Power source: a mode written without a refresh rate gets the AC or
    battery refresh rate.
  - Accelerometer (iio-sensor-proxy) left-up or right-up: both panels rotate,
    the enabled panels are placed side by side, and the layout uses a
    vertical main axis. bottom-up and undefined orientations are ignored.

Properties written in monitor.kdl take precedence:
  - "off" keeps the panel off.
  - "mode" with "@<rate>" keeps that refresh rate.
  - "transform" in either eDP block disables automatic rotation for both.
  - "layout" is kept as written.

The parser expects each node of an eDP block on its own line, "//" or "/-"
comments, and the block opening as `output "eDP-1" {` on its own line. On a
parse error the generated file is removed, so monitor.kdl applies directly.

Environment:
  NIRI_MONITOR_PATH  monitor config to read (default: ~/.config/niri/monitor.kdl)
  RUNTIME_DIRECTORY  output directory (default: $XDG_RUNTIME_DIR/niri-display)
"""
import json
import os
import pathlib
import queue
import re
import subprocess
import sys
import threading
import time
from dataclasses import dataclass

PRIMARY = "eDP-1"  # Top panel in the normal orientation.
SECONDARY = "eDP-2"  # Bottom panel, covered by the attached keyboard.
PANELS = (PRIMARY, SECONDARY)
KEYBOARD_USB_ID = ("0b05", "1bf2")
REFRESH_AC = "120.000"
REFRESH_BATTERY = "60.001"
# iio-sensor-proxy orientation -> (niri transform, panels from left to right).
ROTATIONS = {
    "left-up": ("90", (SECONDARY, PRIMARY)),
    "right-up": ("270", (PRIMARY, SECONDARY)),
}
SCAN_DEBOUNCE_SECONDS = 0.25
ROTATION_DEBOUNCE_SECONDS = 1.0
SENSOR_RETRY_SECONDS = 5.0
SENSOR_COMMAND = ["monitor-sensor", "--accel"]
OUTPUT_FILE_NAME = "panels.kdl"

OUTPUT_START_RE = re.compile(r'^output\s+"([^"]+)"\s*\{$')
NODE_NAME_RE = re.compile(r"^([A-Za-z0-9_-]+)")
MODE_RE = re.compile(r'^mode\s+"([^"]+)"$')
SCALE_RE = re.compile(r"^scale\s+([0-9.]+)$")
POSITION_RE = re.compile(r"^position\s+x=(-?\d+)\s+y=(-?\d+)$")
ORIENTATION_RE = re.compile(r"orientation(?: changed)?: ([a-z-]+)")


class ConfigError(Exception):
    pass


@dataclass
class Node:
    name: str
    code: str
    lines: list[str]


@dataclass
class Hardware:
    lid_closed: bool
    keyboard_attached: bool
    on_ac: bool
    orientation: str


def log(message: str) -> None:
    print(f"niri-display-manager: {message}", file=sys.stderr, flush=True)


def scan_line(line: str) -> tuple[str, int]:
    """Return the line without a trailing // comment and its brace balance."""
    balance = 0
    in_string = False
    escaped = False
    for index, char in enumerate(line):
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif line.startswith("//", index):
            return line[:index], balance
        elif line.startswith("/*", index):
            raise ConfigError("block comments are not supported")
        elif char == "{":
            balance += 1
        elif char == "}":
            balance -= 1
    return line, balance


def parse_panel_blocks(text: str) -> dict[str, list[Node]]:
    """Return the nodes of the first output block of each panel."""
    blocks: dict[str, list[Node]] = {}
    current: list[Node] | None = None
    node: Node | None = None
    depth = 0
    for number, line in enumerate(text.splitlines(), start=1):
        code, balance = scan_line(line)
        code = code.strip()
        if current is not None and depth >= 2:
            # Continuation of a nested node such as `layout { ... }`.
            if node is not None:
                node.lines.append(line)
        elif current is not None and depth == 1 and code:
            if code == "}":
                current = None
            elif balance < 0:
                raise ConfigError(f"line {number}: put the closing brace on its own line")
            elif code.startswith("/-"):
                node = None
            else:
                name = NODE_NAME_RE.match(code)
                if name is None:
                    raise ConfigError(f"line {number}: unexpected content {code!r}")
                node = Node(name.group(1), code, [line])
                current.append(node)
        elif depth == 0:
            match = OUTPUT_START_RE.match(code)
            if match and match.group(1) in PANELS and match.group(1) not in blocks:
                current = blocks[match.group(1)] = []
        depth += balance
        if depth < 0:
            raise ConfigError(f"line {number}: unbalanced closing brace")
    missing = [name for name in PANELS if name not in blocks]
    if missing:
        raise ConfigError(f"no output block for {', '.join(missing)}")
    return blocks


def find_node(nodes: list[Node], name: str) -> Node | None:
    return next((node for node in nodes if node.name == name), None)


def base_position(name: str, nodes: list[Node]) -> tuple[int, int]:
    node = find_node(nodes, "position")
    match = POSITION_RE.match(node.code) if node else None
    if match is None:
        raise ConfigError(f'{name}: rotation needs "position x=<x> y=<y>"')
    return int(match.group(1)), int(match.group(2))


def logical_size(name: str, nodes: list[Node]) -> tuple[int, int]:
    mode = find_node(nodes, "mode")
    scale = find_node(nodes, "scale")
    mode_match = MODE_RE.match(mode.code) if mode else None
    scale_match = SCALE_RE.match(scale.code) if scale else None
    if mode_match is None or scale_match is None:
        raise ConfigError(f'{name}: rotation needs "mode" and "scale"')
    width, height = (int(value) for value in mode_match.group(1).split("@")[0].split("x"))
    factor = float(scale_match.group(1))
    return round(width / factor), round(height / factor)


def render_panels(blocks: dict[str, list[Node]], hardware: Hardware) -> str:
    off = {name: hardware.lid_closed or find_node(blocks[name], "off") is not None for name in PANELS}
    if hardware.keyboard_attached:
        off[SECONDARY] = True

    rotation = None
    rotation_locked = any(find_node(blocks[name], "transform") for name in PANELS)
    if not rotation_locked and not hardware.keyboard_attached:
        rotation = ROTATIONS.get(hardware.orientation)

    positions: dict[str, tuple[int, int]] = {}
    if rotation is not None:
        x, y = base_position(PRIMARY, blocks[PRIMARY])
        for name in rotation[1]:
            if not off[name]:
                positions[name] = (x, y)
                # Rotated by 90 or 270 degrees, the width is the unrotated height.
                x += logical_size(name, blocks[name])[1]

    refresh = REFRESH_AC if hardware.on_ac else REFRESH_BATTERY
    lines = ["// Generated by niri-display-manager from monitor.kdl. Edit monitor.kdl instead."]
    for name in PANELS:
        nodes = blocks[name]
        lines.append(f'output "{name}" {{')
        for node in nodes:
            if node.name == "position" and name in positions:
                continue
            mode = MODE_RE.match(node.code) if node.name == "mode" else None
            if mode is not None and "@" not in mode.group(1):
                lines.append(f'    mode "{mode.group(1)}@{refresh}"')
            else:
                lines.extend(node.lines)
        if off[name] and find_node(nodes, "off") is None:
            lines.append("    off")
        if rotation is not None:
            lines.append(f'    transform "{rotation[0]}"')
            if find_node(nodes, "layout") is None:
                lines.extend(["    layout {", '        main-axis "vertical"', "    }"])
        if name in positions:
            lines.append(f"    position x={positions[name][0]} y={positions[name][1]}")
        lines.append("}")
    return "\n".join(lines) + "\n"


def read_lid_closed() -> bool:
    return any(
        "closed" in path.read_text() for path in pathlib.Path("/proc/acpi/button/lid").glob("*/state")
    )


def read_keyboard_attached() -> bool:
    for device in pathlib.Path("/sys/bus/usb/devices").iterdir():
        try:
            vendor = (device / "idVendor").read_text().strip().lower()
            product = (device / "idProduct").read_text().strip().lower()
        except OSError:
            continue
        if (vendor, product) == KEYBOARD_USB_ID:
            return True
    return False


def read_on_ac() -> bool:
    for supply in pathlib.Path("/sys/class/power_supply").iterdir():
        try:
            mains = (supply / "type").read_text().strip() == "Mains"
            if mains and (supply / "online").read_text().strip() == "1":
                return True
        except OSError:
            continue
    return False


def is_config_loaded(line: str) -> bool:
    try:
        event = json.loads(line)
    except json.JSONDecodeError:
        return False
    loaded = event.get("ConfigLoaded") if isinstance(event, dict) else None
    return isinstance(loaded, dict) and loaded.get("failed") is False


class Manager:
    def __init__(self, monitor_path: pathlib.Path, output_path: pathlib.Path) -> None:
        self.monitor_path = monitor_path
        self.output_path = output_path
        self.events: queue.Queue[tuple[str, str]] = queue.Queue()
        self.orientation = "normal"
        self.pending_orientation: str | None = None
        self.rotation_deadline: float | None = None
        self.scan_deadline: float | None = None
        self.sensor_retry_deadline: float | None = None
        self.last_error: str | None = None

    def start_source(self, name: str, command: list[str]) -> None:
        process = subprocess.Popen(command, stdout=subprocess.PIPE, text=True, bufsize=1)
        if process.stdout is None:
            raise RuntimeError(f"{name} event source has no stdout")

        def read_lines() -> None:
            try:
                for line in process.stdout:
                    self.events.put((name, line.rstrip("\n")))
            finally:
                process.wait()
                self.events.put(("exit", name))

        threading.Thread(target=read_lines, daemon=True).start()

    def start_sources(self) -> None:
        self.start_source(
            "udev",
            ["udevadm", "monitor", "--udev", "--subsystem-match=usb", "--subsystem-match=power_supply"],
        )
        # PrepareForSleep covers resume; PropertiesChanged on login1 carries LidClosed.
        self.start_source(
            "logind",
            [
                "dbus-monitor",
                "--system",
                "type='signal',interface='org.freedesktop.login1.Manager',member='PrepareForSleep'",
                "type='signal',interface='org.freedesktop.DBus.Properties',"
                "member='PropertiesChanged',path='/org/freedesktop/login1'",
            ],
        )
        self.start_source("niri", ["niri", "msg", "--json", "event-stream"])
        self.start_source("sensor", SENSOR_COMMAND)

    def schedule_scan(self) -> None:
        if self.scan_deadline is None:
            self.scan_deadline = time.monotonic() + SCAN_DEBOUNCE_SECONDS

    def handle_event(self, source: str, line: str) -> None:
        if source == "exit" and line == "sensor":
            # monitor-sensor quits when claiming the accelerometer fails, which
            # happens when a claim follows the release of a previous one closely.
            log(f"monitor-sensor exited; retrying in {SENSOR_RETRY_SECONDS:g}s")
            self.sensor_retry_deadline = time.monotonic() + SENSOR_RETRY_SECONDS
            return
        if source == "exit":
            raise RuntimeError(f"{line} event source exited")
        if source == "sensor":
            match = ORIENTATION_RE.search(line)
            if match is None:
                return
            if match.group(1) == "normal" or match.group(1) in ROTATIONS:
                if line.startswith("==="):
                    # Initial reading after claiming the sensor, not a transition.
                    self.orientation = match.group(1)
                    self.schedule_scan()
                else:
                    self.pending_orientation = match.group(1)
                    self.rotation_deadline = time.monotonic() + ROTATION_DEBOUNCE_SECONDS
            else:
                self.pending_orientation = None
                self.rotation_deadline = None
        elif source == "niri":
            if is_config_loaded(line):
                self.schedule_scan()
        else:
            self.schedule_scan()

    def reconcile(self) -> None:
        hardware = Hardware(read_lid_closed(), read_keyboard_attached(), read_on_ac(), self.orientation)
        try:
            content = render_panels(parse_panel_blocks(self.monitor_path.read_text()), hardware)
        except (ConfigError, OSError) as error:
            message = f"{self.monitor_path}: {error}; using monitor.kdl without generated blocks"
            if message != self.last_error:
                log(message)
                self.last_error = message
            self.output_path.unlink(missing_ok=True)
            return
        self.last_error = None
        try:
            current = self.output_path.read_text()
        except FileNotFoundError:
            current = None
        if content == current:
            return
        temporary = self.output_path.with_name(self.output_path.name + ".tmp")
        temporary.write_text(content)
        temporary.replace(self.output_path)
        log(f"applied {hardware}")

    def run(self) -> None:
        self.start_sources()
        self.schedule_scan()
        while True:
            deadlines = [
                d
                for d in (self.scan_deadline, self.rotation_deadline, self.sensor_retry_deadline)
                if d is not None
            ]
            timeout = max(0.0, min(deadlines) - time.monotonic()) if deadlines else None
            try:
                source, line = self.events.get(timeout=timeout)
            except queue.Empty:
                pass
            else:
                self.handle_event(source, line)

            now = time.monotonic()
            if self.sensor_retry_deadline is not None and now >= self.sensor_retry_deadline:
                self.sensor_retry_deadline = None
                self.start_source("sensor", SENSOR_COMMAND)
            due = False
            if self.rotation_deadline is not None and now >= self.rotation_deadline:
                if self.pending_orientation is not None:
                    self.orientation = self.pending_orientation
                self.pending_orientation = None
                self.rotation_deadline = None
                due = True
            if self.scan_deadline is not None and now >= self.scan_deadline:
                self.scan_deadline = None
                due = True
            if due:
                self.reconcile()


def main() -> None:
    monitor_path = pathlib.Path(
        os.environ.get("NIRI_MONITOR_PATH", pathlib.Path.home() / ".config" / "niri" / "monitor.kdl")
    )
    runtime_dir = os.environ.get("RUNTIME_DIRECTORY") or os.path.join(
        os.environ["XDG_RUNTIME_DIR"], "niri-display"
    )
    output_path = pathlib.Path(runtime_dir) / OUTPUT_FILE_NAME
    try:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        Manager(monitor_path, output_path).run()
    except Exception as error:
        log(str(error))
        raise SystemExit(1) from error


if __name__ == "__main__":
    main()
