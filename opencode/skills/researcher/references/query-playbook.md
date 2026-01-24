# Query Playbook (for `researcher` skill)

Use this file when you need help generating better search queries, choosing sources, and deciding when you’ve searched “enough”.

## 1) Query generation patterns

### Keyword expansion

- Translate: Chinese ↔ English terms; include acronyms and spelling variants.
- Add intent words: `overview`, `introduction`, `tutorial`, `guide`, `best practices`, `pitfalls`, `lessons learned`.
- Add evaluation words: `benchmark`, `comparison`, `survey`, `systematic review`, `state of the art`.
- Add debugging words: `issue`, `bug`, `regression`, `breaking change`, `migration`, `deprecation`.

### Operators (when supported by the search engine)

- Quotes: `"exact phrase"`
- OR: `termA OR termB`
- Exclude: `-term`
- Site: `site:github.com` / `site:arxiv.org` / `site:reddit.com`
- Filetype: `filetype:pdf` / `filetype:md`
- Title: `intitle:...` (if supported)

### Community signal targets (use selectively)

- Engineering discussion: `site:news.ycombinator.com`, `site:lobste.rs`
- Q&A: `site:stackoverflow.com`
- Practitioner reports: “postmortem”, “incident”, “lessons learned”
- Implementation truth: GitHub issues/PRs, release notes, migration guides

## 2) Source triage (what to trust first)

1. Primary: official docs/specs/standards, peer-reviewed papers, authoritative repos, release notes.
2. Secondary: high-quality blog posts by maintainers, reputable vendors, conference talks with slides/code.
3. Tertiary: forum/Q&A threads (use for pitfalls, but verify with primary sources).

Prefer diversity: if every source says the same thing but all cite each other, find a primary.

## 3) “Searched enough” checklist (deep dive rounds)

- Have ≥ 2 independent sources for key claims.
- Have at least one primary source for each major conclusion (when possible).
- Have checked recency for fast-moving topics (dates within the last 6–24 months, depending on domain).
- Have looked for known failure modes / counterexamples.

## 4) Notes format (keep it lightweight)

Write notes as:

- Claim:
- Evidence (link + date):
- Context/assumptions:
- Confidence (high/medium/low):

## 5) Fetch originals (don’t stop at search snippets)

When you find a promising result in search:

1. Open/fetch the original page/paper/spec and read the relevant sections.
2. Extract the exact claim you will use (and record the date/version if applicable).
3. Only then summarize; don’t infer from titles/abstracts/snippets alone.

This is especially important for:

- “Latest” questions (release notes, breaking changes)
- Papers (abstracts may omit limitations/assumptions)
- Benchmarks (methodology details matter)

## 6) PDFs → text first

If a source is a PDF, prefer converting it to text locally so you can:

- search quickly (grep/find)
- quote accurately
- avoid missing details hidden in figures/footnotes

Recommended: run `scripts/pdf_to_text.sh <paper.pdf> <paper.txt>` and then search within the text.

## 7) Download workspace: prefer `/tmp`

If you need to download any files for analysis, keep them out of the repo by using a temporary work directory under `/tmp`.

- Create a workdir: `workdir="$(scripts/mk_workdir.sh)"`
- Download into: `$workdir`
- Optionally clean up afterward: `rm -rf "$workdir"`
