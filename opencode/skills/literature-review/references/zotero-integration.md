# Zotero Integration

This skill imports curated papers into the user's Zotero library via a
**hybrid** model:

- **Metadata** (items, collections, notes) -> Zotero Web API (`api.zotero.org`).
  The desktop client pulls this on its next sync.
- **Attachment files** (PDFs) -> written directly to `~/Zotero/storage/<key>/`
  on the local disk, with matching `md5` + `mtime` stored in the item
  metadata. The S3 file-upload flow is skipped entirely. The desktop client
  finds the local file by md5 and never contacts Zotero file storage.

This fits setups where a third-party tool (e.g. Syncthing, Nextcloud, rsync)
replicates `~/Zotero/storage/` across machines while Zotero's free-tier
metadata sync handles the database.

Metadata resolution uses public REST APIs (CrossRef + arXiv) - no
metadata-server container is required.

Pipeline:

```
          +-- arxiv_id --> arxiv_fetch.py (Stage A metadata reused)
paper ----|
          +-- DOI ------> crossref_client.py (api.crossref.org/works/<doi>)
                |
                v
          Zotero JSON (itemType + creators + date + DOI + ...)
                |
                v
          zotero_operator.py
                |
                +-- POST /items          (create item, dedup by DOI/arXiv)
                +-- POST /items/.../file (3-step PDF upload)
                +-- POST /items          (note: one-line contribution)
                +-- PATCH /items/...     (link to collection)
                |
                v
          Zotero Cloud (api.zotero.org)
```

## 1. Prerequisites

### 1.1 API credentials (one-time)

1. Sign in at https://www.zotero.org/settings/keys.
2. Click **Create new private key**:
   - **Personal Library**: `Allow library access` + `Allow write access`
   - Give it a name, e.g. `literature-review-skill`.
3. Note the **userID** shown at the top of the keys page (a number, not your username).

Set environment variables in your shell rc:

```bash
export ZOTERO_API_KEY="P9Xxxxxxxxxxxxxxxxxxxxxx"
export ZOTERO_USER_ID="1234567"
```

> Group libraries are not supported in this minimal client; only the personal
> library is targeted (`/users/{ZOTERO_USER_ID}/...`).

### 1.1.1 Zotero client setting (IMPORTANT)

In the Zotero desktop client, open **Edit -> Preferences -> Sync -> File
Syncing** and set **"My Library"** to one of:

- **Off** - recommended if you use Syncthing / rsync / etc. for file
  replication. The client will trust local files by md5 and never try to
  re-upload them to Zotero storage.
- **WebDAV** - if you have your own WebDAV server.

Do **NOT** use "Zotero" as the file-sync option. If you do, the client will
try to upload the PDFs we placed locally and either fail (quota) or create
cloud-side duplicates.

### 1.1.2 Local data directory

Default: `~/Zotero/`. Override with `ZOTERO_DATA_DIR`:

```bash
export ZOTERO_DATA_DIR="/path/to/synced/Zotero"
```

The skill writes PDFs to `$ZOTERO_DATA_DIR/storage/<attachment_key>/<filename>`.

### 1.2 Email (CrossRef polite pool + Unpaywall)

```bash
export UNPAYWALL_EMAIL="you@example.com"
```

The same email is:
- Required by Unpaywall (`pdf_fetch.py` fallback for non-arXiv PDFs).
- Used by `crossref_client.py` in the `User-Agent` header, which puts the
  skill into CrossRef's "polite pool" (no rate limits). Without it, CrossRef
  still works but may rate-limit under heavy use.

### 1.3 MinerU container (optional)

Only needed if you will extract text from non-arXiv PDFs at Phase 4:

```bash
bash scripts/setup_containers.sh
# Skip entirely on CPU-only hosts:
SKIP_MINERU=1 bash scripts/setup_containers.sh
```

## 2. Metadata resolution

**Preference order: DOI > OpenReview forum_id > arXiv id.** The DOI route
gives a formally-published Zotero entry (journalArticle / conferencePaper,
with venue / pages / issue). OpenReview gives an exact conferencePaper for
ICLR / NeurIPS / ICML / COLM and similar venues that do not issue DOIs.
arXiv id is the fallback - even so, the operator's internal cascade tries
hard to upgrade an arxiv-only input to conferencePaper or journalArticle
before settling on preprint.

Internal cascade for `import-by-id --arxiv-id <id>`:

```
T1: arxiv API
    arxiv:doi populated?    yes -> CrossRef          -> done (published)
                            no  -> continue
T2: S2 lookup ARXIV:<id>
    S2 doi populated?       yes -> CrossRef          -> done (published)
                            no  -> continue
    venue == "arXiv.org"?   yes -> preprint          -> done (T0 in
                                                       _s2_pick_item_type)
    venue populated?        yes -> conferencePaper / journalArticle, with
                                   canonical proceedingsTitle/
                                   publicationTitle from data/venues.json
                                   when the S2 venue name matches a
                                   known entry; otherwise the raw S2
                                   venue value is used. JournalArticle
                                   mistags get auto-corrected to
                                   conferencePaper when venues.json
                                   asserts the venue is a conference
                                   (Bug 2b mitigation).
                                                     -> done (venue)
                            no  -> continue
T3: arxiv preprint fallback                          -> done (preprint)
```

Each tier silently falls through on failure (404, rate-limit, network),
so a single transient upstream issue never blocks the import. The whole
cascade exits 4 only if all tiers raise, which means the orchestrator
should defer the paper to the next session.

### 2.1 arXiv papers (preprint-only fallback)

Reach this path only when arXiv has no `<arxiv:doi>` for the paper - i.e.
it is genuinely a preprint that has not been formally published, or the
authors have not yet deposited the published-version DOI back to arXiv.

`zotero_operator.py` calls `arxiv_fetch.py fetch <id>` as a subprocess and
gets the parsed Atom entry, including:

- `arxiv_id`, `title`, `authors`, `abstract`, `published`, `categories`,
  `url`, `pdf_url`, `html_url`
- `doi` - populated from `<arxiv:doi>` when present
- `journal_ref` - populated from `<arxiv:journal_ref>` when present
  (free-text venue+pages, e.g. "Nature 596 (2021) 583-589")

If `doi` is null, the operator builds a minimal Zotero JSON
(`itemType=preprint`, `title`, `creators`, `date`, `abstractNote`, `url`,
`extra: "arXiv:<id>"`). If `doi` is non-null, the operator transparently
routes to CrossRef (see 2.2) - the caller does not have to know.

### 2.2 OpenReview-indexed papers (ICLR / NeurIPS 2021+ / ICML / COLM / ...)

Most modern ML conferences do not issue DOIs and are not on CrossRef. They
do, however, expose stable forum IDs through the OpenReview API. When a
paper is discovered via Phase 1 OpenReview search (`openreview_client.py
search`), the resulting JSONL already includes `forum_id`. Pass it in
Phase 5.2:

```bash
python scripts/zotero_operator.py import-by-id \
    --openreview rhgIgTSSxW \
    --collection "AI/Tabular/2024" \
    --contribution "..."
```

The operator subprocess-calls `openreview_client.py fetch --id <forum_id>`
(which transparently cascades v2 -> v1 to handle ICLR / NeurIPS / ICML
2022 and earlier), gets the normalized submission record (title, authors,
abstract, year, venue_display, venue_id), and converts it to
`itemType=conferencePaper`. The `proceedingsTitle` is resolved via a
3-tier resolver:

```
T1: data/venues.json lookup by venue_id (fnmatch glob,
    e.g. "ICLR.cc/*/Conference") -> canonical_name
    (e.g. "International Conference on Learning Representations")
    -- ONLY tier that produces a canonical proceedings title
T2: closed track-keyword strip on venue.value (Poster, Oral,
    Spotlight, Findings, Demo, Industry, Tutorial, Long, Short,
    Main, Track) -- e.g. "ICLR 2024 poster" -> "ICLR 2024".
    Yields a short form, not canonical. Used when venues.json has
    no entry for this venue.
T3: structural parse of venue_id (e.g. "ICLR.cc/2024/Conference"
    -> "ICLR 2024") -- final fallback when venue.value is empty.
```

`extra` is set to `"OpenReview: <forum_id>"`. See section 2.5 below for
the venues.json schema and how to add a new venue.

### 2.3 DOI-indexed papers (journals, conferences, books)

```bash
python scripts/crossref_client.py fetch --doi 10.1038/s41586-021-03819-2
```

Output is already a Zotero items POST payload:

```json
{
  "itemType": "journalArticle",
  "title": "Highly accurate protein structure prediction with AlphaFold",
  "creators": [{"creatorType": "author", "firstName": "John", "lastName": "Jumper"}, ...],
  "date": "2021-08-26",
  "publicationTitle": "Nature",
  "volume": "596", "issue": "7873", "pages": "583-589",
  "DOI": "10.1038/s41586-021-03819-2",
  "url": "https://doi.org/10.1038/s41586-021-03819-2",
  "abstractNote": "...",
  "ISSN": "0028-0836, 1476-4687"
}
```

CrossRef type -> Zotero itemType mapping (`_CROSSREF_TYPE_TO_ZOTERO` in the
client): `journal-article` -> `journalArticle`, `proceedings-article` ->
`conferencePaper`, `book-chapter` -> `bookSection`, `posted-content` ->
`preprint`, and so on.

### 2.4 Neither arXiv id nor DOI nor OpenReview forum_id

Dropped from the import loop. The user can add such papers manually in the
Zotero UI. We do not scrape publisher landing pages.

### 2.5 `data/venues.json` (canonical venue lookup)

`zotero_operator.py` consults `data/venues.json` in two places:

1. **OpenReview path (Bug 1 fix)**: maps venue_id glob to the canonical
   proceedings title. Without this, raw `content.venue.value` strings like
   `"ICLR 2024 poster"` (which include acceptance track suffix) would land
   verbatim in Zotero `proceedingsTitle`, rendering bibliography entries
   like *"In ICLR 2024 poster, 2024."*.

2. **S2 path (Bug 2b mitigation)**: when S2 `publicationVenue.type` is
   missing AND `publicationTypes` contains only `"JournalArticle"` for an
   actually-conference paper (S2 mistag, common for older proceedings),
   the operator looks up the S2 `publicationVenue.name` (and any
   `alternate_names`) against `s2_venue_aliases`. If the venue is on file
   as a conference, the itemType is overridden to `conferencePaper`.

Each entry MUST cite at least 2 authoritative sources (DBLP, official
venue website, S2 publicationVenue record). Lookup semantics:

- `openreview_id_globs`: fnmatch-style glob matched against OpenReview
  `content.venueid.value` (first match wins).
- `s2_venue_aliases`: case-insensitive **EXACT** match against
  S2 `publicationVenue.name` and any `alternate_names`. No substring
  match, to avoid over-matching workshops (`"NeurIPS Workshop on X"`
  must NOT hit the NeurIPS conference entry).

Initial seed (2026-04-26): ICLR, NeurIPS, ICML, COLM. To add a venue,
verify the canonical name against DBLP `https://dblp.org/streams/conf/<id>`
plus the official venue website, then PR. Do NOT add entries from memory
- the constraint `_schema.review_protocol` in venues.json forbids it.

When venues.json has no entry for the venue:

- **OpenReview path**: falls through to closed track-keyword strip on the
  raw venue display (e.g. `"EMNLP 2024 Findings" -> "EMNLP 2024"`).
- **S2 path**: T2 trusts the S2 `publicationTypes` mistag; result may be
  `journalArticle` for conference papers if S2 mis-tags. Adding the venue
  to venues.json is the fix.

## 3. Collection paths

Pass collections as a slash-separated path, e.g. `"AI/RAG/Survey"`:

```bash
python scripts/zotero_operator.py resolve-collection --path "AI/RAG/Survey"
# {"key": "ABCD1234", "path": "AI/RAG/Survey"}
```

- Path matching is **case-sensitive** and walks the parent chain (top-level
  collection named `AI`, child `RAG`, grandchild `Survey`).
- Missing nodes are **created automatically** with `POST /collections`.
- Existing names at the same level are reused (no duplicate creation).

## 4. Importing a paper

The preferred entry point is `import-by-id`. It re-resolves metadata inside
`zotero_operator.py` via `arxiv_fetch` (for `--arxiv-id`) or `crossref_client`
(for `--doi`) as a subprocess. **No LLM-supplied metadata can reach the
Zotero Web API along this path.** If the upstream API is rate-limited, the
command exits 4 and the caller defers; this is by design - hand-constructed
metadata bypasses the deterministic API parsing chain and produces
unverifiable Zotero entries.

When called with `--arxiv-id`, the operator runs the full 3-tier cascade
described in section 2: arxiv:doi -> CrossRef, then S2-routed CrossRef or
S2-venue conferencePaper, then preprint fallback. Each tier silently falls
through on transient API failures (404 / 429 / network), so the import is
never blocked by a single rate-limited upstream.

End-to-end examples:

```bash
# 1. DOI-first (formally published paper)
echo '{"doi":"10.1038/s41586-021-03819-2"}' | \
    python scripts/pdf_fetch.py --out /tmp/lr/alphafold
python scripts/zotero_operator.py import-by-id \
    --doi 10.1038/s41586-021-03819-2 \
    --pdf /tmp/lr/alphafold/paper.pdf \
    --collection "AI/Bio/AlphaFold" \
    --contribution "End-to-end neural structure prediction."

# 2. arXiv-only (cascade auto-upgrades when possible)
python scripts/zotero_operator.py import-by-id \
    --arxiv-id 2006.11239 \
    --pdf /tmp/lr/ddpm/paper.pdf \
    --collection "AI/Diffusion/Foundations" \
    --contribution "Denoising diffusion via predictive variational lower bound."
# stderr: arxiv 2006.11239 -> S2 venue 'Neural Information Processing Systems'
#         -> conferencePaper

# 3. OpenReview forum_id (exact ICLR / NeurIPS conferencePaper)
python scripts/zotero_operator.py import-by-id \
    --openreview rhgIgTSSxW \
    --pdf /tmp/lr/tabr/paper.pdf \
    --collection "AI/Tabular/2024" \
    --contribution "Retrieval-augmented tabular DL with kNN attention component."
# stderr: openreview rhgIgTSSxW -> conferencePaper (ICLR 2024 poster)
# Zotero entry: proceedingsTitle = "International Conference on Learning
# Representations" (canonical from venues.json), NOT "ICLR 2024 poster".

# 4. OpenReview forum_id, pre-2024 venue (uses v1 fallback transparently)
python scripts/zotero_operator.py import-by-id \
    --openreview KmtVD97J43e \
    --collection "AI/CodeGen/2022" \
    --contribution "Constrained semantic decoding for code generation."
# stderr: [openreview_client] v2 returned no matching note for forum_id=
#         KmtVD97J43e; trying older API
# stderr: openreview KmtVD97J43e -> conferencePaper (ICLR 2022 Poster)
# Zotero entry: proceedingsTitle = "International Conference on Learning
# Representations".
```

The `--pdf` flag is optional only when the PDF is genuinely unreachable
(`pdf_fetch.py` status `paywalled` or `no_identifier`); metadata-only
entries are auto-tagged `literature-review-no-pdf`.

### 4.1 Legacy `import --meta` path (REQUIRES --unverified signature)

The `import --meta` subcommand exists for emergency use (testing, manual
migration from another tool, manual fix-up). It now **requires** an
explicit `--unverified true|false` flag - there is no default. The flag
is the LLM's provenance attestation:

| `--unverified value` | Caller is attesting | Resulting Zotero entry |
|---|---|---|
| `false` | Every metadata field came from a deterministic API parse (cached `arxiv_meta.json` from Phase 1, exported BibTeX from a verified pipeline, etc.). The JSON is just being re-imported from disk. | Clean. No tag, no warning. Treated identically to `import-by-id`. |
| `true` | Some/any field was constructed by the LLM (guessed, paraphrased, completed from memory). | Tagged `literature-review-unverified-metadata`, contribution prefixed `[UNVERIFIED METADATA]`, `extra` appended with `[UNVERIFIED METADATA: manually constructed, not API-fetched]`. |

Filter the false-attest items in the Zotero UI with
`tag:literature-review-unverified-metadata`.

The signature mechanism shifts the responsibility model: previously the
operator unconditionally tagged every `import --meta` call, which meant
legitimate cached-JSON re-imports were also polluted with the tag. Now
the LLM consciously chooses. **Falsely signing `--unverified false` when
metadata was actually fabricated is a stronger breach than the old
unverified path** - the operator has no way to detect this; the only
defense is the LLM's own discipline.

Stage A/B/C orchestration should still never go through `import --meta` -
the SKILL.md anti-patterns explicitly forbid it. The cascade in
`import-by-id` (DOI -> arxiv:doi -> S2 -> preprint) is the right answer
for almost every Phase 5 use case.

Idempotency: `import_paper` first calls `find_by_identifier(doi=..., arxiv=...)`
on the user's library. If a match exists, it skips creation and only:

- Adds the existing item to the requested collection (if not already there).
- Appends the contribution note (current logic always appends; manual cleanup
  required if re-running with a different note).

## 5. PDF policy and the `literature-review-no-pdf` tag

**Default**: every paper that enters the Phase 5 import loop must come
with a PDF. Calling `import-by-id` without `--pdf` is allowed only for
papers whose `manifest.json` reports `status = paywalled` or
`status = no_identifier` from `pdf_fetch.py` (and where any Phase 4
chrome-devtools fallback also failed).

When `import-by-id` runs without an attached PDF (either because `--pdf`
was omitted or the path did not exist on disk), the operator auto-tags
the freshly created Zotero item with `literature-review-no-pdf`. This
matches the existing `literature-review-unverified-metadata` namespace
pattern and is trivially filterable in the Zotero UI:

```
tag:literature-review-no-pdf
```

The user can use this tag to drive a backfill workflow (e.g. fetch the
PDF via institutional VPN, drop it into the attachment directory, then
remove the tag manually). The tag is added only on `status: created` -
existing items are never re-tagged, since they may already have a PDF
from a previous session or manual upload that we cannot see without an
extra round-trip.

## 6. PDF attachment flow (hybrid local+metadata)

Instead of Zotero's standard 3-step S3 upload, `attach_pdf` does:

1. **Compute md5 + mtime** of the local PDF.
2. **Create attachment item**: `POST /items` with
   `linkMode=imported_file`, `parentItem=<paperKey>`, and the computed
   `md5` + `mtime` embedded in the item data. No file upload is authorized.
3. **Place file locally**: copy the PDF to
   `$ZOTERO_DATA_DIR/storage/<attach_key>/<filename>`, then `utime` the file
   to the `mtime` we posted.

When the desktop client next syncs:

- It pulls down the new attachment metadata from `api.zotero.org`.
- It computes the md5 of `~/Zotero/storage/<attach_key>/<filename>` and
  compares to the stored md5.
- Match -> the file is considered present locally, no cloud download
  attempted (there is none - `GET /items/{key}/file` on the cloud returns
  404 for these items).

A third-party sync tool (Syncthing, rsync, Nextcloud) is responsible for
replicating `storage/<attach_key>/` to other machines. Each machine's
Zotero client independently verifies md5 on first open.

Why not use Zotero's S3 storage? In our testing, the `{"exists": 1}` code
path returned by Zotero's file-upload authorization for md5 matches across
the library is unreliable: the server accepts the reference but the client
cannot always resolve it back to a file, causing "attached file could not
be found" errors. Skipping the S3 flow sidesteps the entire class of bug.

## 7. Error handling

| HTTP | Cause | Operator behavior |
|------|-------|-------------------|
| 412 | Library version conflict (concurrent edit) | Re-fetch item, retry |
| 403 | API key lacks write permission | Hard fail with hint |
| 429 | Rate limit (Zotero is generous, ~120 req/min) | Sleep `Retry-After` then retry |
| 500-504 | Transient server error | Retry up to 4 times with backoff |
| CrossRef 404 | DOI not indexed | `crossref_client.py` exits 3; skip the paper |

`import_paper` does not catch these; the orchestrator (SKILL.md Phase 5)
collects per-paper errors and continues with the next paper.

## 8. Limitations

- Group libraries: not implemented. Add `--library group:<id>` support if needed.
- Non-DOI, non-arXiv papers are dropped (workshop PDFs on personal sites, etc.).
- CrossRef's abstract field is optional and publisher-dependent; many journals
  do not deposit abstracts in CrossRef. `pdf_fetch.py` + MinerU can recover
  the full text for papers where the abstract is critical.
- Notes are append-only; no de-dup of contribution text.

## 9. Why not `zotero/translation-server`?

An earlier revision used `zotero/translation-server` (a local Node.js
container that maps any URL to Zotero metadata via 700+ community-maintained
translators). Three reasons we replaced it with CrossRef:

1. **Broken upstream image**: `:latest` is arm64-only since 2.0.6 and the last
   amd64 tag (2.0.4) ships translators with a `requestText is not defined`
   bug that breaks arXiv and several DOI flows.
2. **Rootless podman + NixOS** blocks the arm64 image from running under
   binfmt emulation (default `P` flag, not `F`), which would require a NixOS
   config change + reboot for every user of the skill.
3. **Academic coverage**: CrossRef + arXiv together cover >95% of papers in a
   typical literature review. The long tail (no DOI, not on arXiv) is small
   enough that manual Zotero UI import is acceptable.

If you still need the full translator pipeline, resurrecting it requires
fixing (1) on your host.
