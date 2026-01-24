---
name: researcher
description: "Iterative web research workflow: clarify vague prompts, do a broad scan, propose directions, then run multiple deep-dive rounds (papers/docs/forums) incorporating user feedback. Prefer fetching/reading originals (not only search snippets) and extract PDFs via pdftotxt/pdftotext when needed. Use when the user asks to research, collect sources, find papers/docs, track latest developments, compare approaches, gather community discussions, or fact-check claims."
---

# Researcher (Iterative Web Research)

## Outcome

- Turn a question into an evidence-backed answer by running a repeatable, multi-round web research loop.
- Prefer up-to-date sources; surface trade-offs, uncertainties, and next research directions.

## 0) Online Tools

Confirm what online-capable tools exist *in this session* and explicitly state the plan to use them.

### Non-negotiable

- Do not rely on search result snippets/abstracts alone; fetch/open the original page/paper and extract the relevant parts. THIS IS CRITICAL.

### If no browsing is available

- Ask the user to provide links/files or explicitly enable browsing; then proceed with offline synthesis + reasoning.

### Organize tools by phase

1. Discover: `search_query`
2. Drill-down: `open` / `click`
3. Fetch & Extract: `open` / `find` / `screenshot`
4. Synthesize: summarize + compare
5. Iterate: refine queries based on gaps + user feedback

For query patterns and source-triage heuristics, see `references/query-playbook.md`.

### Local downloads: use a `/tmp` work directory

If you need to download files for local analysis (PDFs, datasets, repos, etc.), create a dedicated work directory under `/tmp` first and download there.

- Preferred: `workdir="$(scripts/mk_workdir.sh)"`
- Then download into: `$workdir`
- Keep the repo clean; treat the `/tmp` directory as disposable.

### PDFs: Can use `pdftotext` if you can not directly read them

If a key source is a PDF, prefer converting it to text locally so you can search/quote accurately.

- If you can download the PDF: use `scripts/pdf_to_text.sh` (wrapper around `pdftotext`/`pdftotxt`).
- If you cannot download: fall back to `web.run.screenshot` + manual extraction, but note the limitations.

### Arxiv papers: Prefer fetching HTML over PDF when possible

- Many Arxiv papers have HTML versions that are easier to read/search than PDFs. e.g. https://arxiv.org/abs/XXXX.XXXXX often has a link to HTML which is available at https://arxiv.org/html/XXXX.XXXXX.
- If you can open the HTML version, prefer that over downloading the PDF.

### If encountering access restrictions (like CAPTCHAs or paywalls)

- Inform the user to manually access the source and provide the content or a screenshot.

## 1) Workflow (n-round research loop)

### Step 1: Detect vagueness → request clarification

If the prompt is too vague to search effectively, ask 2–5 clarification questions before browsing, covering:

- Goal: what decision/action will this inform?
- Scope: which sub-area(s) matter and which don’t?
- Time window: “latest” as of when? (date range)
- Region/context constraints: geography, industry, stack, budget, risk tolerance
- Output preference: quick overview vs deep dive; recommendations vs neutral map

If the user can’t answer, state explicit assumptions and proceed.

### Step 2: Round 1 broad scan

Generate 6–12 query variants, mixing:

- Chinese + English keywords (and common acronyms)
- Synonyms and alternative names
- “comparison / vs / benchmark / survey / tutorial / docs / RFC / issue / postmortem”
- Community filters (as needed): `site:reddit.com`, `site:news.ycombinator.com`, `site:stackoverflow.com`, `site:github.com`

Run `web.run.search_query` and quickly open the top results to extract:

- Canonical definitions / terminology
- Mainstream approaches and current “best practices”
- Key trade-offs / controversies
- High-signal sources to read next (official docs, top repos, surveys, FAQs)

Keep lightweight notes as: **claim → source → date**.

### Step 3: Report after Round 1 (directions + plan)

Return a short landscape map:

- 3–7 plausible directions (each: what it is + why it matters)
- What seems stable consensus vs what’s disputed
- A proposed deep-dive plan (2–4 subtopics, sources to prioritize, questions to resolve)
- 2–3 targeted questions for the user to choose direction and constraints

Then explicitly ask the user to comment/choose: “Which direction should we deep dive first?”

### Step 4: Round 2..N deep dive loop

After the user’s feedback, pick 1–3 focused subtopics and search deeply:

- Prioritize primary sources when possible: official docs/specs, standards, research papers, repos/design docs.
- Include community discussion for pitfalls and edge cases: issues/PRs, postmortems, forums.
- Search “enough” before concluding: multiple independent sources, and at least one primary source when available.

For each round, deliver:

- Key findings with supporting links (and dates for time-sensitive claims)
- Comparison table / pros-cons / decision criteria
- Open questions + next search angles (what to look up next and why)

Then ask for feedback and repeat Step 4 as needed.

## Quality Bar

- Treat “latest” as time-sensitive: always include dates and call out what may have changed recently.
- Separate facts, informed interpretation, and speculation.
- If sources disagree, present both sides and explain plausible reasons (methodology, context, recency).
