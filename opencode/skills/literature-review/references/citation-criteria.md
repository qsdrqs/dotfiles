# Citation Count Criteria

This skill uses citation count as a quantitative signal across Phase 2
(triage), Phase 3 (core detection + chase priority), and Phase 6 (matrix
sort). Citation data alone is never a sufficient inclusion signal, but it
is one of the few objective filters available.

## Sources (priority order)

| Source | Fields exposed | Coverage | Quality |
|--------|----------------|----------|---------|
| Semantic Scholar | `citation_count`, `influential_citation_count`, `reference_count` | broad (CS, biology, etc.) | High; influential count is human/curated |
| CrossRef | `is-referenced-by-count` | broad (any DOI-indexed) | Medium; CrossRef's own graph only, smaller numbers than S2 |
| arXiv API | (none) | preprints only | None; arXiv does not expose citations |
| OpenReview | (none) | conferences only | None; cross-link to S2 needed |

`dedupe.py` max-merges `citation_count` across sources, with S2 overriding
CrossRef when both surface the same paper. The downstream `citation_source`
tag records which source the final number came from.

## Enrichment

Phase 1 candidates often arrive with `citation_count = null` (arXiv or web
search hits). Run `citation_enricher.py` after `dedupe.py` to backfill
missing counts via S2 lookup by `arxiv_id` or `doi`. The enricher caches
results in `$LITREV_WORKDIR/.citation_cache.json` so re-runs skip lookups.

```bash
python scripts/citation_enricher.py --in candidates.jsonl > enriched.jsonl
```

The enricher also computes `cite_velocity = citation_count / max(1,
current_year - year + 1)`. Velocity normalizes for paper age so a recent
paper is not penalized against a 5-year-old classic.

## Signals (definitions)

| Signal | Meaning | Best for |
|--------|---------|----------|
| `citation_count` | Total cites (raw S2 count or CrossRef fallback) | Older papers; saturates |
| `influential_citation_count` | S2-curated subset; "actually used as method/baseline/data" | Distinguishing real impact |
| `cite_velocity` | cites per year since publication | Recent papers; comparing across ages |
| `citation_percentile_X` | rank position within a fixed pool (matrix or candidate set) | Within-survey ranking |

`influential_citation_count` is generally the highest-signal field:
papers must be cited in a non-trivial way (introduction-only mentions are
filtered out by S2). When available it should be weighted higher than raw
count.

## Thresholds (age-bucketed)

For Phase 2 triage, classify each candidate as **high / medium / low**
citation signal. The thresholds match a "default" CS / ML survey;
override per topic if domain norms differ (e.g. theory papers cite more
slowly).

| Age bucket | High | Medium | Low |
|------------|------|--------|-----|
| `>= 5y old` | raw >= 100 OR influential >= 5 | raw 30-99 OR influential 2-4 | raw < 30 AND influential < 2 |
| `2-5y old` | raw >= 30 OR influential >= 3 | raw 10-29 OR influential 1-2 | raw < 10 AND influential 0 |
| `< 2y old` | velocity >= 10 OR influential >= 1 | velocity 3-9 | velocity < 3 |

Where `velocity = round(citation_count / max(1, current_year - year + 1), 2)`.

A "high" signal alone does not justify inclusion; it does justify
**not dropping** a paper at triage when topic match is borderline. A
"low" signal also does not justify rejection if the paper is topically
central (LLM judgment overrides).

## Composition rules (how signals combine)

1. **Topic match outranks citation signal.** A perfect-match low-citation
   paper beats an off-topic high-citation one.
2. **Multiple signals are stronger than one.** A paper with raw=80 AND
   influential=5 AND velocity=15 is much stronger than one with raw=200
   only.
3. **Velocity reveals momentum.** Recent papers with high velocity often
   become foundational; do not let raw-count thresholds bury them.
4. **Within-pool percentile is more robust than absolute thresholds.**
   When sub-domains have very different citation norms (e.g. theory vs
   applied), use percentile within the matrix rather than raw cuts.

## Caveats

- **S2 staleness.** Citation count updates lag 1-3 months. A 2024 paper
  may show 0 cites for weeks even if heavily referenced.
- **Citation cartels / self-citation.** S2 does not strip these. A high
  raw count from a single research group does not equal field impact.
  `influential_citation_count` partially mitigates this.
- **Venue bias.** Workshop papers under-cite peer venues. Do not penalize
  them for low absolute counts if velocity or influential count is okay.
- **Pre-print double-counting.** A paper on arXiv + later in NeurIPS may
  have one S2 entry per identifier with split counts. The dedupe step
  collapses these by DOI / arxiv_id, but if both have separate S2 IDs the
  numbers may understate impact.
- **Negative citations.** S2 does not distinguish "cited as motivation"
  from "cited as broken baseline". Treat raw counts as scope-of-attention,
  not endorsement.

## Where each signal is consumed

| Phase | Consumer | Signal used | Threshold / Formula |
|-------|----------|-------------|---------------------|
| 1.5 | `citation_enricher.py` | computes cc, ic, velocity | n/a (just fills) |
| 2 | LLM triage rubric | bucket (high/med/low) | this doc's table |
| 3 (core) | `core_detector.py` `citation_percentile_90` | matrix-percentile cc | top 10% -> +3 |
| 3 (core) | `core_detector.py` `influential_citation_count_20` | ic | >= 20 -> +2 |
| 3 (core) | `core_detector.py` `foundational_classic` | year + cc | oldest 20% AND cc >= 50 -> +2 |
| 3 (chase) | `citation_chaser._priority_score` | ic, velocity, cc | see citation-chasing.md |
| 6 | matrix sort | cc | year DESC, citation_count DESC |
