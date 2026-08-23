---
name: agent-team
description: >
  Orchestrate a swarm of AI agents for parallel task execution using opencode 2 sessions and tmux.
  Worker sessions live on the shared background service; tmux windows provide
  visual monitoring via the full opencode2 TUI. A standardized Python CLI (swarm.py) handles all
  inter-agent communication. Use when: (1) user asks to parallelize work across agents,
  (2) user says "spin up a team", "agent team", "swarm", "use multiple agents",
  (3) a task naturally decomposes into 2+ independent sub-tasks that benefit from parallel execution,
  (4) user says "start agents", "multi-agent", "work in parallel".
  IMPORTANT: This skill has two roles. If you receive a message containing [SWARM INIT], you are
  a WORKER - read references/worker-protocol.md immediately. Otherwise you are the LEADER orchestrator.
---

# Agent Team

## Role Detection

**If your first message contains `[SWARM INIT]`**: You are a WORKER worker.
Read `references/worker-protocol.md` and follow it. Stop reading this file.

**Otherwise**: You are the LEADER orchestrator. Continue below.

## Prerequisites

The opencode 2 background service must be running and healthy. Verify with:
```bash
opencode2 service status
```
Worker sessions are created on this shared service, so the user's own TUI session
and all workers live on the same server. `swarm.py init` resolves the service URL
(`opencode2 service status`) and authenticates via `~/.config/opencode/service.json`
(Basic Auth), so no manual server setup is needed.

## Swarm CLI

All communication uses `scripts/swarm.py` in this skill directory. Resolve the path:
```bash
SWARM_CLI="$(dirname "$(dirname "$(readlink -f "$(which opencode2)")")")/skills/agent-team/scripts/swarm.py"
# Or use the skill directory directly if known
```

Locate `swarm.py` by reading the skill directory from the skill loading context. The script
requires only Python 3.10+ stdlib.

## Leader Workflow

### Phase 1: Decompose the Task

Analyze the user's request and break it into parallelizable sub-tasks.

Guidelines:
- Each sub-task should touch different files/modules when possible
- 2-4 workers is typical. More adds coordination overhead.
- Define clear boundaries: "worker-api owns src/api/**, worker-ui owns src/components/**"
- Identify dependencies: does worker-B need worker-A's output? If yes, note it in worker-B's task.

Output a plan table before proceeding:

| Worker Name | Role | Files/Scope | Dependencies |
|------------|------|-------------|--------------|
| worker-api  | Backend API | src/api/** | none |
| worker-ui   | Frontend | src/components/** | needs API types from worker-api |

### Phase 2: Initialize the Swarm

**MANDATORY: workers must be created with an explicit model.** Pass
`--model providerID/modelID[#variant]` (same format as `opencode2 run
--model`). If omitted, `--leader-session` is required so the workers default
to the leader session's current model:

```bash
# Preferred: explicit model (replace providerID/modelID#variant with a real model)
python3 {SWARM_CLI} init \
  --model "providerID/modelID#variant" \
  --worker "api:Implement REST API endpoints" \
  --worker "ui:Implement React frontend components"

# Or: default to the leader's current model (needs --leader-session)
python3 {SWARM_CLI} init \
  --leader-session {your_session_id} \
  --worker "api:Implement REST API endpoints" \
  --worker "ui:Implement React frontend components"
```

`init` refuses to start without a resolvable model: no `--model` and no
`--leader-session` is an error, because falling back to the server's default
model would silently diverge from the leader's model.

This creates worker sessions on the shared background service (each carrying
the chosen model), starts tmux windows with the full opencode2 TUI for visual
monitoring, and writes state. The model is persisted in state; later `add`
calls reuse it unless overridden with `--model`.

### Phase 2.5: Register Leader Session

Workers `report` back to the leader session, so it must be registered. If you
already passed `--leader-session` to `init`, it is registered - skip this
step. Otherwise:

1. List sessions via the V2 API and find yours (search for a unique string from this conversation, e.g. the session title):
   ```
   opencode2 api get /api/session
   ```
   The list includes `id`, `title`, `agent`, and timestamps; match by title or by most-recent-updated.
2. Register it:
   ```bash
   python3 {SWARM_CLI} set-leader --session {your_session_id}
   ```

This enables the `report` command - workers use it to send completion messages directly to you
instead of broadcasting to all peers.

### Phase 3: Send Initial Tasks

For each worker, compose an initial prompt. The FIRST line MUST be `Load skill agent-team.` -
this triggers the worker to load this skill and read `references/worker-protocol.md`, which
teaches it the full communication protocol (swarm.py commands, message conventions, peer
interaction rules). Without this line, the worker will not know how to collaborate.

The prompt must include:
1. **`Load skill agent-team.`** (FIRST LINE - MANDATORY - triggers protocol loading)
2. The `[SWARM INIT]` marker (triggers worker role detection)
3. Identity block (name, role)
4. Swarm CLI path
5. Team roster (all peers with names and roles)
6. The actual task description
7. File scope boundaries

Template (use EXACTLY this structure):
```
Load skill agent-team.

[SWARM INIT]
Name: {worker_name}
Role: {role}
Swarm CLI: {SWARM_CLI}

Team:
- {peer_name} ({peer_role})
- {peer_name} ({peer_role})

Task:
{detailed task description}

Scope: Only modify files under {path}. Do not touch files outside your scope.
Dependencies: {any dependencies on other workers, or "none"}
```

IMPORTANT: Do NOT omit the `Load skill agent-team.` line. Without it, the worker will:
- Not know about swarm.py or how to communicate with peers
- Reject messages from other workers as "prompt injection"
- Not follow the completion protocol ([DONE] report to leader)

Send via:
```bash
python3 {SWARM_CLI} send --to {worker_name} --message "{initial_prompt}"
```

Send tasks to independent workers first, dependent workers after.

### Phase 4: Monitor

Periodically check progress:
```bash
python3 {SWARM_CLI} status
```

When a worker's message count increases or you want details:
```bash
python3 {SWARM_CLI} read --from {worker_name} --last 3
```

Wait for a specific worker to finish:
```bash
python3 {SWARM_CLI} wait --for {worker_name} --timeout 300
```

### Phase 5: Verify and Report

When all workers report `[DONE]` (via `report` to leader or detected idle via `status`):

1. Read each worker's final output:
   ```bash
   python3 {SWARM_CLI} read --from {worker_name} --last 5
   ```

2. Check for conflicts:
   - Run `git status` or `git diff` to see all changes
   - Verify no two workers modified the same file

3. Run project validation:
   - Build: run the project's build command
   - Test: run the project's test suite
   - Lint: run linters on changed files

4. If issues found, send fix instructions to the relevant worker:
   ```bash
   python3 {SWARM_CLI} send --to {worker_name} --message "Fix: {issue description}"
   ```

5. Report results to the user.

### Phase 6: Teardown

```bash
python3 {SWARM_CLI} teardown
```

Or keep tmux alive for user inspection:
```bash
python3 {SWARM_CLI} teardown --keep-state
```

## Handling Common Situations

**Worker asks a question**: The worker will block. Check `status` regularly. When you see a
worker waiting, read their messages and respond via `send`.

**Two workers need to coordinate**: They can talk directly via the swarm CLI. But if they are
stuck, intervene by reading both and relaying information.

**Worker goes off-track**: Abort and re-task:
```bash
# Via the opencode 2 API directly (Basic Auth: user "opencode", password from ~/.config/opencode/service.json):
curl -u "opencode:$(python3 -c 'import json;print(json.load(open("$HOME/.config/opencode/service.json"))["password"])')" \
  -X POST http://127.0.0.1:$(opencode2 service status | sed 's|.*:||')/api/session/{session_id}/interrupt
python3 {SWARM_CLI} send --to {worker_name} --message "Stop. New task: {corrected task}"
```

**Build fails after all workers done**: Read the error, determine which worker's code caused it,
send a fix request to that worker only.
