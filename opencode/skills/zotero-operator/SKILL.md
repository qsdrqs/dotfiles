---
name: zotero-operator
description: "Direct Zotero Web API operations on a personal or group library: CRUD on items / collections / notes / tags, PDF attachments via either hybrid local-file mode or standard 3-step S3 upload, identifier-based item lookup, and bulk tagging. Use when the user asks to add items / import / create / update / delete / move / tag / search / attach files in Zotero programmatically (e.g. 'add to zotero', 'create zotero collection', 'attach PDF to zotero', 'tag items in zotero', 'manage zotero library', '操作 zotero', 'zotero 库'). Does NOT resolve bibliographic metadata from arXiv / CrossRef / Semantic Scholar / OpenReview - hand the script already-formed Zotero JSON via --meta. For bibliography-aware paper import workflows use the literature-review skill instead."
---

# Zotero Operator

Direct, scriptable access to a Zotero library through the Zotero Web API. The skill is a thin layer over `scripts/zotero_api.py`, a stdlib-only Python module that exposes all CRUD operations both as importable functions and as a CLI.

## When to use

- "Add this paper to my Zotero `AI/RAG` collection."
- "Move all items tagged `to-read` to a new `Reading Queue` collection."
- "Attach this PDF to Zotero item ABC12345."
- "Find every Zotero item that has DOI 10.1038/...".
- "Create a nested collection structure for my new project."
- "Replace the note on this Zotero item with this updated summary."
- "Bulk add the tag `survey-2025` to these 12 item keys."
- Any task whose primary action is talking to `api.zotero.org`.

## When NOT to use

- **Bibliographic resolution** ("look up arXiv:2401.12345 and import"): use the `literature-review` skill. It owns the arXiv/CrossRef/Semantic Scholar/OpenReview cascade plus venue normalization. This skill takes already-formed Zotero JSON.
- **Reading the Zotero UI**: the desktop client and connectors are usually faster.
- **BibTeX/CSL export of an existing library**: the Zotero client has native export.
- **Modifying the Zotero application itself** (preferences, plugins): out of scope.

## Setup

### 1. API credentials (one-time)

Get a personal API key at <https://www.zotero.org/settings/keys>. Pick:

- `Allow library access` + `Allow write access` for personal libraries
- For group libraries: also `Allow group access` for the relevant group(s)

Note your numeric `userID` from the same page (NOT the username).

```bash
export ZOTERO_API_KEY="P9Xxxxxxxxxxxxxxxxxxxxxx"
export ZOTERO_USER_ID="1234567"

# Group library (optional)
export ZOTERO_LIBRARY_TYPE="groups"
export ZOTERO_LIBRARY_ID="987654"
```

When `ZOTERO_LIBRARY_TYPE` is unset or `users`, calls hit `/users/<id>/...`. When `groups`, calls hit `/groups/<id>/...` and `ZOTERO_LIBRARY_ID` is mandatory.

### 2. Zotero client file-sync setting (only matters for `attach-pdf`)

`scripts/zotero_api.py attach-pdf` defaults to `--mode hybrid`: it writes the PDF into your local `$ZOTERO_DATA_DIR/storage/<key>/` directory with matching md5+mtime, and the Zotero client picks it up locally without contacting Zotero file storage. This requires:

- **Edit > Preferences > Sync > File Syncing > "My Library"** = `Off` or `WebDAV`. Do NOT use `Zotero` here, or the client will try to re-upload your local file.
- A third-party file-sync tool (Syncthing, rsync, WebDAV) replicates `storage/` across machines.
- Override the data dir with `ZOTERO_DATA_DIR` (default `~/Zotero`). It may point at the full data dir (with `zotero.sqlite` + `storage/`) or directly at the `storage/` folder.

Use `--mode upload` if your client uses Zotero's own file storage. The script then runs the standard 3-step S3 upload flow (claim -> upload -> register). Hybrid is preferred when usable because it sidesteps Zotero storage quotas and the `{"exists": 1}` deduplication corner cases.

### 3. Verify

```bash
python scripts/zotero_api.py library-info
```

Returns library type/id/version + key permissions. If this fails with `ERROR: set ZOTERO_API_KEY`, the env vars are not exported into the shell that ran the command.

## Workflow Decision Tree

```
User wants to ...                              Use this command
-----------------                              ----------------
"add this paper" (already have Zotero JSON) -> create-item --meta meta.json --collection "Path/X"
"add this paper" (have only DOI/arxiv id)   -> hand off to literature-review (bibliography resolution)
"is this paper already in my library?"      -> find --doi/--arxiv/--isbn --title-hint "..."
"organize into nested collection"           -> resolve-collection --path "AI/Diffusion/2024" (auto-create)
"move item between collections"             -> add-to-collection + remove-from-collection
"attach a PDF I downloaded"                 -> attach-pdf --parent KEY --pdf path/to/x.pdf
"add or remove a tag"                       -> add-tag / remove-tag
"find all items with this tag"              -> find-by-tag --tag "..."
"replace the note on item X"                -> list-notes --parent X, then update-note --key NOTE_KEY
"see what's in collection Y"                -> list-items --collection "Y" --top
"build my own automation"                   -> import zotero_api as a Python module (see below)
```

## Quick Start: Five Common Recipes

### A. Create a paper item from already-formed metadata

```bash
cat > /tmp/paper.json <<'EOF'
{
  "itemType": "journalArticle",
  "title": "Highly Accurate Protein Structure Prediction with AlphaFold",
  "creators": [
    {"creatorType": "author", "firstName": "John", "lastName": "Jumper"}
  ],
  "date": "2021-08-26",
  "publicationTitle": "Nature",
  "DOI": "10.1038/s41586-021-03819-2",
  "url": "https://doi.org/10.1038/s41586-021-03819-2",
  "abstractNote": "..."
}
EOF

python scripts/zotero_api.py create-item \
    --meta /tmp/paper.json \
    --collection "AI/Bio/AlphaFold"
```

The `--collection` argument accepts either a path (auto-created) or a raw 8-char collection key. See `references/api-reference.md` for required fields per item type.

### B. Idempotent import (skip if already in library)

```bash
python scripts/zotero_api.py find \
    --doi 10.1038/s41586-021-03819-2 \
    --title-hint "AlphaFold protein structure prediction" \
  | python -c "import json,sys; sys.exit(0 if json.load(sys.stdin) else 1)" \
  || python scripts/zotero_api.py create-item --meta /tmp/paper.json --collection "AI/Bio"
```

`find` matches DOI/arXiv/ISBN client-side because Zotero's `q=` does not index those fields. Always pass `--title-hint` to keep the candidate set small (50 items via `qmode=titleCreatorYear`); otherwise `find` falls back to scanning the 100 most-recent items.

### C. Attach a PDF to an existing item

```bash
ITEM_KEY=$(python scripts/zotero_api.py find --doi 10.x/y --title-hint "Foo" \
           | python -c "import json,sys; print(json.load(sys.stdin)[0]['key'])")

python scripts/zotero_api.py attach-pdf \
    --parent "$ITEM_KEY" \
    --pdf /tmp/foo.pdf \
    --mode hybrid
```

Returns `{attach_key, local_path, md5, bytes}`. The Zotero client picks up the new attachment on its next sync; the file is read locally because md5 matches.

### D. Bulk-tag items returned by a search

```bash
python scripts/zotero_api.py list-items --tag "to-review" --top --limit 50 \
  | python -c "
import json, subprocess, sys
script = '/home/qsdrqs/dotfiles/opencode/skills/zotero-operator/scripts/zotero_api.py'
for it in json.load(sys.stdin):
    subprocess.run([sys.executable, script, 'add-tag',
                    '--item', it['key'], '--tag', 'survey-2025'], check=True)
"
```

For larger bulk operations, importing `zotero_api` as a module (Recipe E) is faster - it avoids the Python startup cost per item.

### E. Use as an importable Python module

```python
import sys
sys.path.insert(0, "/home/qsdrqs/dotfiles/opencode/skills/zotero-operator/scripts")

from zotero_api import (
    resolve_collection, find_by_identifier, create_item,
    attach_pdf_hybrid, add_note, add_tag, list_items,
)

coll = resolve_collection("Project/2025-Q2")
hits = find_by_identifier(arxiv="2401.12345", title_hint="Foo bar")
if not hits:
    item = create_item(my_zotero_json, collection_key=coll["key"])
    add_tag(item["key"], "auto-imported")
    attach_pdf_hybrid(item["key"], "/tmp/foo.pdf")
    add_note(item["key"], "<p>One-line summary here.</p>")
```

All public functions are documented inline (`pydoc zotero_api`). Errors raise `RuntimeError` with the offending HTTP status and body; no silent fallbacks.

## Common Operations Reference

### Collections

```bash
python scripts/zotero_api.py list-collections [--top|--parent KEY]
python scripts/zotero_api.py resolve-collection --path "A/B/C" [--no-create]
python scripts/zotero_api.py create-collection --name "X" [--parent KEY]
python scripts/zotero_api.py rename-collection --key KEY --name "Y"
python scripts/zotero_api.py delete-collection --key KEY
```

`resolve-collection` walks a slash-separated path and auto-creates missing nodes. Path matching is case-sensitive. `delete-collection` removes the collection node only - items inside survive (they just lose the collection link).

### Items

```bash
python scripts/zotero_api.py create-item --meta meta.json [--collection PATH_OR_KEY]
python scripts/zotero_api.py get-item --key KEY
python scripts/zotero_api.py update-item --key KEY --meta patch.json
python scripts/zotero_api.py delete-item --key KEY                  # -> trash
python scripts/zotero_api.py list-items [--collection PATH_OR_KEY] \
    [--tag T] [--q QUERY] [--qmode titleCreatorYear|everything] \
    [--item-type IT] [--top] [--limit N]
python scripts/zotero_api.py find --doi D | --arxiv A | --isbn I [--title-hint T]
python scripts/zotero_api.py add-to-collection --key K --collection PATH_OR_KEY
python scripts/zotero_api.py remove-from-collection --key K --collection PATH_OR_KEY
```

`update-item` does PATCH semantics: only fields named in `patch.json` are touched. The script automatically fetches the current `version` and sends `If-Unmodified-Since-Version` for optimistic concurrency.

### Attachments

```bash
python scripts/zotero_api.py attach-pdf --parent KEY --pdf PATH \
    [--mode hybrid|upload]                                          # default hybrid
python scripts/zotero_api.py list-attachments --parent KEY [--content-type TYPE]
python scripts/zotero_api.py delete-attachment --key KEY            # -> trash
```

### Notes

```bash
python scripts/zotero_api.py add-note --parent KEY (--html "..." | --md PATH)
python scripts/zotero_api.py update-note --key NOTE_KEY (--html "..." | --md PATH)
python scripts/zotero_api.py delete-note --key NOTE_KEY
python scripts/zotero_api.py list-notes --parent KEY
```

`--md` does a minimal Markdown-to-HTML conversion (paragraph splitting only). Pass `--html` directly for any non-trivial formatting. Zotero notes accept the standard rich-text HTML subset.

### Tags

```bash
python scripts/zotero_api.py add-tag --item KEY --tag T1 [--tag T2 ...]
python scripts/zotero_api.py remove-tag --item KEY --tag T1 [--tag T2 ...]
python scripts/zotero_api.py list-tags [--prefix STR] [--limit N]
python scripts/zotero_api.py find-by-tag --tag T [--limit N]
```

`add-tag`/`remove-tag` are idempotent. `find-by-tag` uses Zotero's `tag` filter syntax: `tag1 && tag2` for AND, `tag1 || tag2` for OR, `-tag1` for NOT (see Zotero docs for full syntax).

## Anti-Patterns

- **DO NOT** invoke this skill for bibliographic metadata resolution. Hand the script already-formed Zotero JSON via `--meta`. If the user asked you to "import this DOI/arxiv id", the right answer is to either (a) use the `literature-review` skill, which owns the resolver cascade, or (b) construct the metadata yourself from a verified source (cached arXiv API output, exported BibTeX) and pass it via `--meta`.
- **DO NOT** invent metadata fields. If `--meta` is built from LLM memory rather than a deterministic API parse, the resulting Zotero entry is unverifiable. Either verify against an authoritative source first or hand the task back to `literature-review`, whose `import-by-id` path uses subprocess-isolated API resolvers.
- **DO NOT** call `attach-pdf --mode hybrid` if the user's Zotero client `File Syncing` is set to `Zotero`. Use `--mode upload` instead, or instruct the user to flip the setting first.
- **DO NOT** assume `find` is exhaustive. Without `--title-hint`, the search only scans the 100 most-recent items. With a hint, it scans 50 hits from `q=titleCreatorYear`. For library-wide identifier audits, iterate via `list-items` and match locally.
- **DO NOT** edit `~/.config/opencode/skills/zotero-operator/`. That path is a symlink output. Real edits live under `/home/qsdrqs/dotfiles/opencode/skills/zotero-operator/`.

## Stop Conditions

- All requested item / collection / tag operations report `status: "successful"` or idempotent no-op.
- `find` confirmed no duplicate before `create-item`.
- For attachment work: the local file exists at `local_path` (hybrid) or the upload returned `uploaded: True` (upload mode).
- Any HTTP 4xx that is not 412 (concurrency) or 429 (rate limit) - inspect the error body and stop.

## Reference Material

- `references/api-reference.md` - item types, required fields per type, common metadata schemas.
- `references/workflows.md` - longer end-to-end recipes (bulk import, library reorganization, attachment backfill).

The script is also self-documenting: every public function in `scripts/zotero_api.py` has a docstring, and every subcommand exposes `--help`.
