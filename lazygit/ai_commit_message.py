#!/usr/bin/env python3
"""
Generate commit message suggestions via aichat using the staged diff.

Usage:
  ai_commit_message.py [MESSAGE_COUNT]
"""

from __future__ import annotations

import subprocess
import sys

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


def _parse_count(argv: list[str]) -> int:
    if len(argv) < 2:
        return DEFAULT_MESSAGE_COUNT
    try:
        count = int(argv[1])
    except ValueError:
        raise RuntimeError("MESSAGE_COUNT must be an integer") from None
    if count <= 0:
        raise RuntimeError("MESSAGE_COUNT must be greater than 0") from None
    return count


def build_prompt(message_count: int, diff: str, recent_commits: str) -> str:
    return f'''Please suggest {message_count} commit messages, given the following diff:
```diff
{diff}
```

**Criteria:**

1. **Format:** Each commit message must follow the conventional commits format,
which is `<type>(<scope>): <description>`.
2. **Relevance:** Avoid mentioning a module name unless it's directly relevant
to the change.
3. **Enumeration:** List the commit messages from 1 to {message_count}.
4. **Clarity and Conciseness:** Each message should clearly and concisely convey
the change made.

**Commit Message Examples:**

- fix(app): add password regex pattern
- test(unit): add new test cases
- style: remove unused imports
- refactor(pages): extract common code to `utils/wait.ts`

**Recent Commits on Repo for Reference:**

```
{recent_commits}```

**Output Template**

Follow this output template and ONLY output raw commit messages without spacing,
numbers or other decorations.

fix(app): add password regex pattern
test(unit): add new test cases
style: remove unused imports
refactor(pages): extract common code to `utils/wait.ts`

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

Keep in mind you will suggest {message_count} commit messages. Only 1 will be used. It's
better to push yourself (esp to synthesize to a higher level) and maybe wrong
about some of the {message_count} commits because only one needs to be good. I'm looking
for your best commit, not the best average commit. It's better to cover more
scenarios than include a lot of overlap.

Write your {message_count} commit messages below in the format shown in Output Template section above.'''


def main() -> int:
    try:
        message_count = _parse_count(sys.argv)
        diff = _run_git(["diff", "--cached"])
        recent_commits = _run_git(["log", "-n", "10", "--pretty=format:%h %s"])
    except RuntimeError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return 1

    prompt = build_prompt(message_count, diff, recent_commits)
    return _run_aichat(prompt)


if __name__ == "__main__":
    raise SystemExit(main())
