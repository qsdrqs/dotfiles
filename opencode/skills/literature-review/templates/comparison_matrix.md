<!--
Template consumed by the literature-review skill at Phase 6.
The orchestrator fills placeholders with data from $LITREV_WORKDIR/papers/*/row.json.
One table row per shortlisted paper; sorted by year desc, then citation_count desc.
-->

# Comparison Matrix: {{TOPIC}}

Generated: {{DATE}}
Papers reviewed: {{N_PAPERS}}

## Matrix

| # | Paper | Year | Venue | Task | Method | Dataset | Metric | Result | Limitations | Cite |
|---|-------|------|-------|------|--------|---------|--------|--------|-------------|------|
| 1 | {{title_short}} | {{year}} | {{venue}} | {{task}} | {{method}} | {{dataset}} | {{metric}} | {{result}} | {{limitations}} | {{bibkey}} |

## Column Legend

- **Task**: The problem formulation the paper tackles (e.g. text-to-image alignment, RLHF for LLMs).
- **Method**: Core technique in one phrase (e.g. DPO, classifier-free guidance, LoRA adapter).
- **Dataset**: Primary evaluation dataset (e.g. COCO, MT-Bench, MMLU).
- **Metric**: Headline metric reported (e.g. FID, win rate, accuracy).
- **Result**: Best number reported, with baseline comparison if available.
- **Limitations**: Author-acknowledged or reviewer-surfaced weaknesses.
- **Cite**: BibTeX key (matches Zotero entry key in Stage B+).

## Per-Paper One-Line Contribution

<!-- Feeds into Zotero note (one-line) via zotero_operator.add_note in Stage B. -->

- **{{bibkey}}**: {{one_line_contribution}}

## Rendering rules (for the orchestrator)

1. If a column value is unknown, write `?` (not `N/A`, not an invented guess).
2. Truncate `title_short` at ~60 chars; use full title in `related_work.md`.
3. `result` should include a baseline delta when the paper reports one (e.g. `FID 3.2 (-1.8 vs baseline)`).
4. `limitations` prefers author-acknowledged text from section_splitter's `limitations` bucket; fall back to `?` if absent.
5. Sort order: `year DESC, citation_count DESC`.
