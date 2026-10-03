#!/usr/bin/env python3
"""Run an isolated headless niri desktop for computer use.

Usage: agent_desktop.py start
       agent_desktop.py status
       agent_desktop.py spawn -- COMMAND [ARGS...]
       agent_desktop.py chrome [--audio] [-- CHROME_ARGS...]
       agent_desktop.py vnc
       agent_desktop.py stop

The agent desktop is a second niri instance on the headless backend, started as
the transient systemd user service computer-use-agent.service together with a
private D-Bus session bus. It shares HOME and XDG_RUNTIME_DIR with the user, so
applications run with the user's real configuration, but they connect to the
agent compositor and the private bus, never to the main session. XDG_SEAT names
a seat without devices so the agent compositor never reads the physical keyboard
and mouse.

The internal secrets-bridge subcommand owns org.freedesktop.secrets on the
private bus and forwards it to the main session bus, so agent applications can
use the user's keyring. Chrome runs on a reflink copy of the user's profile that
is made at start and deleted at stop.

Every command prints one JSON object and exits 1 on failure.
"""

import argparse
import json
import os
from pathlib import Path
import re
import select
import shutil
import socket
import struct
import subprocess
import sys
import time
from urllib.parse import unquote


UNIT_NAME = "computer-use-agent"
UNIT = f"{UNIT_NAME}.service"
SECRETS_NAME = "org.freedesktop.secrets"
DBUS_NAME = "org.freedesktop.DBus"
DBUS_PATH = "/org/freedesktop/DBus"
CHROME_FLAGS = (
    "--password-store=gnome-libsecret", "--no-first-run", "--no-default-browser-check", "--disable-sync",
)
# Variables that would connect agent processes to the main session or describe its login session.
BLOCKED_ENV = {
    "WAYLAND_DISPLAY", "WAYLAND_SOCKET", "DISPLAY", "XAUTHORITY", "DBUS_SESSION_BUS_ADDRESS",
    "DBUS_SESSION_BUS_PID", "DBUS_SESSION_BUS_WINDOWID", "NIRI_SOCKET", "SWAYSOCK", "I3SOCK",
    "HYPRLAND_INSTANCE_SIGNATURE", "XDG_SESSION_ID", "XDG_SESSION_PATH", "XDG_SESSION_CLASS",
    "XDG_SESSION_DESKTOP", "XDG_SESSION_TYPE", "XDG_SEAT", "XDG_SEAT_PATH", "XDG_VTNR",
    "XDG_ACTIVATION_TOKEN", "DESKTOP_STARTUP_ID", "SESSION_MANAGER", "NOTIFY_SOCKET", "INVOCATION_ID",
    "JOURNAL_STREAM", "MANAGERPID", "LISTEN_PID", "LISTEN_FDS", "LISTEN_FDNAMES", "WINDOWID",
    "GPG_TTY", "SSH_TTY", "SSH_CONNECTION", "SSH_CLIENT", "TMUX", "TMUX_PANE", "STY",
}
BLOCKED_ENV_PREFIXES = ("KITTY_",)
# The headless backend still runs libinput. XDG_SEAT selects a udev seat that has no
# devices, otherwise the agent compositor would read the user's keyboard and mouse from seat0.
AGENT_ENV = {
    "XDG_SEAT": "seat-agent", "NIRI_BACKEND": "headless",
    "XDG_SESSION_TYPE": "wayland", "XDG_CURRENT_DESKTOP": "niri",
}
SAFE_PATH = re.compile(r"[A-Za-z0-9_./+-]+")
ERRORS = (OSError, ValueError, KeyError, subprocess.TimeoutExpired)

METHOD_CALL, METHOD_RETURN, ERROR, SIGNAL = 1, 2, 3, 4
NO_REPLY_EXPECTED = 1
FIELD_PATH, FIELD_INTERFACE, FIELD_MEMBER, FIELD_ERROR_NAME = 1, 2, 3, 4
FIELD_REPLY_SERIAL, FIELD_DESTINATION, FIELD_SENDER, FIELD_SIGNATURE = 5, 6, 7, 8


def runtime_dir():
    base = os.environ.get("XDG_RUNTIME_DIR")
    if not base:
        raise ValueError("XDG_RUNTIME_DIR is not set")
    return Path(base) / UNIT_NAME


def cache_dir():
    return Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache") / UNIT_NAME


def chrome_source():
    return Path(os.environ.get("XDG_CONFIG_HOME") or Path.home() / ".config") / "google-chrome"


def chrome_copy():
    return cache_dir() / "google-chrome"


def safe_path(path):
    text = str(path)
    if not SAFE_PATH.fullmatch(text):
        raise ValueError(f"Path contains characters that cannot be quoted safely: {text}")
    return text


def run(*args, timeout=30, check=True):
    result = subprocess.run(args, capture_output=True, timeout=timeout)
    if check and result.returncode:
        detail = result.stderr.decode("utf-8", errors="replace").strip() or result.stdout.decode("utf-8", errors="replace").strip()
        raise ValueError(f"{args[0]} exited {result.returncode}: {detail}")
    return result


def require_command(name):
    if shutil.which(name) is None:
        raise ValueError(f"{name} is not available on PATH")
    return name


def unit_property(name):
    return run("systemctl", "--user", "show", "--property", name, "--value", UNIT).stdout.decode().strip()


def unit_active():
    return unit_property("ActiveState") == "active"


def unit_pids():
    cgroup = unit_property("ControlGroup")
    if not cgroup:
        return []
    try:
        return [int(pid) for pid in (Path("/sys/fs/cgroup") / cgroup.lstrip("/") / "cgroup.procs").read_text().split()]
    except OSError:
        return []


def niri_pid():
    for pid in unit_pids():
        try:
            if Path(f"/proc/{pid}/comm").read_text().strip() == "niri":
                return pid
        except OSError:
            continue
    return None


def open_input_devices(pid):
    try:
        fds = list(Path(f"/proc/{pid}/fd").iterdir())
    except OSError:
        return None
    devices = set()
    for fd in fds:
        try:
            target = os.readlink(fd)
        except OSError:
            continue
        if target.startswith("/dev/input/"):
            devices.add(target)
    return sorted(devices)


def read_agent_env(runtime):
    data = (runtime / "agent.env").read_bytes().decode("utf-8", errors="replace")
    return dict(item.split("=", 1) for item in data.split("\0") if "=" in item)


def tail(path, lines=20):
    try:
        return "\n".join(path.read_text(errors="replace").splitlines()[-lines:])
    except OSError:
        return ""


def write_bus_config(runtime):
    (runtime / "bus.conf").write_text(f'''<!DOCTYPE busconfig PUBLIC "-//freedesktop//DTD D-Bus Bus Configuration 1.0//EN"
 "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
<busconfig>
  <type>session</type>
  <keep_umask/>
  <listen>unix:path={safe_path(runtime / "bus")}</listen>
  <auth>EXTERNAL</auth>
  <policy context="default">
    <allow send_destination="*" eavesdrop="true"/>
    <allow eavesdrop="true"/>
    <allow own="*"/>
    <allow user="*"/>
  </policy>
</busconfig>
''')


def write_niri_config(runtime):
    # niri gives its children a null stdio, so the bridge logs through a shell redirection.
    env_file = safe_path(runtime / "agent.env")
    python = safe_path(sys.executable)
    script = safe_path(Path(__file__).resolve())
    log = safe_path(runtime / "secrets-bridge.log")
    (runtime / "niri.kdl").write_text(f'''hotkey-overlay {{
    skip-at-startup
}}
prefer-no-csd
screenshot-path null
binds {{
}}
spawn-at-startup "sh" "-c" "env -0 > \\"$0.tmp\\" && mv \\"$0.tmp\\" \\"$0\\"" "{env_file}"
spawn-at-startup "sh" "-c" "exec \\"$0\\" \\"$1\\" secrets-bridge >> \\"$2\\" 2>&1" "{python}" "{script}" "{log}"
''')


def copy_chrome_profile():
    source, target = chrome_source(), chrome_copy()
    if not source.is_dir():
        return None
    staging = target.with_name(target.name + ".tmp")
    if staging.exists():
        shutil.rmtree(staging)
    target.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
    run("cp", "-a", "--reflink=auto", str(source), str(staging), timeout=600)
    # Drop the running instance's locks, its DevTools port, and the tabs it would restore.
    for pattern in ("Singleton*", "DevToolsActivePort", "*/Sessions"):
        for path in staging.glob(pattern):
            if path.is_dir() and not path.is_symlink():
                shutil.rmtree(path)
            else:
                path.unlink()
    staging.rename(target)
    return target


def manager_environment_names():
    output = run("systemctl", "--user", "show-environment").stdout.decode("utf-8", errors="replace")
    return {line.split("=", 1)[0] for line in output.splitlines() if "=" in line}


def agent_environment():
    environment = {
        key: value for key, value in os.environ.items()
        if key not in BLOCKED_ENV and not key.startswith(BLOCKED_ENV_PREFIXES) and "\n" not in value
    }
    dropped = sorted(key for key, value in os.environ.items() if "\n" in value)
    environment.update(AGENT_ENV)
    # The service also inherits the user manager's environment, which carries the main session's
    # sockets. UnsetEnvironment applies after the explicit values, so it must not name any of them.
    blocked = BLOCKED_ENV | {name for name in manager_environment_names() if name.startswith(BLOCKED_ENV_PREFIXES)}
    return environment, sorted(blocked - environment.keys()), dropped


def align(offset, size):
    return offset + (-offset % size)


def unpack_basic(endian, signature, data, offset):
    if signature in ("s", "o"):
        offset = align(offset, 4)
        (length,) = struct.unpack_from(endian + "I", data, offset)
        offset += 4
        return data[offset:offset + length].decode("utf-8"), offset + length + 1
    if signature == "g":
        length = data[offset]
        offset += 1
        return data[offset:offset + length].decode("ascii"), offset + length + 1
    if signature in ("u", "b"):
        offset = align(offset, 4)
        (value,) = struct.unpack_from(endian + "I", data, offset)
        return (value != 0 if signature == "b" else value), offset + 4
    raise ValueError(f"Unsupported D-Bus type {signature!r}")


def pack_basic(endian, signature, value, buffer):
    if signature in ("s", "o"):
        data = value.encode("utf-8")
        buffer.extend(b"\0" * (-len(buffer) % 4))
        buffer += struct.pack(endian + "I", len(data)) + data + b"\0"
    elif signature == "g":
        data = value.encode("ascii")
        buffer += bytes([len(data)]) + data + b"\0"
    elif signature in ("u", "b"):
        buffer.extend(b"\0" * (-len(buffer) % 4))
        buffer += struct.pack(endian + "I", int(value))
    else:
        raise ValueError(f"Unsupported D-Bus type {signature!r}")


def pack_body(signature, *values):
    buffer = bytearray()
    for item, value in zip(signature, values):
        pack_basic("<", item, value, buffer)
    return bytes(buffer)


class Message:
    def __init__(self, endian, kind, flags, serial, fields, body):
        self.endian, self.kind, self.flags, self.serial, self.fields, self.body = endian, kind, flags, serial, fields, body

    def field(self, code):
        return self.fields[code][1] if code in self.fields else None

    def first(self, signature):
        return unpack_basic(self.endian, signature, self.body, 0)[0]

    def encode(self, serial):
        fields = bytearray()
        for code, (signature, value) in self.fields.items():
            fields.extend(b"\0" * (-len(fields) % 8))
            fields.append(code)
            pack_basic(self.endian, "g", signature, fields)
            pack_basic(self.endian, signature, value, fields)
        marker = b"l" if self.endian == "<" else b"B"
        header = struct.pack(self.endian + "cBBBIII", marker, self.kind, self.flags, 1, len(self.body), serial, len(fields))
        return header + bytes(fields) + b"\0" * (-(16 + len(fields)) % 8) + self.body


def parse_message(data):
    if len(data) < 16:
        return None, data
    endian = "<" if data[:1] == b"l" else ">"
    kind, flags, _version, body_length, serial, fields_length = struct.unpack_from(endian + "BBBIII", data, 1)
    header_length = align(16 + fields_length, 8)
    if len(data) < header_length + body_length:
        return None, data
    fields, offset = {}, 16
    while offset < 16 + fields_length:
        offset = align(offset, 8)
        code = data[offset]
        signature, offset = unpack_basic(endian, "g", data, offset + 1)
        value, offset = unpack_basic(endian, signature, data, offset)
        fields[code] = (signature, value)
    body = data[header_length:header_length + body_length]
    return Message(endian, kind, flags, serial, fields, body), data[header_length + body_length:]


def connect_bus(address):
    for item in address.split(";"):
        transport, _, parameters = item.partition(":")
        options = dict(part.split("=", 1) for part in parameters.split(",") if "=" in part)
        if transport != "unix" or not ({"path", "abstract"} & options.keys()):
            continue
        sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        if "path" in options:
            sock.connect(unquote(options["path"]))
        else:
            sock.connect(b"\0" + unquote(options["abstract"]).encode("utf-8"))
        return sock
    raise ValueError(f"Unsupported D-Bus address: {address}")


class Bus:
    def __init__(self, address, timeout=10):
        self.sock = connect_bus(address)
        self.sock.settimeout(timeout)
        self.buffer = b""
        self.serial = 0
        uid = str(os.getuid()).encode("ascii").hex()
        self.sock.sendall(b"\0AUTH EXTERNAL " + uid.encode("ascii") + b"\r\n")
        line = b""
        while not line.endswith(b"\r\n"):
            chunk = self.sock.recv(1)
            if not chunk:
                raise ValueError("D-Bus authentication: connection closed")
            line += chunk
        if not line.startswith(b"OK "):
            raise ValueError(f"D-Bus authentication failed: {line.strip().decode(errors='replace')}")
        self.sock.sendall(b"BEGIN\r\n")
        self.unique_name = self.call(DBUS_NAME, DBUS_PATH, DBUS_NAME, "Hello").first("s")

    def send(self, message):
        self.serial += 1
        self.sock.sendall(message.encode(self.serial))
        return self.serial

    def call(self, destination, path, interface, member, signature="", body=b""):
        fields = {
            FIELD_PATH: ("o", path), FIELD_INTERFACE: ("s", interface),
            FIELD_MEMBER: ("s", member), FIELD_DESTINATION: ("s", destination),
        }
        if signature:
            fields[FIELD_SIGNATURE] = ("g", signature)
        serial = self.send(Message("<", METHOD_CALL, 0, 0, fields, body))
        while True:
            reply = self.receive()
            if reply.kind in (METHOD_RETURN, ERROR) and reply.field(FIELD_REPLY_SERIAL) == serial:
                if reply.kind == ERROR:
                    detail = reply.first("s") if (reply.field(FIELD_SIGNATURE) or "").startswith("s") else ""
                    raise ValueError(f"{member} failed: {reply.field(FIELD_ERROR_NAME)} {detail}".strip())
                return reply

    def receive(self):
        while True:
            message, self.buffer = parse_message(self.buffer)
            if message is not None:
                return message
            chunk = self.sock.recv(65536)
            if not chunk:
                raise ValueError("D-Bus connection closed")
            self.buffer += chunk

    def fill(self):
        chunk = self.sock.recv(65536)
        if not chunk:
            raise ValueError("D-Bus connection closed")
        self.buffer += chunk

    def drain(self):
        messages = []
        while True:
            message, self.buffer = parse_message(self.buffer)
            if message is None:
                return messages
            messages.append(message)


def name_has_owner(address, name):
    bus = Bus(address)
    try:
        return bus.call(DBUS_NAME, DBUS_PATH, DBUS_NAME, "NameHasOwner", "s", pack_body("s", name)).first("b")
    finally:
        bus.sock.close()


def log(text):
    print(time.strftime("%Y-%m-%d %H:%M:%S"), text, file=sys.stderr, flush=True)


def forward(message, bus, changes):
    fields = {code: value for code, value in message.fields.items() if code not in (FIELD_SENDER, FIELD_DESTINATION)}
    fields.update(changes)
    return bus.send(Message(message.endian, message.kind, message.flags, 0, fields, message.body))


def secrets_bridge():
    runtime = runtime_dir()
    private_address = os.environ.get("DBUS_SESSION_BUS_ADDRESS")
    if not private_address:
        raise ValueError("DBUS_SESSION_BUS_ADDRESS is not set; the bridge runs inside the agent desktop")
    main_bus = Bus((runtime / "main-bus").read_text().strip())
    private = Bus(private_address)
    # Flag 4 is DBUS_NAME_FLAG_DO_NOT_QUEUE; result 1 means primary owner.
    result = private.call(DBUS_NAME, DBUS_PATH, DBUS_NAME, "RequestName", "su", pack_body("su", SECRETS_NAME, 4)).first("u")
    if result != 1:
        raise ValueError(f"RequestName({SECRETS_NAME}) returned {result}")
    main_bus.call(DBUS_NAME, DBUS_PATH, DBUS_NAME, "AddMatch", "s", pack_body("s", f"type='signal',sender='{SECRETS_NAME}'"))
    log(f"owning {SECRETS_NAME} as {private.unique_name}; forwarding to the main bus as {main_bus.unique_name}")
    for bus in (main_bus, private):
        bus.sock.settimeout(None)
    pending = {}
    while True:
        # Messages that arrived together with an earlier reply are already buffered.
        for message in private.drain():
            if message.kind != METHOD_CALL:
                continue
            serial = forward(message, main_bus, {FIELD_DESTINATION: ("s", SECRETS_NAME)})
            if not message.flags & NO_REPLY_EXPECTED:
                pending[serial] = (message.field(FIELD_SENDER), message.serial)
        for message in main_bus.drain():
            if message.kind in (METHOD_RETURN, ERROR):
                target = pending.pop(message.field(FIELD_REPLY_SERIAL), None)
                if target is not None:
                    forward(message, private, {FIELD_DESTINATION: ("s", target[0]), FIELD_REPLY_SERIAL: ("u", target[1])})
            elif message.kind == SIGNAL and message.field(FIELD_SENDER) != DBUS_NAME:
                forward(message, private, {})
        readable, _, _ = select.select([main_bus.sock, private.sock], [], [])
        for bus in (private, main_bus):
            if bus.sock in readable:
                bus.fill()


def wait_for_agent_env(runtime, timeout=30):
    deadline = time.monotonic() + timeout
    while True:
        if (runtime / "agent.env").exists():
            env = read_agent_env(runtime)
            if all(key in env for key in ("WAYLAND_DISPLAY", "NIRI_SOCKET", "DBUS_SESSION_BUS_ADDRESS")):
                return env
        if not unit_active():
            raise ValueError(f"The agent desktop exited during startup:\n{tail(runtime / 'session.log')}")
        if time.monotonic() > deadline:
            raise ValueError(f"Timed out waiting for the agent desktop:\n{tail(runtime / 'session.log')}")
        time.sleep(0.1)


def wait_for_name(address, name, timeout=15):
    deadline = time.monotonic() + timeout
    while True:
        try:
            if name_has_owner(address, name):
                return True
        except OSError:
            pass
        if time.monotonic() > deadline:
            return False
        time.sleep(0.1)


def status_report(runtime):
    if not unit_active():
        return {"running": False, "unit": UNIT}
    env = read_agent_env(runtime) if (runtime / "agent.env").exists() else {}
    pid = niri_pid()
    bus = env.get("DBUS_SESSION_BUS_ADDRESS")
    try:
        bridge = name_has_owner(bus, SECRETS_NAME) if bus else None
    except ERRORS:
        bridge = False
    return {
        "running": True, "unit": UNIT, "runtimeDir": str(runtime), "log": str(runtime / "session.log"),
        "waylandDisplay": env.get("WAYLAND_DISPLAY"), "niriSocket": env.get("NIRI_SOCKET"), "busAddress": bus,
        "x11Display": env.get("DISPLAY"), "niriPid": pid, "inputDevices": open_input_devices(pid) if pid else None,
        "secretsBridge": bridge, "chromeProfile": str(chrome_copy()) if chrome_copy().is_dir() else None,
        "vncSocket": str(runtime / "vnc") if (runtime / "vnc").exists() else None,
    }


def release_mouse_holder():
    # desktop.py --target agent runs wlroots-bridge with CLAUDE_PROFILE set to UNIT_NAME, so a held
    # left button belongs to this holder. It lives outside the unit and must release before niri exits.
    pidfile = Path(os.environ["XDG_RUNTIME_DIR"]) / f"wlroots-bridge-lmb-{UNIT_NAME}.pid"
    try:
        pid = int(pidfile.read_text().strip())
        if Path(f"/proc/{pid}/comm").read_text().strip() == "wlroots-bridge":
            os.kill(pid, 15)
            deadline = time.monotonic() + 0.5
            while pidfile.exists() and time.monotonic() < deadline:
                time.sleep(0.01)
    except (OSError, ValueError):
        pass
    pidfile.unlink(missing_ok=True)


def cleanup(runtime):
    release_mouse_holder()
    run("systemctl", "--user", "stop", UNIT, check=False, timeout=60)
    run("systemctl", "--user", "reset-failed", UNIT, check=False)
    if unit_active():
        raise ValueError(f"{UNIT} did not stop; its files were kept")
    removed = []
    for path in (runtime, cache_dir()):
        if path.is_dir():
            shutil.rmtree(path)
            removed.append(str(path))
    return removed


def require_running():
    runtime = runtime_dir()
    if not unit_active():
        raise ValueError("The agent desktop is not running; run agent_desktop.py start")
    env = read_agent_env(runtime)
    try:
        bridge = name_has_owner(env["DBUS_SESSION_BUS_ADDRESS"], SECRETS_NAME)
    except ERRORS:
        bridge = False
    if not bridge:
        raise ValueError(f"The secrets bridge is not running; restart the agent desktop:\n{tail(runtime / 'secrets-bridge.log')}")
    os.environ.update(WAYLAND_DISPLAY=env["WAYLAND_DISPLAY"], NIRI_SOCKET=env["NIRI_SOCKET"])
    return runtime, env


def niri_spawn(command):
    run("niri", "msg", "action", "spawn", "--", *command)
    return command


def remainder(argv):
    return argv[1:] if argv[:1] == ["--"] else argv


def rfb_banner(path):
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.settimeout(2)
            sock.connect(str(path))
            banner = sock.recv(12)
    except OSError:
        return None
    return banner.decode("ascii", errors="replace").strip() if banner.startswith(b"RFB ") else None


def start(args):
    runtime = runtime_dir()
    if unit_active():
        return {**status_report(runtime), "alreadyRunning": True}
    if not os.environ.get("DBUS_SESSION_BUS_ADDRESS"):
        raise ValueError("DBUS_SESSION_BUS_ADDRESS is not set; the secrets bridge needs the main session bus")
    for name in ("systemd-run", "dbus-run-session", "niri"):
        require_command(name)
    cleanup(runtime)
    runtime.mkdir(mode=0o700)
    (runtime / "main-bus").write_text(os.environ["DBUS_SESSION_BUS_ADDRESS"] + "\n")
    write_bus_config(runtime)
    write_niri_config(runtime)
    copy_chrome_profile()
    environment, unset, dropped = agent_environment()
    log_path = runtime / "session.log"
    run(
        "systemd-run", "--user", "--quiet", "--collect", f"--unit={UNIT_NAME}",
        "--property=TimeoutStopSec=10", f"--property=WorkingDirectory={Path.home()}",
        f"--property=StandardOutput=append:{log_path}", f"--property=StandardError=append:{log_path}",
        f"--property=UnsetEnvironment={' '.join(unset)}",
        *[f"--setenv={key}={value}" for key, value in sorted(environment.items())],
        "--", "dbus-run-session", f"--config-file={runtime / 'bus.conf'}", "--", "niri", "-c", str(runtime / "niri.kdl"),
        timeout=60,
    )
    env = wait_for_agent_env(runtime)
    pid = niri_pid()
    devices = open_input_devices(pid) if pid else None
    if devices != []:
        cleanup(runtime)
        problem = f"opened input devices {devices}" if devices else "could not be checked for input devices"
        raise ValueError(f"The agent compositor (pid {pid}) {problem}; stopped it")
    bridge = wait_for_name(env["DBUS_SESSION_BUS_ADDRESS"], SECRETS_NAME)
    if not bridge:
        raise ValueError(f"The secrets bridge did not come up:\n{tail(runtime / 'secrets-bridge.log')}")
    return {**status_report(runtime), "alreadyRunning": False, "droppedEnvironment": dropped}


def status(args):
    return status_report(runtime_dir())


def spawn(args):
    command = remainder(args.argv)
    if not command:
        raise ValueError("spawn requires a command after --")
    require_running()
    return {"spawned": niri_spawn(command)}


def chrome(args):
    require_running()
    copy = chrome_copy()
    if not copy.is_dir():
        raise ValueError("No Chrome profile copy exists; the user's profile was missing when the agent desktop started")
    command = [require_command("google-chrome-stable"), f"--user-data-dir={copy}", *CHROME_FLAGS]
    if not args.audio:
        command.append("--mute-audio")
    return {"spawned": niri_spawn(command + remainder(args.argv))}


def vnc(args):
    runtime, _ = require_running()
    path = runtime / "vnc"
    banner = rfb_banner(path)
    if banner is None:
        if path.exists():
            path.unlink()
        require_command("wayvnc")
        control = safe_path(runtime / "wayvncctl")
        niri_spawn(["sh", "-c", f"exec wayvnc --config=/dev/null --unix-socket --socket={control} {safe_path(path)} >> {safe_path(runtime / 'wayvnc.log')} 2>&1"])
        deadline = time.monotonic() + 10
        while banner is None:
            if time.monotonic() > deadline:
                raise ValueError(f"wayvnc did not start listening on {path}:\n{tail(runtime / 'wayvnc.log')}")
            time.sleep(0.2)
            banner = rfb_banner(path)
    return {"socket": str(path), "protocol": banner, "viewer": f"wlvncc {path}"}


def stop(args):
    return {"running": False, "removed": cleanup(runtime_dir())}


COMMANDS = {"start": start, "status": status, "spawn": spawn, "chrome": chrome, "vnc": vnc, "stop": stop}


def make_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    commands = parser.add_subparsers(dest="command", required=True)
    commands.add_parser("start", help="Start the agent desktop, or report it when it already runs")
    commands.add_parser("status", help="Report the agent desktop endpoints")
    spawn_parser = commands.add_parser("spawn", help="Run a command inside the agent desktop; put it after --")
    spawn_parser.add_argument("argv", nargs=argparse.REMAINDER, metavar="COMMAND")
    chrome_parser = commands.add_parser("chrome", help="Open the copied Chrome profile inside the agent desktop; extra Chrome arguments go after --")
    chrome_parser.add_argument("--audio", action="store_true", help="Start Chrome with audio instead of --mute-audio")
    chrome_parser.add_argument("argv", nargs=argparse.REMAINDER, metavar="CHROME_ARGS")
    commands.add_parser("vnc", help="Start wayvnc on a unix socket for watching and taking over")
    commands.add_parser("stop", help="Stop the agent desktop and delete its runtime files and the profile copy")
    commands.add_parser("secrets-bridge", help="Internal: forward org.freedesktop.secrets to the main session bus")
    return parser


def main():
    args = make_parser().parse_args()
    if args.command == "secrets-bridge":
        try:
            secrets_bridge()
        except ERRORS as error:
            log(f"exiting: {error}")
        return 1
    try:
        result, code = COMMANDS[args.command](args), 0
    except ERRORS as error:
        result, code = {"error": str(error)}, 1
    print(json.dumps(result))
    return code


if __name__ == "__main__":
    sys.exit(main())
