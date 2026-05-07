# Zotero API Reference

Schema notes for hand-building Zotero JSON to feed `create-item --meta` or `update-item --meta`. This is a working subset; the canonical authority is the Zotero developer docs at <https://www.zotero.org/support/dev/web_api/v3/basics> and the type/field schema endpoint at <https://api.zotero.org/schema>.

## Table of Contents

- [Common Item Types](#common-item-types)
- [Required Fields by Item Type](#required-fields-by-item-type)
- [Universal Optional Fields](#universal-optional-fields)
- [Creators](#creators)
- [Date Formats](#date-formats)
- [Identifiers](#identifiers)
- [Tags](#tags)
- [Notes (HTML)](#notes-html)
- [Attachments](#attachments)
- [Pagination](#pagination)
- [Versioning and Concurrency](#versioning-and-concurrency)
- [Rate Limits and Errors](#rate-limits-and-errors)

## Common Item Types

The 12 item types you will use 95% of the time. Pass as `"itemType": "..."` in the JSON payload.

| itemType | Use for |
|----------|---------|
| `journalArticle` | Peer-reviewed journal paper |
| `conferencePaper` | Conference proceedings (NeurIPS, ICLR, ICML, etc.) |
| `preprint` | arXiv, bioRxiv, OpenReview, SSRN before formal publication |
| `book` | Whole book |
| `bookSection` | Chapter in an edited volume |
| `thesis` | PhD/Master/Undergraduate thesis |
| `report` | Tech report, white paper |
| `webpage` | Generic web page |
| `blogPost` | Blog entry |
| `software` | Source code release, model release |
| `dataset` | Dataset release |
| `presentation` | Talk slides / poster |

The full type list (35+) is at <https://api.zotero.org/itemTypes>. To see the field schema for a specific type:

```bash
curl https://api.zotero.org/itemTypeFields?itemType=journalArticle
curl https://api.zotero.org/itemTypeCreatorTypes?itemType=journalArticle
```

## Required Fields by Item Type

Zotero accepts a missing field, but rendering bibliographic citations requires the type-specific minimums below. Always populate these.

### `journalArticle`

```json
{
  "itemType": "journalArticle",
  "title": "...",
  "creators": [{"creatorType": "author", "firstName": "...", "lastName": "..."}],
  "date": "YYYY-MM-DD or YYYY",
  "publicationTitle": "Journal Name",
  "DOI": "10.x/y",                  // strongly preferred
  "abstractNote": "..."             // optional but recommended
}
```

Optional but useful: `volume`, `issue`, `pages`, `ISSN`, `url`.

### `conferencePaper`

```json
{
  "itemType": "conferencePaper",
  "title": "...",
  "creators": [...],
  "date": "YYYY",
  "proceedingsTitle": "Advances in Neural Information Processing Systems",
  "DOI": "10.x/y or null"
}
```

`proceedingsTitle` should be the canonical proceedings name, NOT the short conference name. Examples:

- ICLR -> `International Conference on Learning Representations`
- NeurIPS -> `Advances in Neural Information Processing Systems`
- ICML -> `International Conference on Machine Learning`

Optional: `place`, `publisher`, `pages`, `series`.

### `preprint`

```json
{
  "itemType": "preprint",
  "title": "...",
  "creators": [...],
  "date": "YYYY-MM-DD",
  "repository": "arXiv",            // or "bioRxiv", "OpenReview"
  "archiveID": "2401.12345",        // arXiv id / OpenReview forum id
  "DOI": "10.48550/arXiv.2401.12345",  // arXiv issues DOIs since 2022
  "extra": "arXiv:2401.12345 [cs.LG]",
  "url": "https://arxiv.org/abs/2401.12345"
}
```

`extra` is a free-text field Zotero uses for everything that does not fit elsewhere. Convention:

```
arXiv:<id> [<primary_category>]
OpenReview: <forum_id>
PMID: <pubmed_id>
```

Multi-line values are allowed; one key=value or `Key:` per line.

### `book`

```json
{
  "itemType": "book",
  "title": "...",
  "creators": [{"creatorType": "author", "firstName": "...", "lastName": "..."}],
  "date": "YYYY",
  "publisher": "...",
  "place": "...",
  "ISBN": "978-..."
}
```

### `bookSection`

```json
{
  "itemType": "bookSection",
  "title": "Chapter title",
  "creators": [
    {"creatorType": "author", "firstName": "...", "lastName": "..."},
    {"creatorType": "editor", "firstName": "...", "lastName": "..."}
  ],
  "bookTitle": "Book title",
  "date": "YYYY",
  "publisher": "...",
  "place": "...",
  "pages": "100-150",
  "ISBN": "978-..."
}
```

### `thesis`

```json
{
  "itemType": "thesis",
  "title": "...",
  "creators": [{"creatorType": "author", ...}],
  "date": "YYYY",
  "thesisType": "PhD Thesis",
  "university": "...",
  "place": "..."
}
```

### `report`

```json
{
  "itemType": "report",
  "title": "...",
  "creators": [...],
  "date": "YYYY",
  "reportNumber": "TR-2025-001",
  "reportType": "Technical Report",
  "institution": "..."
}
```

### `webpage` / `blogPost`

```json
{
  "itemType": "webpage",
  "title": "...",
  "creators": [...],
  "date": "YYYY-MM-DD",
  "websiteTitle": "Site name",
  "websiteType": "Blog post or null",
  "url": "https://...",
  "accessDate": "YYYY-MM-DD"
}
```

For `blogPost` swap `websiteTitle` -> `blogTitle`.

### `software`

```json
{
  "itemType": "software",
  "title": "Project name",
  "creators": [{"creatorType": "programmer", ...}],
  "date": "YYYY-MM-DD",
  "versionNumber": "1.2.3",
  "url": "https://github.com/..."
}
```

### `dataset`

```json
{
  "itemType": "dataset",
  "title": "...",
  "creators": [{"creatorType": "author", ...}],
  "date": "YYYY-MM-DD",
  "repository": "Hugging Face / Zenodo / ...",
  "DOI": "10.5281/zenodo.... or null",
  "url": "..."
}
```

## Universal Optional Fields

Available on every item type. Use them for cross-cutting metadata.

| Field | Use |
|-------|-----|
| `tags` | Array of `{"tag": "...", "type": 0}` (or just strings, server normalizes). `type=1` = automatic tag, `type=0` (default) = manual. |
| `collections` | Array of collection keys this item belongs to. Set at create-time or via PATCH; cannot reference paths directly via API (resolve first). |
| `relations` | Free-form linked-data relations. Rarely set programmatically. |
| `extra` | Free-text catch-all. See `preprint` example above for conventions. |
| `accessDate` | ISO date when the URL was last verified. |
| `url` | Canonical web URL. |
| `language` | Two-letter ISO 639-1 code or full name. |
| `rights` | License or copyright statement. |
| `archive` | Repository name (preprints, datasets). |
| `archiveLocation` | ID inside the repository. |
| `libraryCatalog` | Where the item was found (auto-populated by Zotero connectors). |

## Creators

Every author/editor/translator/programmer is a `creator` object. Two valid forms:

```json
// Two-field form (preferred for personal names)
{"creatorType": "author", "firstName": "Yann", "lastName": "LeCun"}

// Single-field form (for organizations or single-token names)
{"creatorType": "author", "name": "Google DeepMind"}
```

The `creatorType` is constrained per `itemType`. Common types:

| itemType | Allowed creatorType (subset) |
|----------|-----------------------------|
| `journalArticle` | author, contributor, editor, reviewedAuthor, translator |
| `conferencePaper` | author, contributor, editor, seriesEditor |
| `book` | author, contributor, editor, translator |
| `bookSection` | author, contributor, editor, bookAuthor, translator |
| `thesis` | author, contributor |
| `software` | programmer, contributor |

Full per-type allowed creator types: `curl https://api.zotero.org/itemTypeCreatorTypes?itemType=journalArticle`.

## Date Formats

Zotero accepts the field as free text and parses internally. Use one of:

- `YYYY-MM-DD` - full date (preferred when known)
- `YYYY-MM` - month + year
- `YYYY` - year only
- `Month YYYY` - human form, parsed but normalized internally
- `YYYY/MM/DD` - also accepted

Empty string is acceptable but causes "n.d." to render in citations. Never use formats Zotero cannot parse (e.g. `Q1 2024`); store such values in `extra` instead.

## Identifiers

Zotero recognizes these identifier fields at the item level:

| Field | Format | Example |
|-------|--------|---------|
| `DOI` | `10.<prefix>/<suffix>` (no `doi:` prefix, no URL) | `10.1038/s41586-021-03819-2` |
| `ISBN` | `978-...` or `0-...`, dashes optional | `978-0-262-03561-3` |
| `ISSN` | `XXXX-XXXX` | `0028-0836` |
| `archiveID` | Repository-specific id | `2401.12345` (arXiv) |
| `extra` | Free text, see preprint example | `arXiv:2401.12345 [cs.LG]\nPMID: 1234567` |

The Zotero `q=` search does NOT index DOI / ISBN / archiveID. To find items by these, use `find` (this skill) or scan via `list-items` and match locally.

## Tags

Tag value is any string. The Zotero client treats tags as case-sensitive. Conventions seen in larger libraries:

- `kebab-case` for procedural / automation tags (`survey-2025`, `to-review`, `auto-imported`).
- `Title Case` or `Sentence case` for topic tags (`Diffusion Models`, `Reinforcement learning`).
- Skill-specific tag namespaces (`literature-review-no-pdf`, `literature-review-unverified-metadata`) are owned by their skill - leave them alone unless explicitly asked.

For complex tag queries via `--tag`:

- AND: `tag1 && tag2`
- OR: `tag1 || tag2`
- NOT: `-tag1`
- Combinations: `survey-2025 && -to-review`

(The `&&`/`||`/`-` operators are Zotero API syntax, not shell - quote them.)

## Notes (HTML)

Zotero notes are HTML. Allowed tags include `p`, `strong`, `em`, `ul`, `ol`, `li`, `a`, `br`, `img` (with limits), `span`, `div`, `h1`-`h6`, `blockquote`, `code`, `pre`. Disallowed/stripped: `script`, `style`, `iframe`, raw event handlers.

Common patterns:

```html
<!-- Single paragraph -->
<p>One-line summary.</p>

<!-- Structured note -->
<h2>Contribution</h2>
<p>Proposes X.</p>
<h2>Method</h2>
<ul><li>Step 1</li><li>Step 2</li></ul>
<h2>Limitations</h2>
<p>Author-acknowledged: requires GPU cluster.</p>

<!-- Code reference -->
<p>See <a href="https://github.com/foo/bar">repo</a>.</p>
<pre><code>def foo(): pass</code></pre>
```

The `--md` flag in `add-note` does paragraph splitting only. Anything more complex (lists, headings, code blocks) requires `--html` with hand-built or pre-rendered HTML.

## Attachments

Attachments are first-class items with `itemType: "attachment"`. Required fields:

```json
{
  "itemType": "attachment",
  "linkMode": "imported_file",       // or "linked_file", "imported_url", "linked_url"
  "parentItem": "PARENT_KEY",
  "title": "filename.pdf",
  "filename": "filename.pdf",
  "contentType": "application/pdf",
  "charset": "",
  "md5": "...",                       // hex string, hybrid mode only
  "mtime": 1234567890000              // milliseconds, hybrid mode only
}
```

`linkMode` semantics:

- `imported_file` - file lives in `storage/<key>/`. Used by both hybrid and upload modes. Standard PDF attachment.
- `linked_file` - file lives elsewhere, Zotero stores only the path. Not portable across machines.
- `imported_url` - Zotero downloaded the URL on save. Used by web connectors.
- `linked_url` - bookmark only.

The `attach-pdf` subcommand always creates `imported_file` attachments. For `linked_file` (bookmark-only attachments) build the JSON yourself and POST via `create-item`:

```json
{
  "itemType": "attachment",
  "linkMode": "linked_url",
  "parentItem": "PARENT_KEY",
  "title": "Project page",
  "url": "https://..."
}
```

## Pagination

The Zotero API caps responses at 100 items per page. `_paginate` in `zotero_api.py` walks all pages transparently. For very large libraries (10000+ items), iterate by collection or filter via `since=<version>` to incremental-sync.

CLI commands that page automatically:

- `list-collections`, `list-items`, `list-tags`

CLI commands that DO NOT page (single API call):

- `list-attachments`, `list-notes`, `find`, `get-item`

## Versioning and Concurrency

Zotero uses optimistic concurrency via `If-Unmodified-Since-Version`. Every read returns a `Last-Modified-Version` header (per-item) and `Zotero-Last-Modified-Version` (library-wide). Writes that include the wrong version get HTTP 412.

`zotero_api.py` handles this automatically: PATCH/DELETE operations re-read the item to get the current version before sending. Concurrent edits from the Zotero client (or another script) trigger an automatic retry with the fresh version.

For batch writes, send the `Zotero-Write-Token` header to make POSTs idempotent. The current script does not - it relies on `find_by_identifier` to avoid double-creates. If you build automation that creates many items in tight loops, add the token to avoid duplicate items on retry.

## Rate Limits and Errors

| HTTP | Meaning | Operator behavior |
|------|---------|-------------------|
| 200/201 | Success | parsed JSON returned |
| 204 | Success, no content (DELETE) | empty payload |
| 304 | Not Modified (rare on writes) | passes through |
| 400 | Bad request - usually a malformed payload field | `RuntimeError` raised; inspect message |
| 403 | API key lacks the requested permission | `RuntimeError`; check key scopes at <https://www.zotero.org/settings/keys> |
| 404 | Library/item/collection not found | `RuntimeError` |
| 409 | Conflict (creating a name twice) | `RuntimeError` |
| 412 | Version mismatch (concurrent edit) | retried internally with fresh version |
| 413 | Payload too large (rare) | `RuntimeError` |
| 429 | Rate limit | sleeps `Retry-After` seconds, retries |
| 500-504 | Transient server error | retried up to 4 times with backoff |

Zotero's standard rate limit is generous (around 120 req/min for API users). The script throttles to `0.4 s` minimum between requests by default to stay well below it.

For long-running bulk operations, set `MIN_INTERVAL_SEC` higher in `zotero_api.py` if you see 429s, or add `Backoff` header logic to slow down dynamically. The default is conservative enough for typical interactive sessions.
