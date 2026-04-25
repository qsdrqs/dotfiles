---
name: opencode-session-trajectory-dump
description: Dump opencode chat session trajectories (messages, thinking, tool I/O) to readable markdown files for offline analysis, sharing, or LLM-driven review. Use when the user asks to (1) dump/export an opencode session by ID, (2) save chat history to disk, (3) get a markdown transcript of a past session, (4) list recent opencode sessions, or (5) extract trajectories for a specific time range. Triggers on phrases like "dump session ses_xxx", "导出聊天记录", "save trajectory", "export the chat", "list recent sessions". Reads directly from the opencode SQLite database; does NOT use the MCP session_read tool (which truncates and is slow on long sessions).
---

# Opencode Session Trajectory Dump

## When to Use This Over MCP `session_read`

The MCP `session_read` tool has two limitations that make it bad for full dumps:
- Output > ~50KB gets truncated mid-stream (the tool reports the truncation but you lose the tail)
- `offset`/`limit` parameters do not work as expected for messages (they index into transcript entries, not messages)

This skill bypasses MCP and reads the opencode SQLite DB at `~/.local/share/opencode/opencode.db` directly. Use this skill any time the user wants the full trajectory of a session, not a partial peek.

## Quick Start

The skill ships one script at `scripts/dump_session.py` with two subcommands.

### Dump a session

```bash
python <skill_dir>/scripts/dump_session.py dump <session_id> [-o output.md]
```

Default output is `<session_id>.dump.md` in the current working directory.

### List recent sessions

```bash
python <skill_dir>/scripts/dump_session.py list [--limit N] [--from ISO] [--to ISO]
```

Sorted by most-recent-message DESC.

## Common Tasks

### "Dump session ses_xxx for me"

```bash
python <skill_dir>/scripts/dump_session.py dump ses_xxx -o /tmp/ses_xxx.dump.md
```

Then read the file with the `read` tool (use `offset`/`limit` for large files; dumps can exceed 500KB).

### "Show me only the user/assistant text, no tool noise"

```bash
python <skill_dir>/scripts/dump_session.py dump ses_xxx --no-thinking --no-tools -o /tmp/ses_xxx.clean.md
```

Stripping thinking + tools typically reduces size by 5x and is ideal for LLM-driven re-analysis.

### "List sessions from the last 2 days"

```bash
python <skill_dir>/scripts/dump_session.py list --from 2026-04-22 --limit 20
```

Date can be `YYYY-MM-DD` or full ISO `2026-04-22T10:00:00`.

### "Dump only the messages between two timestamps"

```bash
python <skill_dir>/scripts/dump_session.py dump ses_xxx --from 2026-04-22T05:00 --to 2026-04-22T18:00 -o /tmp/slice.md
```

## Output Format

Each message becomes:

```markdown
---
## [role (agent_name)] 2026-04-22T17:30:54Z  id=msg_xxx

[thinking]
...reasoning text...
[/thinking]

[tool: bash status=completed]
INPUT: { "command": "..." }
OUTPUT:
...stdout/stderr (truncated at 4000 chars per tool call)...

regular assistant text
```

## Script Flags Reference

| Flag | Subcommand | Purpose |
|---|---|---|
| `--db PATH` | global | Override SQLite DB path (default `~/.local/share/opencode/opencode.db`, also via `$OPENCODE_DB`) |
| `-o`, `--output` | dump | Output markdown path (default `./<session_id>.dump.md`) |
| `--no-thinking` | dump | Strip `reasoning` parts |
| `--no-tools` | dump | Strip tool input/output parts |
| `--from`, `--to` | both | ISO timestamp filter (`YYYY-MM-DD` or full ISO) |
| `--limit N` | list | Cap rows (default 50) |
| `--include-empty` | list | Include sessions with 0 messages |

## Troubleshooting

- **"no messages found"**: Verify the session ID exists with `list`, or the `--from`/`--to` window is too narrow.
- **DB locked**: Opencode is writing to the DB. Re-run; SQLite is concurrent-read safe but contention can cause transient errors.
- **Tool output truncated at 4000 chars**: This is intentional to keep dumps manageable. Edit `TRUNC_LIMIT` in the script if a session has a single critical large tool output.
- **Session ID not in DB but visible in MCP**: Some session IDs come from compaction/checkpoint sessions stored elsewhere. The DB only contains live sessions for the current install.
