# Query Playbook (for `researcher` skill)

Use this file when you need help generating better search queries, choosing sources, and deciding when you've searched "enough".

## Delegated Research Supplement

When delegating research (see SKILL.md), each research agent should:

### Focus on ONE angle only
Each agent gets a specific ANGLE assignment. Don't drift into other angles' territory.

### Use role-appropriate tools

- `explore` agents use repository search and file-reading tools for local evidence.
- `librarian` agents use available search and fetch tools for external evidence.
- `general` agents use only the tools needed for their explicitly unresolved reasoning scope.

External research agents follow this sequence:

**1. Search Phase:**
- `websearch` - For general web searches, documentation, discussions
- GitHub search via `websearch` with `site:github.com` for issues, PRs, code patterns

**2. Fetch Phase (CRITICAL):**
- `webfetch` - MUST fetch and read full content from URLs
- **NEVER rely on search snippets** - Always fetch the full page

**3. Read & Extract Phase:**
- Actually read the fetched content
- Extract specific findings with context
- Record URL + date for every source

**Example workflow:**
```python
# Step 1: Search
results = websearch(query="GraphQL performance caching best practices")

# Step 2: Fetch each promising source
for url in [r.url for r in results[:4]]:
    content = webfetch(url=url, format="markdown")
    # Step 3: Read and extract specific findings
    # Look for: specific claims, numbers, quotes, dates
```

### Search breadth per agent

In focused mode, use 2-4 relevant primary sources per angle. Source quality and independence matter more than count. Expand only when evidence conflicts, a claim spans versions or environments, or the user approved deep mode.

- **Docs agent**: official docs, specs, source, tests, and release notes needed for the claim
- **Papers agent**: papers with enough methodological detail to evaluate the claim
- **Community agent**: targeted issues or reports that reveal concrete failure modes
- **Benchmarks agent**: studies whose methodology and environment can be verified

### Return structure for agents
```markdown
## Summary (2-3 sentences)
## Key Findings (5-10 bullets with inline citations)
## Sources (full list: link + date + type)
## Confidence (high/medium/low with rationale)
## Contradictions Found
## Open Questions
```

---

## 1) Query generation patterns

### Keyword expansion

- Translate: Chinese ↔ English terms; include acronyms and spelling variants.
- Add intent words: `overview`, `introduction`, `tutorial`, `guide`, `best practices`, `pitfalls`, `lessons learned`.
- Add evaluation words: `benchmark`, `comparison`, `survey`, `systematic review`, `state of the art`.
- Add debugging words: `issue`, `bug`, `regression`, `breaking change`, `migration`, `deprecation`.

### Angle-specific query modifiers

Use these to sharpen queries for specific agent angles:

| Angle | Modifier Examples |
|-------|-------------------|
| docs | `official documentation`, `specification`, `RFC`, `API reference`, `changelog` |
| papers | `arxiv`, `research paper`, `survey`, `systematic review`, `empirical study` |
| community | `reddit`, `github issues`, `stackoverflow`, `postmortem`, `experience report` |
| benchmarks | `benchmark`, `performance test`, `load test`, `comparison`, `measurement` |
| migration | `migration guide`, `lessons learned`, `before after`, `case study` |

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
- Practitioner reports: "postmortem", "incident", "lessons learned"
- Implementation truth: GitHub issues/PRs, release notes, migration guides

## 2) Source triage (what to trust first)

1. Primary: official docs/specs/standards, peer-reviewed papers, authoritative repos, release notes.
2. Secondary: high-quality blog posts by maintainers, reputable vendors, conference talks with slides/code.
3. Tertiary: forum/Q&A threads (use for pitfalls, but verify with primary sources).

Prefer diversity: if every source says the same thing but all cite each other, find a primary.

### Multi-agent source coordination
When multiple agents investigate the same direction:
- Choose only the roles needed to resolve the question; do not instantiate every role by default.
- **Docs agent** focuses on primary sources
- **Papers agent** validates with academic rigor
- **Community agent** finds real-world counterexamples
- **Benchmarks agent** provides quantitative evidence

## 3) "Searched enough" checklist (deep dive rounds)

### Single-agent mode
- Have ≥ 2 independent sources for key claims.
- Have at least one primary source for each major conclusion (when possible).
- Have checked recency for fast-moving topics (dates within the last 6–24 months, depending on domain).
- Have looked for known failure modes / counterexamples.

### Delegated mode
- [ ] Every delegated role was necessary for the decision.
- [ ] Primary sources support each major claim.
- [ ] When multiple agents investigated related evidence, their findings were cross-validated.
- [ ] Contradictions are explained or clearly left open.
- [ ] The orchestrator can make a recommendation without another research wave.

## 4) Notes format (keep it lightweight)

### Single-agent notes
Write notes as:

- Claim:
- Evidence (link + date):
- Context/assumptions:
- Confidence (high/medium/low):

### Multi-agent agent output format
Each research agent should return:

```markdown
## Summary
[2-3 sentences answering the KEY_QUESTION]

## Key Findings
- [Finding 1] [Source: link]
- [Finding 2] [Source: link]
- ...

## Sources
| Source | Date | Type | Key Claim |
|--------|------|------|-----------|
| link | 2024-01 | docs | ... |
| link | 2023-12 | paper | ... |

## Confidence: [high/medium/low]
[Rationale based on source quality and consistency]

## Contradictions Found
- [If conflicting info found, note it here]

## Open Questions
- [Gaps in research for this angle]
```

## 5) Fetch originals (don't stop at search snippets)

When you find a promising result in search:

1. Open/fetch the original page/paper/spec and read the relevant sections.
2. Extract the exact claim you will use (and record the date/version if applicable).
3. Only then summarize; don't infer from titles/abstracts/snippets alone.

This is especially important for:

- "Latest" questions (release notes, breaking changes)
- Papers (abstracts may omit limitations/assumptions)
- Benchmarks (methodology details matter)

### Delegated fetch strategy

External research agents use tools in this order. Local `explore` agents instead inspect the repository and pinned source directly.

1. **Search** (use appropriate tool for your angle):
   - Docs: `websearch` for official docs, specs
   - Papers: `websearch` for arXiv, Google Scholar
   - Community: `websearch` for discussions (reddit, HN, stackoverflow)
   - Benchmarks: `websearch` for performance studies

2. **Fetch** (MANDATORY - use `webfetch`):
   - **Docs agent**: Fetch full documentation pages, not just landing pages
   - **Papers agent**: Download PDFs or use HTML versions; read methodology sections
   - **Community agent**: Read full threads, not just top comments
   - **Benchmarks agent**: Verify benchmark methodology before accepting results

3. **Extract** (manual work):
   - Pull out specific claims, numbers, quotes
   - Note methodology details
   - Record URL + date for every source

## 6) PDFs → text first

If a source is a PDF, prefer converting it to text locally so you can:

- search quickly (grep/find)
- quote accurately
- avoid missing details hidden in figures/footnotes

Recommended: run `scripts/pdf_to_text.sh <paper.pdf> <paper.txt>` and then search within the text.

## 7) Download workspace: use `/tmp/opencode`

If you need to download any files for analysis, keep them out of the repo by using a temporary work directory under `/tmp/opencode`.

- Create a workdir: `workdir="$(scripts/mk_workdir.sh)"`
- Download into: `$workdir`
- Optionally clean up afterward: `rm -rf "$workdir"`

### Multi-agent workspace management
Each research agent should:
1. Create its own subdir: `workdir="$(scripts/mk_workdir.sh ${ANGLE}_${DIRECTION})"`
2. Download all sources to `$workdir/`
3. Not clean up immediately (Orchestrator may need to review)
4. Report downloaded files in output for orchestrator reference
