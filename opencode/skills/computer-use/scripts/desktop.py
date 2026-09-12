#!/usr/bin/env python3
"""Operate Wayland windows with PNG observations and configurable batches.

Usage: desktop.py screenshot [--display ID] [--output-dir DIR]
       desktop.py zoom --display ID --x X --y Y --w W --h H
       desktop.py point --metadata FILE --x X --y Y
       desktop.py click --metadata FILE --x X --y Y [--dry-run]
       desktop.py type --display ID --text TEXT
       desktop.py activate-window --app-id APP --title TEXT
       desktop.py paste --window niri:ID --text-file FILE
       desktop.py batch --file FILE [--display ID] [--metadata FILE]
       desktop.py --help
"""

import argparse
import base64
import json
import math
import os
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile
import time


QUERIES = ("doctor", "screens", "windows", "frontmost-app", "clipboard-read")
POINTER_ACTIONS = ("move", "click", "scroll", "drag", "mouse-down", "mouse-up")
KEYBOARD_ACTIONS = ("type", "key", "hold-key", "paste")
ACTIONS = (*POINTER_ACTIONS, *KEYBOARD_ACTIONS, "activate-window", "clipboard-write")
ERRORS = (OSError, ValueError, KeyError, TypeError, subprocess.TimeoutExpired)


def temp_parent():
    return Path("/tmp/opencode") if Path("/tmp/opencode").is_dir() else Path("/tmp")


def require_command(name):
    executable = shutil.which(name)
    if executable is None:
        raise ValueError(f"{name} is not available on PATH; install it separately.")
    return executable


def run_command(name, *args, timeout=30, input_data=None):
    executable = require_command(name)
    # Mouse holders and clipboard owners fork with inherited stdout/stderr.
    with tempfile.TemporaryFile(dir=temp_parent()) as stdout, tempfile.TemporaryFile(
        dir=temp_parent()
    ) as stderr:
        stdin = {"input": input_data} if input_data is not None else {"stdin": subprocess.DEVNULL}
        result = subprocess.run(
            [executable, *args], stdout=stdout, stderr=stderr, timeout=timeout, **stdin
        )
        stdout.seek(0)
        stderr.seek(0)
        output = stdout.read()
        error = stderr.read().decode("utf-8", errors="replace")
    if result.returncode:
        detail = error.strip() or output.decode("utf-8", errors="replace").strip()
        raise ValueError(f"{name} exited {result.returncode}: {detail}")
    return output


def bridge(*args, timeout=30):
    return json.loads(run_command("wlroots-bridge", *args, timeout=timeout))


def has_niri():
    return bool(os.environ.get("NIRI_SOCKET") and shutil.which("niri"))


def niri_query(name, timeout=30):
    return json.loads(run_command("niri", "msg", "--json", name, timeout=timeout))


def niri_windows(timeout=30):
    windows = niri_query("windows", timeout)
    workspaces = {ws["id"]: ws for ws in niri_query("workspaces", timeout)}
    return [
        {
            "id": f"niri:{window['id']}", "app_id": window.get("app_id"),
            "title": window.get("title"), "workspace_id": window.get("workspace_id"),
            "displayId": workspaces.get(window.get("workspace_id"), {}).get("output"),
            "is_focused": window["is_focused"],
        }
        for window in sorted(windows, key=lambda window: window["id"])
    ]


def filter_windows(windows, app_id, title):
    return [
        window for window in windows
        if (app_id is None or app_id.casefold() in
            (window.get("app_id") or window.get("desktop_file_name") or "").casefold())
        and (title is None or title.casefold() in (window.get("title") or "").casefold())
    ]


def validate_target_args(args):
    if args.window and (args.app_id is not None or args.title is not None):
        raise ValueError("Use --window or --app-id/--title, not both")
    if args.command == "activate-window" and all(value is None for value in (args.window, args.app_id, args.title)):
        raise ValueError("activate-window requires --window or --app-id/--title")


def resolve_target(args, meta=None):
    validate_target_args(args)
    window_id = args.window
    if not window_id and args.app_id is None and args.title is None:
        window_id = meta.get("windowId") if meta else None
    if not window_id and args.app_id is None and args.title is None:
        return None
    if window_id and not window_id.startswith("niri:"):
        if args.command == "activate-window":
            return None
        raise ValueError("Targeted input/display discovery requires a niri:ID from windows")
    windows = niri_windows(args.timeout or 30)
    candidates = (
        [window for window in windows if window["id"] == window_id]
        if window_id else filter_windows(windows, args.app_id, args.title)
    )
    if not candidates:
        raise ValueError("No matching window; discover windows again or refine the target")
    if len(candidates) != 1:
        raise ValueError(f"Ambiguous target; choose --window from: {json.dumps(candidates)}")
    target = candidates[0]
    if target["displayId"] is None:
        raise ValueError(f"Window {target['id']} has no output; discover windows again")
    return target


def check_focus(window_id, timeout=30, wait=False):
    deadline = time.monotonic() + timeout
    while True:
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise ValueError(f"Timed out waiting for focus on {window_id}")
        window = niri_query("focused-window", remaining)
        if window is not None and f"niri:{window['id']}" == window_id:
            return
        if not wait:
            raise ValueError(f"Window {window_id} is not focused; activate it and inspect the screenshot")
        time.sleep(min(0.05, max(0, deadline - time.monotonic())))


def query(args):
    timeout = args.timeout or 30
    if args.command == "clipboard-read":
        text = run_command("wl-paste", "--no-newline", "--type", "text", timeout=timeout)
        return {"text": text.decode("utf-8")}
    if args.command == "windows":
        windows = niri_windows(timeout) if has_niri() else bridge("windows", timeout=timeout)
        return filter_windows(windows, args.app_id, args.title)
    if args.command == "frontmost-app" and has_niri():
        window = niri_query("focused-window", timeout)
        return {"id": f"niri:{window['id']}", "app_id": window.get("app_id"), "title": window.get("title")} if window else None
    output = bridge(args.command, timeout=timeout)
    if args.command == "doctor":
        output["tools"] = {name: bool(shutil.which(name)) for name in ("grim", "niri", "wl-copy", "wl-paste")}
        output["windowBackend"] = "niri" if has_niri() else "wlroots-bridge"
    return output


def capture_backend(name):
    if name == "auto":
        name = "grim" if shutil.which("grim") else "wlroots-bridge"
    require_command(name)
    return name


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


def capture(display, directory, timeout=30, region=None, backend="auto", window_id=None):
    backend = capture_backend(backend)
    screen = select_screen(bridge("screens", timeout=timeout), display)
    geometry = screen["geometry"]
    x, y, w, h = region or (0, 0, geometry["width"], geometry["height"])
    if x < 0 or y < 0 or w <= 0 or h <= 0 or x + w > geometry["width"] or y + h > geometry["height"]:
        raise ValueError("Zoom region must lie within the selected screen's logical bounds")
    if backend == "grim":
        image_path = directory / "screenshot.png"
        selection = ["-o", screen["id"]] if region is None else [
            "-g", f"{geometry['x'] + x},{geometry['y'] + y} {w}x{h}",
        ]
        run_command("grim", "-t", "png", *selection, str(image_path), timeout=timeout)
        with image_path.open("rb") as image:
            header = image.read(24)
        if len(header) != 24 or header[:16] != b"\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR":
            raise ValueError("Expected a PNG screenshot from grim")
        width, height = struct.unpack(">II", header[16:24])
        data = {"width": width, "height": height, "format": "png"}
    elif region is None:
        data = bridge("screenshot", "--display", screen["id"], timeout=timeout)
        validate_metadata(data)
        if data["displayId"] != screen["id"] or geometry_from_metadata(data) != geometry:
            raise ValueError("Screen geometry changed during capture; capture again")
    else:
        data = bridge(
            "zoom", "--display", screen["id"], "--x", str(x), "--y", str(y),
            "--w", str(w), "--h", str(h), timeout=timeout,
        )
    current = select_screen(bridge("screens", timeout=timeout), screen["id"])
    if current["geometry"] != geometry:
        raise ValueError("Screen geometry changed during capture; capture again")
    data.update(
        displayId=screen["id"], displayWidth=w, displayHeight=h,
        originX=geometry["x"] + x, originY=geometry["y"] + y,
        screenGeometry=geometry, captureKind="zoom" if region else "screenshot",
        captureBackend=backend,
    )
    if window_id and window_id.startswith("niri:"):
        data["windowId"] = window_id
    validate_metadata(data)
    if backend == "wlroots-bridge":
        image = base64.b64decode(data.pop("base64"), validate=True)
        if not image.startswith(b"\xff\xd8\xff"):
            raise ValueError("Expected a JPEG screenshot from wlroots-bridge")
        image_path = directory / "screenshot.jpg"
        image_path.write_bytes(image)
    metadata_path = directory / "screenshot.json"
    metadata_path.write_text(json.dumps(data, indent=2) + "\n", encoding="ascii")
    return {"image": str(image_path), "metadata": str(metadata_path), **data}


def output_directory(parent):
    parent = parent if parent is not None else temp_parent()
    return Path(tempfile.mkdtemp(prefix="computer-use-", dir=parent)).resolve()


def action_command(args, meta):
    name = args.command
    if name == "clipboard-write":
        return ["wl-copy", "--type", "text/plain;charset=utf-8"]
    if name == "activate-window":
        if args.window is None:
            if args.app_id is None and args.title is None:
                raise ValueError("activate-window requires --window or --app-id/--title")
            return ["niri", "msg", "--json", "action", "focus-window", "--id", "<resolved-window-id>"]
        if args.window.startswith("niri:"):
            window_id = str(int(args.window.removeprefix("niri:")))
            return ["niri", "msg", "--json", "action", "focus-window", "--id", window_id]
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
        return ["wlroots-bridge", *command]
    if name == "drag":
        start = map_point(meta, args.from_x, args.from_y)
        end_meta = read_metadata(args.to_metadata) if args.to_metadata else meta
        end = map_point(end_meta, args.to_x, args.to_y)
        return [
            "wlroots-bridge", "pointer-drag", "--from-x", str(start["x"]), "--from-y", str(start["y"]),
            "--to-x", str(end["x"]), "--to-y", str(end["y"]),
        ]
    if name in ("mouse-down", "mouse-up"):
        return ["wlroots-bridge", f"left-{name}"]
    if name == "type":
        return ["wlroots-bridge", "type", f"--text={args.text}", "--delay-ms", str(args.delay_ms)]
    if name == "key":
        return ["wlroots-bridge", "key-sequence", f"--keys={args.keys}", "--repeat", str(args.repeat)]
    if name == "paste":
        return ["wlroots-bridge", "key-sequence", f"--keys={args.keys}", "--repeat", "1"]
    if name == "hold-key":
        return ["wlroots-bridge", "hold-key", *[f"--key={key}" for key in args.key], "--duration-ms", str(args.duration_ms)]
    return ["wlroots-bridge", "activate-window", f"--window={args.window}"]


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


def preflight(args, meta, display, capture_after=True):
    timeout = args.timeout or 30
    capabilities = bridge("doctor", timeout=timeout)["globals"]
    target = resolve_target(args, meta)
    required = ["screencopy"] if capture_after else []
    if args.command in POINTER_ACTIONS:
        required += ["virtual_pointer"]
    if args.command in KEYBOARD_ACTIONS or (args.command == "click" and args.modifier):
        required += ["virtual_keyboard"]
    if args.command == "activate-window" and target is None:
        required += ["foreign_toplevel_wlr"]
    missing = [name for name in required if not capabilities.get(name)]
    if missing:
        raise ValueError(f"Required Wayland capabilities missing: {', '.join(missing)}")
    if capture_after:
        capture_backend(args.capture_backend)
    if args.command == "clipboard-write" or (args.command == "paste" and args.text is not None):
        require_command("wl-copy")
    if display is None:
        display = target["displayId"] if target else meta["displayId"] if meta else None
    screens = bridge("screens", timeout=timeout)
    observation_screen = select_screen(screens, display)
    if capture_after and args.capture_region:
        x, y, w, h = args.capture_region
        geometry = observation_screen["geometry"]
        if w <= 0 or h <= 0 or x + w > geometry["width"] or y + h > geometry["height"]:
            raise ValueError("Capture region must lie within the observation screen's logical bounds")
    if meta is not None:
        check_geometry(meta, select_screen(screens, meta["displayId"]))
        if target and args.command in ("move", "click", "scroll", "drag") and meta["displayId"] != target["displayId"]:
            raise ValueError("Target window is on another output; take a new screenshot before acting")
    if args.command == "drag" and args.to_metadata:
        end_meta = read_metadata(args.to_metadata)
        check_geometry(end_meta, select_screen(screens, end_meta["displayId"]))
    if args.command in ("move", "click", "scroll", "drag"):
        if any(s["geometry"][axis] < 0 for s in screens for axis in ("x", "y")):
            raise ValueError("Backend pointer mapping is unreliable for negative output origins")
    if target and args.command in KEYBOARD_ACTIONS:
        check_focus(target["id"], timeout)
    return observation_screen["id"], target


def perform_action(args, capture_after=True):
    result = {
        "action": args.command, "actionSucceeded": False, "actionStatus": "not-started",
        "screenshotRequested": capture_after, "screenshotSucceeded": False,
        "image": None, "metadata": None,
    }
    display, directory, window_id = args.display, None, args.window
    try:
        validate_target_args(args)
        meta = read_metadata(args.metadata)
        if args.command in ("type", "paste", "clipboard-write") and args.text_file:
            args.text = args.text_file.read_text(encoding="utf-8")
        command = action_command(args, meta)
        result["command"] = command
        if args.dry_run:
            return {
                **result, "dryRun": True, "captureDisplay": display,
                "target": {"window": args.window, "app_id": args.app_id, "title": args.title},
                "clipboardWriteRequested": args.command == "clipboard-write" or (args.command == "paste" and args.text is not None),
            }, 0
        display, target = preflight(args, meta, display, capture_after)
        if target:
            window_id = target["id"]
            result["windowId"] = window_id
            if args.command == "activate-window":
                result["target"] = target
                command = ["niri", "msg", "--json", "action", "focus-window", "--id", window_id.removeprefix("niri:")]
                result["command"] = command
        if capture_after:
            directory = output_directory(args.output_dir)
    except ERRORS as error:
        if args.command != "mouse-up" or args.dry_run:
            return {**result, "error": str(error)}, 1
        # Releasing an existing hold must work even if observation is unavailable.
        command = ["wlroots-bridge", "left-mouse-up"]
        result.update(command=command, observationPreflightError=str(error))
    try:
        result["actionStatus"] = "unknown"
        result["actionSucceeded"] = None
        timeout = action_timeout(args)
        if args.command in ("clipboard-write", "paste") and args.text is not None:
            run_command("wl-copy", "--type", "text/plain;charset=utf-8", input_data=args.text.encode("utf-8"), timeout=timeout)
            result["clipboardWritten"] = True
        if args.command == "clipboard-write":
            result["result"] = {"characters": len(args.text), "mimeType": "text/plain;charset=utf-8"}
        elif command[0] == "niri":
            run_command(*command, timeout=timeout)
            check_focus(window_id, timeout, wait=True)
            result["target"]["is_focused"] = True
            result["result"] = {"focused": True}
        else:
            if args.command == "paste" and window_id:
                check_focus(window_id, timeout)
            result["result"] = bridge(*command[1:], timeout=timeout)
        result.update(actionSucceeded=True, actionStatus="succeeded")
    except ERRORS as error:
        result["actionError"] = str(error)
    try:
        time.sleep(args.wait_ms / 1000)
        if capture_after:
            if directory is None:
                directory = output_directory(args.output_dir)
            result.update(capture(
                display, directory, timeout=args.timeout or 30,
                region=args.capture_region, backend=args.capture_backend, window_id=window_id,
            ))
            result["screenshotSucceeded"] = True
    except ERRORS as error:
        result["screenshotError"] = str(error)
    success = result["actionSucceeded"] is True and (not capture_after or result["screenshotSucceeded"])
    return result, 0 if success else 1


def perform_batch(args):
    steps = json.load(sys.stdin) if str(args.file) == "-" else json.loads(args.file.read_text(encoding="utf-8"))
    if not isinstance(steps, list) or not steps:
        raise ValueError("Batch file must contain a nonempty JSON array of steps")
    defaults = []
    for name in ("display", "window", "app_id", "title", "metadata", "output_dir", "wait_ms", "timeout", "capture_backend"):
        value = getattr(args, name)
        if value is not None:
            defaults.append(f"--{name.replace('_', '-')}={value}")
    if args.capture_region:
        defaults += ["--capture-region", *map(str, args.capture_region)]
    if args.dry_run:
        defaults.append("--dry-run")
    parser = make_parser()
    plan = []
    for index, step in enumerate(steps, start=1):
        if not isinstance(step, dict) or set(step) - {"action", "args", "screenshot"}:
            raise ValueError(f"Step {index}: expected action, args, and optional screenshot")
        action = step.get("action")
        flags = step.get("args", [])
        capture_after = step.get("screenshot", True)
        if action not in ACTIONS:
            raise ValueError(f"Step {index}: action must be one of {', '.join(ACTIONS)}")
        if not isinstance(flags, list) or not all(isinstance(flag, str) for flag in flags):
            raise ValueError(f"Step {index}: args must be an array of CLI argument strings")
        if type(capture_after) is not bool:
            raise ValueError(f"Step {index}: screenshot must be true or false")
        target_flags = ("--window", "--app-id", "--title")
        explicit_target = any(flag.split("=", 1)[0] in target_flags for flag in flags)
        step_defaults = [flag for flag in defaults if not explicit_target or flag.split("=", 1)[0] not in target_flags]
        try:
            parsed = parser.parse_args([action, *step_defaults, *flags])
            validate_target_args(parsed)
        except (SystemExit, ValueError) as error:
            raise ValueError(f"Step {index}: invalid action arguments") from error
        inherits_target = not explicit_target and any(value is not None for value in (args.window, args.app_id, args.title))
        plan.append((parsed, capture_after, inherits_target))
    results = []
    selected_window = None
    summary_keys = (
        "action", "actionSucceeded", "actionStatus", "windowId", "clipboardWritten",
        "screenshotRequested", "screenshotSucceeded", "image", "metadata",
        "width", "height", "displayId", "captureBackend", "error", "actionError",
        "screenshotError", "observationPreflightError",
    )
    for index, (parsed, capture_after, inherits_target) in enumerate(plan, start=1):
        if inherits_target and selected_window:
            parsed.window, parsed.app_id, parsed.title = selected_window, None, None
        result, code = perform_action(parsed, capture_after)
        if inherits_target and result.get("windowId"):
            selected_window = result["windowId"]
        summary = result if args.dry_run else {key: result[key] for key in summary_keys if key in result}
        results.append({"step": index, **summary})
        if code:
            return {"action": "batch", "succeeded": False, "steps": results, "stoppedAt": index}, code
    return {
        "action": "batch", "succeeded": True, "dryRun": args.dry_run,
        "steps": results, "stoppedAt": None,
    }, 0


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
    for name in (*QUERIES, "screenshot", "zoom", "point", "batch", *ACTIONS):
        command = commands.add_parser(name)
        command.add_argument("--timeout", type=positive_number, help="Backend timeout in seconds")
        if name == "windows" or name not in (*QUERIES, "point"):
            command.add_argument("--app-id", help="Case-insensitive application ID substring")
            command.add_argument("--title", help="Case-insensitive window title substring")
        if name in QUERIES:
            continue
        if name != "point":
            command.add_argument("--display", help="Observation screen ID; never changes keyboard focus")
            command.add_argument("--output-dir", type=Path, help="Existing parent directory for captures")
            command.add_argument("--window", help="Target niri:ID from windows; activation also accepts bridge IDs")
            command.add_argument("--capture-backend", choices=("auto", "grim", "wlroots-bridge"), default="auto", help="Prefer grim PNG when installed (default: auto)")
        if name in ("point", "move", "click", "scroll", "drag"):
            command.add_argument("--metadata", type=Path, required=True)
        elif name in (*ACTIONS, "batch"):
            command.add_argument("--metadata", type=Path, help="Infer the observation display from a capture")
        if name in (*ACTIONS, "batch"):
            command.add_argument("--capture-region", type=nonnegative_int, nargs=4, metavar=("X", "Y", "W", "H"), help="Observe a screen-local logical region after input")
            command.add_argument("--wait-ms", type=nonnegative_int, default=300, help="Post-action settle time (default: 300)")
            command.add_argument("--dry-run", action="store_true", help="Build the command only; no backend calls or files")
        if name in ("point", "move", "click", "scroll"):
            command.add_argument("--x", type=finite_number, required=True)
            command.add_argument("--y", type=finite_number, required=True)
        if name == "batch":
            command.add_argument("--file", type=Path, required=True, help="JSON array of action/args/screenshot steps; - reads stdin")
        elif name == "click":
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
        elif name in ("type", "clipboard-write", "paste"):
            text = command.add_mutually_exclusive_group(required=name != "paste")
            text.add_argument("--text")
            text.add_argument("--text-file", type=Path, help="Read UTF-8 text verbatim")
            if name == "type":
                command.add_argument("--delay-ms", type=nonnegative_int, default=12)
            elif name == "paste":
                command.add_argument("--keys", default="ctrl+v", help="Paste shortcut (default: ctrl+v); terminals often use ctrl+shift+v")
        elif name == "key":
            command.add_argument("--keys", required=True, help="A key or chord, such as ctrl+shift+tab")
            command.add_argument("--repeat", type=positive_int, default=1)
        elif name == "hold-key":
            command.add_argument("--key", action="append", required=True)
            command.add_argument("--duration-ms", type=nonnegative_int, required=True)
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
            result = query(args)
        elif args.command == "point":
            result = map_point(read_metadata(args.metadata), args.x, args.y)
        elif args.command in ACTIONS:
            result, code = perform_action(args)
        elif args.command == "batch":
            result, code = perform_batch(args)
        else:
            region = (args.x, args.y, args.w, args.h) if args.command == "zoom" else None
            capabilities = bridge("doctor", timeout=args.timeout or 30)["globals"]
            if not capabilities.get("screencopy"):
                raise ValueError("Required Wayland capability missing: screencopy")
            target = resolve_target(args)
            display = args.display or (target["displayId"] if target else None)
            result = capture(
                display, output_directory(args.output_dir), args.timeout or 30,
                region, args.capture_backend, target["id"] if target else None,
            )
    except ERRORS as error:
        result, code = {"error": str(error)}, 1
    print(json.dumps(result))
    return code


if __name__ == "__main__":
    sys.exit(main())
