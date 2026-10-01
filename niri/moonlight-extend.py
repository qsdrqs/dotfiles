#!/usr/bin/env python3
"""Show two paired Sunshine desktops on the laptop's niri outputs."""

import ipaddress
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import tempfile
import time
import urllib.request
import xml.etree.ElementTree as ET


DEFAULT_HOST = "192.168.12.8"
PORTS = (31089, 31189)
CONFIG_NAME = "Moonlight Game Streaming Project/Moonlight.conf"


def graphical_environment():
    result = subprocess.run(
        ["systemctl", "--user", "show-environment"],
        capture_output=True,
        text=True,
        check=True,
    )
    session = dict(line.split("=", 1) for line in result.stdout.splitlines() if "=" in line)
    env = os.environ.copy()
    env.setdefault("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    for key in ("NIRI_SOCKET", "WAYLAND_DISPLAY"):
        if not env.get(key):
            env[key] = session.get(key, "")

    niri_socket = Path(env["NIRI_SOCKET"]) if env["NIRI_SOCKET"] else None
    wayland_socket = Path(env["XDG_RUNTIME_DIR"]) / env["WAYLAND_DISPLAY"]
    if not niri_socket or not niri_socket.is_socket() or not wayland_socket.is_socket():
        raise RuntimeError("An active niri/Wayland session is required to start Moonlight")
    return env


def check_existing_streams():
    result = subprocess.run(
        [
            "pgrep", "-u", str(os.getuid()), "-f",
            r"^moonlight stream .*:(31089|31189) Desktop",
        ],
        stdout=subprocess.DEVNULL,
        check=False,
    )
    if result.returncode == 0:
        raise RuntimeError("Moonlight is already running for a laptop display; stop it before starting another pair")
    if result.returncode != 1:
        raise RuntimeError("Could not check for existing Moonlight streams")


def restricted_profile(host, env, directory):
    host = str(ipaddress.IPv4Address(host))
    source_dir = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    sections = {}
    name = None
    for line in (source_dir / CONFIG_NAME).read_text(encoding="utf-8").splitlines():
        if line.startswith("[") and line.endswith("]"):
            name = line[1:-1]
            sections[name] = []
        elif name is not None:
            sections[name].append(line)

    host_lines = sections["hosts"]
    selected = []
    for port in PORTS:
        with urllib.request.urlopen(f"http://{host}:{port}/serverinfo", timeout=8) as response:
            uuid = ET.fromstring(response.read()).findtext("uniqueid")
        if not uuid:
            raise RuntimeError(f"No server UUID returned on port {port}")
        indices = [
            match.group(1)
            for line in host_lines
            if (match := re.fullmatch(r"(\d+)\\uuid=(.*)", line))
            and match.group(2).strip('"').casefold() == uuid.casefold()
        ]
        if len(indices) != 1:
            raise RuntimeError(f"Expected one paired host on port {port}, found {len(indices)}")
        selected.append((indices[0], port))

    general = [line for line in sections["General"] if line.split("=", 1)[0] != "mdns"]
    sections["General"] = [*general, "mdns=false"]
    result = []
    for section, lines in sections.items():
        if section.casefold().startswith("hosts"):
            continue
        result.extend([f"[{section}]", *lines, ""])
    result.append("[hosts]")
    for new_index, (old_index, port) in enumerate(selected, 1):
        prefix = old_index + "\\"
        values = {
            line[len(prefix):].split("=", 1)[0]: line.split("=", 1)[1]
            for line in host_lines if line.startswith(prefix) and "=" in line
        }
        for key in ("localaddress", "manualaddress", "remoteaddress"):
            values[key] = host
        for key in ("localport", "manualport", "remoteport"):
            values[key] = str(port)
        values["ipv6address"] = ""
        values["ipv6port"] = "0"
        result.extend(f"{new_index}\\{key}={value}" for key, value in values.items())
    result.append(f"size={len(selected)}")

    config_dir = Path(directory) / "Moonlight Game Streaming Project"
    config_dir.mkdir(mode=0o700)
    fd = os.open(config_dir / "Moonlight.conf", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as output:
        output.write("\n".join(result) + "\n")
    env["XDG_CONFIG_HOME"] = directory


def niri_json(env, topic):
    result = subprocess.run(
        ["niri", "msg", "--json", topic],
        env=env,
        capture_output=True,
        text=True,
        check=True,
    )
    return json.loads(result.stdout)


def place_window(env, process, title, output):
    for _ in range(60):
        if process.poll() is not None:
            raise RuntimeError(f"Moonlight exited before opening {title}: {process.returncode}")
        windows = niri_json(env, "windows")
        window = next((item for item in windows if item["pid"] == process.pid and item["title"] == title), None)
        if window:
            workspaces = niri_json(env, "workspaces")
            workspace = next(item for item in workspaces if item["id"] == window["workspace_id"])
            if workspace["output"] == output:
                return
            subprocess.run(
                ["niri", "msg", "action", "move-window-to-monitor", "--id", str(window["id"]), output],
                env=env,
                check=True,
            )
        time.sleep(0.5)
    raise RuntimeError(f"Could not place {title} on {output} within 30 seconds")


def run_streams(host, env):
    processes = []
    try:
        for port in PORTS:
            processes.append(subprocess.Popen([
                "moonlight", "stream", f"{host}:{port}", "Desktop",
                "--resolution", "2880x1800", "--fps", "60", "--bitrate", "30000",
                "--display-mode", "fullscreen", "--audio-on-host",
            ], env=env))

        place_window(env, processes[0], "DESKSERVER-laptop-1 - Moonlight", "eDP-1")
        place_window(env, processes[1], "DESKSERVER-laptop-2 - Moonlight", "eDP-2")
        for process in processes:
            if process.wait() != 0:
                raise RuntimeError(f"Moonlight exited with status {process.returncode}")
    finally:
        for process in processes:
            if process.poll() is None:
                process.terminate()
        for process in processes:
            process.wait()


def main():
    env = graphical_environment()
    check_existing_streams()
    host = os.environ.get("MOONLIGHT_HOST", DEFAULT_HOST)
    if "MOONLIGHT_HOST" in os.environ:
        with tempfile.TemporaryDirectory(prefix="moonlight-extend-", dir=env["XDG_RUNTIME_DIR"]) as directory:
            restricted_profile(host, env, directory)
            run_streams(host, env)
    else:
        run_streams(host, env)
    return 0


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda signum, frame: sys.exit(128 + signum))
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, RuntimeError, subprocess.CalledProcessError) as error:
        print(f"moonlight-extend: {error}", file=sys.stderr)
        sys.exit(1)
