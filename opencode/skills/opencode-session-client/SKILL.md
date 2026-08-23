---
name: opencode-session-client
description: 'Drive opencode 2 sessions from the shell with the opencode2 CLI: send a prompt and wait for the reply, list/create/delete sessions, read past messages, and export a session (JSON) or render it as a readable markdown transcript. Use when the user asks to talk to / message an opencode session, send a prompt and wait, list or manage sessions, or dump/export a session. Triggers: "send message to opencode session", "talk to opencode session", "wait for opencode reply", "list opencode sessions", "export session", "dump session". Only the opencode2 binary; no scripts. Do NOT use for parallel multi-agent orchestration - use the agent-team skill.'
---

# OpenCode Session Client (V2)

A doc-only skill: everything is done with the `opencode2` CLI. There is no
helper script, because the CLI and its built-in `api` subcommand already cover
session management, prompting, waiting, reading, and exporting.

## When to Use

- Drive an existing opencode session from outside its TUI (shell scripts,
  cron, other automation, another LLM).
- Send a one-shot prompt to an opencode session and wait synchronously for the
  reply (`opencode2 run --session ...`).
- List sessions on the running background service and pick one.
- Create or delete sessions for ad-hoc scripted workflows.
- Export a session as JSON, or render it as a readable markdown transcript
  (with thinking/tool noise stripped) for offline analysis.

If you need to **orchestrate a team of opencode workers in parallel**, use
the separate `agent-team` skill instead. This skill is the simpler "single
session, send + poll" primitive.

## Prerequisites

- `opencode2` is installed and the background service is running. Verify:
  ```bash
  opencode2 service status
  # -> http://127.0.0.1:49374
  ```
- The API is healthy:
  ```bash
  opencode2 api get /api/health
  # -> {"healthy":true,"version":"0.0.0-beta-...","pid":...}
  ```

No port, host, or auth flags are needed for the local background service:
`opencode2` discovers it automatically. Use `--server URL` only for a custom
or remote server.

## Quick Start

### 1. List sessions and pick one

```bash
opencode2 api get "/api/session?limit=10"
# -> {"data":[{id,title,agent,model,location,...}], "cursor":{...}}
```

Filter by working directory to find sessions for a specific project:

```bash
opencode2 api get "/api/session?directory=/home/user/my-project"
```

### 2. Send a prompt to a session and wait for the reply

```bash
opencode2 run --session ses_26279da23ffeR5gUrvp7A9OBq6 "Summarize the last test run."
# -> build · provider/model ...
#    The last test run had 42 passing and 3 failing...
```

`run` blocks until the assistant finishes and prints the response text. Use
`--format json` when the output feeds a script (see below).

### 3. Create a session, use it, delete it

```bash
SES=$(opencode2 api post /api/session --data '{}' | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["id"])')
echo "$SES"  # -> ses_241c32a2dffeYaEeSJJ0tTK4dU
opencode2 run --session "$SES" "Hello, who are you?"
opencode2 api delete /api/session/$SES   # cleanup
```

## Common Tasks

### Send and wait for a response (single shot)

```bash
opencode2 run --session ses_xxx "what is in this directory?"
```

By default only the final response text (plus a small header line) is printed.
Other flags:

| Flag | Meaning |
|---|---|
| `--format json` | Machine-readable event stream (JSONL), one event per line |
| `--agent NAME` | Route through a specific agent (`build`, `explore`, etc.) |
| `--model provider/model#variant` | Override the model (`providerID/modelID[#variant]`) |
| `--file PATH` | Attach a file to the prompt |
| `--title TITLE` | Set the session title |
| `--thinking` | Also print thinking/reasoning blocks |
| `--fork` | Fork the session before continuing |
| `--continue, -c` | Continue the last session instead of `--session` |

Examples:

```bash
opencode2 run --session ses_xxx --agent explore \
  "Find all files that reference the PaymentService class."
opencode2 run --session ses_xxx --model provider/model#variant \
  "Refactor the authentication middleware."
opencode2 run --session ses_xxx --file tests/data.csv \
  "Analyze this data and summarize trends."
```

### Parse JSON output in a script

`--format json` emits one JSON object per line. Text parts look like:

```json
{"type":"text","timestamp":...,"sessionID":"ses_xxx","part":{"type":"text","text":"..."}}
```

Extract all assistant text:

```bash
opencode2 run --session ses_xxx --format json "..." | python3 -c '
import json, sys
for line in sys.stdin:
    item = json.loads(line)
    if item.get("type") == "text":
        part = item.get("part") or {}
        text = part.get("text")
        if text:
            print(text.strip())
'
```

### Send asynchronously and wait later

Useful when you want to enqueue several prompts, or when the caller must not
block on the reply:

```bash
opencode2 api post /api/session/ses_xxx/prompt --data '{"text":"Run pytest and report results."}'
# -> {"data":{"id":"msg_...","type":"user",...}}   (queued)
```

Wait for the session to finish (blocks server-side, returns when idle):

```bash
opencode2 api post /api/session/ses_xxx/wait
```

Then read the results:

```bash
opencode2 api get /api/session/ses_xxx/message
```

### Read past messages

```bash
opencode2 api get /api/session/ses_xxx/message
# -> {"data":[{id,type:"user"|"assistant",agent,model,content:[...]}, ...]}
```

Extract only the latest assistant text with jq:

```bash
opencode2 api get /api/session/ses_xxx/message | jq -r '
  .data[] | select(.type == "assistant")
       | .content[] | select(.type == "text") | .text
' | tail -n 5
```

Note the V2 message shape: top-level `type` (not `role`) and `content`
array (not `parts`).

### List agents and models

```bash
opencode2 api get /api/agent   # agents usable with --agent
opencode2 models               # available models (pick providerID/modelID from the list)
```

### Export a session transcript

```bash
opencode2 export ses_xxx > session.json
# -> {"info":{...},"messages":[...]}
```

`--sanitize` redacts sensitive transcript and file data. The JSON shape is
`info` (metadata) plus `messages`. User messages carry a flat `text` field;
assistant messages carry a `content` array with `text`, `reasoning`
(thinking), and `tool` parts.

Render it as a readable markdown transcript (drop thinking/tool noise) for
offline reading or LLM re-analysis:

```bash
opencode2 export ses_xxx | python3 -c '
import json, sys
doc = json.load(sys.stdin)
for msg in doc["messages"]:
    if msg["type"] == "user":
        print("## user\n\n" + msg.get("text", "") + "\n")
    else:
        print("## " + (msg.get("agent") or "assistant") + "\n")
        for part in msg.get("content", []):
            if part["type"] == "text":
                print(part["text"] + "\n")
            # reasoning (thinking) and tool parts are skipped here;
            # remove this filter to keep them
'
```

### Find recent sessions (time-window filter)

`export` has no time filter, but session list carries `time.created` (epoch
ms), so filter locally:

```bash
opencode2 api get "/api/session?limit=100" | python3 -c '
import json, sys, time
cutoff = time.time() - 2 * 86400  # last 2 days
for s in json.load(sys.stdin)["data"]:
    if (s.get("time", {}).get("created") or 0) / 1000 >= cutoff:
        print(s["id"], s.get("title") or "", s.get("location", {}).get("directory"))
'
```

## Endpoint Reference

| Method | Path | Use |
|---|---|---|
| GET | `/api/health` | Health check |
| GET | `/api/session` | List sessions (`?limit=`, `?directory=`, `?cursor=`, `?search=`...) |
| POST | `/api/session` | Create session (`--data '{}'`) |
| GET | `/api/session/{id}` | Get session |
| DELETE | `/api/session/{id}` | Delete session |
| POST | `/api/session/{id}/prompt` | Send message asynchronously (`--data '{"text":"..."}'`) |
| POST | `/api/session/{id}/wait` | Block until the session is idle |
| GET | `/api/session/{id}/message` | Read messages |
| GET | `/api/session/{id}/export` | Export session |
| GET | `/api/agent` | List agents |
| POST | `/api/session/{id}/interrupt` | Interrupt running work |

Query parameters go directly in the URL (`?limit=2`); the `--param` flag is
unreliable in current beta builds.

## Cheat Sheet

```text
opencode2 service status                                        # is the service up?
opencode2 api get /api/health                                   # server health
opencode2 api get "/api/session?limit=10"                       # list sessions
opencode2 api get "/api/session?directory=/path"                # list sessions by dir
opencode2 api post /api/session --data '{}'                     # create session
opencode2 api delete /api/session/ses_xxx                       # delete session
opencode2 run --session ses_xxx "prompt"                        # send + wait (common case)
opencode2 run --session ses_xxx --format json "prompt"          # send + wait (machine-readable)
opencode2 run -c "prompt"                                       # continue last session
opencode2 api post /api/session/ses_xxx/prompt --data '{"text":"prompt"}'  # async send
opencode2 api post /api/session/ses_xxx/wait                    # wait until idle
opencode2 api get /api/session/ses_xxx/message                  # read messages
opencode2 export ses_xxx                                        # export transcript
opencode2 models                                                # list models
opencode2 api get /api/agent                                    # list agents
```

## Anti-Patterns

- **Do NOT** use this skill to orchestrate multiple workers - use `agent-team`.
- **Do NOT** call `opencode2 run --session` on the session your own agent is
  currently running in - you would be waiting for yourself.
- **Do NOT** poll `/api/session/{id}/message` in a busy loop to detect
  completion - use `run` (blocks until done) or `prompt` + `wait`.
- **Do NOT** rely on `--param` for query parameters in beta builds - put them
  in the URL instead (e.g. `?limit=2`).