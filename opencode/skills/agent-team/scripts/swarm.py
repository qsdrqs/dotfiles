#!/usr/bin/env python3
"""Manage named opencode swarm sessions via HTTP and tmux."""

from __future__ import annotations

import argparse
import json
import os
import shlex
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.request
from typing import Any

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_DIR = "/tmp/agent-team"
STATE_FILE = os.path.join(STATE_DIR, "state.json")
TMUX_SESSION = "agent-team"
DEFAULT_PORT = 4096
WAIT_INTERVAL = 5
class SwarmError(Exception): pass

def api_url(port: int, path: str = "") -> str:
    return f"http://localhost:{port}{path}"

def ensure_program(name: str) -> None:
    if shutil.which(name) is None:
        raise SwarmError(f"required program not found in PATH: {name}")

def http_json(port: int, method: str, path: str, payload: dict[str, Any] | None = None, expected_status: int | None = None) -> Any:
    headers = {"Accept": "application/json"}
    data = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(api_url(port, path), data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read()
            if expected_status is not None and response.status != expected_status:
                raise SwarmError(f"unexpected HTTP status for {method} {path}: {response.status}")
            if not body:
                return None
            try:
                return json.loads(body.decode("utf-8"))
            except json.JSONDecodeError as exc:
                raise SwarmError(f"invalid JSON response from {method} {path}: {exc}") from exc
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace").strip()
        message = f"HTTP {exc.code} for {method} {path}"
        raise SwarmError(f"{message}: {detail}" if detail else message) from exc
    except urllib.error.URLError as exc:
        raise SwarmError(f"failed to reach opencode server on port {port}: {exc}") from exc

def check_health(port: int) -> None:
    payload = http_json(port, "GET", "/global/health")
    if not isinstance(payload, dict) or not payload.get("healthy"):
        raise SwarmError(f"opencode server on port {port} is not healthy")


def try_health(port: int) -> bool:
    """Return True if server is reachable and healthy, False otherwise."""
    try:
        check_health(port)
        return True
    except SwarmError:
        return False


SERVE_WINDOW = "opencode-serve"


def ensure_server(port: int, workdir: str) -> bool:
    """Ensure an opencode server is running on the given port.

    Returns True if we started a new server, False if one was already running.
    """
    if try_health(port):
        return False
    ensure_program("opencode")
    ensure_program("tmux")
    serve_cmd = shlex.join(["opencode", "serve", "--port", str(port)])
    if tmux_session_exists(TMUX_SESSION):
        run_command(
            ["tmux", "new-window", "-t", TMUX_SESSION, "-n", SERVE_WINDOW, serve_cmd],
            "failed to start opencode serve in tmux",
        )
    else:
        run_command(
            ["tmux", "new-session", "-d", "-s", TMUX_SESSION, "-n", SERVE_WINDOW, serve_cmd],
            "failed to create tmux session for opencode serve",
        )
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        if try_health(port):
            return True
        time.sleep(1)
    raise SwarmError(f"opencode serve started but not healthy after 30s on port {port}")

def load_state() -> dict[str, Any]:
    if not os.path.exists(STATE_FILE):
        raise SwarmError("state file not found, run 'swarm.py init' first")
    try:
        with open(STATE_FILE, "r", encoding="utf-8") as handle:
            state = json.load(handle)
    except OSError as exc:
        raise SwarmError(f"failed to read state file {STATE_FILE}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise SwarmError(f"invalid JSON in state file {STATE_FILE}: {exc}") from exc
    if not isinstance(state, dict) or not isinstance(state.get("workers"), list):
        raise SwarmError(f"invalid state file format in {STATE_FILE}")
    return state

def save_state(state: dict[str, Any]) -> None:
    try:
        os.makedirs(STATE_DIR, exist_ok=True)
        with open(STATE_FILE, "w", encoding="utf-8") as handle:
            json.dump(state, handle, indent=2)
            handle.write("\n")
    except OSError as exc:
        raise SwarmError(f"failed to write state file {STATE_FILE}: {exc}") from exc

def parse_worker_spec(spec: str) -> dict[str, str]:
    name, sep, role = spec.partition(":")
    name = name.strip()
    role = role.strip()
    if not sep or not name or not role:
        raise SwarmError(f"invalid --worker value '{spec}', expected 'name:role description'")
    return {"name": name, "role": role}

def get_worker(state: dict[str, Any], name: str) -> dict[str, Any]:
    for worker in state["workers"]:
        if worker.get("name") == name:
            return worker
    raise SwarmError(f"worker not found in state: {name}")

def format_table(headers: list[str], rows: list[list[str]]) -> str:
    widths = [len(header) for header in headers]
    for row in rows:
        for index, cell in enumerate(row):
            widths[index] = max(widths[index], len(cell))
    def render(row: list[str]) -> str:
        return " | ".join(cell.ljust(widths[index]) for index, cell in enumerate(row))
    lines = [render(headers), "-+-".join("-" * width for width in widths)]
    lines.extend(render(row) for row in rows)
    return "\n".join(lines)

def message_text(message: dict[str, Any]) -> str:
    parts = message.get("parts") or []
    texts = [part["text"].strip() for part in parts if isinstance(part, dict) and isinstance(part.get("text"), str) and part["text"].strip()]
    if texts:
        return "\n".join(texts)
    labels = [f"[{part['type']}]" for part in parts if isinstance(part, dict) and isinstance(part.get("type"), str) and part["type"]]
    return " ".join(labels)

def snippet(text: str, limit: int = 60) -> str:
    flat = " ".join(text.split())
    return flat if len(flat) <= limit else flat[: limit - 3] + "..."

def prefixed_message(sender: str, message: str) -> str:
    sender = sender.strip() or "leader"
    message = message.strip()
    if not message:
        raise SwarmError("message cannot be empty")
    return f"[FROM {sender}] {message}"

def run_command(command: list[str], failure: str) -> subprocess.CompletedProcess[str]:
    try:
        return subprocess.run(command, capture_output=True, text=True, check=True)
    except subprocess.CalledProcessError as exc:
        detail = (exc.stderr or exc.stdout or "").strip()
        raise SwarmError(detail or failure) from exc

def tmux_session_exists(name: str) -> bool:
    ensure_program("tmux")
    result = subprocess.run(["tmux", "has-session", "-t", name], capture_output=True, text=True, check=False)
    return result.returncode == 0

def tmux_attach_command(port: int, session_id: str) -> str:
    return shlex.join(["opencode", "attach", api_url(port), "--session", session_id])


def create_tmux_windows(port: int, workdir: str, workers: list[dict[str, Any]]) -> None:
    ensure_program("tmux")
    session_exists = tmux_session_exists(TMUX_SESSION)
    for worker in workers:
        cmd = tmux_attach_command(port, worker["session_id"])
        if not session_exists:
            run_command(
                ["tmux", "new-session", "-d", "-s", TMUX_SESSION, "-n", worker["name"], "-c", workdir, cmd],
                "failed to create tmux session",
            )
            session_exists = True
        else:
            run_command(
                ["tmux", "new-window", "-t", TMUX_SESSION, "-n", worker["name"], "-c", workdir, cmd],
                f"failed to create tmux window for {worker['name']}",
            )


def read_messages(port: int, session_id: str) -> list[dict[str, Any]]:
    payload = http_json(port, "GET", f"/session/{session_id}/message")
    if not isinstance(payload, list):
        raise SwarmError(f"unexpected message payload for session {session_id}")
    return [item for item in payload if isinstance(item, dict)]


def session_is_idle(port: int, session_id: str) -> bool:
    payload = http_json(port, "GET", "/session/status")
    if not isinstance(payload, dict):
        raise SwarmError("unexpected payload from /session/status")
    status = payload.get(session_id)
    return not isinstance(status, dict) or status.get("type") != "busy"


def create_session(port: int) -> str:
    payload = http_json(port, "POST", "/session", payload={})
    if not isinstance(payload, dict) or not isinstance(payload.get("id"), str):
        raise SwarmError("failed to create opencode session")
    return payload["id"]


def async_send(port: int, session_id: str, message: str) -> None:
    http_json(port, "POST", f"/session/{session_id}/prompt_async", payload={"parts": [{"type": "text", "text": message}]}, expected_status=204)


def sync_send(port: int, session_id: str, message: str) -> str:
    ensure_program("opencode")
    result = run_command(["opencode", "run", "--attach", api_url(port), "--session", session_id, "--format", "json", message], f"opencode run failed for session {session_id}")
    texts = []
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            item = json.loads(line)
        except json.JSONDecodeError:
            continue
        if item.get("type") == "text":
            part = item.get("part") or {}
            text = part.get("text")
            if isinstance(text, str) and text.strip():
                texts.append(text.strip())
    if texts:
        return "\n".join(texts)
    raw = result.stdout.strip()
    if raw:
        return raw
    raise SwarmError(f"no response text returned for session {session_id}")


def init_command(args: argparse.Namespace) -> int:
    if not args.worker:
        raise SwarmError("at least one --worker is required")
    workdir = os.path.abspath(args.workdir)
    os.makedirs(workdir, exist_ok=True)
    auto_started = ensure_server(args.port, workdir)
    if auto_started:
        print(f"started opencode serve on port {args.port}")
    names = set()
    workers: list[dict[str, Any]] = []
    for spec in args.worker:
        worker = parse_worker_spec(spec)
        if worker["name"] in names:
            raise SwarmError(f"duplicate worker name: {worker['name']}")
        names.add(worker["name"])
        worker["session_id"] = create_session(args.port)
        workers.append(worker)
    create_tmux_windows(args.port, workdir, workers)
    leader_session = args.leader_session
    save_state({
        "port": args.port,
        "workdir": workdir,
        "leader_session": leader_session,
        "auto_started_server": auto_started,
        "workers": workers,
    })
    rows = [[worker["name"], worker["session_id"], worker["role"]] for worker in workers]
    print(format_table(["name", "session_id", "role"], rows))
    print(f"state: {STATE_FILE}")
    print(f"tmux:  {TMUX_SESSION}")
    return 0


def add_command(args: argparse.Namespace) -> int:
    state = load_state()
    port = int(state["port"])
    workdir = state.get("workdir", ".")
    existing_names = {s["name"] for s in state["workers"]}
    added: list[dict[str, Any]] = []
    for spec in args.worker:
        worker = parse_worker_spec(spec)
        if worker["name"] in existing_names:
            raise SwarmError(f"worker name already exists: {worker['name']}")
        existing_names.add(worker["name"])
        worker["session_id"] = create_session(port)
        added.append(worker)
    create_tmux_windows(port, workdir, added)
    state["workers"].extend(added)
    save_state(state)
    rows = [[s["name"], s["session_id"], s["role"]] for s in added]
    print(format_table(["name", "session_id", "role"], rows))
    return 0


def send_command(args: argparse.Namespace) -> int:
    state = load_state()
    worker = get_worker(state, args.to)
    port = int(state["port"])
    message = prefixed_message(args.sender, args.message)
    if args.async_mode:
        async_send(port, worker["session_id"], message)
        print(f"queued async message for {worker['name']}")
        return 0
    print(sync_send(port, worker["session_id"], message))
    return 0


def status_command(args: argparse.Namespace) -> int:
    del args
    state = load_state()
    port = int(state["port"])
    rows = []
    for worker in state["workers"]:
        messages = read_messages(port, worker["session_id"])
        rows.append([worker["name"], worker["role"], str(len(messages)), snippet(message_text(messages[-1])) if messages else "-"])
    print(format_table(["name", "role", "messages", "last activity"], rows))
    return 0


def read_command(args: argparse.Namespace) -> int:
    state = load_state()
    worker = get_worker(state, args.source)
    messages = read_messages(int(state["port"]), worker["session_id"])
    selected = messages[-args.last :] if args.last > 0 else []
    if not selected:
        print(f"no messages for {worker['name']}")
        return 0
    blocks = []
    for message in selected:
        info = message.get("info") or {}
        blocks.append(f"[{info.get('role', 'unknown')}] {message_text(message) or '[no text parts]'}")
    print("\n\n".join(blocks))
    return 0


def broadcast_command(args: argparse.Namespace) -> int:
    state = load_state()
    port = int(state["port"])
    sender = args.sender.strip()
    message = prefixed_message(sender, args.message)
    recipients = [s for s in state["workers"] if s["name"] != sender]
    if not recipients:
        print("no recipients (all workers excluded as sender)")
        return 0
    if args.async_mode:
        rows = []
        for worker in recipients:
            async_send(port, worker["session_id"], message)
            rows.append([worker["name"], "queued"])
        print(format_table(["name", "status"], rows))
        return 0
    blocks = []
    for worker in recipients:
        blocks.append(f"== {worker['name']} ==\n{sync_send(port, worker['session_id'], message)}")
    print("\n\n".join(blocks))
    return 0


def set_leader_command(args: argparse.Namespace) -> int:
    state = load_state()
    state["leader_session"] = args.session
    save_state(state)
    print(f"leader_session set to {args.session}")
    return 0


def report_command(args: argparse.Namespace) -> int:
    state = load_state()
    leader_session = state.get("leader_session")
    if not leader_session:
        raise SwarmError("leader_session not set, run 'set-leader --session <id>' or pass --leader-session to init")
    port = int(state["port"])
    message = prefixed_message(args.sender, args.message)
    async_send(port, leader_session, message)
    print(f"reported to leader")
    return 0


def wait_command(args: argparse.Namespace) -> int:
    state = load_state()
    worker = get_worker(state, args.target)
    port = int(state["port"])
    deadline = time.monotonic() + args.timeout
    while True:
        if session_is_idle(port, worker["session_id"]):
            print(f"{worker['name']} is idle")
            return 0
        if time.monotonic() >= deadline:
            raise SwarmError(f"timed out waiting for {worker['name']} after {args.timeout} seconds")
        time.sleep(WAIT_INTERVAL)


def teardown_command(args: argparse.Namespace) -> int:
    ensure_program("tmux")
    if tmux_session_exists(TMUX_SESSION):
        run_command(["tmux", "kill-session", "-t", TMUX_SESSION], "failed to kill tmux")
        print(f"killed tmux session {TMUX_SESSION}")
        state = None
        if os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, "r", encoding="utf-8") as handle:
                    state = json.load(handle)
            except (OSError, json.JSONDecodeError):
                pass
        if state and state.get("auto_started_server"):
            print("(auto-started opencode serve was terminated with tmux)")
    else:
        print(f"tmux session {TMUX_SESSION} not found")
    if args.keep_state:
        return 0
    if os.path.exists(STATE_FILE):
        os.remove(STATE_FILE)
        print(f"removed state file {STATE_FILE}")
        try:
            os.rmdir(STATE_DIR)
        except OSError:
            pass
    else:
        print(f"state file {STATE_FILE} not found")
    return 0


def add_async_flags(parser: argparse.ArgumentParser, default: bool) -> None:
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--async", dest="async_mode", action="store_true")
    mode.add_argument("--sync", dest="async_mode", action="store_false")
    parser.set_defaults(async_mode=default)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Manage a named multi-agent opencode swarm.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    init_parser = subparsers.add_parser("init", help="create worker sessions and tmux windows")
    init_parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    init_parser.add_argument("--workdir", required=True)
    init_parser.add_argument("--worker", action="append", default=[])
    init_parser.add_argument("--leader-session", default=None, help="session ID of the leader agent")
    init_parser.set_defaults(func=init_command)

    add_parser = subparsers.add_parser("add", help="add new workers to a running swarm")
    add_parser.add_argument("--worker", action="append", default=[], required=True)
    add_parser.set_defaults(func=add_command)

    send_parser = subparsers.add_parser("send", help="send a message to one worker")
    send_parser.add_argument("--to", required=True)
    send_parser.add_argument("--message", required=True)
    send_parser.add_argument("--from", dest="sender", default="leader")
    add_async_flags(send_parser, False)
    send_parser.set_defaults(func=send_command)

    status_parser = subparsers.add_parser("status", help="show worker activity summary")
    status_parser.set_defaults(func=status_command)

    read_parser = subparsers.add_parser("read", help="read recent messages from one worker")
    read_parser.add_argument("--from", dest="source", required=True)
    read_parser.add_argument("--last", type=int, default=5)
    read_parser.set_defaults(func=read_command)

    broadcast_parser = subparsers.add_parser("broadcast", help="send a message to all workers")
    broadcast_parser.add_argument("--message", required=True)
    broadcast_parser.add_argument("--from", dest="sender", default="leader")
    add_async_flags(broadcast_parser, True)
    broadcast_parser.set_defaults(func=broadcast_command)

    set_leader_parser = subparsers.add_parser("set-leader", help="register the leader session ID")
    set_leader_parser.add_argument("--session", required=True, help="leader's opencode session ID")
    set_leader_parser.set_defaults(func=set_leader_command)

    report_parser = subparsers.add_parser("report", help="send a message to the leader (used by workers)")
    report_parser.add_argument("--message", required=True)
    report_parser.add_argument("--from", dest="sender", default="worker")
    report_parser.set_defaults(func=report_command)

    wait_parser = subparsers.add_parser("wait", help="wait until one worker becomes idle")
    wait_parser.add_argument("--for", dest="target", required=True)
    wait_parser.add_argument("--timeout", type=int, default=300)
    wait_parser.set_defaults(func=wait_command)

    teardown_parser = subparsers.add_parser("teardown", help="stop tmux monitoring and clean state")
    teardown_parser.add_argument("--keep-state", action="store_true")
    teardown_parser.set_defaults(func=teardown_command)
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    try:
        return args.func(args)
    except SwarmError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Error: interrupted", file=sys.stderr)
        return 130
    except BrokenPipeError:
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
