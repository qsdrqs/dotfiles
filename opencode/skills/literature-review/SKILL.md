---
name: literature-review
description: "Academic literature review workflow for Related Work sections, project feasibility reports, and surveys. Multi-source paper discovery (brave + exa + cited + arXiv + Semantic Scholar), lightweight triage, arXiv HTML deep reading, and generation of a comparison matrix and a Related Work draft. Use when the user asks for 文献调研 / literature review / 综述 / survey / related work / paper survey / 论文调研 / 文献综述. Stage A supports end-to-end arXiv-centric workflow; Zotero import and MinerU PDF extraction come in Stage B; paywall fallback and citation chasing come in Stage C."
---

# Literature Review Skill

## When to use

- "帮我做文献调研" / "文献综述"
- "literature review on X"
- "survey of X" / "综述 X 方向"
- "写一下 related work 草稿"
- "调研这个方向的论文"

## When NOT to use

- General web research -> use the `researcher` skill.
- Single-paper deep reading -> use `webfetch` + `arxiv_fetch.py html` directly.
- Quick factual Q&A about a known paper -> use direct MCP tools.

---

## Architecture

You (the orchestrator LLM) drive six phases. Python scripts in `scripts/` handle
mechanical work (API calls, parsing, de-duplication). All decisions about what
to search, what to keep, and how to cluster are YOURS.

```
Phase 0: Scope Negotiation (collect requirements from user)
  |
Phase 1: Layer 1 Broad Discovery (parallel MCP search + API scripts)
  |
Phase 2: Layer 2 Lightweight Triage (per-candidate webfetch / abstract scoring)
  |     [USER GATE: confirm shortlist before deep reading]
Phase 3: Citation Chasing (Stage C; skip in Stage A)
  |
Phase 4: Layer 3 Deep Read (arXiv HTML -> section split; MinerU in Stage B)
  |
Phase 5: Layer 4 Zotero import (Stage B; skip in Stage A)
  |
Phase 6: Synthesis (render comparison matrix + related-work draft)
```

**Stage A+B+C status**: All phases functional. Stage C adds citation chasing
(Phase 3), the chrome-devtools paywall fallback inside Phase 4, OpenReview
discovery inside Phase 1, and the `project_proposal` / `survey_skeleton`
output templates at Phase 6.

---

## Environment setup

At the start of every session, initialize the workdir:

```bash
export LITREV_WORKDIR="/tmp/literature-review/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LITREV_WORKDIR"

export SKILL_DIR="$HOME/.config/opencode/skills/literature-review"

# Optional: Semantic Scholar API key avoids 429 rate-limits
export S2_API_KEY="${S2_API_KEY:-}"

# Stage B (Zotero import + PDF fetch). REQUIRED if Phase 5 will run.
export ZOTERO_API_KEY="${ZOTERO_API_KEY:-}"   # https://www.zotero.org/settings/keys
export ZOTERO_USER_ID="${ZOTERO_USER_ID:-}"   # numeric, same page
export UNPAYWALL_EMAIL="${UNPAYWALL_EMAIL:-}" # used by pdf_fetch Unpaywall fallback
```

Print the workdir path to the user so they can inspect artifacts.

---

## Phase 0.1: Container Setup (one-time per machine)

Stage B runs **one optional container** (MinerU, GPU). Metadata resolution
uses external REST APIs (CrossRef + arXiv) with no container.

```bash
bash "$SKILL_DIR/scripts/setup_containers.sh"
# CPU-only host: SKIP_MINERU=1 bash setup_containers.sh
```

This brings up:

- `mineru` (GPU) on `:8000` - PDF -> Markdown extraction.

Runs with `--restart unless-stopped`. Tear down with
`bash "$SKILL_DIR/scripts/teardown_containers.sh"`.

Verify before running Phases 4-5:

```bash
python "$SKILL_DIR/scripts/crossref_client.py" health
python "$SKILL_DIR/scripts/mineru_client.py" health
```

If `mineru` health is false, Phase 4 deep-read still works via the arXiv HTML
path; non-arXiv PDFs will be metadata-only at Phase 5 (no extracted text).

Pre-flight checklist before Phase 5:

- [ ] `$ZOTERO_API_KEY` and `$ZOTERO_USER_ID` exported.
- [ ] `$UNPAYWALL_EMAIL` exported (PDF fallback + CrossRef polite pool).
- [ ] `$ZOTERO_DATA_DIR` exported (or `~/Zotero` exists). PDFs are written
      here directly; a sync tool (Syncthing, WebDAV, rsync) is expected to
      replicate `storage/` across machines.
- [ ] Zotero client **File Syncing** set to "Off" or "WebDAV" (not "Zotero").
      Otherwise the client re-uploads files we placed locally.
- [ ] CrossRef health = true (public API, normally reachable).
- [ ] User has named a target Zotero collection path.

See `references/zotero-integration.md` and `references/mineru-integration.md`
for deeper details.

---

## Phase 0: Scope Negotiation

Before any search, ask the user (one question at a time, or bundled via the
`mcp_Question` tool if available):

1. **Output type** (picks the template):
   - Related Work draft  -> `templates/related_work.md`  (Stage A)
   - Project proposal     -> `templates/project_proposal.md` (Stage C; NSF/ERC hybrid)
   - Survey / review      -> `templates/survey_skeleton.md` (Stage C)

2. **Topic and scope**: 1-sentence problem framing plus 3-8 domain keywords.

3. **Time window**: e.g. "last 3 years", "2022-now", "including classics".

4. **Seed papers** (optional but strongly recommended): 1-3 papers the user
   already knows are relevant. Use them to bootstrap query variants and later
   citation expansion.

5. **Paper budget**: target shortlist size (default 20-30).

6. **Zotero collection path** (Stage B only; can be skipped in Stage A):
   e.g. `Research/DiffusionAlignment/2025`.

Write decisions to `$LITREV_WORKDIR/scope.json`.

---

## Phase 1: Layer 1 Broad Discovery

**Goal**: produce `$LITREV_WORKDIR/candidates.jsonl` with 100-300 de-duplicated entries.

### 1.1 Generate 6-10 query variants

Mix three styles:

- **Keyword** (for `brave_web_search`): `"diffusion alignment" "DPO"`
- **Natural language** (for `web_search_exa`): `recent 2024 papers on aligning text-to-image diffusion models with human preferences`
- **Authoritative framing** (for `websearch_cited`): `overview of preference learning methods for generative models`

### 1.2 Parallel general web search (3 MCP tools)

In a SINGLE response, call all three tools IN PARALLEL for each query variant
(multiple tool calls inside one response block):

```
brave_web_search(query=Q, count=10)
web_search_exa(query=Q, numResults=10)
websearch_cited(query=Q)
```

Normalize each hit to one JSONL line and append to `$LITREV_WORKDIR/raw_search.jsonl`:

```json
{"source": "brave", "query": "...", "url": "...", "title": "...", "snippet": "..."}
```

### 1.3 Structured API search (Python scripts, SERIAL not parallel)

Both arXiv and Semantic Scholar are rate-limited. Run them SEQUENTIALLY,
NOT in parallel. The scripts throttle internally (arXiv: 1 req / 3.1 s;
S2: 1 req / 1.1 s with `S2_API_KEY`, else 1 req / 3.1 s) and retry with
30s backoff on HTTP 429 / 503.

Pick 1-3 representative queries; do NOT loop over all 6-10 variants here
(broad coverage already came from Layer 1.2).

```bash
python "$SKILL_DIR/scripts/arxiv_fetch.py" search \
    --query "<arxiv query, e.g. ti:alignment AND cat:cs.LG>" --max 50 \
    >> "$LITREV_WORKDIR/raw_search.jsonl"

python "$SKILL_DIR/scripts/s2_client.py" search \
    --query "<broader keywords>" --max 100 \
    >> "$LITREV_WORKDIR/raw_search.jsonl"
```

arXiv query syntax cheat sheet: `ti:`, `abs:`, `au:`, `cat:`, combined with
`AND` / `OR` / `ANDNOT`.

### 1.4 De-duplicate

```bash
python "$SKILL_DIR/scripts/dedupe.py" \
    "$LITREV_WORKDIR/raw_search.jsonl" \
    > "$LITREV_WORKDIR/candidates.jsonl"
```

Stderr reports: `[dedupe] merged N unique entries, key-kind breakdown: {...}`.

---

## Phase 2: Layer 2 Lightweight Triage

**Goal**: reduce 100-300 candidates to 20-40 shortlist entries worth deep reading.

Process candidates in batches of ~20:

1. If the candidate already has `abstract` populated (from `arxiv_api` or
   `s2_api`), skip the fetch and score directly from
   `title + abstract + venue + citation_count`.

2. Otherwise, call `webfetch(url, format="markdown")` to get the landing page
   content, extract the abstract / TL;DR / lead paragraph.

3. Score each candidate on a 0-3 scale:
   - 3 = central to topic, strong signal (high citation, top venue, abstract matches).
   - 2 = relevant but tangential.
   - 1 = weak match, include only if the paper budget allows.
   - 0 = reject (off-topic, wrong modality, etc.).

4. Annotate with `{"triage_score": N, "triage_reason": "..."}`.

Write entries with score >= 2 to `$LITREV_WORKDIR/shortlist.jsonl`.

### USER GATE (mandatory)

Present to the user:
- Shortlist size with score distribution (e.g. "32 papers: 12 at score 3, 20 at score 2").
- Top 10 titles with one-line triage reason.
- Any dropped-high-signal concerns (e.g. "3 papers at score 3 had no abstract, should I webfetch them?").

Ask: "Proceed to deep reading with these N papers, or adjust?" Wait for confirmation.

---

## Phase 3: Citation Chasing (Stage C)

**When to run**: only for output_type `project_proposal` or `survey` and only
when the Stage A/B matrix is already >= 10 papers. For Related Work drafts
this phase is usually skipped. See `references/citation-chasing.md` for full
rationale and failure-mode mitigations.

This phase is **strictly 1-hop**. The main agent MUST NOT re-dispatch chasing
on survivors.

### 3.1 Build shortlisted matrix input

The `matrix.jsonl` input for Stage C is produced after Phase 2 (shortlist
confirmation). If the current session ran Phase 4 first, pass the enriched
rows (with references[] populated by s2_client so that the matrix-citation-hub
signal works). Fall back to abstract+citation_count only when S2 refs are
unavailable.

### 3.2 Heuristic core detection

```bash
python "$SKILL_DIR/scripts/core_detector.py" \
    --matrix "$LITREV_WORKDIR/matrix.jsonl" \
    --scope  "$LITREV_WORKDIR/scope.json" \
    --top-k 20 \
  > "$LITREV_WORKDIR/core_candidates.json"
```

Heuristic signals (see `references/citation-chasing.md` for weights): user
seed, matrix-citation-hub, citation percentile, S2 influential-citation,
foundational classic, top-tier venue.

### 3.3 Main-agent review + user confirmation

YOU (the orchestrator) then:

1. Read `core_candidates.json`.
2. For each candidate, assign a **matrix role**:
   `baseline` / `method-anchor` / `dataset-anchor` / `theory-anchor` /
   `opposing-approach`. Papers without a defensible role are dropped even
   if the heuristic score is high.
3. Override heuristic gaps: add missing cores the heuristic missed (e.g.
   low-citation but narratively central paper); drop famous-but-off-topic
   picks.
4. Invoke `mcp_Question` so the user confirms / edits the final core set.
   Each listed core must show its matrix role.

Write the confirmed list to `$LITREV_WORKDIR/core.json`:

```json
[
  {"paper_id": "s2:abc", "title": "...", "arxiv_id": "...",
   "s2_id": "...", "matrix_role": "method-anchor"},
  ...
]
```

### 3.4 Citation chase

```bash
python "$SKILL_DIR/scripts/citation_chaser.py" chase \
    --core    "$LITREV_WORKDIR/core.json" \
    --scope   "$LITREV_WORKDIR/scope.json" \
    --workdir "$LITREV_WORKDIR" \
    --per-core-refs 50 --per-core-cites 50 --total-cap 300 --max-batches 6
```

The script produces:

- `citation_candidates.jsonl` - deduped candidate pool with provenance.
- `provenance_edges.jsonl` - candidate -> core edges.
- `dispatch_batches.json` - advisory batch plan (<= 6 batches).

### 3.5 Parallel subagent triage

Read `dispatch_batches.json` (N = up to 6 batches). For each batch, fire a
background Task agent:

```python
task(
    subagent_type="general",
    run_in_background=True,
    load_skills=[],
    description=f"Stage C triage batch {batch_id}",
    prompt="""
    TASK: Triage N candidate papers for literature review.

    GOAL: User is writing a {{output_type}} on {{topic}}. Score each
    candidate 0-10 for inclusion in the final matrix.

    CORE PAPERS (candidates are 1-hop neighbors):
    {{compact_core_summaries}}

    SCORING RUBRIC:
      9-10: central to topic, unique contribution, must include
      6-8:  relevant, would enrich matrix
      3-5:  tangential, include only if low coverage area
      0-2:  reject

    CANDIDATES: <JSONL lines from citation_candidates.jsonl for this batch>

    OUTPUT (strict JSONL, one line per input candidate, no prose):
    {"paper_id": "...", "keep_score": N, "confidence": "high|medium|low",
     "one_line_contribution": "...", "relation_to_core": "...",
     "needs_fulltext": false, "reason": "..."}

    MUST DO:
      - Exactly one output line per input line
      - Use ONLY provided metadata (no web search)
      - Set needs_fulltext=true if abstract is missing AND candidate looks high-value

    MUST NOT:
      - Invent citations or contributions
      - Suggest further expansion (Stage C is strictly 1-hop)
      - Skip candidates
    """,
)
```

Do NOT dispatch more than 6 agents in parallel even if the plan has more
batches; re-use agents sequentially if needed. Collect results when
`<system-reminder>` notifications arrive, save each to
`$LITREV_WORKDIR/triage_results/batch_<id>.jsonl`.

### 3.6 Merge

```bash
python "$SKILL_DIR/scripts/citation_chaser.py" merge \
    --workdir "$LITREV_WORKDIR" \
    --matrix  "$LITREV_WORKDIR/matrix.jsonl" \
    --score-threshold 5 \
  > "$LITREV_WORKDIR/merge_summary.json"
```

Writes `matrix_updated.jsonl` with surviving candidates appended (tagged
`via_core: [A, B]` and `source: "citation_chase"`). Papers flagged
`needs_fulltext: true` AND `keep_score >= 7` are queued for Phase 4 deep
read (which may trigger the paywall fallback).

### 3.7 Stage C gate

Report to the user:
- Cores confirmed: N.
- Pool size before triage: M.
- Survivors: K, of which F need full-text retrieval.
- Estimated added matrix rows: K.

Ask: "Add these K papers to the matrix and proceed to Phase 4 deep-read on
the F full-text ones?" Wait for confirmation.

---

## Phase 4: Layer 3 Deep Read

For each paper in the confirmed shortlist:

### If source is arXiv (preferred path):

```bash
mkdir -p "$LITREV_WORKDIR/papers/$ARXIV_ID"

python "$SKILL_DIR/scripts/arxiv_fetch.py" html "$ARXIV_ID" \
    > "$LITREV_WORKDIR/papers/$ARXIV_ID/full.html" \
    || { echo "[skill] no HTML for $ARXIV_ID, falling back"; continue; }

python "$SKILL_DIR/scripts/section_splitter.py" \
    "$LITREV_WORKDIR/papers/$ARXIV_ID/full.html" \
    > "$LITREV_WORKDIR/papers/$ARXIV_ID/sections.json"
```

### If source is non-arXiv or HTML unavailable (Stage B path):

1. Fetch the PDF:

   ```bash
   echo "$META_JSON" | python "$SKILL_DIR/scripts/pdf_fetch.py" \
       --out "$LITREV_WORKDIR/papers/$PAPER_ID"
   ```

   Resolution order: `arxiv_id` -> direct `pdf_url` -> Unpaywall by `doi`.
   Status: `ok` (PDF written), `paywalled` (Stage C), `no_identifier` (skip).

2. Decide whether to invoke MinerU. **You judge case by case**:

   - Use MinerU if the paper is heavy on tables / formulas / figures, or
     no usable HTML version exists.
   - Skip MinerU for text-heavy papers when `webfetch` of the abstract or
     publisher landing page already gives enough signal for the matrix row.

   ```bash
   python "$SKILL_DIR/scripts/mineru_client.py" convert \
       --pdf "$LITREV_WORKDIR/papers/$PAPER_ID/paper.pdf" \
       --out "$LITREV_WORKDIR/papers/$PAPER_ID/mineru"
   ```

   Use `mineru/content.md` instead of `sections.json` for matrix-row extraction.

3. If `pdf_fetch` reported `paywalled` (exit 3), invoke the Stage C paywall
   fallback. See `references/paywall-fallback.md`. Do NOT block the deep-read
   loop; queue paywalled papers and handle them in a single sweep at the end
   of Phase 4:

   ```bash
   python "$SKILL_DIR/scripts/paywall_browser.py" prepare \
       --manifest "$PAPER_DIR/manifest.json"
   # -> emits navigation recipe (publisher + landing_url + strategy + hint)
   ```

   Then YOU (main agent) drive chrome-devtools MCP per the recipe:
   `chrome-devtools_new_page` -> `chrome-devtools_wait_for` -> extract PDF url
   -> navigate/download -> save bytes to `$PAPER_DIR/paper.pdf`. Hard rule:
   max 2 strategy attempts per paper, 1 req / 5 s per publisher host.
   Finalize with:

   ```bash
   python "$SKILL_DIR/scripts/paywall_browser.py" verify \
       --manifest "$PAPER_DIR/manifest.json" \
       --pdf      "$PAPER_DIR/paper.pdf"
   ```

   `verify` rewrites `manifest.json` to `status: ok, source: chrome-devtools`
   so the rest of Phase 4 / Phase 5 treats the paper normally. If `verify`
   fails (non-PDF, too small), log `paywalled_no_access` and move on.

### Extract a comparison-matrix row per paper

From `sections.json`, populate:

- `task` (from title + introduction bucket)
- `method` (from method / approach bucket, one phrase)
- `dataset` (from experiments / setup bucket)
- `metric` (from results bucket)
- `result` (best number with baseline delta if reported)
- `limitations` (from limitations bucket; author-acknowledged preferred)
- `one_line_contribution` (distilled from abstract + introduction)

Save as `$LITREV_WORKDIR/papers/$ARXIV_ID/row.json`.

If a field cannot be determined from the source text, write `?`. NEVER invent.

---

## Phase 5: Layer 4 Zotero Import (Stage B)

**Scope**: only papers that **entered the comparison matrix** (Phase 4 row.json
exists). Triaged-out candidates are not imported.

### 5.1 Resolve target collection

Use the path the user gave at Phase 0 (e.g. `Research/RAG/Survey`):

```bash
python "$SKILL_DIR/scripts/zotero_operator.py" resolve-collection \
    --path "$ZOTERO_COLLECTION_PATH"
# -> {"key": "ABCD1234", "path": "..."}
```

Missing nodes are auto-created. Confirm with the user if the resolved key is
unexpected.

### 5.2 Per-paper import loop

For each paper with a `row.json`:

```bash
PAPER_DIR="$LITREV_WORKDIR/papers/$PAPER_ID"
META="$PAPER_DIR/zotero_meta.json"
PDF="$PAPER_DIR/paper.pdf"

# (a) Resolve metadata. arXiv papers reuse the API metadata captured at Phase 1.
#     Non-arXiv: hit CrossRef by DOI (Zotero-compatible JSON out of the box).
if [ -f "$PAPER_DIR/arxiv_meta.json" ]; then
    cp "$PAPER_DIR/arxiv_meta.json" "$META"
elif [ -n "$PAPER_DOI" ]; then
    python "$SKILL_DIR/scripts/crossref_client.py" fetch \
        --doi "$PAPER_DOI" > "$META"
else
    echo "[skip] $PAPER_ID has no arXiv id / DOI - drop from import" >&2
    continue
fi

# (b) Import (idempotent: dedup by DOI / arXiv id within the user library).
CONTRIBUTION="$(jq -r .one_line_contribution "$PAPER_DIR/row.json")"
python "$SKILL_DIR/scripts/zotero_operator.py" import \
    --meta "$META" \
    ${PDF:+--pdf "$PDF"} \
    --collection "$ZOTERO_COLLECTION_PATH" \
    --contribution "$CONTRIBUTION" \
    >> "$LITREV_WORKDIR/zotero_import.jsonl"
```

Notes:

- arXiv papers: skip CrossRef entirely. Build a minimal Zotero JSON from the
  arXiv API record already captured at Phase 1 (`itemType=preprint`, `title`,
  `creators`, `date`, `abstractNote`, `url`, `extra: arXiv:<id>`).
- Non-DOI, non-arXiv papers (workshop PDFs on personal sites, etc.) are dropped
  from Phase 5. The user can add them by hand in Zotero; we do not attempt a
  best-effort scrape.
- The operator returns `{status: "created"|"existed", item_key, ...}`. Append
  per-paper outcomes to `zotero_import.jsonl` for the session log.
- On `RuntimeError` (HTTP 4xx/5xx), record the failure and continue with the
  next paper. Do not abort the whole import loop.

### 5.3 Report

After the loop, summarize: created vs existed counts, attachments uploaded,
notes added, paywalled papers waiting on Stage C.

---

## Phase 6: Synthesis

### 6.1 Comparison matrix

Aggregate all `row.json` into a Markdown table using `templates/comparison_matrix.md`
as skeleton. Sort by `year DESC, citation_count DESC`. Write to
`$LITREV_WORKDIR/comparison_matrix.md`.

### 6.2 Related Work draft

Use `templates/related_work.md`. Cluster papers thematically (2-4 themes) BY
SHARED TECHNIQUE OR PROBLEM FRAMING, not by chronology. For each theme, write
a paragraph that weaves 2-5 citations using the extracted contribution and
limitation. End with a "Positioning of Our Work" section only if the user has
stated their own angle at Phase 0. Write to `$LITREV_WORKDIR/related_work.md`.

### 6.3 Session log

Write `$LITREV_WORKDIR/session_log.md` with:

- Scope summary (from `scope.json`)
- Query variants used + counts per source
- Shortlist size, score distribution
- Deep-read success / failure per paper (with reason)
- Known gaps (papers we failed to retrieve or triage)

### 6.4 Present to user

Summarize with 3-5 bullet findings plus paths to the three artifacts above.
Include the workdir path so the user can open them directly.

---

## Anti-patterns

- DO NOT start deep reading without user confirmation of the shortlist
  (the Phase 2 USER GATE is mandatory).
- DO NOT invent citations or paper content. Every matrix cell must trace
  to a source file under `$LITREV_WORKDIR/papers/`.
- DO NOT skip de-duplication (Phase 1.4). Raw search is noisy.
- DO NOT call the three web search tools serially. Always parallel in one response.
- DO NOT parallelize `arxiv_fetch.py` and `s2_client.py` (background `&` them).
  They share rate-limit pressure even though they hit different hosts; serial
  invocation lets the in-process throttle do its job.
- DO NOT use the `researcher` skill for this. `literature-review` for academic
  scope, `researcher` for general web research.
- DO NOT write to `~/.config/opencode/skills/literature-review` directly.
  That is symlinked output from dotfiles. Edits go in
  `/home/qsdrqs/dotfiles/opencode/skills/literature-review/`.

## Stop conditions

Stop when:
- User explicitly says the shortlist is final.
- Diminishing returns: 2 consecutive search variants yielded no new candidates.
- Paper budget reached.
- 3 consecutive deep-read failures for the same source type (investigate before retrying).

## Scripts reference

All scripts accept `--help` and write errors to stderr.

| Script | Purpose | Stage |
|--------|---------|-------|
| `dedupe.py` | Merge multi-source search results | A |
| `arxiv_fetch.py` | arXiv API + HTML fetcher | A |
| `s2_client.py` | Semantic Scholar Graph API | A |
| `section_splitter.py` | HTML -> canonical sections JSON | A |
| `openreview_client.py` | OpenReview forum API | C |
| `pdf_fetch.py` | arXiv -> direct -> Unpaywall PDF resolver | B |
| `mineru_client.py` | MinerU HTTP client for PDF extraction | B |
| `crossref_client.py` | CrossRef REST (DOI -> Zotero metadata) | B |
| `zotero_operator.py` | Zotero Web API (CRUD + collection + attach + note) | B |
| `setup_containers.sh` / `teardown_containers.sh` | Deploy mineru | B |
| `paywall_browser.py` | chrome-devtools fallback for IEEE/ACM | C |

## Further reading

- `references/data-sources.md` - per-source API details, rate limits, and auth.
- `references/output-templates.md` - template selection and rendering rules.
- `references/zotero-integration.md` - Zotero API + CrossRef pipeline (Stage B).
- `references/mineru-integration.md` - MinerU container + decision rules (Stage B).
