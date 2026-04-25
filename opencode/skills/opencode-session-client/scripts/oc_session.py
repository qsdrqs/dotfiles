#!/usr/bin/env python3
"""Stateless CLI client for opencode HTTP sessions.

Talks to an opencode server over HTTP (default localhost:4096) to:
  - list / create / delete sessions on the server,
  - send messages to a session asynchronously,
  - read past messages,
  - poll for the assistant response (idle + new messages),
  - or do a single-shot send + wait + return-response.

Requires only Python 3.10+ stdlib. No external packages.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from typing import Any

DEFAULT_HOST = "127.0.0.1"
DEFAULT_PORT = 4096
DEFAULT_INTERVAL = 2.0
DEFAULT_TIMEOUT = 300.0
# Bootstrap window: how long after send to wait for the session to become busy
# or for the user message to appear, before assuming the send was a no-op.
BOOTSTRAP_TIMEOUT = 30.0
HTTP_TIMEOUT = 30.0


class OcError(Exception):
    """Domain error reported as 'Error: <msg>' on stderr with exit code 1."""


def base_url(host: str, port: int) -> str:
    return f"http://{host}:{port}"


def http_json(
    host: str,
    port: int,
    method: str,
    path: str,
    payload: dict[str, Any] | None = None,
    expected_status: int | None = None,
) -> Any:
    """Issue an HTTP request and decode JSON, raising OcError on failure."""
    headers = {"Accept": "application/json"}
    data = None
    if payload is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(payload).encode("utf-8")
    request = urllib.request.Request(
        base_url(host, port) + path, data=data, headers=headers, method=method
    )
    try:
        with urllib.request.urlopen(request, timeout=HTTP_TIMEOUT) as response:
            body = response.read()
            if expected_status is not None and response.status != expected_status:
                raise OcError(
                    f"unexpected HTTP status for {method} {path}: "
                    f"{response.status} (expected {expected_status})"
                )
            if not body:
                return None
            try:
                return json.loads(body.decode("utf-8"))
            except json.JSONDecodeError as exc:
                raise OcError(f"invalid JSON response from {method} {path}: {exc}") from exc
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace").strip()
        msg = f"HTTP {exc.code} for {method} {path}"
        raise OcError(f"{msg}: {detail}" if detail else msg) from exc
    except urllib.error.URLError as exc:
        raise OcError(
            f"failed to reach opencode server at {base_url(host, port)}: {exc.reason}"
        ) from exc
    except TimeoutError as exc:
        raise OcError(f"HTTP {method} {path} timed out after {HTTP_TIMEOUT}s") from exc


def get_health(host: str, port: int) -> dict[str, Any]:
    payload = http_json(host, port, "GET", "/global/health")
    if not isinstance(payload, dict):
        raise OcError("unexpected payload from /global/health")
    return payload


def list_sessions(host: str, port: int) -> list[dict[str, Any]]:
    payload = http_json(host, port, "GET", "/session")
    if not isinstance(payload, list):
        raise OcError("unexpected payload from GET /session")
    return [item for item in payload if isinstance(item, dict)]


def create_session(host: str, port: int) -> dict[str, Any]:
    payload = http_json(host, port, "POST", "/session", payload={})
    if not isinstance(payload, dict) or not isinstance(payload.get("id"), str):
        raise OcError("failed to create opencode session")
    return payload


def delete_session(host: str, port: int, session_id: str) -> bool:
    payload = http_json(host, port, "DELETE", f"/session/{session_id}")
    return bool(payload) if payload is not None else True


def read_messages(host: str, port: int, session_id: str) -> list[dict[str, Any]]:
    payload = http_json(host, port, "GET", f"/session/{session_id}/message")
    if not isinstance(payload, list):
        raise OcError(f"unexpected message payload for session {session_id}")
    return [item for item in payload if isinstance(item, dict)]


def session_status(host: str, port: int) -> dict[str, Any]:
    payload = http_json(host, port, "GET", "/session/status")
    if not isinstance(payload, dict):
        raise OcError("unexpected payload from /session/status")
    return payload


def session_is_busy(host: str, port: int, session_id: str) -> bool:
    """Return True when /session/status reports the session as 'busy'."""
    status = session_status(host, port).get(session_id)
    return isinstance(status, dict) and status.get("type") == "busy"


def async_send(host: str, port: int, session_id: str, message: str) -> None:
    http_json(
        host,
        port,
        "POST",
        f"/session/{session_id}/prompt_async",
        payload={"parts": [{"type": "text", "text": message}]},
        expected_status=204,
    )


def message_text(message: dict[str, Any]) -> str:
    """Best-effort flatten of a message's parts into plain text."""
    parts = message.get("parts") or []
    texts: list[str] = []
    for part in parts:
        if not isinstance(part, dict):
            continue
        text = part.get("text")
        if isinstance(text, str) and text.strip():
            texts.append(text.strip())
    if texts:
        return "\n".join(texts)
    labels = [
        f"[{part['type']}]"
        for part in parts
        if isinstance(part, dict) and isinstance(part.get("type"), str) and part["type"]
    ]
    return " ".join(labels)


def message_role(message: dict[str, Any]) -> str:
    info = message.get("info") or {}
    role = info.get("role")
    return role if isinstance(role, str) else "unknown"


def message_id(message: dict[str, Any]) -> str | None:
    info = message.get("info") or {}
    mid = info.get("id")
    return mid if isinstance(mid, str) else None


def snippet(text: str, limit: int = 80) -> str:
    flat = " ".join(text.split())
    return flat if len(flat) <= limit else flat[: limit - 3] + "..."


def prefixed(sender: str | None, message: str) -> str:
    """Optionally prefix the outgoing message with [FROM <sender>]."""
    message = message.strip()
    if not message:
        raise OcError("message cannot be empty")
    if sender is None:
        return message
    sender = sender.strip()
    if not sender:
        return message
    return f"[FROM {sender}] {message}"


def format_table(headers: list[str], rows: list[list[str]]) -> str:
    widths = [len(h) for h in headers]
    for row in rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))
    sep = "-+-".join("-" * w for w in widths)

    def render(row: list[str]) -> str:
        return " | ".join(cell.ljust(widths[i]) for i, cell in enumerate(row))

    return "\n".join([render(headers), sep, *(render(r) for r in rows)])


def wait_until_idle(
    host: str,
    port: int,
    session_id: str,
    timeout: float,
    interval: float,
) -> None:
    """Block until /session/status no longer reports the session as busy."""
    deadline = time.monotonic() + timeout
    while True:
        if not session_is_busy(host, port, session_id):
            return
        if time.monotonic() >= deadline:
            raise OcError(
                f"timed out waiting for session {session_id} to become idle "
                f"(after {timeout:.0f}s)"
            )
        time.sleep(interval)


def poll_for_response(
    host: str,
    port: int,
    session_id: str,
    baseline_count: int,
    timeout: float,
    interval: float,
) -> list[dict[str, Any]]:
    """Poll until session is idle AND new messages have arrived past baseline.

    Strategy ('idle + new messages'):
      Phase 1 (bootstrap, up to BOOTSTRAP_TIMEOUT): wait for the session to
        become busy, OR for the user message to appear in /message. This avoids
        a race where we check 'idle' before the server has registered the
        prompt and conclude there is nothing to wait for.
      Phase 2 (main, up to `timeout`): wait until the session is no longer
        busy AND len(messages) has grown past `baseline_count`.

    Returns the new messages (those with index >= baseline_count).
    """
    overall_deadline = time.monotonic() + timeout
    bootstrap_deadline = min(time.monotonic() + BOOTSTRAP_TIMEOUT, overall_deadline)

    while time.monotonic() < bootstrap_deadline:
        if session_is_busy(host, port, session_id):
            break
        if len(read_messages(host, port, session_id)) > baseline_count:
            break
        time.sleep(interval)

    while True:
        if not session_is_busy(host, port, session_id):
            messages = read_messages(host, port, session_id)
            if len(messages) > baseline_count:
                return messages[baseline_count:]
        if time.monotonic() >= overall_deadline:
            raise OcError(
                f"timed out polling session {session_id} for response "
                f"(after {timeout:.0f}s)"
            )
        time.sleep(interval)


def emit(args: argparse.Namespace, payload: Any, table: str | None = None) -> None:
    """Emit either JSON (--json) or a human-readable text representation."""
    if getattr(args, "json", False):
        print(json.dumps(payload, indent=2, ensure_ascii=False))
        return
    if table is not None:
        print(table)
        return
    if isinstance(payload, str):
        print(payload)
    else:
        print(json.dumps(payload, indent=2, ensure_ascii=False))


def render_messages_text(messages: list[dict[str, Any]]) -> str:
    blocks: list[str] = []
    for msg in messages:
        role = message_role(msg)
        mid = message_id(msg) or "?"
        body = message_text(msg) or "[no text parts]"
        blocks.append(f"[{role}] ({mid})\n{body}")
    return "\n\n".join(blocks) if blocks else "(no messages)"


def cmd_health(args: argparse.Namespace) -> int:
    info = get_health(args.host, args.port)
    if args.json:
        emit(args, info)
    else:
        healthy = info.get("healthy")
        version = info.get("version", "?")
        print(f"healthy={healthy} version={version} url={base_url(args.host, args.port)}")
    return 0 if info.get("healthy") else 2


def cmd_list_sessions(args: argparse.Namespace) -> int:
    sessions = list_sessions(args.host, args.port)
    if args.json:
        emit(args, sessions)
        return 0
    if not sessions:
        print("(no sessions)")
        return 0
    rows = [
        [
            s.get("id", "?"),
            s.get("slug", "?"),
            snippet(s.get("title", "") or "", 60),
            s.get("directory", "?"),
        ]
        for s in sessions
    ]
    print(format_table(["session_id", "slug", "title", "directory"], rows))
    return 0


def cmd_create_session(args: argparse.Namespace) -> int:
    session = create_session(args.host, args.port)
    if args.json:
        emit(args, session)
    else:
        print(session["id"])
    return 0


def cmd_delete_session(args: argparse.Namespace) -> int:
    ok = delete_session(args.host, args.port, args.session)
    if args.json:
        emit(args, {"deleted": ok, "session": args.session})
    else:
        print(f"deleted={ok} session={args.session}")
    return 0 if ok else 1


def cmd_send(args: argparse.Namespace) -> int:
    text = prefixed(args.sender, args.message)
    async_send(args.host, args.port, args.session, text)
    if args.json:
        emit(args, {"queued": True, "session": args.session, "bytes": len(text.encode("utf-8"))})
    else:
        print(f"queued (session={args.session}, {len(text.encode('utf-8'))} bytes)")
    return 0


def cmd_read(args: argparse.Namespace) -> int:
    messages = read_messages(args.host, args.port, args.session)
    if args.role and args.role != "all":
        messages = [m for m in messages if message_role(m) == args.role]
    if args.last and args.last > 0:
        messages = messages[-args.last :]
    if args.json:
        emit(args, messages)
        return 0
    print(render_messages_text(messages))
    return 0


def cmd_wait(args: argparse.Namespace) -> int:
    wait_until_idle(args.host, args.port, args.session, args.timeout, args.interval)
    if args.json:
        emit(args, {"idle": True, "session": args.session})
    else:
        print(f"idle (session={args.session})")
    return 0


def cmd_poll(args: argparse.Namespace) -> int:
    """Poll for new messages on a session (without sending anything first).

    Treats `args.baseline` (or current count if omitted) as the cutoff and
    waits until the session is idle AND len(messages) > baseline.
    """
    if args.baseline is not None:
        baseline = args.baseline
    else:
        baseline = len(read_messages(args.host, args.port, args.session))
    new_messages = poll_for_response(
        args.host, args.port, args.session, baseline, args.timeout, args.interval
    )
    if args.json:
        emit(args, new_messages)
    else:
        print(render_messages_text(new_messages))
    return 0


def cmd_send_and_wait(args: argparse.Namespace) -> int:
    text = prefixed(args.sender, args.message)
    baseline = len(read_messages(args.host, args.port, args.session))
    async_send(args.host, args.port, args.session, text)
    new_messages = poll_for_response(
        args.host, args.port, args.session, baseline, args.timeout, args.interval
    )
    # Conventionally the assistant reply is what the caller wants. Filter to
    # assistant messages unless the caller asked for everything.
    if args.all_messages:
        result = new_messages
    else:
        result = [m for m in new_messages if message_role(m) == "assistant"]
        if not result:
            # Fallback: return everything new so caller still sees something.
            result = new_messages
    if args.json:
        emit(args, result)
    else:
        print(render_messages_text(result))
    return 0


def add_global(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--port",
        type=int,
        default=int(os.environ.get("OPENCODE_PORT", DEFAULT_PORT)),
        help=f"OpenCode server port (default: {DEFAULT_PORT}, env: OPENCODE_PORT)",
    )
    parser.add_argument(
        "--host",
        default=os.environ.get("OPENCODE_HOST", DEFAULT_HOST),
        help=f"OpenCode server host (default: {DEFAULT_HOST}, env: OPENCODE_HOST)",
    )
    parser.add_argument("--json", action="store_true", help="Emit JSON output")


def add_session_arg(parser: argparse.ArgumentParser, required: bool = True) -> None:
    env_default = os.environ.get("OPENCODE_SESSION")
    parser.add_argument(
        "--session",
        required=required and not env_default,
        default=env_default,
        help="Session ID (env: OPENCODE_SESSION)",
    )


def add_poll_args(parser: argparse.ArgumentParser) -> None:
    parser.add_argument(
        "--timeout",
        type=float,
        default=DEFAULT_TIMEOUT,
        help=f"Poll timeout in seconds (default: {DEFAULT_TIMEOUT})",
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=DEFAULT_INTERVAL,
        help=f"Poll interval in seconds (default: {DEFAULT_INTERVAL})",
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="oc_session",
        description="Talk to opencode sessions over HTTP (send + poll + read).",
    )
    add_global(parser)
    common = argparse.ArgumentParser(add_help=False)
    add_global(common)
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("health", parents=[common], help="Check that the opencode server is reachable")
    p.set_defaults(func=cmd_health)

    p = sub.add_parser("list-sessions", parents=[common], help="List all sessions on the server")
    p.set_defaults(func=cmd_list_sessions)

    p = sub.add_parser("create-session", parents=[common], help="Create a new session")
    p.set_defaults(func=cmd_create_session)

    p = sub.add_parser("delete-session", parents=[common], help="Delete a session by ID")
    add_session_arg(p)
    p.set_defaults(func=cmd_delete_session)

    p = sub.add_parser(
        "send",
        parents=[common],
        help="Send a message to a session (async, returns immediately)",
    )
    add_session_arg(p)
    p.add_argument("--message", required=True, help="Message text to send")
    p.add_argument(
        "--from",
        dest="sender",
        default=None,
        help="Optional sender name (prefixes message with '[FROM <name>]')",
    )
    p.set_defaults(func=cmd_send)

    p = sub.add_parser("read", parents=[common], help="Read messages from a session")
    add_session_arg(p)
    p.add_argument("--last", type=int, default=0, help="Only show the last N messages (0 = all)")
    p.add_argument(
        "--role",
        choices=["all", "user", "assistant"],
        default="all",
        help="Filter by role (default: all)",
    )
    p.set_defaults(func=cmd_read)

    p = sub.add_parser("wait", parents=[common], help="Block until the session is no longer busy")
    add_session_arg(p)
    add_poll_args(p)
    p.set_defaults(func=cmd_wait)

    p = sub.add_parser(
        "poll",
        parents=[common],
        help="Poll for new messages on a session (idle + new-message strategy)",
    )
    add_session_arg(p)
    p.add_argument(
        "--baseline",
        type=int,
        default=None,
        help="Wait until message count exceeds this (default: current count at poll start)",
    )
    add_poll_args(p)
    p.set_defaults(func=cmd_poll)

    p = sub.add_parser(
        "send-and-wait",
        parents=[common],
        help="Send a message, poll until the session is idle, return new messages",
    )
    add_session_arg(p)
    p.add_argument("--message", required=True, help="Message text to send")
    p.add_argument(
        "--from", dest="sender", default=None, help="Optional sender name"
    )
    p.add_argument(
        "--all-messages",
        action="store_true",
        help="Return all new messages, not just assistant replies",
    )
    add_poll_args(p)
    p.set_defaults(func=cmd_send_and_wait)

    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    if hasattr(args, "session") and args.session is None:
        parser.error("--session is required (or set OPENCODE_SESSION)")
    try:
        return args.func(args)
    except OcError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1
    except KeyboardInterrupt:
        print("Error: interrupted", file=sys.stderr)
        return 130
    except BrokenPipeError:
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
