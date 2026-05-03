---
name: opencode-session-client
description: Stateless HTTP client for talking to a running opencode server by port. Send a message to a session, poll for the assistant's response (idle + new-message strategy), list/create/delete sessions, or read past messages. Use when the user asks to (1) connect to / talk to / message an opencode session by port, (2) drive an opencode session from the shell, (3) script an opencode session (send + wait + read), (4) bridge to an opencode TUI/serve instance running on localhost or another host, (5) list or manage sessions on an opencode server. Triggers on phrases like "connect to opencode session", "send message to opencode on port", "talk to opencode session", "poll opencode for response", "list opencode sessions". Uses only Python 3.10+ stdlib and opencode's HTTP API. Do NOT use this for orchestrating multiple agents in parallel - use the agent-team skill for that.
---

# OpenCode Session Client

A small stateless Python CLI that speaks the opencode HTTP API. One opencode
server hosts many sessions; this skill lets you target one of them by ID, send
a prompt, and poll until the assistant has replied.

## When to Use

- Drive an existing opencode session from outside its TUI (shell scripts,
  cron, other automation, another LLM).
- Send a one-shot question to an opencode session and wait synchronously for
  the answer (`send-and-wait`).
- List sessions on a running opencode server (default port 4096) and pick one.
- Create or delete sessions for ad-hoc scripted workflows.

If you need to **orchestrate a team of opencode workers in parallel**, use
the separate `agent-team` skill instead. This skill is the simpler "single
session, send + poll" primitive.

## Prerequisites

An opencode server must be reachable. Either:
- The user is running `opencode --port 4096` (TUI + server on same port), or
- A standalone `opencode serve --port 4096`, or
- Any other reachable host:port combination.

Confirm with:
```bash
python3 <skill_dir>/scripts/oc_session.py health --port 4096
```

The script needs only Python 3.10+ stdlib (`urllib`, `json`, `argparse`).

## Locating the Script

Resolve `<skill_dir>` from this skill's load path. The script lives at
`<skill_dir>/scripts/oc_session.py` and is executable, so it can be invoked as
either `python3 <path>` or directly.

For brevity below, this doc abbreviates `python3 <skill_dir>/scripts/oc_session.py`
as `oc`.

## Global Flags

Every subcommand accepts these globals (most are optional, sensible defaults):

| Flag | Default | Notes |
|---|---|---|---|
| `--port` | `4096` | Override with env `OPENCODE_PORT` |
| `--host` | `127.0.0.1` | Override with env `OPENCODE_HOST` |
| `--json` | off | Emit machine-readable JSON instead of text |
| `--dir` | none | Filter sessions by directory (for `list-sessions`); working directory context |
| `--agent` | none | Agent type for prompt processing: `build`, `explore`, `oracle`, etc. (for `send`/`send-and-wait`) |
| `--model` | none | Model in `providerID/modelID` format, e.g. `openai/gpt-4o` (for `send`/`send-and-wait`) |

Subcommands that target a specific session also accept `--session SES_ID`
(or env `OPENCODE_SESSION`).

Polling subcommands accept `--timeout` (default 300s) and `--interval`
(default 2s).

## Quick Start

### 1. Verify the server

```bash
oc health --port 4096
# -> healthy=True version=1.14.22 url=http://127.0.0.1:4096
```

### 2. List existing sessions and pick one

```bash
oc list-sessions --port 4096
# session_id                     | slug          | title              | directory
# ses_26279da23ffeR5gUrvp7A9OBq6 | quick-falcon  | Some session title | /path/to/project
```

Filter by directory to find sessions for a specific project:

```bash
oc list-sessions --port 4096 --dir /home/user/my-project
# session_id                     | slug          | title              | directory
# ses_26279da23ffeR5gUrvp7A9OBq6 | quick-falcon  | My project session | /home/user/my-project
```

### 3. Talk to a session and wait for the reply

```bash
oc send-and-wait \
  --port 4096 \
  --session ses_26279da23ffeR5gUrvp7A9OBq6 \
  --message "Summarize the last test run."
# -> [assistant] (msg_xxx)
#    The last test run had 42 passing and 3 failing...
```

That single command does: snapshot current message count -> async POST the
prompt -> poll `/session/status` and `/session/{id}/message` -> return when
the session is idle AND new messages have arrived.

## Common Tasks

### Send and wait for a response (single shot)

```bash
oc send-and-wait \
  --session ses_xxx \
  --message "what is in this directory?" \
  --timeout 600 --interval 3
```

`--timeout 600` allows up to 10 minutes for the assistant to finish.
`--interval 3` polls every 3s.

### Specify an agent type for a prompt

Use `--agent` to route the prompt through a specific subagent type:

```bash
oc send-and-wait \
  --session ses_xxx \
  --agent explore \
  --message "Find all files that reference the PaymentService class."
```

Available agents typically include `build`, `explore`, `oracle`, `plan`, `general`,
and others configured on the server. Omitting `--agent` uses the session's default.

### Specify a model for a prompt

Use `--model` to override the model used for processing. Format is
`providerID/modelID`:

```bash
oc send-and-wait \
  --session ses_xxx \
  --model openai/gpt-4o \
  --message "Refactor the authentication middleware."
```

Agent and model can be combined:

```bash
oc send-and-wait \
  --session ses_xxx \
  --agent explore \
  --model anthropic/claude-sonnet-4 \
  --message "Audit the codebase for hardcoded secrets."
```

By default only assistant messages are returned. Add `--all-messages` to
include the user echo and any tool messages too.

Add `--from "alice"` to prefix the outgoing message with `[FROM alice]`,
matching the agent-team peer-message convention.

### Send asynchronously and continue (fire-and-forget)

```bash
oc send --session ses_xxx --message "Run pytest and report results."
# -> queued (session=ses_xxx, 32 bytes)
```

The `send` command returns immediately after the server accepts the prompt
(HTTP 204). Use `wait` or `poll` later to retrieve the reply.

Agent and model flags also apply to async sends:

```bash
oc send --session ses_xxx --agent oracle --model openai/gpt-4o --message "Analyze the test output."
```

### Poll for new messages without sending

Useful when something else queued a prompt and you just want to wait for the
response.

```bash
# Snapshot current count NOW, then wait until count grows AND session is idle.
oc poll --session ses_xxx --timeout 300 --interval 2
```

Override the baseline if you already know it:
```bash
oc poll --session ses_xxx --baseline 42
```

**Important race condition**: `poll` (without `--baseline`) snapshots the
current message count when it starts, then waits for NEW messages past that
count. If you do `send` followed by `poll` as two separate commands, and the
LLM responds faster than the gap between them, the response is already in
the count by the time `poll` starts -> `poll` waits forever for a "next"
response that never comes -> timeout.

Two safe patterns:

1. **Use `send-and-wait` for send+receive** (recommended single-shot pattern):
   it captures baseline atomically before sending.

2. **For separated send+poll**, capture baseline BEFORE sending:
   ```bash
   BASELINE=$(oc read --session ses_xxx --json | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')
   oc send --session ses_xxx --message "..."
   oc poll --session ses_xxx --baseline "$BASELINE" --timeout 300
   ```

### Wait until the session is idle (no message expectation)

```bash
oc wait --session ses_xxx --timeout 120
# -> idle (session=ses_xxx)
```

Equivalent to `wait_until_idle`: returns as soon as `/session/status` no
longer reports the session as `busy`. Does NOT check that any new messages
arrived. Prefer `poll` or `send-and-wait` if you expect a reply.

### Read the most recent N messages

```bash
oc read --session ses_xxx --last 3
oc read --session ses_xxx --last 5 --role assistant
```

`--role` filter accepts `all` (default), `user`, or `assistant`.

### Create a new session and use it

```bash
SES=$(oc create-session --port 4096)
echo "$SES"
# -> ses_241c32a2dffeYaEeSJJ0tTK4dU

oc send-and-wait --session "$SES" --message "Hello, who are you?"
oc delete-session --session "$SES"
```

### Delete a session

```bash
oc delete-session --session ses_xxx
# -> deleted=True session=ses_xxx
```

### List available agent types

```bash
oc list-agents
# agent                | model                    |
# ---------------------+--------------------------+
# build                |                          | (hidden)
# explore              | anthropic/claude-haiku-4-5 |
# oracle               | openai/gpt-5.5           |
```

Use the `--agent` flag with `send` or `send-and-wait` to route a prompt
through a specific agent. Hidden agents are internal and marked as such.

### List available providers and their models

```bash
oc list-providers
# provider       | source   | models
# ---------------+----------+-------
# openai         | [env]    | 15
# anthropic      | [env]    | 24
# deepseek       | [config] | 4
```

List models for a specific provider:

```bash
oc list-models-by-provider --provider openai
# openai (env)
#   active (15):
#     gpt-5.5
#     gpt-5.1-codex-max
#     gpt-5.2
#     ...
```

Use the `--model` flag with `providerID/modelID` format (e.g.
`openai/gpt-5.5`) to override the model for a prompt.

### JSON output for piping into jq / another script

```bash
oc list-sessions --port 4096 --json | jq '.[].id'
oc list-agents --json | jq '.[].name'
oc list-providers --json | jq '.all[].id'
oc list-models-by-provider --json --provider openai | jq '.all[0].models | keys'
oc read --session ses_xxx --last 1 --role assistant --json \
  | jq -r '.[0].parts[0].text'
```

## Polling Strategy: "Idle + New Messages"

The risky path is `send-and-wait` and `poll`, where we have to decide when
the assistant is "done". The script implements a two-phase wait:

1. **Bootstrap (up to 30s):** after `send`, wait until either the session
   becomes `busy` OR the user message appears in `/session/{id}/message`.
   This avoids a race where we check `/session/status`, see the session is
   not yet busy, and conclude (incorrectly) that there is nothing to wait for.

2. **Settle (up to `--timeout`):** wait until the session is no longer `busy`
   AND `len(messages)` exceeds the baseline. Both conditions must hold to
   guarantee we have actually received at least one new message.

The bootstrap window protects against the common race where the LLM hasn't
started streaming yet at the moment of the first poll. The settle window
guarantees we don't return mid-stream.

If the assistant fails to respond within `--timeout`, the command exits
non-zero with `Error: timed out polling session ...`.

## Endpoint Reference

For reference (and for debugging), the script uses these opencode endpoints:

| Method | Path | Use |
|---|---|---|
| GET | `/global/health` | `health` |
| GET | `/session` | `list-sessions` |
| GET | `/agent` | `list-agents` |
| GET | `/provider` | `list-providers`, `list-models-by-provider` |
| POST | `/session` (body `{}`) | `create-session` |
| DELETE | `/session/{id}` | `delete-session` |
| GET | `/session/{id}/message` | `read`, `poll`, `send-and-wait` |
| GET | `/session/status` | `wait`, `poll`, `send-and-wait` |
| POST | `/session/{id}/prompt_async` | `send`, `send-and-wait` |

The `prompt_async` body shape is:
```json
{
  "parts": [{"type": "text", "text": "..."}],
  "agent": "explore",
  "model": {"providerID": "openai", "modelID": "gpt-4o"}
}
```
Both `agent` and `model` are optional. A successful enqueue returns HTTP 204
with no body.

## Subcommand Cheat Sheet

```text
oc health
oc list-sessions                              [--dir DIR]
oc list-agents
oc list-providers
oc list-models-by-provider    --provider PID
oc create-session
oc delete-session   --session SES_ID
oc send             --session SES_ID --message "..." [--from NAME]
                                            [--agent AGENT] [--model MODEL]
oc read             --session SES_ID [--last N] [--role all|user|assistant]
oc wait             --session SES_ID [--timeout 300] [--interval 2]
oc poll             --session SES_ID [--baseline N] [--timeout 300] [--interval 2]
oc send-and-wait    --session SES_ID --message "..." [--from NAME] [--all-messages]
                    [--timeout 300] [--interval 2] [--agent AGENT] [--model MODEL]
```

All subcommands accept `--port`, `--host`, `--json`, `--dir`, `--agent`, and `--model`.
Flags that are not relevant for a subcommand are silently ignored.

## Failure Modes and Exit Codes

- `0` = success
- `1` = `OcError` (server unreachable, HTTP failure, timeout, bad JSON, missing
  `--session`, etc.). Error message is printed to stderr as `Error: ...`.
- `2` = `health` ran but the server reported `healthy: false`.
- `130` = `KeyboardInterrupt` (Ctrl+C during a poll).

Common cases:
- `failed to reach opencode server at http://...`: server is not running on
  that host:port, or wrong host/port.
- `HTTP 404 for GET /session/<id>/message: ...`: session ID does not exist on
  this server.
- `timed out polling session ... for response (after 300s)`: assistant did
  not finish within `--timeout`. Bump `--timeout`, or use `send` + manual
  `poll` to get progress.

## Anti-Patterns

- **Do NOT** use this skill to orchestrate multiple workers - use `agent-team`.
- **Do NOT** call `send-and-wait` from inside the same opencode session you
  are targeting (you would be waiting for yourself).
- **Do NOT** use `wait` alone when you actually expect a reply - it returns
  on idle even if no new messages arrived (e.g. the session was never busy).
  Use `poll` or `send-and-wait` for that.
- **Do NOT** poll with `--interval` smaller than ~1s; the server prefers
  larger intervals and the LLM rarely produces tokens that fast anyway.
