#!/usr/bin/env python3
"""
Generate commit message suggestions via aichat using the staged diff.

Usage:
  ai_commit_message.py [MESSAGE_COUNT]
  ai_commit_message.py --full --title "subject line"
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

MODEL = "openai:gpt-5-mini"
DEFAULT_MESSAGE_COUNT = 5

def _run_git(args: list[str]) -> str:
    try:
        result = subprocess.run(
            ["git", *args],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError:
        raise RuntimeError("git not found in PATH") from None
    except subprocess.CalledProcessError as exc:
        err = exc.stderr.strip() or exc.stdout.strip()
        raise RuntimeError(f"git {' '.join(args)} failed: {err}") from None
    return result.stdout


def _run_aichat(prompt: str) -> int:
    try:
        result = subprocess.run(["aichat", "-m", MODEL, prompt])
    except FileNotFoundError:
        print("Error: aichat not found in PATH", file=sys.stderr)
        return 1
    return result.returncode


def _run_aichat_capture(prompt: str) -> str:
    try:
        result = subprocess.run(
            ["aichat", "-m", MODEL, prompt],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError:
        raise RuntimeError("aichat not found in PATH") from None
    except subprocess.CalledProcessError as exc:
        err = exc.stderr.strip() or exc.stdout.strip()
        raise RuntimeError(f"aichat failed: {err}") from None
    return result.stdout


def build_title_prompt(diff: str, recent_commits: str) -> str:
    return f'''Please suggest ONE git commit message, given the following diff:
```diff
{diff}
```

**Criteria:**

1. **Format:** Follow the same commits format of previous commit messages. The
commit message should be within 50 characters if possible.
2. **Relevance:** Avoid mentioning a module name unless it's directly relevant
to the change.
3. **Clarity and Conciseness:** The message should clearly and concisely convey
the change made.

**Recent Commits on Repo for Reference:**

```
{recent_commits}
```

Follow the same writing style as recent commits messages.

**Instructions:**

- Take a moment to understand the changes made in the diff.

- Think about the impact of these changes on the project (e.g., bug fixes, new
features, performance improvements, code refactoring, documentation updates).
It's critical to my career you abstract the changes to a higher level and not
just describe the code changes.

- Generate commit messages that accurately describe these changes, ensuring they
are helpful to someone reading the project's history.

- Remember, a well-crafted commit message can significantly aid in the maintenance
and understanding of the project over time.

- If multiple changes are present, make sure you capture them all in each commit
message.

Aim for a higher level abstraction over raw code changes.

**Output:**

Return exactly one commit message on a single line. Do not add numbering,
bullets, or extra commentary.

'''


def build_full_message_prompt(title: str, diff: str, recent_commits: str) -> str:
    return f'''Please write a complete multi-line git commit message based on the diff.

Selected title (use as the subject inspiration, you may refine for accuracy):
{title}

```diff
{diff}
```

**Criteria:**

1. **Body:** Always include a body with 1-3 bullet points describing what and
   why. Wrap body lines at ~72 characters.
2. **Relevance:** Avoid mentioning a module name unless it's directly relevant
   to the change.
3. **Bullet Points:** Each bullet point should focus on a single aspect of the change.
   Use concise language to describe the change and its purpose. If you think there
   is only one change, then include only one bullet point. If you think there are
   n changes, then include n bullet points.

**Output Template (exactly):**

subject line here

1. bullet point 1 about the 1st change
2. bullet point 2 about the 2nd change
...
n. bullet point n about the nth change

**Instructions:**

- Only output the commit message text. No numbering, quotes, or extra commentary.
- Use a blank line between subject and body.
'''


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate AI commit messages.")
    parser.add_argument("message_count", nargs="?", type=int, default=DEFAULT_MESSAGE_COUNT)
    parser.add_argument("--full", action="store_true", help="Generate a full multi-line message.")
    parser.add_argument("--title", help="Selected title to expand into a full message.")
    args = parser.parse_args()

    try:
        if args.message_count <= 0:
            raise RuntimeError("MESSAGE_COUNT must be greater than 0")
        diff = _run_git(["diff", "--cached"])
        recent_commits = _run_git(["log", "-n", "10", "--pretty=format:%h %s"])
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    if args.full:
        if not args.title:
            print("Error: --full requires --title", file=sys.stderr)
            return 1
        prompt = build_full_message_prompt(args.title, diff, recent_commits)
        return _run_aichat(prompt)

    prompt = build_title_prompt(diff, recent_commits)
    results: list[str] = []
    errors: list[str] = []
    with ThreadPoolExecutor(max_workers=args.message_count) as executor:
        futures = [
            executor.submit(_run_aichat_capture, prompt)
            for _ in range(args.message_count)
        ]
        for future in futures:
            try:
                output = future.result()
            except RuntimeError as exc:
                errors.append(str(exc))
                continue
            cleaned = output.strip()
            if cleaned:
                results.append(cleaned)
            else:
                errors.append("aichat returned empty output")

    for err in errors:
        print(f"Warning: {err}", file=sys.stderr)

    if not results:
        return 1

    for message in results:
        print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
