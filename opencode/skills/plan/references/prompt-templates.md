# Plan Mode Prompt Templates (copy‑paste)

These templates are for “coding assistant / agent” workflows. Pick one and paste as needed.

## Template A: Strict Planning (no execution)

```text
Enter 【Plan Mode】:
1) Only plan and analyze. Do not execute. Do not modify files. Do not output large blocks of final code.
2) Ask up to 5 key clarification questions; if answers are unavailable, state assumptions explicitly.
3) Provide at least 2 viable options with trade-offs, then recommend one.
4) Provide a 3–7 step actionable plan, scope/impact, validation, risks, and rollback.
5) At the end, wait for my reply “ACT / start executing” before switching to execution.

Use this fixed structure:
Goal / Success Criteria
Known Info & Assumptions
Open Questions
Options & Trade-offs (with recommendation)
Plan Steps (3–7)
Impact / Scope (files/commands)
Validation
Risks & Rollback
Approval Prompt (wait for confirmation)
```

## Template B: PLAN / ACT Switching

```text
You have two modes: # Mode: PLAN and # Mode: ACT

Rules:
- When I say “plan mode / # Mode: PLAN”, only output planning and analysis; do not execute, do not modify files, do not run side-effecting commands, and do not dump large final code.
- When I say “# Mode: ACT / ACT / start executing”, begin executing the plan. If the plan needs to change, update the plan first, then continue.

# Mode: PLAN output structure:
1) Goal / Success Criteria
2) Assumptions / Constraints
3) Open Questions (optional)
4) Option A/B trade-offs + Recommendation
5) Steps (3–7)
6) Validation & Rollback
7) Ask for confirmation: “Reply ACT to start executing”
```

## Template C: Auto‑Gate (plan before any action)

```text
Default to “plan-first, execute-after-approval”:
- Before any action that could change external state (editing code/files, installing deps, deleting, deploying, sending requests, etc.), present a plan and wait for approval.
- Even for small changes (single file, few lines), provide a mini plan (≤3 steps) plus how to validate.
- If information is missing, ask clarifying questions first; if I say “proceed with your assumptions”, continue using clearly stated assumptions.
```
