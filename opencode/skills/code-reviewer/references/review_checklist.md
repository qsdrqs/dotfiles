# Code Review Checklist (Git Diff)

Supplemental material for the `code-reviewer` skill: deeper checklists and output templates. Read this only when you need more depth.

## 1) Scope Summary Template

Goal: answer “what changed, what is impacted, where are the entry points, which files are involved” in ~5–15 lines.

- Change goal (1 sentence): …
- Feature blocks (ordered by user impact/risk):
  1. …
  2. …
- Files (grouped by feature block):
  - Block A: `path/...` `path/...`
  - Block B: `path/...`
- Key entry points (user-reachable):
  - …
- Key logic chain (entry → core → side-effect/data):
  - `entry()` → `core()` → `storage()` / `api_call()`

## 2) Review Plan Template (Collaborative)

Goal: let the user walk through the code with you (“from entry to core”), not a one-way lecture.

List blocks; for each block include:

- Acceptance checks (what must be true after reviewing this block): …
- Reading order (entry → core → data/side-effects → edges → tests/docs):
  1. `file:line` / `Symbol`: why start here
  2. …
- Items to confirm with the user (expected behavior, compatibility constraints, data assumptions): …

## 3) Findings Writing Standard (Avoid Nitpicks)

Try to include for each finding:

- Priority: `P0` / `P1` / `P2`
- Pointer: `file:line` + relevant function/path
- What it does now: current behavior
- Risk/impact: why it matters (user impact / prod risk / maintenance cost)
- Recommendation: actionable next step (ideally 1–2 options)
- Note: if optional, explicitly label as “suggestion (optional)”

Priority guidance:

- `P0` blocker: data loss, security, production incident risk, high-likelihood bug, clear compatibility break
- `P1` important: medium-risk bugs, major test gaps, high future maintenance/observability cost
- `P2` suggestion: small refactors, naming/structure, micro-optimizations, style consistency

## 4) Common Checks (Risk-First)

### Correctness / Semantics
- Defaults, nulls, boundaries (0, empty list, too long, invalid chars)
- Error handling: error/exception semantics changed? swallowed errors? duplicated reporting?
- Idempotency/retry: retries repeating side effects? need request-id / locking?

### Compatibility / Upgrade & Rollback
- Public API (function signature, HTTP schema, CLI flags) compatibility
- Data migration: backfill and rollback strategy for new fields/tables/indexes
- Config changes: default value changes that alter production behavior

### Security
- Input validation: injection (SQL/command/template/path), deserialization, SSRF, XSS
- Authorization: clear boundaries? bypass risks? sensitive data in logs/errors?
- Secrets: tokens/keys accidentally committed in the diff

### Performance / Concurrency
- Hot path complexity, N+1, unbounded loops/recursion, unbounded cache growth
- Locks/concurrency: deadlocks, races, shared mutable state
- IO: sync IO on main/request thread; timeouts

### Maintainability / Observability
- Names reflect intent, clean boundaries, reuse vs duplication
- Logs/metrics: enough context on failure paths; avoid logging secrets

### Tests / Docs
- Regression tests for new/changed behavior and critical branches
- Failure path coverage (auth failure, network failure, invalid inputs)
- README/comments/examples updated as needed

## 5) Large Diff Strategy (Don’t Drown)

- Use `--stat` / `--name-status` to bound scope first; then ask the user which 1–2 blocks to review first.
- De-prioritize generated files and lockfiles (unless they are the root cause).
- Review “entry points + contracts” (API/schema/flags) before internal implementation details.
