#!/usr/bin/env python3
import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_DB = Path(os.environ.get("OPENCODE_DB", Path.home() / ".local/share/opencode/opencode.db"))
TRUNC_LIMIT = 4000


def fmt_ts(ts_ms):
    if not ts_ms:
        return ""
    try:
        return datetime.fromtimestamp(ts_ms / 1000.0, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except Exception:
        return str(ts_ms)


def parse_iso(s):
    if not s:
        return None
    try:
        return int(datetime.fromisoformat(s.replace("Z", "+00:00")).timestamp() * 1000)
    except ValueError:
        sys.exit(f"ERROR: invalid ISO timestamp: {s!r}")


def render_part(data, include_thinking=True, include_tools=True):
    ptype = data.get("type", "?")
    if ptype == "text":
        return data.get("text", "")
    if ptype == "reasoning":
        if not include_thinking:
            return ""
        return f"[thinking]\n{data.get('text', '')}\n[/thinking]"
    if ptype == "tool":
        if not include_tools:
            return ""
        tname = data.get("tool", "?")
        state = data.get("state", {}) or {}
        status = state.get("status", "")
        inp = state.get("input", {})
        out = state.get("output", "")
        try:
            inp_str = json.dumps(inp, ensure_ascii=False, indent=2)
        except Exception:
            inp_str = repr(inp)
        out_str = out if isinstance(out, str) else json.dumps(out, ensure_ascii=False)
        if len(out_str) > TRUNC_LIMIT:
            out_str = out_str[:TRUNC_LIMIT] + f"\n... [TRUNCATED {len(out_str)-TRUNC_LIMIT} chars]"
        return f"[tool: {tname} status={status}]\nINPUT: {inp_str}\nOUTPUT:\n{out_str}"
    if ptype == "file":
        return f"[file: {data.get('filename', '?')}]"
    if ptype in ("step-start", "step-finish"):
        return ""
    return f"[part type={ptype}] {json.dumps(data, ensure_ascii=False)[:300]}"


def cmd_list(args):
    db = sqlite3.connect(args.db)
    db.row_factory = sqlite3.Row
    where = []
    params = []
    if args.from_:
        where.append("m.time_created >= ?")
        params.append(parse_iso(args.from_))
    if args.to:
        where.append("m.time_created <= ?")
        params.append(parse_iso(args.to))

    sql = """
        SELECT s.id, COUNT(m.id) AS msgs,
               MIN(m.time_created) AS first_ts,
               MAX(m.time_created) AS last_ts
        FROM session s
        LEFT JOIN message m ON m.session_id = s.id
    """
    if where:
        sql += " WHERE " + " AND ".join(where)
    sql += " GROUP BY s.id"
    sql += " HAVING msgs > 0" if not args.include_empty else ""
    sql += " ORDER BY last_ts DESC"
    if args.limit:
        sql += f" LIMIT {int(args.limit)}"

    rows = db.execute(sql, params).fetchall()
    print(f"{'session_id':<48} {'msgs':>5}  {'first':<20} {'last':<20}")
    print("-" * 100)
    for r in rows:
        print(f"{r['id']:<48} {r['msgs']:>5}  {fmt_ts(r['first_ts']):<20} {fmt_ts(r['last_ts']):<20}")
    print(f"\nTotal: {len(rows)} sessions")


def cmd_dump(args):
    db = sqlite3.connect(args.db)
    db.row_factory = sqlite3.Row
    sid = args.session_id

    where = ["session_id = ?"]
    params = [sid]
    if args.from_:
        where.append("time_created >= ?")
        params.append(parse_iso(args.from_))
    if args.to:
        where.append("time_created <= ?")
        params.append(parse_iso(args.to))
    where_sql = " AND ".join(where)

    msgs = db.execute(
        f"SELECT id, time_created, data FROM message WHERE {where_sql} ORDER BY time_created, id",
        params,
    ).fetchall()

    if not msgs:
        sys.exit(f"ERROR: no messages found for session {sid!r} (with given filters)")

    msg_ids = [m["id"] for m in msgs]
    placeholders = ",".join("?" for _ in msg_ids)
    parts_by_msg = {}
    for p in db.execute(
        f"SELECT id, message_id, time_created, data FROM part WHERE message_id IN ({placeholders}) ORDER BY message_id, time_created, id",
        msg_ids,
    ).fetchall():
        parts_by_msg.setdefault(p["message_id"], []).append(p)

    out = [f"# Session dump: {sid}", f"Total messages: {len(msgs)}", ""]
    for m in msgs:
        mdata = json.loads(m["data"])
        role = mdata.get("role", "?")
        agent = mdata.get("agent", "")
        ts = fmt_ts(m["time_created"])
        atag = f" ({agent})" if agent else ""
        out.append(f"\n---\n## [{role}{atag}] {ts}  id={m['id']}\n")
        for p in parts_by_msg.get(m["id"], []):
            pdata = json.loads(p["data"])
            rendered = render_part(pdata, include_thinking=not args.no_thinking, include_tools=not args.no_tools)
            if rendered:
                out.append(rendered)
                out.append("")

    output_path = Path(args.output) if args.output else Path(f"{sid}.dump.md")
    output_path.write_text("\n".join(out), encoding="utf-8")
    total_parts = sum(len(v) for v in parts_by_msg.values())
    print(f"WROTE {output_path} ({len(msgs)} messages, {total_parts} parts, {output_path.stat().st_size} bytes)")


def main():
    parser = argparse.ArgumentParser(description="Dump opencode session trajectory to markdown.")
    parser.add_argument("--db", default=str(DEFAULT_DB), help=f"opencode SQLite DB (default: {DEFAULT_DB})")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_list = sub.add_parser("list", help="List sessions")
    p_list.add_argument("--from", dest="from_", help="ISO timestamp lower bound (e.g. 2026-04-20)")
    p_list.add_argument("--to", help="ISO timestamp upper bound")
    p_list.add_argument("--limit", type=int, default=50, help="Max rows (default 50)")
    p_list.add_argument("--include-empty", action="store_true", help="Show sessions with 0 messages")
    p_list.set_defaults(func=cmd_list)

    p_dump = sub.add_parser("dump", help="Dump a session to markdown")
    p_dump.add_argument("session_id", help="Session ID (e.g. ses_xxxxxxxxxxxx)")
    p_dump.add_argument("-o", "--output", help="Output markdown file (default: <session_id>.dump.md in cwd)")
    p_dump.add_argument("--from", dest="from_", help="ISO timestamp lower bound to filter messages")
    p_dump.add_argument("--to", help="ISO timestamp upper bound to filter messages")
    p_dump.add_argument("--no-thinking", action="store_true", help="Strip reasoning parts")
    p_dump.add_argument("--no-tools", action="store_true", help="Strip tool input/output parts")
    p_dump.set_defaults(func=cmd_dump)

    args = parser.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
