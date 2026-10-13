---
name: debugger
description: "Evidence-driven debugging for project or system issues: reproduce the bug, capture commands/logs/stack traces, narrow scope, prove root cause with concrete evidence (no guessing), apply minimal fix, and re-run reproduction/tests to verify. Use when asked to debug/triage errors, crashes, segfaults/panics/tracebacks, failing/flaky tests, service/system problems (systemd/journalctl), or performance regressions."
---

# Debugger (Evidence-Driven Debugging)

## Outcome

- Deliver an evidence-backed root cause and a verified fix. If investigation is genuinely blocked, identify the concrete blocker and the exact input or authorization needed to continue.
- Always produce a reproducible failing command/test (or a concrete explanation of why reproduction is blocked).

## Hard Constraints (Non‑Negotiable)

1. **Reproduce first** unless the user explicitly forbids it.
2. **No guessing.** Avoid language like “maybe/probably/possibly”.
   - If you must reason under uncertainty, label it a **testable hypothesis** and immediately propose the **single** experiment that can falsify it.
3. **Every conclusion must be tied to concrete evidence**: a command output, a stack trace, a log line, a file+line, or a test.
4. **After any fix, re-run the reproduction** (and relevant tests) to verify the bug is gone.
5. **Keep an audit trail**: commands you ran + files you changed + the observed results.
6. **Investigate instead of disclaiming.** Follow the user-facing reporting rules below; uncertainty is a reason to perform the next diagnostic check, not a substitute for an answer.

## User-Facing Reporting

- Do not use empty evidence-limit disclaimers, including equivalents in any language of "This cannot show/explain/represent X; the specific cause remains unknown" or "The evidence only shows X, not Y." Do not evade this rule by rephrasing the same non-answer.
- When a relevant cause remains unresolved and an in-scope diagnostic check is available, run it. Do not stop at a symptom, list unrelated things the evidence does not prove, or merely propose checks you can perform yourself.
- Report the causal explanation and the decisive evidence concisely. Intermediate updates should communicate a useful finding or a concrete blocker, not generic uncertainty.
- Stop without a diagnosis only at a concrete access, permission, input, or execution-limit blocker. Name the failed check and observed obstacle, then request the specific input or authorization needed for the next check. "The cause is not yet clear" is not a blocker.
- Never invent certainty to avoid a disclaimer. Resolve uncertainty through investigation; if blocked, report the obstacle directly without presenting an unfinished investigation as a completed diagnosis.

## 0) Intake Checklist (Ask If Missing)

- Expected vs actual behavior (one sentence each).
- Exact reproduction steps: commands, inputs, configs, data, and where to run them.
- Environment: OS/arch, language/runtime versions, dependency versions, commit hash, build flags.
- Frequency: always vs sometimes; any correlation (time, load, specific input, specific machine).
- Constraints: no network? no root? cannot run heavy load? cannot touch prod data? (safety).
- Success criteria: what observable output/log means “fixed”.

## 1) Reproduce (and Minimize)

- Run the user-provided steps **exactly**. Capture stdout/stderr + exit code.
- Reduce to the smallest deterministic reproducer (single test, single command, smallest input).
- If you cannot reproduce:
  - Report the command attempted and its observed result.
  - Perform available in-scope checks to obtain the missing evidence (logs, inputs, exact command, environment mismatch).
  - If blocked, request the specific missing input or authorization needed for the next check.

**Tip:** Use a disposable workdir under `/tmp` to keep artifacts (logs, traces, repro inputs) tidy:

- `workdir="$(scripts/mk_workdir.sh)"`
- `scripts/capture_cmd.sh -- <your-command>` (captures output to a file and prints the workdir path)

## 2) Collect Evidence (Prefer Existing Logs First)

### 2.1 Read Built‑In Logs

- If the system already has logs, read them before adding new instrumentation:
  - Services (systemd): `systemctl status …`, `journalctl -u … -b …`
  - Kernel/system: `dmesg`, `journalctl -b`
- If the app has a log level, increase to debug/trace and re-run reproduction.

### 2.2 Add Targeted Logging (Only When Needed)

- Add logs at the boundary between “expected” and “observed”.
- Log inputs, derived values, and invariants; add correlation IDs; avoid secrets.
- Keep it minimal (don’t spam logs); remove/guard after the fix if appropriate.

### 2.3 Use a Debugger / Tracer (When Logs Aren’t Enough)

- Pick the best-fitting tool for the stack (gdb/lldb, language debugger, syscall trace, profiler).
- Extract evidence: stack trace, signal, syscall trace, profile flamegraph, core dump analysis.

### 2.4 Other High‑Leverage Techniques

- Isolate the fault domain: disable features, narrow inputs, stub dependencies.
- Bisect: `git bisect` (for regressions).
- Freeze the bug: add/extend a failing test to make the reproducer stable.

See `references/cheatsheet.md` for quick commands/knobs by scenario.

## 3) Diagnosis Loop (Evidence → Hypothesis → Test)

Repeat until a single root cause is proven:

- State the **fact** and cite the evidence (exact log/trace/output).
- Write one **testable hypothesis** that explains the fact.
- Before proposing a new experiment, identify the specific evidence gap and review existing logs, prior tests, and source-level evidence. Reuse evidence that already answers the same question; do not require a fresh experiment merely to recreate that evidence.
- If a genuine evidence gap remains, define and run the smallest **falsification experiment** that resolves it. Do not add A/B, rollback, or restart controls solely to strengthen an already-supported causal explanation after the complete fix has been verified.
- Record result and update the hypothesis set.

## 4) Fix + Verify

- Implement the smallest fix aligned with the proven root cause.
- Add a regression test when feasible.
- Re-run the reproduction and relevant tests; capture evidence.
- Summarize: what changed, why it fixes it, and exactly how you verified it.

## Output Format (Use Every Time)

- **Repro**: exact command(s) / inputs / where you ran them
- **Facts (Evidence)**: key logs/trace/output excerpts (with file+line when relevant)
- **Root cause**: a single statement, backed by evidence (no speculation)
- **Fix**: minimal patch summary
- **Verification**: commands/tests re-run + outcomes
- **Next steps / questions**: only if blocked; each question must be actionable
