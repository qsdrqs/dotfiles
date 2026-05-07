# End-to-End Workflows

Longer recipes that build on the SKILL.md quick start. Each section is a runnable example. All commands assume `ZOTERO_API_KEY` and `ZOTERO_USER_ID` are exported.

## Table of Contents

- [Bulk Import from JSONL](#bulk-import-from-jsonl)
- [Find Items Missing PDFs](#find-items-missing-pdfs)
- [Move Items Between Collections](#move-items-between-collections)
- [Rename a Tag Across the Library](#rename-a-tag-across-the-library)
- [Backfill PDFs to Existing Items](#backfill-pdfs-to-existing-items)
- [Mirror a Collection Tree](#mirror-a-collection-tree)
- [Switch to a Group Library](#switch-to-a-group-library)
- [Handle Concurrent Edits Gracefully](#handle-concurrent-edits-gracefully)
- [Resume an Interrupted Bulk Operation](#resume-an-interrupted-bulk-operation)

## Bulk Import from JSONL

Common scenario: you have a `papers.jsonl` produced by some upstream pipeline, one Zotero-formed item per line.

```bash
SCRIPT=/home/qsdrqs/dotfiles/opencode/skills/zotero-operator/scripts/zotero_api.py
COLLECTION="Project/2025-Q2/Imports"

# Resolve the collection once (auto-creates).
COLL_KEY=$(python "$SCRIPT" resolve-collection --path "$COLLECTION" \
           | python -c "import json,sys; print(json.load(sys.stdin)['key'])")

# Import each line, skipping items that already exist by DOI/arXiv.
while IFS= read -r line; do
    DOI=$(echo "$line" | python -c "import json,sys;d=json.load(sys.stdin);print(d.get('DOI') or d.get('doi') or '')")
    ARXIV=$(echo "$line" | python -c "import json,sys;d=json.load(sys.stdin);x=d.get('archiveID') or '';e=d.get('extra') or '';print(x or (e.split('arXiv:')[1].split()[0] if 'arXiv:' in e else ''))")
    TITLE=$(echo "$line" | python -c "import json,sys;print(json.load(sys.stdin).get('title','')[:60])")

    # Idempotency check.
    HITS=$(python "$SCRIPT" find ${DOI:+--doi "$DOI"} ${ARXIV:+--arxiv "$ARXIV"} ${TITLE:+--title-hint "$TITLE"})
    if [ "$(echo "$HITS" | python -c 'import json,sys;print(len(json.load(sys.stdin)))')" -gt 0 ]; then
        echo "[skip] already in library: $TITLE" >&2
        continue
    fi

    echo "$line" > /tmp/zotero_meta.json
    python "$SCRIPT" create-item --meta /tmp/zotero_meta.json --collection "$COLL_KEY"
done < papers.jsonl
```

For a faster version, use the importable module to avoid Python-startup overhead per item:

```python
import json
import sys
sys.path.insert(0, "/home/qsdrqs/dotfiles/opencode/skills/zotero-operator/scripts")
from zotero_api import resolve_collection, find_by_identifier, create_item

coll = resolve_collection("Project/2025-Q2/Imports")
with open("papers.jsonl") as f:
    for line in f:
        meta = json.loads(line)
        doi = meta.get("DOI") or meta.get("doi")
        arxiv = meta.get("archiveID")
        if find_by_identifier(doi=doi, arxiv=arxiv, title_hint=meta.get("title")):
            print(f"[skip] {meta.get('title')!r}", file=sys.stderr)
            continue
        result = create_item(meta, collection_key=coll["key"])
        print(f"[ok] {result['key']} {meta.get('title')!r}")
```

## Find Items Missing PDFs

Identify top-level items in a collection that have no PDF attachment yet, so you can backfill them.

```python
import sys
sys.path.insert(0, "/home/qsdrqs/dotfiles/opencode/skills/zotero-operator/scripts")
from zotero_api import resolve_collection, list_items, list_attachments

coll = resolve_collection("Research/RAG/Survey", create_missing=False)
items = list_items(collection_key=coll["key"], top_only=True)

missing = []
for it in items:
    attaches = list_attachments(it["key"], content_type="application/pdf")
    if not attaches:
        missing.append({"key": it["key"], "title": it["data"].get("title", ""),
                        "doi": it["data"].get("DOI"),
                        "url": it["data"].get("url")})

print(f"{len(missing)} of {len(items)} items missing a PDF:")
for m in missing:
    print(f"  {m['key']}  {m['title'][:60]}")
```

If you tag missing-PDF items, you can also use `find-by-tag` once and skip the per-item attachment check:

```bash
python "$SCRIPT" find-by-tag --tag "literature-review-no-pdf"
```

(That specific tag is set by the `literature-review` skill. For your own automation, pick a tag in your own namespace.)

## Move Items Between Collections

Move every item from `Old/Path` to `New/Path`. Both must exist.

```python
import sys
sys.path.insert(0, "/home/qsdrqs/dotfiles/opencode/skills/zotero-operator/scripts")
from zotero_api import resolve_collection, list_items, add_to_collection, remove_from_collection

src = resolve_collection("Old/Path", create_missing=False)
dst = resolve_collection("New/Path")  # auto-creates if needed

items = list_items(collection_key=src["key"], top_only=True)
for it in items:
    add_to_collection(it["key"], dst["key"])
    remove_from_collection(it["key"], src["key"])
    print(f"moved {it['key']}: {it['data'].get('title','')[:60]}")
```

To copy (link into both collections without removing from the source) drop the `remove_from_collection` call. Zotero items can belong to any number of collections - linking is cheap.

## Rename a Tag Across the Library

Zotero has no native rename-tag API. Implement it as add-then-remove on every item carrying the old tag.

```python
import sys
sys.path.insert(0, "/home/qsdrqs/dotfiles/opencode/skills/zotero-operator/scripts")
from zotero_api import find_by_tag, add_tag, remove_tag

OLD = "to-review"
NEW = "queue/to-review"

items = find_by_tag(OLD)
print(f"{len(items)} items carry tag {OLD!r}")
for it in items:
    add_tag(it["key"], NEW)
    remove_tag(it["key"], OLD)
    print(f"  retagged {it['key']}: {it['data'].get('title','')[:60]}")
```

After the loop the old tag still exists library-wide if it was applied to deleted items or as an automatic tag. Clean it up via the Zotero client UI (Tools > Manage Tags) or by calling `DELETE /tags?tag=...` directly via `_request`.

## Backfill PDFs to Existing Items

Given a list of `(item_key, pdf_path)` pairs, attach each PDF and remove the missing-PDF marker tag if present.

```python
import os
import sys
sys.path.insert(0, "/home/qsdrqs/dotfiles/opencode/skills/zotero-operator/scripts")
from zotero_api import attach_pdf_hybrid, list_attachments, remove_tag

backfill = [
    ("ABCD1234", "/tmp/papers/2401.12345.pdf"),
    ("EFGH5678", "/tmp/papers/10.1038_s41586-021-03819-2.pdf"),
]

for item_key, pdf_path in backfill:
    if not os.path.isfile(pdf_path):
        print(f"[skip] missing file {pdf_path}", file=sys.stderr)
        continue
    if list_attachments(item_key, content_type="application/pdf"):
        print(f"[skip] {item_key} already has a PDF", file=sys.stderr)
        continue
    result = attach_pdf_hybrid(item_key, pdf_path)
    remove_tag(item_key, "literature-review-no-pdf")  # idempotent
    print(f"[ok] {item_key} <- {os.path.basename(pdf_path)} "
          f"({result['bytes']} bytes)")
```

## Mirror a Collection Tree

Build the same nested collection structure under a different parent. Useful when starting a new project from a template.

```python
import sys
sys.path.insert(0, "/home/qsdrqs/dotfiles/opencode/skills/zotero-operator/scripts")
from zotero_api import list_all_collections, create_collection

src_top = "Templates/ProjectTemplate"
dst_top = "Projects/2025-Q3"

all_cols = list_all_collections()
by_key = {c["key"]: c for c in all_cols}

def path_of(c):
    parts = []
    cur = c
    while cur:
        parts.append(cur["data"]["name"])
        parent = (cur["data"].get("parentCollection") or "")
        cur = by_key.get(parent)
    return "/".join(reversed(parts))

src_paths = [path_of(c) for c in all_cols if path_of(c).startswith(src_top + "/")]
print(f"mirroring {len(src_paths)} child collections")

# Use resolve_collection on the destination paths to auto-create.
from zotero_api import resolve_collection
for p in sorted(src_paths):
    new_path = p.replace(src_top, dst_top, 1)
    resolve_collection(new_path)
    print(f"  {new_path}")
```

This mirrors structure only - items in the source are not copied. Add `add_to_collection` calls if you want to link items too.

## Switch to a Group Library

Group libraries use a different API path (`/groups/<id>/` instead of `/users/<id>/`). The script reads `ZOTERO_LIBRARY_TYPE` and `ZOTERO_LIBRARY_ID` at module-load time.

```bash
# Personal library (default)
unset ZOTERO_LIBRARY_TYPE ZOTERO_LIBRARY_ID
export ZOTERO_USER_ID="1234567"

# Group library (e.g. lab shared library)
export ZOTERO_LIBRARY_TYPE="groups"
export ZOTERO_LIBRARY_ID="987654"
# ZOTERO_USER_ID remains your personal id but is unused for group ops.

# Verify which library you're hitting
python "$SCRIPT" library-info
# {"library_type": "groups", "library_id": "987654", ...}
```

The API key must have group-write access (`Allow group access` ticked at key creation time, or edit-access granted in the group's member admin panel). `library-info` shows the access scope:

```json
{
  "key_info": {
    "access": {
      "groups": {
        "987654": {"library": true, "write": true}
      }
    }
  }
}
```

If `write: false` here, attempting any modification will return HTTP 403.

## Handle Concurrent Edits Gracefully

When the user edits an item in the Zotero client at the same time your script PATCHes it, the API returns 412 (Precondition Failed). The script retries automatically by re-reading the item to refresh the version. For multi-step workflows where you want to know if a conflict happened, wrap the operation:

```python
from zotero_api import update_item, get_item

def patch_with_diff_check(item_key, expected_field, expected_value, patch):
    """Only PATCH if the field still has its expected pre-edit value."""
    current = get_item(item_key)
    if current["data"].get(expected_field) != expected_value:
        return {"key": item_key, "skipped": True,
                "reason": "field changed since last read"}
    return update_item(item_key, patch)
```

For truly atomic operations (e.g. read-modify-write of `tags`), the underlying script already uses `If-Unmodified-Since-Version`. If you see 412 surfacing despite that, the item was edited between your `get_item` and the PATCH within milliseconds. Retry once.

## Resume an Interrupted Bulk Operation

For long-running imports, log every successful operation to a checkpoint file so you can re-run without re-doing work.

```python
import json
import os
import sys
sys.path.insert(0, "/home/qsdrqs/dotfiles/opencode/skills/zotero-operator/scripts")
from zotero_api import resolve_collection, find_by_identifier, create_item

CHECKPOINT = "/tmp/zotero_import_checkpoint.jsonl"
done_keys = set()
if os.path.isfile(CHECKPOINT):
    with open(CHECKPOINT) as f:
        for line in f:
            done_keys.add(json.loads(line)["source_key"])

coll = resolve_collection("Imports/2025")
with open("papers.jsonl") as f, open(CHECKPOINT, "a") as ck:
    for line in f:
        meta = json.loads(line)
        src_key = meta.get("source_key") or meta.get("DOI") or meta.get("title")
        if src_key in done_keys:
            continue
        if find_by_identifier(doi=meta.get("DOI"),
                              arxiv=meta.get("archiveID"),
                              title_hint=meta.get("title")):
            ck.write(json.dumps({"source_key": src_key,
                                 "status": "already_existed"}) + "\n")
            continue
        result = create_item(meta, collection_key=coll["key"])
        ck.write(json.dumps({"source_key": src_key,
                             "status": "created",
                             "zotero_key": result["key"]}) + "\n")
        ck.flush()
```

The `ck.flush()` after every line is important: Python's default line buffering does NOT flush on newline when stdout is a pipe vs a terminal, so explicit flush keeps the checkpoint usable after kill -9.
