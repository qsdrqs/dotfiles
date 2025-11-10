#!/usr/bin/env python3

"""
codex_notifier.py (kitty OSC only)

Usage:
  codex_notifier.py <NOTIFICATION_JSON>

Behavior:
  - Emit kitty OSC 99 desktop notification escape codes to stderr.
  - No HTTP/OS-native fallbacks; non-kitty terminals will likely ignore it.

Notes:
  - Payloads are base64-encoded (e=1) and chunked to <= 4096 bytes per piece.
  - Final chunk sets d=1 to display the notification.
"""

import base64
import json
import sys
from typing import Iterable, Optional


ESC = "\x1b"  # ESC
ST = ESC + "\\"  # String Terminator (ESC \)


def _parse_args(argv: list[str]) -> Optional[str]:
    """Return the JSON string from argv (stdin mode disabled)."""
    if len(argv) < 2:
        print("Usage: codex_notifier.py <NOTIFICATION_JSON>", file=sys.stderr)
        return None
    if argv[1] == "-":
        print("stdin mode is disabled; pass JSON as a single argument", file=sys.stderr)
        return None
    # Collect everything after the program name to allow spaces
    return " ".join(argv[1:])


def _b64_chunks(text: str, max_encoded_len: int = 4096) -> Iterable[str]:
    """Yield base64-encoded chunks with each chunk length <= max_encoded_len."""
    if not text:
        return []
    raw = text.encode("utf-8", errors="replace")
    # Base64 expands by ~4/3. We can slice the encoded form directly to stay under 4096.
    enc = base64.b64encode(raw).decode("ascii")
    for i in range(0, len(enc), max_encoded_len):
        yield enc[i : i + max_encoded_len]


def _osc99(metadata: str, payload: str) -> str:
    # Always include both semicolons: ESC ] 99 ; <meta> ; <payload> ST
    return f"{ESC}]99;{metadata};{payload}{ST}"


def send_kitty_notification(title: str | None, body: str | None, *, nid: str = "1") -> None:
    """Send a kitty OSC 99 desktop notification with chunking and base64.

    - Title chunks: i=<nid>:p=title:e=1; <b64>
    - Body  chunks: i=<nid>:p=body:e=1; <b64>
    - Last chunk sets d=1 to display.
    """

    pieces: list[tuple[str, str]] = []

    title_chunks = list(_b64_chunks(title or ""))
    body_chunks = list(_b64_chunks(body or ""))

    # Build metadata/payload pairs, leaving d unset until final piece
    for ch in title_chunks:
        pieces.append((f"i={nid}:p=title:e=1", ch))
    for ch in body_chunks:
        pieces.append((f"i={nid}:p=body:e=1", ch))

    if not pieces:
        return

    # Mark the last one as done
    last_meta, last_payload = pieces[-1]
    pieces[-1] = (last_meta + ":d=1", last_payload)

    # Emit to stderr to avoid interfering with stdout pipelines
    for meta, payload in pieces:
        sys.stderr.write(_osc99(meta, payload))
    try:
        sys.stderr.flush()
    except Exception:
        pass


def _derive_title_body(notification: dict) -> tuple[str, str]:
    ntype = notification.get("type")
    if ntype == "agent-turn-complete":
        assistant_message = (notification.get("last-assistant-message") or "").strip()
        if assistant_message:
            title = f"Codex: {assistant_message}"
        else:
            title = "Codex: Turn Complete!"
        input_messages = notification.get("input-messages", [])
        body = " \n".join(str(m) for m in input_messages if m)
        return title, body
    # Fallback generic mapping
    title = notification.get("title") or "Codex Notification"
    body = notification.get("message") or notification.get("body") or ""
    return str(title), str(body)


def main() -> int:
    json_arg = _parse_args(sys.argv)
    if json_arg is None:
        return 1

    try:
        notification = json.loads(json_arg)
    except json.JSONDecodeError as e:
        print(f"invalid JSON: {e}", file=sys.stderr)
        return 1

    ntype = notification.get("type")
    if ntype not in {"agent-turn-complete", None}:
        # Keep behavior explicit: only known type or generic payload
        print(f"not sending a notification for type: {ntype}", file=sys.stderr)
        return 0

    title, body = _derive_title_body(notification)
    if (not title) and (not body):
        print("empty title/body; nothing to notify", file=sys.stderr)
        return 0

    # Prefer kitty; other terminals may ignore OSC 99 harmlessly.
    send_kitty_notification(title, body, nid=notification.get("thread-id", "1") or "1")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
