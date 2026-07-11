---
name: background-task
description: Use when running a command that may take longer than 60 seconds, may hang, or needs progress monitoring and cancellation without blocking the agent.
---

# Background Task

## Overview

Run long commands in a uniquely named tmux session. Keep each foreground wait under 60 seconds, preserve output and exit status, and remain able to inspect or cancel the exact task.

Do not add a reusable management script. Use the standard tmux workflow below.

## Decision Rule

- Run a command normally when it should finish within 60 seconds.
- Use this workflow when it may exceed 60 seconds or its duration is uncertain.
- Prefer splitting work into foreground commands shorter than 60 seconds when practical.
- Do not use `nohup`, `disown`, an ad hoc watchdog, or one long blocking tool call instead of tmux.

## Start

Choose a collision-resistant session name, retain its state directory for later checks, and replace `COMMAND` with the exact command to run.

```bash
SESSION="bg-$(date +%s)-$$"
STATE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${SESSION}.XXXXXX")"
WORKDIR="${PWD}"
COMMAND='./long-build-command --target release'

WRAPPER='
write_state() {
    value="$1"
    path="$2"
    printf "%s\n" "$value" >"${path}.tmp"
    mv -f "${path}.tmp" "$path"
}

finish() {
    code="$1"
    state="$2"
    trap - HUP INT TERM
    write_state "$code" "$BG_STATE_DIR/exit-code"
    write_state "$state" "$BG_STATE_DIR/status"
    exit "$code"
}

trap "finish 129 cancelled" HUP
trap "finish 130 cancelled" INT
trap "finish 143 cancelled" TERM

write_state running "$BG_STATE_DIR/status"
set +e
bash -lc "$BG_COMMAND" 2>&1 | tee -a "$BG_STATE_DIR/output.log"
code=${PIPESTATUS[0]}

if [ "$code" -eq 0 ]; then
    finish "$code" completed
elif [ "$code" -eq 129 ] || [ "$code" -eq 130 ] || [ "$code" -eq 143 ]; then
    finish "$code" cancelled
else
    finish "$code" failed
fi
'

printf -v LAUNCH '%q ' env BG_STATE_DIR="$STATE_DIR" BG_COMMAND="$COMMAND" bash -lc "$WRAPPER"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    printf 'Refusing to reuse tmux session: %s\n' "$SESSION" >&2
    exit 1
fi

PANE_ID="$(tmux new-session -d -P -F '#{pane_id}' -s "$SESSION" -c "$WORKDIR")"
tmux set-option -t "$SESSION" remain-on-exit on
tmux respawn-pane -k -t "$PANE_ID" "$LAUNCH"
printf 'session=%s\npane=%s\nstate_dir=%s\n' "$SESSION" "$PANE_ID" "$STATE_DIR"
```

Keep `SESSION`, `PANE_ID`, and `STATE_DIR` in the working context. The pane ID avoids assumptions about tmux window and pane indexes. A successful `tmux new-session` means only that launch succeeded, not that the command succeeded.

## Monitor

Each monitoring cycle must be short:

```bash
tmux capture-pane -p -t "$PANE_ID" -S -80
tmux display-message -p -t "$PANE_ID" \
    'pane_dead=#{pane_dead} pane_exit=#{pane_dead_status}'
test -f "$STATE_DIR/status" && printf 'status_file=present\n'
test -f "$STATE_DIR/exit-code" && printf 'exit_code_file=present\n'
```

Use the Read tool to inspect `status`, `exit-code`, and `output.log`. Treat the state files as authoritative. If the pane disappears without a terminal status, report the outcome as unknown rather than guessing.

Choose the next wait from observed progress:

- Start with a short wait, usually 5 to 10 seconds, to catch immediate failures.
- Increase toward 15 to 30 seconds after repeated healthy progress or during an expected quiet phase.
- Shorten toward 5 seconds when output changes quickly, completion is near, or behavior looks suspicious.
- Keep every foreground `sleep` below 60 seconds. Do not tight-poll, and do not use one large sleep.
- After every wait, explicitly decide: continue waiting, inspect more output, cancel, or collect the result.

## Complete

Terminal states are `completed`, `failed`, and `cancelled`. Read `exit-code` and the relevant final section of `output.log` before reporting the result. Do not infer success from log text or a dead pane alone.

## Cancel

Verify the target session first, then request graceful interruption:

```bash
tmux list-sessions -F '#{session_name}'
tmux capture-pane -p -t "$PANE_ID" -S -30
tmux send-keys -t "$PANE_ID" C-c
sleep 2
```

Check `status` and the pane again. If the task remains alive, escalate only against that session:

```bash
tmux kill-session -t "$SESSION"
printf '%s\n' cancelled >"$STATE_DIR/status"
```

After forced cancellation, do not invent an exit code. Never use `killall`, broad `pkill`, or an ambiguous tmux target. Cancellation does not imply automatic retry; diagnose first, then rerun only if the user's task still requires it.

## Cleanup

After reading the final result:

```bash
tmux has-session -t "$SESSION" 2>/dev/null && tmux kill-session -t "$SESSION"
```

Remove `STATE_DIR` only after its logs are no longer needed. Preserve it and report its path when the output is evidence for debugging.

## Quick Reference

| Goal | Command |
|---|---|
| List sessions | `tmux list-sessions` |
| Recent output | `tmux capture-pane -p -t "$PANE_ID" -S -80` |
| Pane state | `tmux display-message -p -t "$PANE_ID" '#{pane_dead} #{pane_dead_status}'` |
| Graceful cancel | `tmux send-keys -t "$PANE_ID" C-c` |
| Forced cancel | `tmux kill-session -t "$SESSION"` |

## Common Mistakes

- Waiting synchronously for the original long command.
- Using a fixed polling interval regardless of progress.
- Treating quiet output as proof of a hang.
- Losing the command exit code through `tee` instead of using `PIPESTATUS[0]`.
- Killing a session before verifying its name and recent output.
- Cleaning logs before reading the final result.
- Automatically retrying a failed or cancelled command.
