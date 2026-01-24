---
name: plan
description: "Plan Mode: produce a clear, reviewable execution plan (steps, options, trade-offs, risks, and validation) and wait for explicit user approval before taking any action that changes code, files, or external state. Use when the user asks “plan mode”, “make a plan first”, “only plan, don’t execute”, “roadmap/proposal”, or similar (also: 计划模式/先给计划)."
---

# Plan Mode

## Goal

- Before “doing”, break the task into actionable steps, surface unknowns/risks, and align on scope + how success will be verified.

## Non‑negotiable Rules

1. Plan only, no execution: until the user explicitly says “ACT / start executing”, do **not**:
   - Modify any files (e.g., via `apply_patch`)
   - Run side‑effecting commands (install deps, write/delete/overwrite files, deploy, etc.)
   - Dump large amounts of final code (small pseudocode/interface sketches are OK for alignment)
2. Ask before assuming: if info is missing, ask 1–5 key questions; if the user can’t answer, state reasonable assumptions explicitly.
3. Provide options + recommendation: usually give at least 2 viable approaches with trade‑offs; if only one approach is reasonable, explain why.
4. Make it testable: always state how to validate success and how to roll back.

## Suggested Output Structure (keep consistent)

Use the sections below in order, with short, scannable bullets:

### 1) Goal / Success Criteria
- …

### 2) Known Info & Assumptions
- …

### 3) Open Questions (if any)
- …

### 4) Options (with trade‑offs)
- Option A: …
- Option B: …
- Recommendation: … (why)

### 5) Step‑by‑Step Plan (3–7 steps, verb-led)
1. …
2. …

### 6) Impact / Scope
- Files/modules likely to change: …
- Files likely to be added: …
- Commands likely to run: …

### 7) Validation
- Automated: tests/build/static checks (commands or scope)
- Manual: key user flows & acceptance checks

### 8) Risks & Rollback
- Risks: …
- Mitigations: …
- Rollback: …

### 9) Approval Prompt
- Ask the user to confirm in one line: `ACT` / “start executing” / “go with the recommended option”

## `update_plan` Usage in Codex CLI (if available)

- After the user approves execution, call `update_plan` to initialize the plan (short steps, one sentence each).
- Keep **exactly one** step as `in_progress`; others `pending`. Mark finished steps as `completed` promptly.
- If the plan changes, update `update_plan` first, then continue.
- End by marking all steps `completed`; never leave a dangling `in_progress`.

## Prompt Templates

For copy‑paste Plan Mode prompt templates, see `references/prompt-templates.md`.
