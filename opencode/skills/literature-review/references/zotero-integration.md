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

### 2.1 arXiv papers

Reuse the metadata captured in Phase 1 by `arxiv_fetch.py`. Build a minimal
Zotero JSON (`itemType=preprint`, `title`, `creators`, `date`, `abstractNote`,
`url`, `extra: "arXiv:<id>"`). No extra API call.

### 2.2 DOI-indexed papers (journals, conferences, books)

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

### 2.3 Neither arXiv id nor DOI

Dropped from the import loop. The user can add such papers manually in the
Zotero UI. We do not scrape publisher landing pages.

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

End-to-end:

```bash
# 1. Resolve metadata
python scripts/crossref_client.py fetch \
    --doi 10.1038/s41586-021-03819-2 > meta.json

# 2. Fetch PDF (arXiv -> direct -> Unpaywall fallback)
echo '{"doi":"10.1038/s41586-021-03819-2"}' | \
    python scripts/pdf_fetch.py --out /tmp/lr/alphafold

# 3. Import into Zotero
python scripts/zotero_operator.py import \
    --meta meta.json \
    --pdf /tmp/lr/alphafold/paper.pdf \
    --collection "AI/Bio/AlphaFold" \
    --contribution "End-to-end neural structure prediction with attention over MSA + pair repr."
```

Idempotency: `import_paper` first calls `find_by_identifier(doi=..., arxiv=...)`
on the user's library. If a match exists, it skips creation and only:

- Adds the existing item to the requested collection (if not already there).
- Appends the contribution note (current logic always appends; manual cleanup
  required if re-running with a different note).

## 5. PDF attachment flow (hybrid local+metadata)

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

## 6. Error handling

| HTTP | Cause | Operator behavior |
|------|-------|-------------------|
| 412 | Library version conflict (concurrent edit) | Re-fetch item, retry |
| 403 | API key lacks write permission | Hard fail with hint |
| 429 | Rate limit (Zotero is generous, ~120 req/min) | Sleep `Retry-After` then retry |
| 500-504 | Transient server error | Retry up to 4 times with backoff |
| CrossRef 404 | DOI not indexed | `crossref_client.py` exits 3; skip the paper |

`import_paper` does not catch these; the orchestrator (SKILL.md Phase 5)
collects per-paper errors and continues with the next paper.

## 7. Limitations

- Group libraries: not implemented. Add `--library group:<id>` support if needed.
- Non-DOI, non-arXiv papers are dropped (workshop PDFs on personal sites, etc.).
- CrossRef's abstract field is optional and publisher-dependent; many journals
  do not deposit abstracts in CrossRef. `pdf_fetch.py` + MinerU can recover
  the full text for papers where the abstract is critical.
- Notes are append-only; no de-dup of contribution text.

## 8. Why not `zotero/translation-server`?

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
