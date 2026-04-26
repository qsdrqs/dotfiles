# Data Sources

This document describes the search and fetch sources the `literature-review` skill uses,
organized by Layer in the workflow (see SKILL.md for the layer definitions).

## Layer 1: Broad Discovery

The orchestrator LLM calls these directly. Python scripts for structured APIs,
MCP tools for general web search. All calls within a layer run in parallel.

### A. General web search (primary, 3 engines in parallel)

| Tool | Call style | Best for |
|------|------------|----------|
| `brave_web_search` | MCP tool | Keyword queries, direct URLs, survey recommendations |
| `web_search_exa` | MCP tool | Semantic matching ("describe the ideal page") |
| `websearch_cited` | MCP tool | Citation-grounded digests for authoritative sources |

Run all three IN PARALLEL in a single response for each query variant. Default query
count: 6-10 variants per topic. Suggested variant styles:

- **Keyword** (for brave): `"diffusion alignment" "DPO"`
- **Natural language** (for exa): `recent 2024 papers on aligning text-to-image diffusion models with human preferences`
- **Authoritative framing** (for cited): `overview of preference learning methods for generative models`

One JSONL line per result, written to `$LITREV_WORKDIR/raw_search.jsonl`:

```json
{"source": "brave", "query": "...", "url": "...", "title": "...", "snippet": "..."}
{"source": "exa",   "query": "...", "url": "...", "title": "...", "snippet": "..."}
{"source": "cited", "query": "...", "url": "...", "title": "...", "snippet": "..."}
```

### B. Structured API search (secondary, fills metadata gaps)

| Source | Script | Best for |
|--------|--------|----------|
| arXiv API | `scripts/arxiv_fetch.py search` | Fresh preprints, CS / ML / Physics |
| Semantic Scholar | `scripts/s2_client.py search` | Cross-venue metadata, citation counts, TL;DR |
| OpenReview | `scripts/openreview_client.py` (Stage A/B/C) | ICLR / NeurIPS / ICML import + reviews; v1 + v2 |

Call style (SEQUENTIAL, not backgrounded with `&`):

```bash
python "$SKILL_DIR/scripts/arxiv_fetch.py" search \
    --query "diffusion AND preference" --max 50 \
    >> "$LITREV_WORKDIR/raw_search.jsonl"

python "$SKILL_DIR/scripts/s2_client.py" search \
    --query "diffusion preference optimization" --max 100 \
    >> "$LITREV_WORKDIR/raw_search.jsonl"
```

Both scripts implement internal throttling and 30s exponential backoff on
HTTP 429 / 503. Running them in parallel adds no speedup (each script runs
its own loop of throttled requests internally) and risks tripping shared
rate-limit thresholds.

#### arXiv API

- Endpoint: `http://export.arxiv.org/api/query`
- Rate: ~1 request per 3 seconds. The script throttles to 1 / 3.1 s
  internally and retries on 429 / 503 with 30/60/90/120-second backoff.
- No authentication required.
- Query syntax supports field restriction and boolean combinations:
  - `ti:<title words>` (title)
  - `abs:<words>` (abstract)
  - `au:<author>` (author)
  - `cat:<arxiv category>` (e.g. cs.LG, cs.AI, stat.ML)
  - Combine with `AND`, `OR`, `ANDNOT`
- Sort modes: `relevance`, `lastUpdatedDate`, `submittedDate`.
- Script emits one JSONL line per result, source tag `arxiv_api`, with
  structured fields (arxiv_id, title, authors, abstract, year, categories, html_url, pdf_url).

#### Semantic Scholar (S2)

- Endpoint: `https://api.semanticscholar.org/graph/v1`
- Auth: optional env var `S2_API_KEY`. Strongly recommended to avoid 429s.
  - Without key: ~100 requests / 5 minutes; the script throttles to 1 / 3.1 s.
  - With key: 1 request / second baseline; the script throttles to 1 / 1.1 s.
  - Either way: retries 429 / 503 with 30/60/90/120-second backoff.
  - Get a key at https://www.semanticscholar.org/product/api
- Query syntax: plain keywords; supports quoted phrases; no field restriction.
- Identifier formats for fetch / refs / cites:
  - S2 corpus id (paperId)
  - `DOI:<doi>`
  - `ARXIV:<arxiv-id>`
  - `MAG:<id>`, `ACL:<id>`, `PMID:<id>`, etc.
- S2 AGGREGATES data from Google Scholar, IEEE, ACM, Springer, Nature, etc.
  - For discovery of paywalled venues, search S2 FIRST rather than trying to scrape GS/IEEE directly.
- Script emits normalized JSONL with source tag `s2_api` and all identifiers.

#### OpenReview (Stage C discovery + Stage B import)

Relevant for NeurIPS / ICLR / ICML / COLM and similar venues that do not
issue DOIs. The client (`scripts/openreview_client.py`) covers two API
versions to span the venue's lifetime:

- **API v2** (`api2.openreview.net`): late-2022+ venues. ICLR 2023+,
  NeurIPS 2023+, ICML 2023+, COLM, RLC, etc.
- **API v1** (`api.openreview.net`): legacy venues. ICLR 2022 and earlier,
  NeurIPS 2022 and earlier, ICML 2022 and earlier.

Subcommands:

- `search --venue <id>`: lists accepted submissions; v2 only (deliberate -
  v1 venue listing is slower and rarely needed for current literature
  reviews).
- `fetch --id <forum_id>`: single-paper normalized record. Tries v2 first,
  transparently falls back to v1 on no-match. Use for `import-by-id
  --openreview <forum_id>` in Phase 5.
- `forum --id <forum_id>`: full thread (reviews, rebuttals, decisions);
  v2 only.

Both v1 and v2 normalize through the same `_normalize_submission()` because
`_content_value()` transparently handles both schemas (v1 flat strings vs
v2 wrapped `{"value": ...}`).

### C. Google Scholar / IEEE / ACM

No open API available for direct scripting. Strategy:

- **Discovery**: most of their metadata is already in Semantic Scholar.
  Search S2 first; it will surface IEEE / ACM / Springer papers with `externalIds`.
- **Paywalled full text**: Stage C uses `chrome-devtools` MCP to walk through
  the user's logged-in browser session. Not in Stage A.

## Layer 2: Triage

No separate Python tooling. Use `webfetch(url, format="markdown")` MCP tool
per-candidate, or skip for entries that already have `abstract` populated from
`arxiv_api` / `s2_api`.

## Layer 3: Deep read

| Source type | Primary | Fallback | Notes |
|-------------|---------|----------|-------|
| arXiv | `arxiv_fetch.py html <id>` piped to `section_splitter.py` | PDF via MinerU (Stage B) | HTML exists for ~90% of 2022+ papers |
| S2 open-access PDF | Download via `openAccessPdf.url`; pipe to MinerU (Stage B) | S2 TL;DR + abstract | |
| IEEE / ACM / paywalled | `chrome-devtools` MCP (Stage C) | S2 TL;DR + abstract | |

### arXiv HTML flow

```bash
python "$SKILL_DIR/scripts/arxiv_fetch.py" html "$ARXIV_ID" \
    > "$LITREV_WORKDIR/papers/$ARXIV_ID/full.html"

python "$SKILL_DIR/scripts/section_splitter.py" \
    "$LITREV_WORKDIR/papers/$ARXIV_ID/full.html" \
    > "$LITREV_WORKDIR/papers/$ARXIV_ID/sections.json"
```

Exit 3 from `arxiv_fetch.py html` means HTML is not available for that paper.
Fall back to PDF pipeline (MinerU in Stage B; pdftotext in Stage A as a last resort).

## De-duplication

`scripts/dedupe.py` collapses multi-source hits. Key priority:

1. DOI (case-insensitive)
2. arXiv id (version suffix stripped: `2401.12345v3` -> `2401.12345`)
3. OpenReview forum id
4. Canonical URL (host + path, lowercased, trailing slash stripped)
5. Normalized title + year

Structured sources (`arxiv_api`, `s2_api`, `openreview_api`) take priority
over generic web-search sources for scalar fields (title, abstract, year, venue,
authors, pdf_url). `citation_count` takes the max across sources.

```bash
python "$SKILL_DIR/scripts/dedupe.py" \
    "$LITREV_WORKDIR/raw_search.jsonl" \
    > "$LITREV_WORKDIR/candidates.jsonl"
```

Stderr reports summary like:
```
[dedupe] merged 187 unique entries
        key-kind breakdown: {'arxiv': 112, 'doi': 43, 'url': 28, 'title_year': 4}
```

## Environment setup

```bash
# Optional: Semantic Scholar API key for higher quota
export S2_API_KEY="your-key-here"

# Session workdir (where raw_search.jsonl, candidates.jsonl, etc. live)
export LITREV_WORKDIR="/tmp/literature-review/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$LITREV_WORKDIR"

# Skill scripts directory
export SKILL_DIR="$HOME/.config/opencode/skills/literature-review"
```

## Container services (Stage B, not needed for Stage A)

Prefer podman when available:

```bash
CONTAINER_CMD=$(command -v podman || command -v docker)

# Zotero translation-server (for URL -> Zotero metadata conversion)
$CONTAINER_CMD run -d --name zotero-ts -p 1969:1969 \
    zotero/translation-server

# MinerU (for PDF structured extraction)
# NOTE: Podman requires CDI mode for GPU: --device nvidia.com/gpu=all
# Docker uses --gpus all
if [ "$CONTAINER_CMD" = "podman" ]; then
    $CONTAINER_CMD run -d --name mineru \
        --device nvidia.com/gpu=all -p 8000:8000 \
        erikvullings/mineru-api:gpu
else
    $CONTAINER_CMD run -d --name mineru \
        --gpus all -p 8000:8000 \
        erikvullings/mineru-api:gpu
fi
```

Zotero Web API credentials (Stage B):

```bash
export ZOTERO_API_KEY="..."
export ZOTERO_USER_ID="..."       # or ZOTERO_GROUP_ID
export ZOTERO_TS_URL="http://localhost:1969"
```
