#!/usr/bin/env python3
"""
Summarize the current git diff scope (files + stats).

This is a helper for the `code-reviewer` skill. It prints a compact overview that
is useful before creating a review plan.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def _run_git(repo_root: Path, args: list[str]) -> str:
    proc = subprocess.run(
        ["git", *args],
        cwd=repo_root,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if proc.returncode != 0:
        raise RuntimeError(proc.stderr.strip() or f"git {' '.join(args)} failed")
    return proc.stdout.rstrip("\n")


def _maybe_print(title: str, text: str) -> None:
    print(f"\n== {title} ==")
    if not text.strip():
        print("(none)")
        return
    print(text)


def _print_diff(repo_root: Path, label: str, diff_args: list[str], max_lines: int) -> None:
    name_status = _run_git(repo_root, ["diff", *diff_args, "--name-status"])
    stat = _run_git(repo_root, ["diff", *diff_args, "--stat"])

    if max_lines > 0:
        name_lines = name_status.splitlines()
        stat_lines = stat.splitlines()
        if len(name_lines) > max_lines:
            name_status = "\n".join(name_lines[:max_lines] + [f"... ({len(name_lines) - max_lines} more)"])
        if len(stat_lines) > max_lines:
            stat = "\n".join(stat_lines[:max_lines] + [f"... ({len(stat_lines) - max_lines} more)"])

    _maybe_print(f"{label} (name-status)", name_status)
    _maybe_print(f"{label} (stat)", stat)


def main() -> int:
    parser = argparse.ArgumentParser(description="Summarize git diff scope (files + stats).")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--range", dest="rev_range", help="Review a revision range, e.g. main...HEAD")
    group.add_argument("--staged-only", action="store_true", help="Only show staged (index) changes")
    group.add_argument("--unstaged-only", action="store_true", help="Only show unstaged (working tree) changes")
    parser.add_argument(
        "--max-lines",
        type=int,
        default=200,
        help="Truncate each section to N lines (0 = no truncation). Default: 200",
    )
    args = parser.parse_args()

    try:
        repo_root = Path(_run_git(Path.cwd(), ["rev-parse", "--show-toplevel"]))
    except Exception as e:
        print(f"[ERROR] Not a git repository (or git not available): {e}", file=sys.stderr)
        return 2

    try:
        branch = _run_git(repo_root, ["rev-parse", "--abbrev-ref", "HEAD"])
        head = _run_git(repo_root, ["rev-parse", "--short", "HEAD"])
    except Exception:
        branch = "(unknown)"
        head = "(unknown)"

    print("== Repo ==")
    print(f"root:   {repo_root}")
    print(f"branch: {branch}")
    print(f"head:   {head}")

    if args.rev_range:
        _print_diff(repo_root, f"Range {args.rev_range}", [args.rev_range], args.max_lines)
        return 0

    if not args.staged_only:
        _print_diff(repo_root, "Unstaged", [], args.max_lines)
    if not args.unstaged_only:
        _print_diff(repo_root, "Staged", ["--cached"], args.max_lines)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

