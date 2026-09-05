#!/usr/bin/env python3
"""Operate wlroots-bridge and return a saved observation after every input action.

Usage: desktop.py screenshot [--display ID] [--output-dir DIR]
       desktop.py zoom --display ID --x X --y Y --w W --h H
       desktop.py point --metadata FILE --x X --y Y
       desktop.py click --metadata FILE --x X --y Y [--dry-run]
       desktop.py type --display ID --text TEXT
       desktop.py --help
"""

import argparse
import base64
import json
import math
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


QUERIES = ("doctor", "screens", "windows", "frontmost-app")
POINTER_ACTIONS = ("move", "click", "scroll", "drag", "mouse-down", "mouse-up")
KEYBOARD_ACTIONS = ("type", "key", "hold-key")
ACTIONS = (*POINTER_ACTIONS, *KEYBOARD_ACTIONS, "activate-window")
ERRORS = (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired)


def temp_parent():
    return Path("/tmp/opencode") if Path("/tmp/opencode").is_dir() else Path("/tmp")


def bridge(*args, timeout=30):
    executable = shutil.which("wlroots-bridge")
    if executable is None:
        raise ValueError("wlroots-bridge is not available on PATH; install it separately.")
    # The mouse-down holder inherits stdout/stderr. Pipes would wait for its EOF.
    with tempfile.TemporaryFile(dir=temp_parent()) as stdout, tempfile.TemporaryFile(
        dir=temp_parent()
    ) as stderr:
        result = subprocess.run(
            [executable, *args], stdout=stdout, stderr=stderr, timeout=timeout
        )
        stdout.seek(0)
        stderr.seek(0)
        output = stdout.read().decode("utf-8")
        error = stderr.read().decode("utf-8", errors="replace")
    if result.returncode:
        raise ValueError(f"wlroots-bridge exited {result.returncode}: {error.strip() or output.strip()}")
    return json.loads(output)


def select_screen(screens, display):
    if display is None:
        if len(screens) != 1:
            ids = ", ".join(screen["id"] for screen in screens)
            raise ValueError(f"Specify --display from the current screens: {ids or '(none)'}")
        return screens[0]
    for screen in screens:
        if screen["id"] == display:
            return screen
    raise ValueError(f"Display {display!r} is not present; discover screens again.")


def validate_metadata(meta):
    for key in ("width", "height", "displayWidth", "displayHeight"):
        if type(meta[key]) is not int or meta[key] <= 0:
            raise ValueError(f"Invalid screenshot dimension: {key}")
    for key in ("originX", "originY"):
        if type(meta[key]) is not int:
            raise ValueError(f"Invalid screenshot origin: {key}")
    if not isinstance(meta["displayId"], str) or not meta["displayId"]:
        raise ValueError("Missing screenshot display ID")


def geometry_from_metadata(meta):
    return meta.get("screenGeometry", {
        "x": meta["originX"], "y": meta["originY"],
        "width": meta["displayWidth"], "height": meta["displayHeight"],
    })


def read_metadata(path):
    if path is None:
        return None
    meta = json.loads(path.read_text(encoding="utf-8"))
    validate_metadata(meta)
    return meta


def check_geometry(meta, screen):
    if meta is not None and screen["geometry"] != geometry_from_metadata(meta):
        raise ValueError("Screen geometry changed; take a new screenshot before acting")


def map_point(meta, x, y):
    validate_metadata(meta)
    if not (math.isfinite(x) and math.isfinite(y)):
        raise ValueError("Coordinates must be finite")
    if not (0 <= x < meta["width"] and 0 <= y < meta["height"]):
        raise ValueError("Coordinates are outside the saved screenshot")
    return {
        "x": meta["originX"]
        + min(round(x * meta["displayWidth"] / meta["width"]), meta["displayWidth"] - 1),
        "y": meta["originY"]
        + min(round(y * meta["displayHeight"] / meta["height"]), meta["displayHeight"] - 1),
    }


def capture(display, directory, timeout=30, region=None):
    screen = select_screen(bridge("screens", timeout=timeout), display)
    geometry = screen["geometry"]
    if region is None:
        data = bridge("screenshot", "--display", screen["id"], timeout=timeout)
        validate_metadata(data)
        if data["displayId"] != screen["id"] or geometry_from_metadata(data) != geometry:
            raise ValueError("Screen geometry changed during capture; capture again")
    else:
        x, y, w, h = region
        if x < 0 or y < 0 or x + w > geometry["width"] or y + h > geometry["height"]:
            raise ValueError("Zoom region must lie within the selected screen's logical bounds")
        data = bridge(
            "zoom", "--display", screen["id"], "--x", str(x), "--y", str(y),
            "--w", str(w), "--h", str(h), timeout=timeout,
        )
        current = select_screen(bridge("screens", timeout=timeout), screen["id"])
        if current["geometry"] != geometry:
            raise ValueError("Screen geometry changed during zoom; capture again")
        data.update(
            displayId=screen["id"], displayWidth=w, displayHeight=h,
            originX=geometry["x"] + x, originY=geometry["y"] + y,
        )
    data.update(screenGeometry=geometry, captureKind="zoom" if region else "screenshot")
    image = base64.b64decode(data.pop("base64"), validate=True)
    validate_metadata(data)
    if not image.startswith(b"\xff\xd8\xff"):
        raise ValueError("Expected a JPEG screenshot from wlroots-bridge")
    image_path = directory / "screenshot.jpg"
    metadata_path = directory / "screenshot.json"
    image_path.write_bytes(image)
    metadata_path.write_text(json.dumps(data, indent=2) + "\n", encoding="ascii")
    return {"image": str(image_path), "metadata": str(metadata_path), **data}


def output_directory(parent):
    parent = parent if parent is not None else temp_parent()
    return Path(tempfile.mkdtemp(prefix="computer-use-", dir=parent)).resolve()


def action_command(args, meta):
    name = args.command
    if name in ("move", "click", "scroll"):
        point = map_point(meta, args.x, args.y)
        command = [f"pointer-{name}", "--x", str(point["x"]), "--y", str(point["y"])]
        if name == "click":
            command += ["--button", args.button, "--count", str(args.count)]
            command += [f"--modifier={modifier}" for modifier in args.modifier]
        elif name == "scroll":
            if args.dx == 0 and args.dy == 0:
                raise ValueError("Scroll requires a nonzero --dx or --dy (wheel notches)")
            command += ["--dx", str(args.dx), "--dy", str(args.dy)]
        return command
    if name == "drag":
        start = map_point(meta, args.from_x, args.from_y)
        end_meta = read_metadata(args.to_metadata) if args.to_metadata else meta
        end = map_point(end_meta, args.to_x, args.to_y)
        return [
            "pointer-drag", "--from-x", str(start["x"]), "--from-y", str(start["y"]),
            "--to-x", str(end["x"]), "--to-y", str(end["y"]),
        ]
    if name in ("mouse-down", "mouse-up"):
        return [f"left-{name}"]
    if name == "type":
        if args.text_file:
            args.text = args.text_file.read_text(encoding="utf-8")
        return ["type", f"--text={args.text}", "--delay-ms", str(args.delay_ms)]
    if name == "key":
        return ["key-sequence", f"--keys={args.keys}", "--repeat", str(args.repeat)]
    if name == "hold-key":
        return ["hold-key", *[f"--key={key}" for key in args.key], "--duration-ms", str(args.duration_ms)]
    return ["activate-window", f"--window={args.window}"]


def action_timeout(args):
    if args.timeout is not None:
        return args.timeout
    duration = 0
    if args.command == "type":
        duration = max(0, len(args.text) - 1) * args.delay_ms / 1000
    elif args.command == "hold-key":
        duration = args.duration_ms / 1000
    elif args.command == "key":
        duration = (args.repeat - 1) * 0.008
    elif args.command == "click":
        duration = (args.count - 1) * 0.05
    return max(30, duration + 30)


def preflight(args, meta, display):
    timeout = args.timeout or 30
    capabilities = bridge("doctor", timeout=timeout)["globals"]
    required = ["screencopy"]
    if args.command in POINTER_ACTIONS:
        required += ["virtual_pointer"]
    if args.command in KEYBOARD_ACTIONS or (args.command == "click" and args.modifier):
        required += ["virtual_keyboard"]
    if args.command == "activate-window":
        required += ["foreign_toplevel_wlr"]
    missing = [name for name in required if not capabilities.get(name)]
    if missing:
        raise ValueError(f"Required Wayland capabilities missing: {', '.join(missing)}")
    screens = bridge("screens", timeout=timeout)
    observation_screen = select_screen(screens, display)
    if meta is not None:
        check_geometry(meta, select_screen(screens, meta["displayId"]))
    if args.command == "drag" and args.to_metadata:
        end_meta = read_metadata(args.to_metadata)
        check_geometry(end_meta, select_screen(screens, end_meta["displayId"]))
    if args.command in ("move", "click", "scroll", "drag"):
        if any(s["geometry"][axis] < 0 for s in screens for axis in ("x", "y")):
            raise ValueError("Backend pointer mapping is unreliable for negative output origins")
    return observation_screen["id"]


def perform_action(args):
    result = {
        "action": args.command, "actionSucceeded": False, "actionStatus": "not-started",
        "screenshotSucceeded": False, "image": None, "metadata": None,
    }
    display, directory = args.display, None
    try:
        meta = read_metadata(args.metadata)
        if display is None and meta is not None:
            display = meta["displayId"]
        command = action_command(args, meta)
        result["command"] = ["wlroots-bridge", *command]
        if args.dry_run:
            return {**result, "dryRun": True, "captureDisplay": display}, 0
        display = preflight(args, meta, display)
        directory = output_directory(args.output_dir)
    except ERRORS as error:
        if args.command != "mouse-up" or args.dry_run:
            return {**result, "error": str(error)}, 1
        # Releasing an existing hold must work even if observation is unavailable.
        command = ["left-mouse-up"]
        result.update(command=["wlroots-bridge", *command], observationPreflightError=str(error))
    try:
        result["actionStatus"] = "unknown"
        result["actionSucceeded"] = None
        result["result"] = bridge(*command, timeout=action_timeout(args))
        result.update(actionSucceeded=True, actionStatus="succeeded")
    except ERRORS as error:
        result["actionError"] = str(error)
    try:
        time.sleep(args.wait_ms / 1000)
        if directory is None:
            directory = output_directory(args.output_dir)
        result.update(capture(display, directory, timeout=args.timeout or 30))
        result["screenshotSucceeded"] = True
    except ERRORS as error:
        result["screenshotError"] = str(error)
    success = result["actionSucceeded"] is True and result["screenshotSucceeded"]
    return result, 0 if success else 1


def nonnegative_int(value):
    number = int(value)
    if number < 0:
        raise argparse.ArgumentTypeError("Must be nonnegative")
    return number


def positive_int(value):
    number = nonnegative_int(value)
    if number == 0:
        raise argparse.ArgumentTypeError("Must be positive")
    return number


def finite_number(value):
    number = float(value)
    if not math.isfinite(number):
        raise argparse.ArgumentTypeError("Must be finite")
    return number


def positive_number(value):
    number = finite_number(value)
    if number <= 0:
        raise argparse.ArgumentTypeError("Must be positive")
    return number


def make_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in (*QUERIES, "screenshot", "zoom", "point", *ACTIONS):
        command = commands.add_parser(name)
        command.add_argument("--timeout", type=positive_number, help="Backend timeout in seconds")
        if name in QUERIES:
            continue
        if name != "point":
            command.add_argument("--display", help="Observation screen ID; never changes keyboard focus")
            command.add_argument("--output-dir", type=Path, help="Existing parent directory for captures")
        if name in ("point", "move", "click", "scroll", "drag"):
            command.add_argument("--metadata", type=Path, required=True)
        elif name in ACTIONS:
            command.add_argument("--metadata", type=Path, help="Infer the observation display from a capture")
        if name in ACTIONS:
            command.add_argument("--wait-ms", type=nonnegative_int, default=300, help="Post-action settle time (default: 300)")
            command.add_argument("--dry-run", action="store_true", help="Build the command only; no backend calls or files")
        if name in ("point", "move", "click", "scroll"):
            command.add_argument("--x", type=finite_number, required=True)
            command.add_argument("--y", type=finite_number, required=True)
        if name == "click":
            command.add_argument("--button", choices=("left", "right", "middle"), default="left")
            command.add_argument("--count", type=positive_int, default=1)
            command.add_argument("--modifier", action="append", default=[])
        elif name == "scroll":
            command.add_argument("--dx", type=int, default=0, help="Wheel notches; positive scrolls right")
            command.add_argument("--dy", type=int, default=0, help="Wheel notches; positive scrolls down")
        elif name == "drag":
            for flag in ("from-x", "from-y", "to-x", "to-y"):
                command.add_argument(f"--{flag}", type=finite_number, required=True)
            command.add_argument("--to-metadata", type=Path, help="Destination capture for a cross-screen drag")
        elif name == "type":
            text = command.add_mutually_exclusive_group(required=True)
            text.add_argument("--text")
            text.add_argument("--text-file", type=Path, help="Read UTF-8 text verbatim")
            command.add_argument("--delay-ms", type=nonnegative_int, default=12)
        elif name == "key":
            command.add_argument("--keys", required=True, help="A key or chord, such as ctrl+shift+tab")
            command.add_argument("--repeat", type=positive_int, default=1)
        elif name == "hold-key":
            command.add_argument("--key", action="append", required=True)
            command.add_argument("--duration-ms", type=nonnegative_int, required=True)
        elif name == "activate-window":
            command.add_argument("--window", required=True)
        elif name == "zoom":
            for flag in ("x", "y"):
                command.add_argument(f"--{flag}", type=nonnegative_int, required=True, help="Screen-local logical pixels")
            for flag in ("w", "h"):
                command.add_argument(f"--{flag}", type=positive_int, required=True, help="Screen-local logical pixels")
    return parser


def main():
    args = make_parser().parse_args()
    try:
        code = 0
        if args.command in QUERIES:
            result = bridge(args.command, timeout=args.timeout or 30)
        elif args.command == "point":
            result = map_point(read_metadata(args.metadata), args.x, args.y)
        elif args.command in ACTIONS:
            result, code = perform_action(args)
        else:
            region = (args.x, args.y, args.w, args.h) if args.command == "zoom" else None
            result = capture(args.display, output_directory(args.output_dir), args.timeout or 30, region)
    except ERRORS as error:
        result, code = {"error": str(error)}, 1
    print(json.dumps(result))
    return code


if __name__ == "__main__":
    sys.exit(main())
