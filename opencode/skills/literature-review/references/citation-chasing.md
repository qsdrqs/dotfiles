# Citation Chasing (Stage C)

Stage C expands the Stage A/B comparison matrix through **1-hop snowballing** on
a user-confirmed set of `[core]` papers. Pulls both backward references (what
each core cites) and forward citations (who cites each core), triages the
combined pool through up to 6 parallel subagents, then merges survivors back
into the matrix with provenance tags.

Grounded in Wohlin 2014 (backward + forward snowballing) adapted for CS/ML
where arXiv preprints dominate and Semantic Scholar exposes the citation graph
directly.

## When to run

Trigger Stage C only when:

- Stage A/B produced a comparison matrix with >= 10 papers.
- User is producing a **proposal** or **survey** (Related Work draft alone
  rarely needs 1-hop expansion).
- User explicitly approves (the SKILL.md Phase 3 gate).

Skip Stage C when:

- Matrix is already >= 40 papers (likely saturated already).
- Topic is narrow and the Stage A shortlist already exceeds coverage target.
- User is time-boxed and has not flagged `[core]` papers.

## Pipeline

```
matrix.json (Stage A/B output)
    |
    v
[1] core_detector.py  (heuristic rank + evidence fields)
    |
    v
Main agent LLM review
    - inspect top candidates + their evidence
    - add/remove based on matrix role
    - each core MUST cite a matrix role:
        baseline / method-anchor / dataset-anchor / theory-anchor / opposing-approach
    |
    v
mcp_Question user confirmation
    |
    v
core.json  (final confirmed cores)
    |
    v
[2] citation_chaser.py  (1-hop expansion)
    - s2_client.refs (backward) per core, cap per-core
    - s2_client.cites (forward) per core, cap per-core
    - normalize, dedupe by canonical id
    - build provenance_edges.jsonl
    - apply total-pool cap
    - emit citation_candidates.jsonl
    - emit dispatch_batches.json  (advisory batching plan)
    |
    v
Main agent dispatches up to N <= 6 Task subagents (run_in_background=true)
    - N = min(6, len(batches))
    - each agent sees: core_summaries.json + assigned batch
    - scoring rubric in prompt
    - returns JSONL: {paper_id, keep_score, one_line_contribution,
                      relation_to_core, needs_fulltext, confidence}
    |
    v
[3] merge step (main agent + canonical dedupe)
    - merge by canonical id, preserving provenance
    - resolve score conflicts (keep highest-evidence)
    - threshold: keep_score >= 5 and confidence != "low"
    - mark needs_fulltext for later
    |
    v
Updated matrix.json + comparison_matrix.md
    - new rows tagged "related (via [core: A, B])"
    - needs_fulltext papers queued for Phase 4 deep-read (which may trigger
      paywall fallback via chrome-devtools; see paywall-fallback.md)
```

## Core detection (Step 1)

`core_detector.py` produces a ranked list using these heuristics:

| Signal | Weight | Rationale |
|--------|--------|-----------|
| User-provided seed paper | +10 | User intent is authoritative. |
| Already in matrix AND cited by >= 30% of other matrix rows | +5 | Frequently compared to = method anchor. |
| Citation count >= 90th percentile of matrix | +3 | High-impact, likely foundational. |
| Influential citation count (S2 field) >= 20 | +2 | S2's curated "truly used" signal. |
| Year in oldest 20% of matrix AND cite_count >= 50 | +2 | Old + cited = foundational classic. |
| Venue in top-tier set (NeurIPS/ICML/ICLR/Nature/ACL/CVPR/Science) | +1 | Weak signal; quality filter only. |

Output fields per candidate (sorted by score desc):

```json
{
  "paper_id": "canonical id",
  "title": "...",
  "score": 12,
  "signals": [
    "user_seed",
    "matrix_citation_hub(rate=0.45)",
    "citation_percentile_97"
  ],
  "suggested_role": "method-anchor",
  "evidence_links": [
    "workdir/papers/.../row.json",
    "workdir/candidates.jsonl"
  ]
}
```

**Main agent responsibility after this**: review the ranked list, override
heuristics when it conflicts with the narrative, label each retained candidate
with a **matrix role** (baseline / method-anchor / dataset-anchor /
theory-anchor / opposing-approach). Papers without a matrix role are dropped
even if heuristic score is high.

## Citation chase (Step 2)

`citation_chaser.py` pulls both directions for each core:

```bash
for core in core.json:
    s2_client.py refs  <id> --max <per_core_refs_cap>   # backward
    s2_client.py cites <id> --max <per_core_cites_cap>  # forward
```

**Caps (defaults, override via CLI):**

- `--per-core-refs`: 50 (backward per core)
- `--per-core-cites`: 50 (forward per core)
- `--total-cap`: 300 (hard ceiling on candidate pool before triage)

**Provenance** is stored as a list, never collapsed:

```json
{
  "paper_id": "s2:abc123",
  "title": "...",
  "abstract": "...",
  "year": 2023,
  "citation_count": 147,
  "related_to": [
    {"core_id": "A", "relation": "reference"},
    {"core_id": "B", "relation": "citation"}
  ],
  "priority_score": 8
}
```

Papers connected to multiple cores get priority boost. Refs-only papers are
NOT blanket deprioritized (they may be foundations / baselines), but
reference-only + single-core + old + weak-scope-match = low priority.

**Priority score (post-dedupe, pre-capping):**

```
base        = 0
+2 per core connection in related_to
+1 if both reference and citation relations exist
+1 if year within user's time_window (from scope.json)
+2 if influential_citation_count >= 5         (S2 curated impact)
+1 if cite_velocity >= 10                     (cites/year, age-normalized)
+1 if citation_count >= median of citation_candidates (raw fallback)
+1 if abstract contains >= 2 scope keywords
```

`cite_velocity` is computed inline from `citation_count / max(1,
current_year - year + 1)` if the enricher has not already filled it.
See `references/citation-criteria.md` for thresholds and rationale.

Sort descending by priority, keep top `--total-cap`.

**Advisory batches:** emit `dispatch_batches.json` with N batches balanced by
token size (not topic), where `N = min(6, ceil(total_candidates / 50))`.

```json
[
  {
    "batch_id": 0,
    "candidate_ids": ["s2:abc", "s2:def", ...],
    "est_tokens": 8200
  },
  ...
]
```

The main agent consumes this plan and dispatches accordingly.

## Subagent triage (Step 3)

For each batch, main agent fires:

```
task(
  subagent_type="general",
  run_in_background=true,
  load_skills=[],
  prompt="""
  TASK: Triage N candidate papers for literature review.
  
  GOAL: User is writing a {{output_type}} on {{topic}}. Score each candidate 0-10
  for inclusion in the final matrix.
  
  CORE PAPERS SUMMARY (the candidates are 1-hop neighbors of these):
  {{compact_core_summaries}}
  
  SCORING RUBRIC:
    9-10: central to topic, unique contribution, must include
    6-8:  relevant, would enrich matrix
    3-5:  tangential, include only if low coverage area
    0-2:  reject
  
  CANDIDATES:
  {{batch_candidates_jsonl}}
  
  OUTPUT (strict JSONL, one line per candidate):
  {"paper_id": "...", "keep_score": 8, "confidence": "high|medium|low",
   "one_line_contribution": "...", "relation_to_core": "...",
   "needs_fulltext": false, "reason": "..."}
  
  MUST DO:
    - Return valid JSONL, nothing else
    - Use ONLY information from the provided candidate metadata
    - Set needs_fulltext=true if abstract is missing AND candidate looks high-value
  
  MUST NOT:
    - Invent citations or contributions
    - Suggest further expansion (Stage C is strictly 1-hop)
    - Skip candidates (every input line needs one output line)
  """
)
```

## Merge (Step 4)

Main agent (optionally via a `citation_chaser.py merge` helper) reconciles:

1. **Canonical dedupe:** group by paper_id. If duplicate, keep highest keep_score
   entry and merge provenance.
2. **Threshold:** keep rows with `keep_score >= 5` AND `confidence != "low"`.
3. **Matrix tagging:** surviving rows get `via_core: [A, B]` field.
4. **Deep-read queue:** rows with `needs_fulltext: true` and `keep_score >= 7`
   are queued for Phase 4 (deep-read). Others with `needs_fulltext` but lower
   score stay metadata-only.
5. **Paywall queue:** Phase 4 deep-read may emit `paywalled` (pdf_fetch exit
   code 3); those trigger the chrome-devtools fallback per
   `paywall-fallback.md`.

Merged output appends to the existing `$LITREV_WORKDIR/papers/` directory and
updates `$LITREV_WORKDIR/matrix.json`.

## Stop conditions

Stage C is **strictly 1-hop**. The main agent MUST NOT re-dispatch citation
chasing on survivors. Rationale: token budget + diminishing returns (Wohlin
observed that 2-3 iterations typically suffice, but with arXiv/S2 coverage,
1-hop on well-chosen cores reaches saturation for CS/ML topics).

If the user asks for deeper expansion, route to a fresh Stage C run with a
different (smaller) core set drawn from the newly-added papers.

## Failure modes and mitigations

| Failure | Symptom | Mitigation |
|---------|---------|------------|
| Core selection drift | LLM picks famous but off-narrative papers | Force matrix-role labeling before accepting a core |
| Citation graph bias | One famous core floods the pool | Per-core quotas + provenance diversity sort |
| Agent prompt bloat | Batches too large, truncation | Cap per-batch candidates at 50, core_summaries at 1 paragraph each |
| S2 metadata gaps | Missing abstract or citation_count | Record in session_log; low-confidence candidates dropped |
| Provenance loss during dedupe | X via A and X via B collapses to one source | Merge `related_to` as list, never as scalar |
| Runaway re-dispatch | Agent flags many needs_fulltext | Defer to post-merge Phase 4 batch, not inline |

## Outputs

```
$LITREV_WORKDIR/
    core.json                       # confirmed cores (after user gate)
    citation_candidates.jsonl       # deduped candidate pool
    provenance_edges.jsonl          # {candidate, core, relation} edges
    dispatch_batches.json           # advisory batch plan
    triage_results/
        batch_0.jsonl               # subagent outputs
        batch_1.jsonl
        ...
    matrix.json                     # updated with "via_core" field
    comparison_matrix.md            # regenerated table
    session_log.md                  # appended with Stage C events
```

## Primary sources

- Wohlin, C. (2014). "Guidelines for Snowballing in Systematic Literature
  Studies." EASE 2014. https://www.wohlin.eu/ease14.pdf
- Semantic Scholar Graph API: https://api.semanticscholar.org/api-docs/graph
- S2 references/citations endpoints:
  `/paper/{id}/references` and `/paper/{id}/citations`
