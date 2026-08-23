#!/usr/bin/env python3
"""Manage named opencode swarm sessions via HTTP and tmux (OpenCode 2)."""

from __future__ import annotations

import argparse
import base64
import json
import os
import shlex
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from typing import Any

SKILL_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STATE_DIR = "/tmp/agent-team"
STATE_FILE = os.path.join(STATE_DIR, "state.json")
TMUX_SESSION = "agent-team"
AUTH_USER = "opencode"
SERVICE_JSON = os.path.expanduser("~/.config/opencode/service.json")
class SwarmError(Exception): pass

def api_url(base: str, path: str = "") -> str:
    return f"{base.rstrip('/')}{path}"

def ensure_program(name: str) -> None:
    if shutil.which(name) is None:
        raise SwarmError(f"required program not found in PATH: {name}")

def auth_header() -> str:
    try:
        with open(SERVICE_JSON, "r", encoding="utf-8") as handle:
            config = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise SwarmError(f"failed to read {SERVICE_JSON}: {exc}") from exc
    password = config.get("password")
    if not isinstance(password, str) or not password:
        raise SwarmError(f"no password in {SERVICE_JSON}; is the opencode 2 service running?")
    token = base64.b64encode(f"{AUTH_USER}:{password}".encode("utf-8")).decode("ascii")
    return f"Basic {token}"

def resolve_service_base() -> str:
    """Return the base URL of the opencode 2 background service.

    `opencode2 service status` prints the service URL on one line.
    """
    ensure_program("opencode2")
    result = run_command(["opencode2", "service", "status"], "opencode2 service status failed")
    url = (result.stdout or "").strip().splitlines()
    if not url:
        raise SwarmError("opencode2 service status returned no URL; is the service running?")
    return url[0]

def http_json(base: str, method: str, path: str, payload: dict[str, Any] | None = None, expected_status: int | None = None) -> Any:
    headers = {
        "Accept": "application/json",
        "Authorization": auth_header(),
    }
    data = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(api_url(base, path), data=data, headers=headers, method=method)
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
        raise SwarmError(f"failed to reach opencode server at {base}: {exc}") from exc

def check_health(base: str) -> None:
    payload = http_json(base, "GET", "/api/health")
    if not isinstance(payload, dict) or not payload.get("healthy"):
        raise SwarmError(f"opencode server at {base} is not healthy")


def try_health(base: str) -> bool:
    """Return True if server is reachable and healthy, False otherwise."""
    try:
        check_health(base)
        return True
    except SwarmError:
        return False


def ensure_server() -> str:
    """Resolve the opencode 2 background service and verify it is healthy.

    The V2 service owns all sessions; swarm workers live on it alongside the
    user's own TUI sessions. Returns the service base URL.
    """
    base = resolve_service_base()
    if not try_health(base):
        raise SwarmError(f"opencode service at {base} is not healthy; run 'opencode2 service status'")
    return base

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
    text = message.get("text")
    if isinstance(text, str) and text.strip():
        return text.strip()
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

def tmux_attach_command(session_id: str) -> str:
    return shlex.join(["opencode2", "--session", session_id])


def create_tmux_windows(workers: list[dict[str, Any]]) -> None:
    ensure_program("tmux")
    session_exists = tmux_session_exists(TMUX_SESSION)
    for worker in workers:
        cmd = tmux_attach_command(worker["session_id"])
        if not session_exists:
            run_command(
                ["tmux", "new-session", "-d", "-s", TMUX_SESSION, "-n", worker["name"], cmd],
                "failed to create tmux session",
            )
            session_exists = True
        else:
            run_command(
                ["tmux", "new-window", "-t", TMUX_SESSION, "-n", worker["name"], cmd],
                f"failed to create tmux window for {worker['name']}",
            )


def unwrap(payload: Any, what: str) -> Any:
    """Unwrap the V2 API envelope {"data": ...}."""
    if not isinstance(payload, dict) or "data" not in payload:
        raise SwarmError(f"unexpected payload for {what}")
    return payload["data"]


def read_messages(base: str, session_id: str) -> list[dict[str, Any]]:
    payload = unwrap(http_json(base, "GET", f"/api/session/{session_id}/message"), f"session {session_id}")
    if not isinstance(payload, list):
        raise SwarmError(f"unexpected message payload for session {session_id}")
    return [item for item in payload if isinstance(item, dict)]


def session_wait(base: str, session_id: str, timeout: float) -> bool:
    """Block until the session finishes its current work via the V2 /wait endpoint.

    The official V2 endpoint POST /api/session/{id}/wait blocks while the
    session is busy and returns HTTP 204 once it goes idle (immediately for
    an already-idle session). Returns True when idle, False on timeout.
    """
    request = urllib.request.Request(
        api_url(base, f"/api/session/{session_id}/wait"),
        method="POST",
        headers={"Authorization": auth_header()},
    )
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return response.status == 204
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace").strip()
        message = f"HTTP {exc.code} for POST /api/session/{session_id}/wait"
        raise SwarmError(f"{message}: {detail}" if detail else message) from exc
    except urllib.error.URLError as exc:
        if isinstance(exc.reason, TimeoutError):
            return False
        raise SwarmError(f"failed to wait on session {session_id}: {exc}") from exc


def create_session(base: str, model: dict[str, Any] | None = None) -> str:
    payload: dict[str, Any] = {}
    if model is not None:
        payload["model"] = model
    body = unwrap(http_json(base, "POST", "/api/session", payload=payload), "create session")
    if not isinstance(body, dict) or not isinstance(body.get("id"), str):
        raise SwarmError("failed to create opencode session")
    return body["id"]


def parse_model(spec: str) -> dict[str, str]:
    """Parse 'providerID/modelID#variant' into the V2 model object."""
    provider, sep, rest = spec.partition("/")
    model_id, _, variant = rest.partition("#")
    if not sep or not provider or not model_id:
        raise SwarmError(f"invalid --model '{spec}', expected 'providerID/modelID[#variant]'")
    model: dict[str, str] = {"id": model_id, "providerID": provider}
    if variant:
        model["variant"] = variant
    return model


def fetch_session_model(base: str, session_id: str) -> dict[str, Any]:
    """Read the model of an existing session (used as default for workers)."""
    body = unwrap(http_json(base, "GET", f"/api/session/{session_id}"), f"session {session_id}")
    if not isinstance(body, dict):
        raise SwarmError(f"unexpected session payload for {session_id}")
    model = body.get("model")
    if not isinstance(model, dict) or not isinstance(model.get("id"), str) or not isinstance(model.get("providerID"), str):
        raise SwarmError(f"session {session_id} has no readable model; pass --model explicitly")
    return model


def resolve_model(base: str, explicit: str | None, leader_session: str | None) -> dict[str, Any]:
    """Resolve the worker model: explicit --model wins; otherwise default to
    the leader session's current model."""
    if explicit:
        return parse_model(explicit)
    if not leader_session:
        raise SwarmError("--model is required, or pass --leader-session to default to the leader's current model")
    return fetch_session_model(base, leader_session)


def async_send(base: str, session_id: str, message: str) -> None:
    http_json(base, "POST", f"/api/session/{session_id}/prompt", payload={"text": message})


def sync_send(session_id: str, message: str) -> str:
    ensure_program("opencode2")
    result = run_command(["opencode2", "run", "--session", session_id, "--format", "json", message], f"opencode2 run failed for session {session_id}")
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
    base = ensure_server()
    model = resolve_model(base, args.model, args.leader_session)
    names = set()
    workers: list[dict[str, Any]] = []
    for spec in args.worker:
        worker = parse_worker_spec(spec)
        if worker["name"] in names:
            raise SwarmError(f"duplicate worker name: {worker['name']}")
        names.add(worker["name"])
        worker["session_id"] = create_session(base, model)
        workers.append(worker)
    create_tmux_windows(workers)
    leader_session = args.leader_session
    save_state({
        "base": base,
        "leader_session": leader_session,
        "model": model,
        "workers": workers,
    })
    rows = [[worker["name"], worker["session_id"], worker["role"]] for worker in workers]
    print(format_table(["name", "session_id", "role"], rows))
    model_ref = f"{model.get('providerID')}/{model.get('id')}#{model.get('variant')}" if model.get("variant") else f"{model.get('providerID')}/{model.get('id')}"
    print(f"model:  {model_ref}")
    print(f"state: {STATE_FILE}")
    print(f"tmux:  {TMUX_SESSION}")
    return 0


def add_command(args: argparse.Namespace) -> int:
    state = load_state()
    base = str(state["base"])
    model = state.get("model")
    if args.model:
        model = parse_model(args.model)
    elif not isinstance(model, dict) or not isinstance(model.get("id"), str):
        raise SwarmError("--model is required (state has no worker model); pass 'providerID/modelID[#variant]'")
    existing_names = {s["name"] for s in state["workers"]}
    added: list[dict[str, Any]] = []
    for spec in args.worker:
        worker = parse_worker_spec(spec)
        if worker["name"] in existing_names:
            raise SwarmError(f"worker name already exists: {worker['name']}")
        existing_names.add(worker["name"])
        worker["session_id"] = create_session(base, model)
        added.append(worker)
    create_tmux_windows(added)
    state["workers"].extend(added)
    state["model"] = model
    save_state(state)
    rows = [[s["name"], s["session_id"], s["role"]] for s in added]
    print(format_table(["name", "session_id", "role"], rows))
    return 0


def send_command(args: argparse.Namespace) -> int:
    state = load_state()
    worker = get_worker(state, args.to)
    base = str(state["base"])
    message = prefixed_message(args.sender, args.message)
    if args.async_mode:
        async_send(base, worker["session_id"], message)
        print(f"queued async message for {worker['name']}")
        return 0
    print(sync_send(worker["session_id"], message))
    return 0


def status_command(args: argparse.Namespace) -> int:
    del args
    state = load_state()
    base = str(state["base"])
    rows = []
    for worker in state["workers"]:
        messages = read_messages(base, worker["session_id"])
        rows.append([worker["name"], worker["role"], str(len(messages)), snippet(message_text(messages[-1])) if messages else "-"])
    print(format_table(["name", "role", "messages", "last activity"], rows))
    return 0


def read_command(args: argparse.Namespace) -> int:
    state = load_state()
    worker = get_worker(state, args.source)
    messages = read_messages(str(state["base"]), worker["session_id"])
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
    base = str(state["base"])
    sender = args.sender.strip()
    message = prefixed_message(sender, args.message)
    recipients = [s for s in state["workers"] if s["name"] != sender]
    if not recipients:
        print("no recipients (all workers excluded as sender)")
        return 0
    if args.async_mode:
        rows = []
        for worker in recipients:
            async_send(base, worker["session_id"], message)
            rows.append([worker["name"], "queued"])
        print(format_table(["name", "status"], rows))
        return 0
    blocks = []
    for worker in recipients:
        blocks.append(f"== {worker['name']} ==\n{sync_send(worker['session_id'], message)}")
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
    base = str(state["base"])
    message = prefixed_message(args.sender, args.message)
    async_send(base, leader_session, message)
    print(f"reported to leader")
    return 0


def wait_command(args: argparse.Namespace) -> int:
    state = load_state()
    worker = get_worker(state, args.target)
    base = str(state["base"])
    if session_wait(base, worker["session_id"], float(args.timeout)):
        print(f"{worker['name']} is idle")
        return 0
    raise SwarmError(f"timed out waiting for {worker['name']} after {args.timeout} seconds")


def teardown_command(args: argparse.Namespace) -> int:
    ensure_program("tmux")
    if tmux_session_exists(TMUX_SESSION):
        run_command(["tmux", "kill-session", "-t", TMUX_SESSION], "failed to kill tmux")
        print(f"killed tmux session {TMUX_SESSION}")
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
    init_parser.add_argument("--worker", action="append", default=[])
    init_parser.add_argument("--model", default=None, help="worker model as 'providerID/modelID[#variant]' (default: leader session's model)")
    init_parser.add_argument("--leader-session", default=None, help="session ID of the leader agent")
    init_parser.set_defaults(func=init_command)

    add_parser = subparsers.add_parser("add", help="add new workers to a running swarm")
    add_parser.add_argument("--worker", action="append", default=[], required=True)
    add_parser.add_argument("--model", default=None, help="worker model as 'providerID/modelID[#variant]' (default: state's worker model)")
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
