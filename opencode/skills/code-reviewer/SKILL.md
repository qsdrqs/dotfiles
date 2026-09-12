---
name: code-reviewer
description: "Review the current local git diff as a pair-reviewer: summarize diff scope (features + files), produce a collaborative review plan (order, key functions, logic chain), then give prioritized review notes/pitfalls with actionable suggestions. Use when the user asks for code review / PR review / diff review, e.g. 'review this diff', 'code review', '帮我review', '看看git diff'."
---

# Code Reviewer (Git Diff Review)

## Outcome

- Establish the **diff scope** fast: what features changed, which files, and likely entry points.
- Produce a **collaborative review plan**: review order, which modules/functions to inspect, and the logic chain.
- Provide **prioritized findings** for behavioral defects and project convention violations; distinguish required fixes from optional suggestions.

## Non‑negotiables

1. **Read the diff before judging.** Do not review based on assumptions.
2. **Make it collaborative.** Share the plan first, let the user adjust focus, then go deep.
3. **Use clear priorities.** Prioritize by impact, not category. Avoid personal-preference nitpicks, not evidence-backed convention findings.
4. **Anchor to evidence.** Point to `file:line`, function names, or a concrete call path.
5. **Keep output lean.** Do not paste large code blocks; guide the user through the code.
6. **Cover behavior and conventions.** Unless the user explicitly narrows the review, both are required. A focus area changes review order, not coverage. Brevity does not justify silently skipping a dimension.

## Workflow

### 0) Intake (ask only 3–6 key questions if missing)

- What is the goal/context of this change? (one sentence)
- Which behaviors/APIs must remain compatible? Any explicit out-of-scope?
- Risk posture: hotfix / high-risk release / conservative review needed?
- Where to focus: correctness, performance, security, maintainability, tests, readability? (multi-select)

### 1) Pull diff facts (define “what exactly are we reviewing?”)

- Check both working tree and staged changes:
  - `git status --porcelain`
  - `git diff --stat` / `git diff --name-status`
  - `git diff --cached --stat` / `git diff --cached --name-status`
- If there is no local diff, ask what to review (commit / branch / PR) and use:
  - `git show <rev>`
  - `git diff <base>...<head> --stat` (three-dot is usually closer to “branch diff”)

Optional: run `scripts/diff_scope.py` to summarize quickly (good for large diffs).

### 2) Determine scope

Goal: answer “what features changed, and which files implement them?”, and identify entry points / call chains.

- Group files by feature intent (not by directory): new capability / behavior change / refactor / tests / config / docs.
- Mark each group’s **entry points** (user-reachable first): HTTP route, CLI command, UI component, cron job, job handler, public library API.
- For each entry point, list likely core functions/modules (use `rg`, IDE index, and diff hunk headers):
  - `rg -n "<symbol>" <paths>`
  - `git grep -n "<symbol>"`

### 2a) Establish project conventions and check coverage

Before judging conformity:

- Read applicable `AGENTS.md` instructions, lint/formatter configuration, and relevant compiler configuration for the review target.
- Inspect representative neighboring code to establish local conventions, including naming, imports, type-only imports where applicable, comments, and file organization.
- Identify which changed file types and embedded code blocks the configured checks actually cover. Check exclusions and overrides; do not assume a successful command inspected every changed file.

Use this evidence when reviewing each changed file:

- **Explicit rule violation:** cite the applicable rule and report it even if runtime behavior is unaffected. Respect scoped exceptions.
- **Established convention inconsistency:** cite neighboring examples and explain the inconsistency; do not present it as an explicit rule.
- **Personal preference:** omit unless the user requests stylistic advice.

If configuration and neighboring code conflict, describe the conflict rather than silently choosing one. Check external contracts before recommending naming or shape changes. Do not relabel pre-existing inconsistencies as newly introduced defects.

Passing lint or formatting checks proves only what the enabled rules and inspected files cover. It does not replace manual convention review, including embedded code skipped by those checks.

### 3) Make a review plan (walk it together)

Produce an executable plan that includes:

- A list of “feature blocks” to review (sorted by risk/impact).
- For each block, the order: **entry → core logic → data/side-effects → edge cases → tests/docs**.
- Concrete pointers: files and key functions (doesn’t need to be perfect; must be followable).
- Checkpoints: what we must conclude after reviewing the block (e.g., “error semantics unchanged”, “no perf regression”).

Before diving, ask explicitly: **“OK to review in this order? Which block do you want to start with?”**

### 4) Perform the review (follow the plan block by block)

For each block, cover at least:

- Correctness: state machine/branches/defaults/null-handling/errors/retries/idempotency.
- Boundaries & compatibility: behavior changes, input validity, upgrade/rollback.
- Security: injection, authZ bypass, sensitive logging, path traversal, privilege escalation.
- Performance: complexity, N+1, caching/batching, hot paths, IO/locks/concurrency.
- Maintainability: naming, boundaries, duplication, testability, observability (logs/metrics/traces).
- Code style & conventions: compare every changed file with the evidence from step 2a; check consistency across declarations and their consumers.
- Tests & docs: regression coverage, critical branches, README/comments updates.

For each finding, include at least:
- A pointer: `file:line` and/or function name.
- A category (e.g. correctness, compatibility, security, performance, maintainability, conventions) independent of priority; convention findings also need a rule or neighboring-code reference.
- User impact: why it matters.
- Action: what to do; if optional, label as “suggestion”.

Before reporting completion, check that each changed file received both behavioral and convention review where applicable. State any unreviewed areas and call the review partial if required coverage is missing. Unavailable checks are limitations, not passing results.

### 5) Output format (keep it consistent)

Use a stable structure so the user can address items one by one:

- **Scope**: feature blocks → files → entry points/call chain (brief).
- **Review plan**: ordered files/functions to inspect (wait for user confirmation to proceed).
- **Findings (prioritized)**:
  - `P0` blocker: likely bugs, data loss, security issues, production incidents.
  - `P1` important: medium risk, maintainability, significant quality gaps.
  - `P2` non-blocking: lower-impact defects or convention inconsistencies worth fixing. Mark optional suggestions separately; a style finding is not automatically optional or low priority.
- **Coverage & verification**: briefly name the behavioral checks, convention sources inspected, and automated checks with their actual scope and limitations. If convention review found nothing, say so and identify the sources; do not substitute "lint passed" for this conclusion.
- **Questions**: if blocked, ask 1–5 actionable questions.

For a deeper checklist and templates, see `references/review_checklist.md`.
