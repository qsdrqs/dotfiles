---
name: background-task
description: Use when running a long-running or interactive command that needs supervised startup, background completion notification, progress inspection, or precise cancellation.
---

# Background Task

## Overview

Run long-running or interactive commands in a uniquely named tmux session. Start with adaptive foreground monitoring, then move a healthy non-interactive task to a background completion listener with a soft review deadline. Preserve output and exit status, and remain able to inspect or cancel the exact task.

Do not add a reusable management script. Use the standard tmux workflow below.

## Decision Rule

- Run a command normally when it is quick and one-shot.
- Use this workflow when the command is long-running, interactive, may hang, or its duration is uncertain.
- Do not use one long blocking tool call as a substitute for this workflow.
- Do not move an interactive task or a task that is not expected to terminate into callback waiting.
- Do not use `nohup`, `disown`, an ad hoc watchdog, or one long blocking tool call instead of tmux.

## Start

Choose a collision-resistant session name, retain its state directory for later checks, and replace `COMMAND` and `REVIEW_AFTER`. Use a long, task-specific `REVIEW_AFTER` duration accepted by `timeout`, such as `30m` or `2h`.

```bash
SESSION="bg-$(date +%s)-$$"
STATE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/${SESSION}.XXXXXX")"
WORKDIR="${PWD}"
COMMAND='./long-build-command --target release'
REVIEW_AFTER='REPLACE_WITH_DURATION'

WRAPPER='
write_state() {
    value="$1"
    path="$2"
    tmp="${path}.tmp.$$"
    printf "%s\n" "$value" >"$tmp"
    mv -f "$tmp" "$path"
}

initialize_state() {
    (
        flock -x 9
        case "$(cat "$BG_STATE_DIR/status" 2>/dev/null)" in
            completed|failed|cancelled)
                exit 1
                ;;
        esac
        write_state running "$BG_STATE_DIR/status"
    ) 9>"$BG_STATE_DIR/state.lock"
}

commit_terminal() {
    code="$1"
    state="$2"
    (
        flock -x 9
        case "$(cat "$BG_STATE_DIR/status" 2>/dev/null)" in
            completed|failed|cancelled)
                exit 0
                ;;
        esac
        write_state "$code" "$BG_STATE_DIR/exit-code"
        write_state "$state" "$BG_STATE_DIR/status"
    ) 9>"$BG_STATE_DIR/state.lock"
}

finish() {
    code="$1"
    state="$2"
    trap - HUP INT TERM
    if ! commit_terminal "$code" "$state"; then
        printf "Failed to commit terminal task state: %s\n" "$state" >&2
    fi
    exit "$code"
}

trap "finish 129 cancelled" HUP
trap "finish 130 cancelled" INT
trap "finish 143 cancelled" TERM

if ! initialize_state; then
    printf "Refusing to start after terminal state was committed\n" >&2
    exit 1
fi

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

LISTENER='
set +e

exec 8>"$BG_STATE_DIR/listener.lock"
if ! flock -n 8; then
    printf "wake_reason=listener_error\ndetail=listener_already_active\nsession=%s\npane=%s\nstate_dir=%s\n" \
        "$BG_SESSION" "$BG_PANE_ID" "$BG_STATE_DIR"
    exit 75
fi

case "$(cat "$BG_STATE_DIR/status" 2>/dev/null)" in
    completed|failed|cancelled)
        code=0
        ;;
    *)
        timeout "$BG_REVIEW_AFTER" \
            tail --pid="$BG_PANE_PID" -f /dev/null >/dev/null 2>&1
        code=$?
        ;;
esac

case "$code" in
    0)
        reason=task_event
        ;;
    124)
        reason=review_deadline
        ;;
    *)
        reason=listener_error
        ;;
esac

printf "wake_reason=%s\nsession=%s\npane=%s\nstate_dir=%s\n" \
    "$reason" "$BG_SESSION" "$BG_PANE_ID" "$BG_STATE_DIR"

if [ "$reason" = listener_error ]; then
    exit "$code"
fi
'

printf -v LAUNCH '%q ' env \
    BG_STATE_DIR="$STATE_DIR" \
    BG_COMMAND="$COMMAND" \
    bash -lc "$WRAPPER"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    printf 'Refusing to reuse tmux session: %s\n' "$SESSION" >&2
    exit 1
fi

for tool in flock tail timeout; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required command not found: %s\n' "$tool" >&2
        exit 1
    fi
done

PANE_ID="$(tmux new-session -d -P -F '#{pane_id}' -s "$SESSION" -c "$WORKDIR")"
tmux set-option -t "$SESSION" remain-on-exit on
tmux respawn-pane -k -t "$PANE_ID" "$LAUNCH"
PANE_PID="$(tmux display-message -p -t "$PANE_ID" '#{pane_pid}')"

printf -v LISTENER_LAUNCH '%q ' env \
    BG_SESSION="$SESSION" \
    BG_PANE_ID="$PANE_ID" \
    BG_PANE_PID="$PANE_PID" \
    BG_STATE_DIR="$STATE_DIR" \
    BG_REVIEW_AFTER="$REVIEW_AFTER" \
    bash -lc "$LISTENER"

printf 'session=%s\npane=%s\npane_pid=%s\nstate_dir=%s\nlistener_launch=%s\n' \
    "$SESSION" "$PANE_ID" "$PANE_PID" "$STATE_DIR" "$LISTENER_LAUNCH"
```

Keep `SESSION`, `PANE_ID`, `PANE_PID`, `STATE_DIR`, and the emitted `listener_launch` command in the working context. The pane ID avoids assumptions about tmux window and pane indexes. A successful `tmux new-session` means only that launch succeeded, not that the command succeeded.

## Arm the Listener

Immediately after launch, run the exact emitted `listener_launch` value with the shell tool's background mode. Its completion notification is the callback. The listener watches the pane process directly, so its review deadline leaves no tmux server-side waiter behind. Its `flock` is released automatically on every exit path and rejects overlapping listeners.

The review deadline ends only the listener, not the tmux task. Arm the listener before the first monitoring wait. To renew after a deadline, run the same emitted command again only after the previous listener exits. Regenerate it with a different `REVIEW_AFTER` only when the observed task phase justifies changing the review duration.

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

Start in adaptive polling mode. Choose the next wait from observed progress:

- Start with a short wait, usually 5 to 10 seconds, to catch immediate failures.
- Increase toward 15 to 30 seconds after repeated healthy progress or during an expected quiet phase.
- Shorten toward 5 seconds when output changes quickly, completion is near, or behavior looks suspicious.
- Vary each foreground `sleep` adaptively based on observed progress; do not use a fixed interval. Keep a single `sleep` at or under 10 minutes. Do not tight-poll, and do not use one huge sleep to wait out the whole task.
- After every wait, explicitly decide: continue waiting, inspect more output, cancel, or collect the result.

Stop active polling and rely on the already armed listener only when all of the following are true:

- The command is non-interactive and expected to terminate.
- It has passed the startup phase where immediate failures or input prompts are likely.
- Recent output contains no password, confirmation, menu, or other input request.
- Observed output shows credible healthy progress, not merely a live pane.
- The listener is active.

Do not poll while callback waiting is active unless the user requests progress or new evidence makes the task suspicious.

## Handle Listener Wakeups

The listener reports `task_event`, `review_deadline`, or `listener_error`. Treat each value only as a reason to inspect the task. Always read `status` first, then inspect the pane and recent log when the state is still `running`.

- If `status` is terminal, collect the result.
- If `review_deadline` fires while the task is healthy and making credible progress, arm one new listener with a newly chosen review duration.
- If the deadline fires without credible progress, resume adaptive polling or diagnose the task. A live process alone is not evidence of progress.
- If the task now needs input, resume active monitoring and interact through the exact pane.
- If `listener_error` fires, inspect the authoritative state and either re-arm the listener or resume polling. Do not mark the target task failed because its listener failed.
- If `task_event` fires but the state remains `running`, inspect the pane before deciding whether the event was stale or the pane exited without writing terminal state.

Re-arm only after the previous listener has exited. If the task finishes between listeners, the state check or the absent pane PID makes the next listener return promptly.

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
(
    flock -x 9
    case "$(cat "$STATE_DIR/status" 2>/dev/null)" in
        completed|failed|cancelled)
            exit 0
            ;;
    esac
    rm -f "$STATE_DIR/exit-code"
    tmp="$STATE_DIR/status.cancel.$$"
    printf '%s\n' cancelled >"$tmp"
    mv -f "$tmp" "$STATE_DIR/status"
) 9>"$STATE_DIR/state.lock"
```

Graceful and forced cancellation wake the listener when the pane PID exits. The state lock preserves a terminal state that won the race before forced cancellation. After forced cancellation, do not invent an exit code. Never use `killall`, broad `pkill`, or an ambiguous tmux target. Cancellation does not imply automatic retry; diagnose first, then rerun only if the user's task still requires it.

## Cleanup

After reading the final result:

```bash
tmux has-session -t "$SESSION" 2>/dev/null && tmux kill-session -t "$SESSION"
```

Remove `STATE_DIR` only after the listener has exited and its logs are no longer needed. Preserve it and report its path when the output is evidence for debugging. If the agent or OpenCode restarts, inspect the state and pane first. Re-arm only for a live running pane; the listener lock rejects overlap if an old listener survived.

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
- Waiting for the tmux session to disappear even though `remain-on-exit` keeps it alive.
- Wrapping `tmux wait-for` in `timeout`; the timed-out client can leave a server-side waiter behind.
- Starting the callback listener only after polling stops and leaving a completion race.
- Running overlapping listeners for the same task.
- Treating a review deadline or listener failure as target-task failure.
- Treating a live process as proof of healthy progress.
- Treating quiet output as proof of a hang.
- Losing the command exit code through `tee` instead of using `PIPESTATUS[0]`.
- Killing a session before verifying its name and recent output.
- Cleaning logs before reading the final result.
- Automatically retrying a failed or cancelled command.
