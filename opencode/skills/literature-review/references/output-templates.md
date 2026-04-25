# Output Templates

The skill supports three output formats, selected at Phase 0 (Scope Negotiation).

## 1. Related Work draft (`templates/related_work.md`)

**Use when**: Writing the "Related Work" section of a paper.

**Characteristics**:
- Thematic clustering (not chronological).
- Each paragraph weaves 2-5 citations with explicit positioning.
- Ends with a "Positioning of Our Work" section contrasting the user's own contribution (optional; omit if user has not stated one).
- Citation keys must match BibTeX entries (Zotero-origin in Stage B+).

**Typical paper count**: 15-40.

**Status**: Available in Stage A.

## 2. Project Proposal report (`templates/project_proposal.md`)

**Use when**: Writing an academic grant proposal (NSF / ERC / similar).

**Characteristics**:
- Hybrid NSF PAPPG 24-1 (Project Description, 15 pp) + ERC Part B1/B2
  structure. Sections tagged `(NSF)` or `(ERC)` apply to only one scheme.
- Critique-style State-of-the-Art (ERC mandate): name the gap, not a summary.
- Mandatory Intellectual Merit + Broader Impacts framing (NSF).
- Work packages, risk register, timeline.
- BibTeX citations only; NSF prohibits URLs in Project Description.

**Status**: Available in Stage C.

## 3. Survey skeleton (`templates/survey_skeleton.md`)

**Use when**: Writing a formal survey / review article for a CS/ML venue.

**Characteristics**:
- Thematic taxonomy tree (Figure 1) with every paper mapped to a leaf.
- Foundations section before the body (shared vocabulary).
- Thematic top-level organization; chronological only inside subsections.
- Comparison / tradeoff table with domain-appropriate axes.
- Applications section grouped by domain.
- 3-6 named open problems, each falsifiable.
- Companion GitHub repo section.

**Status**: Available in Stage C.

## Common artifacts (all templates emit)

- `$LITREV_WORKDIR/comparison_matrix.md` - tabular view of all papers across fixed columns.
- `$LITREV_WORKDIR/session_log.md` - log of search queries, triage decisions, rejection reasons.
- `$LITREV_WORKDIR/bibliography.bib` - BibTeX export (Stage B+, generated from Zotero).

## Rendering rules for the orchestrator

1. Fill placeholders `{{VAR}}` with content from `shortlist.jsonl` + per-paper `sections.json`.
2. NEVER invent a citation. Every claim must trace to a source file.
3. Every matrix cell must trace to `row.json`. Use `?` for unknown, never fabricate.
4. One-line contribution per paper goes to:
   - Comparison matrix bottom section (all papers)
   - Zotero note (per-paper, in Stage B+)
5. Prefer author-acknowledged limitations (from `section_splitter` `limitations` bucket)
   over inferred ones.
6. Thematic clustering must be MANUAL (orchestrator decides themes from abstracts); do not rely on keyword frequency alone.
