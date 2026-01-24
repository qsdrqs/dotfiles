---
name: slides-creator
description: "Create concise, text-first slide decks written in Markdown. Use when the user asks for slides/slide decks/ppt/presentations, especially when they want: (1) Flow/narrative design first, (2) Bullet-heavy slides with deep nesting (subsubbullets encouraged), (3) Iterative drafting where Codex shows exactly ONE slide per turn, and (4) ASCII-only final deck (validated via scripts/check_ascii.py)."
---

# Slides Creator

## Overview

- Build slide decks in Markdown (text-first).
  - Prefer bullets -> subbullets -> subsubbullets (deep nesting encouraged).
  - Keep phrasing short (avoid long, complete sentences).

## Non-negotiables

- Start with flow (outline) before drafting slides.
  - Align on narrative + slide list first.
- After flow is approved: draft exactly ONE slide per turn.
  - Show only the slide being drafted/edited (not the whole deck).
  - Ask for approval/edits, then wait for user feedback.
- Keep slides concise.
  - Short phrases, abbreviations OK, no paragraphs.
  - If a line gets long, split into sub/subsub bullets.
- Final deck must be ASCII-only.
  - Avoid smart quotes, unicode dashes, unicode bullets, etc.

## Inputs to collect (ask in bullets)

- Audience + goal
  - Who is this for?
    - What should they do/decide after?
- Constraints
  - Target format/tool (default: generic Markdown)
  - Images/diagrams? (default: no; text-first)
  - File path (default: `slides.md` in current dir)
- Length + depth
  - Talk length, Q&A, how technical
  - Target slide count (or time budget per slide)

## Deck format (default)

- One slide = title + bullets
  - Title: `# ...`
  - Bullets: `- ...`
    - Indent 2 spaces per nesting level
    - Encourage subsubbullets over long lines
- Slide separator (when assembling a full deck file): `---` on its own line

Example slide (Markdown):

```md
# Title (2-6 words)
- Top point (short phrase)
  - Sub point (detail)
    - Subsub point (if needed)
```

## Workflow

### 1) Flow pass (no full slides yet)

- Propose a deck flow (outline) first.
  - If user is unsure, offer 2-3 flow options.
    - Problem -> approach -> results -> next steps
    - Context -> decision -> plan -> risks
    - Goal -> constraints -> options -> recommendation
- Write an outline as bullets:
  - Slide 1: title
    - 1-line goal
- Ask the user to confirm:
  - Reorder/add/delete slides
  - Any "must-include" points

### 2) Slide-by-slide loop (exactly ONE slide per turn)

For slide i:
- Confirm slide title + goal (1 line each).
- Draft the slide in Markdown (title + bullets).
  - Aim for 3-6 top-level bullets
    - Use sub/subsub bullets for detail
- Ask for edits + approval.
  - Keep questions minimal (1-3).
- Do not draft the next slide until the user approves the current slide.

### 3) Finalize

- Ensure the deck is assembled in the agreed file (default: `slides.md`).
- Run ASCII validation on the final deck markdown:
  - `python3 .codex/skills/slides-creator/scripts/check_ascii.py slides.md`
  - If needed: add `--replace`, then re-run until clean.

## Resources

- `scripts/check_ascii.py`
- `references/flows-and-templates.md` (optional)
