---
description: Review staged changes and draft a commit message
subagent: false
---

Review the currently staged changes in the active repository, then draft exactly
one git commit message. This command drafts a message only: do not edit files,
change the staging area, or create a commit.

## Review

1. Read applicable repository commit guidelines and recent full commit messages
   with `git log -n 10 --format=%B`. Follow the established format and writing
   style, including language, type/scope prefixes, capitalization, and body list
   style. Default to English and ASCII punctuation when no convention exists.
2. Inspect `git diff --cached --stat` and the full `git diff --cached`. If output
   is truncated, read the remaining staged patches before drafting. For partially
   staged files, use the index version (`git show :path/to/file`) when additional
   context is needed. Describe only staged changes, not unstaged or untracked work.
3. Understand each independent logical change, its purpose, and its effect on the
   project. Base the message on the staged changes rather than assumptions from
   earlier conversation. Do not invent behavior, motivation, or test results.
4. If there are no staged changes, report that and stop without drafting a message.

## Commit message

- The header must summarize the whole commit's changes and their purpose or
  effect. Capture all independent change modules at a useful level of abstraction,
  rather than highlighting only one module or listing low-level edits. Avoid vague
  headers such as "update files".
- Follow the repository's existing type/scope convention. When it uses prefixes
  such as `feat` or `fix`, choose the type based on the actual intent and effect.
  Mention a module name only when it is directly relevant to the change.
- Aim for a header within 50 characters when possible, but prioritize accuracy
  and coverage over the length target.
- Include a body when useful. Separate it from the header with a blank line and
  wrap body lines at approximately 72 characters.
- If using bullet points, each bullet must represent one independent logical
  change module and explain both what changed and why. Group related files and
  implementation details serving the same change into one bullet. Keep independent
  modules in separate bullets; do not split one module's implementation details
  into several bullets. Let the number of modules determine the number of bullets,
  without an arbitrary limit, and follow the repository's existing list style.

## Output

Return only the complete draft commit message as plain text. Do not add a review
report, alternatives, surrounding quotes, code fences, or extra commentary.
