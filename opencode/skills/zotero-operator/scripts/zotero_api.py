#!/usr/bin/env python3
"""
zotero_api.py - General-purpose Zotero Web API client.

Direct CRUD operations on a Zotero library. Intentionally limited to the
Zotero Web API surface; no external bibliography services (arXiv, CrossRef,
Semantic Scholar, OpenReview) are involved. Callers that need metadata
resolution should hand this script already-formed Zotero JSON via --meta.

Importable: every public function (resolve_collection, create_item, etc.)
is module-level and can be reused from another Python module:

    from zotero_api import resolve_collection, create_item, attach_pdf_hybrid

CLI dispatch lives in main(); importing the module does NOT execute it.

Subcommands (run with --help for full args):
    library-info
    list-collections [--parent KEY] [--top]
    resolve-collection --path "AI/RAG/Survey"
    create-collection --name X [--parent KEY]
    rename-collection --key K --name X
    delete-collection --key K
    create-item --meta meta.json [--collection PATH_OR_KEY]
    get-item --key K
    update-item --key K --meta patch.json
    delete-item --key K
    list-items [--collection PATH_OR_KEY] [--tag T] [--q Q] [--qmode M]
               [--item-type IT] [--limit N] [--top]
    find --doi D | --arxiv A | --isbn I [--title-hint T]
    add-to-collection --key K --collection PATH_OR_KEY
    remove-from-collection --key K --collection PATH_OR_KEY
    attach-pdf --parent K --pdf path/to/x.pdf [--mode hybrid|upload]
    list-attachments --parent K
    delete-attachment --key K
    add-note --parent K (--html H | --md path)
    update-note --key K (--html H | --md path)
    delete-note --key K
    list-notes --parent K
    add-tag --item K --tag T [--tag T2 ...]
    remove-tag --item K --tag T [--tag T2 ...]
    list-tags [--limit N] [--prefix P]
    find-by-tag --tag T [--limit N]

Environment (REQUIRED):
    ZOTERO_API_KEY    Personal API key from https://www.zotero.org/settings/keys
    ZOTERO_USER_ID    Numeric user ID (default LIBRARY_TYPE=users)

Environment (group libraries):
    ZOTERO_LIBRARY_TYPE   "users" (default) or "groups"
    ZOTERO_LIBRARY_ID     Numeric library id. For groups, the group id from
                          https://www.zotero.org/groups/<id>. For users,
                          defaults to ZOTERO_USER_ID.

Environment (optional):
    ZOTERO_API_BASE       default https://api.zotero.org
    ZOTERO_DATA_DIR       default ~/Zotero. Used by --mode hybrid PDF attach
                          to place files locally for third-party file sync
                          (Syncthing, rsync, WebDAV) instead of uploading
                          to Zotero's S3 storage. ZOTERO_DATA_DIR may point
                          at the full Zotero data directory (containing
                          zotero.sqlite + storage/) or directly at the
                          storage folder; both layouts are detected.
"""

import argparse
import hashlib
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


API_BASE = os.environ.get("ZOTERO_API_BASE", "https://api.zotero.org").rstrip("/")
API_KEY = os.environ.get("ZOTERO_API_KEY")
USER_ID = os.environ.get("ZOTERO_USER_ID")
LIBRARY_TYPE = os.environ.get("ZOTERO_LIBRARY_TYPE", "users").strip().lower()
if LIBRARY_TYPE == "users":
    LIBRARY_ID = os.environ.get("ZOTERO_LIBRARY_ID") or USER_ID
else:
    LIBRARY_ID = os.environ.get("ZOTERO_LIBRARY_ID")

USER_AGENT = "zotero-operator-skill/0.1"
MIN_INTERVAL_SEC = 0.4
_last_request_at = 0.0


def _need_creds():
    if not API_KEY:
        print("ERROR: set ZOTERO_API_KEY (https://www.zotero.org/settings/keys)",
              file=sys.stderr)
        sys.exit(2)
    if LIBRARY_TYPE not in ("users", "groups"):
        print(f"ERROR: ZOTERO_LIBRARY_TYPE must be 'users' or 'groups' "
              f"(got {LIBRARY_TYPE!r})", file=sys.stderr)
        sys.exit(2)
    if not LIBRARY_ID:
        if LIBRARY_TYPE == "groups":
            print("ERROR: set ZOTERO_LIBRARY_ID for group libraries",
                  file=sys.stderr)
        else:
            print("ERROR: set ZOTERO_USER_ID (or ZOTERO_LIBRARY_ID)",
                  file=sys.stderr)
        sys.exit(2)


def _throttle():
    global _last_request_at
    elapsed = time.monotonic() - _last_request_at
    if elapsed < MIN_INTERVAL_SEC:
        time.sleep(MIN_INTERVAL_SEC - elapsed)
    _last_request_at = time.monotonic()


def _headers(extra=None):
    h = {
        "User-Agent": USER_AGENT,
        "Zotero-API-Version": "3",
        "Zotero-API-Key": API_KEY,
    }
    if extra:
        h.update(extra)
    return h


def _request(method, path_or_url, *, params=None, body=None, headers=None,
             retries=4, raw_url=False, timeout=60):
    """Low-level Zotero API request with throttle, retry, and JSON handling.

    Returns (status_code, response_headers_dict, parsed_body).
    parsed_body is dict/list when Content-Type is JSON, raw bytes otherwise.
    """
    if raw_url:
        url = path_or_url
    else:
        url = f"{API_BASE}/{LIBRARY_TYPE}/{LIBRARY_ID}{path_or_url}"
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    if isinstance(body, (dict, list)):
        data = json.dumps(body).encode("utf-8")
    elif isinstance(body, str):
        data = body.encode("utf-8")
    else:
        data = body

    last_err = None
    for attempt in range(retries):
        _throttle()
        req = urllib.request.Request(url, data=data, method=method,
                                     headers=_headers(headers))
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                payload = resp.read()
                ctype = resp.headers.get("Content-Type", "")
                if "json" in ctype:
                    return resp.status, dict(resp.headers), \
                           json.loads(payload or b"null")
                return resp.status, dict(resp.headers), payload
        except urllib.error.HTTPError as e:
            err_body = e.read()
            if e.code == 429:
                retry_after = int(e.headers.get("Retry-After", "10"))
                time.sleep(retry_after)
                last_err = e
                continue
            if e.code in (500, 502, 503, 504):
                time.sleep(3 * (attempt + 1))
                last_err = e
                continue
            try:
                err_text = err_body.decode("utf-8")
            except Exception:
                err_text = "<binary>"
            raise RuntimeError(
                f"{method} {url} -> HTTP {e.code}: {err_text}"
            ) from e
        except urllib.error.URLError as e:
            last_err = e
            time.sleep(3 * (attempt + 1))
    raise RuntimeError(
        f"{method} {url} failed after {retries} attempts: {last_err}"
    )


def _paginate(path, params=None):
    """Yield items across paginated endpoints (limit=100, start=N)."""
    params = dict(params or {})
    params.setdefault("limit", 100)
    start = 0
    while True:
        params["start"] = start
        _, _, data = _request("GET", path, params=params)
        if not data:
            return
        for item in data:
            yield item
        if len(data) < params["limit"]:
            return
        start += params["limit"]


def library_info():
    """Return basic library info: type, id, version, key permissions."""
    _, _, key_info = _request(
        "GET", f"{API_BASE}/keys/current", raw_url=True,
    )
    _, headers, _ = _request("GET", "/items", params={"limit": 1})
    return {
        "library_type": LIBRARY_TYPE,
        "library_id": LIBRARY_ID,
        "library_version": int(headers.get("Last-Modified-Version", 0)),
        "key_info": key_info,
    }


def list_all_collections(parent_key=None, top_only=False):
    """List collections. If parent_key, list direct children of that node.
    If top_only, list only top-level collections."""
    if top_only:
        return list(_paginate("/collections/top"))
    if parent_key:
        return list(_paginate(f"/collections/{parent_key}/collections"))
    return list(_paginate("/collections"))


def resolve_collection(path, create_missing=True):
    """Resolve a slash-separated collection path to its key. Walks the parent
    chain, optionally auto-creating missing nodes (default True).

    Returns: {"key": "...", "path": "AI/RAG/Survey"}
    Raises:  ValueError on empty path, RuntimeError on API failure or when
             create_missing=False and a path segment is missing.
    """
    parts = [p.strip() for p in path.split("/") if p.strip()]
    if not parts:
        raise ValueError("empty collection path")
    all_cols = list_all_collections()

    parent_key = None
    found_key = None
    for name in parts:
        match = None
        for c in all_cols:
            d = c.get("data", {})
            if (d.get("name") == name
                    and (d.get("parentCollection") or None) == parent_key):
                match = c
                break
        if match is None:
            if not create_missing:
                raise RuntimeError(
                    f"collection segment '{name}' not found under "
                    f"parent_key={parent_key!r}"
                )
            payload = [{"name": name}]
            if parent_key:
                payload[0]["parentCollection"] = parent_key
            _, _, resp = _request("POST", "/collections", body=payload)
            if (not resp or "successful" not in resp
                    or "0" not in resp["successful"]):
                raise RuntimeError(
                    f"failed to create collection '{name}': {resp}"
                )
            new = resp["successful"]["0"]
            all_cols.append(new)
            match = new
        parent_key = match["key"]
        found_key = match["key"]
    return {"key": found_key, "path": "/".join(parts)}


def create_collection(name, parent_key=None):
    """Create a single collection. Returns the created collection record."""
    payload = [{"name": name}]
    if parent_key:
        payload[0]["parentCollection"] = parent_key
    _, _, resp = _request("POST", "/collections", body=payload)
    if not resp or "successful" not in resp or "0" not in resp["successful"]:
        raise RuntimeError(f"create_collection failed: {resp}")
    return resp["successful"]["0"]


def rename_collection(collection_key, new_name):
    """Rename a collection in place."""
    _, _, item = _request("GET", f"/collections/{collection_key}")
    version = item["data"]["version"]
    _request(
        "PATCH", f"/collections/{collection_key}",
        body={"name": new_name},
        headers={"If-Unmodified-Since-Version": str(version)},
    )
    return {"key": collection_key, "name": new_name}


def delete_collection(collection_key):
    """Delete a collection. Items inside the collection are NOT deleted; they
    only lose the collection link."""
    _, _, item = _request("GET", f"/collections/{collection_key}")
    version = item["data"]["version"]
    _request(
        "DELETE", f"/collections/{collection_key}",
        headers={"If-Unmodified-Since-Version": str(version)},
    )
    return {"key": collection_key, "deleted": True}


def _resolve_collection_arg(path_or_key):
    """Helper: accept either a collection key (8-char alnum) or a path.
    Returns the key. Auto-creates path segments when called with a path."""
    if not path_or_key:
        return None
    # Zotero collection keys are 8-char uppercase alphanumeric. Treat
    # anything matching that exact shape as a key; everything else is a path.
    s = path_or_key.strip()
    if len(s) == 8 and s.isalnum() and s.upper() == s:
        return s
    return resolve_collection(s)["key"]


# Fields the API rejects on POST /items because they are server-managed
# response-side scaffolding, not request-side payload fields.
_DROP_ON_CREATE = frozenset({
    "id", "key", "version", "attachments", "notes", "seeAlso",
    "library", "links", "meta",
})


def _normalize_create_payload(item):
    """Strip server-managed fields and empty values from an item payload
    before POST /items. Empty creators arrays are preserved (Zotero
    expects creators=[] for items with no authors)."""
    cleaned = {}
    for k, v in item.items():
        if k in _DROP_ON_CREATE:
            continue
        if v is None or v == "":
            continue
        if k != "creators" and v == []:
            continue
        cleaned[k] = v
    cleaned.setdefault("itemType", item.get("itemType", "journalArticle"))
    return cleaned


def create_item(item_data, collection_key=None):
    """Create a top-level item. item_data must be Zotero-formatted JSON
    (itemType + matching fields). If collection_key is set, the item is
    linked to that collection at creation time.

    Returns the created item record (data + key + version)."""
    payload = _normalize_create_payload(item_data)
    if collection_key:
        payload["collections"] = [collection_key]
    _, _, resp = _request("POST", "/items", body=[payload])
    if not resp or "successful" not in resp or "0" not in resp["successful"]:
        raise RuntimeError(f"create_item failed: {resp}")
    return resp["successful"]["0"]


def get_item(item_key):
    """Fetch full item record."""
    _, _, item = _request("GET", f"/items/{item_key}")
    return item


def update_item(item_key, patch):
    """PATCH an item. patch is a dict of fields to update; unspecified
    fields are preserved by Zotero. Uses If-Unmodified-Since-Version for
    optimistic concurrency."""
    _, _, item = _request("GET", f"/items/{item_key}")
    version = item["data"]["version"]
    _request(
        "PATCH", f"/items/{item_key}",
        body=patch,
        headers={"If-Unmodified-Since-Version": str(version)},
    )
    return {"key": item_key, "patched_fields": list(patch.keys())}


def delete_item(item_key):
    """Move an item to the Zotero trash (DELETE /items/<key> on Web API).
    To purge the trash, the user must empty it via the Zotero client UI."""
    _, _, item = _request("GET", f"/items/{item_key}")
    version = item["data"]["version"]
    _request(
        "DELETE", f"/items/{item_key}",
        headers={"If-Unmodified-Since-Version": str(version)},
    )
    return {"key": item_key, "deleted": True}


def list_items(collection_key=None, tag=None, q=None, qmode=None,
               item_type=None, limit=None, top_only=False):
    """List items with optional filters. Returns a list of item records.

    - collection_key: limit to a single collection
    - tag: limit to a single tag (use Zotero tag operators for unions)
    - q + qmode: full-text or titleCreatorYear search
    - item_type: e.g. 'journalArticle', 'preprint', '-attachment' to exclude
    - top_only: only top-level items (parent items, no notes/attachments)
    - limit: max items to return (None = all, paginated)
    """
    if top_only:
        path = f"/collections/{collection_key}/items/top" if collection_key \
            else "/items/top"
    else:
        path = f"/collections/{collection_key}/items" if collection_key \
            else "/items"

    params = {}
    if tag:
        params["tag"] = tag
    if q:
        params["q"] = q
    if qmode:
        params["qmode"] = qmode
    if item_type:
        params["itemType"] = item_type

    if limit is not None:
        params["limit"] = min(limit, 100)
        results = []
        for it in _paginate(path, params=params):
            results.append(it)
            if len(results) >= limit:
                break
        return results
    return list(_paginate(path, params=params))


def find_by_identifier(doi=None, arxiv=None, isbn=None, title_hint=None):
    """Find items in the library by identifier (DOI, arXiv id, ISBN).

    Zotero's q= search does NOT index DOI/arXiv/ISBN fields directly
    (it covers title/creator/notes/tags/fulltext). This function uses
    title_hint via q=titleCreatorYear to narrow candidates, then matches
    the identifier client-side against data.DOI / data.extra / data.url
    / data.ISBN. When title_hint is None, the 100 most recently added
    top-level items are scanned instead.

    Returns a list of matching item records (usually 0 or 1).
    """
    if not (doi or arxiv or isbn):
        return []
    candidates = []
    if title_hint:
        words = title_hint.split()[:6]
        q = " ".join(words)
        _, _, items = _request(
            "GET", "/items",
            params={"q": q, "qmode": "titleCreatorYear", "limit": 50},
        )
        candidates = items or []
    else:
        _, _, items = _request(
            "GET", "/items/top",
            params={"limit": 100, "sort": "dateAdded", "direction": "desc"},
        )
        candidates = items or []

    hits = []
    doi_norm = (doi or "").strip().lower() or None
    arxiv_norm = (arxiv or "").strip().lower() or None
    isbn_norm = (isbn or "").replace("-", "").strip().lower() or None
    for it in candidates:
        data = it.get("data") or {}
        if data.get("itemType") in ("attachment", "note"):
            continue
        if doi_norm and (data.get("DOI") or "").strip().lower() == doi_norm:
            hits.append(it)
            continue
        if arxiv_norm:
            extra = (data.get("extra") or "").lower()
            url = (data.get("url") or "").lower()
            if f"arxiv:{arxiv_norm}" in extra or arxiv_norm in url:
                hits.append(it)
                continue
        if isbn_norm:
            isbns = (data.get("ISBN") or "").replace("-", "").lower()
            if isbn_norm in isbns:
                hits.append(it)
    return hits


def add_to_collection(item_key, collection_key):
    """Link an existing item into a collection. Idempotent."""
    _, _, item = _request("GET", f"/items/{item_key}")
    data = item["data"]
    cols = list(data.get("collections") or [])
    if collection_key in cols:
        return {"key": item_key, "collections": cols, "changed": False}
    cols.append(collection_key)
    version = data["version"]
    _request(
        "PATCH", f"/items/{item_key}",
        body={"collections": cols},
        headers={"If-Unmodified-Since-Version": str(version)},
    )
    return {"key": item_key, "collections": cols, "changed": True}


def remove_from_collection(item_key, collection_key):
    """Remove an item from a collection. The item itself is not deleted."""
    _, _, item = _request("GET", f"/items/{item_key}")
    data = item["data"]
    cols = list(data.get("collections") or [])
    if collection_key not in cols:
        return {"key": item_key, "collections": cols, "changed": False}
    cols.remove(collection_key)
    version = data["version"]
    _request(
        "PATCH", f"/items/{item_key}",
        body={"collections": cols},
        headers={"If-Unmodified-Since-Version": str(version)},
    )
    return {"key": item_key, "collections": cols, "changed": True}


def _attachment_storage_dir(attach_key):
    """Resolve the local Zotero storage directory for a given attachment key.
    Honors ZOTERO_DATA_DIR; supports both the full data dir layout
    (containing storage/) and the storage-only layout."""
    data_dir = os.path.expanduser(os.environ.get("ZOTERO_DATA_DIR", "~/Zotero"))
    if os.path.isdir(os.path.join(data_dir, "storage")):
        storage_root = os.path.join(data_dir, "storage")
    else:
        storage_root = data_dir
    return os.path.join(storage_root, attach_key)


def attach_pdf_hybrid(parent_key, pdf_path):
    """Attach a PDF via the hybrid local+metadata mode.

    Metadata goes through api.zotero.org; the file itself is placed under
    $ZOTERO_DATA_DIR/storage/<attach_key>/<filename> with matching md5+mtime
    so the desktop client (sync mode set to Off or WebDAV) finds it locally
    instead of downloading from Zotero storage. A third-party file sync
    tool (Syncthing, rsync, WebDAV) must replicate storage/ across machines.

    Use this when your Zotero client setting Edit > Preferences > Sync >
    File Syncing > "My Library" is set to Off or WebDAV (NOT "Zotero").

    Returns: {"attach_key": "...", "local_path": "...", "md5": "...",
              "bytes": N}
    """
    filename = os.path.basename(pdf_path)
    with open(pdf_path, "rb") as f:
        content = f.read()
    md5 = hashlib.md5(content).hexdigest()
    mtime = int(os.path.getmtime(pdf_path) * 1000)

    attach_payload = {
        "itemType": "attachment",
        "linkMode": "imported_file",
        "parentItem": parent_key,
        "title": filename,
        "filename": filename,
        "contentType": "application/pdf",
        "charset": "",
        "md5": md5,
        "mtime": mtime,
    }
    _, _, resp = _request("POST", "/items", body=[attach_payload])
    if not resp or "successful" not in resp or "0" not in resp["successful"]:
        raise RuntimeError(f"create_attachment_item failed: {resp}")
    attach_key = resp["successful"]["0"]["key"]

    storage_dir = _attachment_storage_dir(attach_key)
    os.makedirs(storage_dir, exist_ok=True)
    dest = os.path.join(storage_dir, filename)
    with open(dest, "wb") as f:
        f.write(content)
    os.utime(dest, (mtime / 1000.0, mtime / 1000.0))
    return {
        "attach_key": attach_key,
        "local_path": dest,
        "md5": md5,
        "bytes": len(content),
    }


def attach_pdf_upload(parent_key, pdf_path):
    """Attach a PDF via Zotero's standard 3-step S3 file-upload flow.

    Use this when your Zotero client uses Zotero's own file storage
    (Edit > Preferences > Sync > File Syncing > "My Library" = "Zotero").
    The hybrid mode is preferred for setups using third-party file sync.

    Flow:
      1. POST /items - create attachment item (linkMode=imported_file)
      2. POST /items/<key>/file (md5/mtime/filename/filesize) - claim
         upload, response carries either {"exists": 1} or upload URL
      3. POST to upload URL with prefix+content+suffix wrapping
      4. POST /items/<key>/file with uploadKey to register

    Returns: {"attach_key": "...", "uploaded": bool, "md5": "...",
              "bytes": N}
    """
    filename = os.path.basename(pdf_path)
    with open(pdf_path, "rb") as f:
        content = f.read()
    md5 = hashlib.md5(content).hexdigest()
    mtime = int(os.path.getmtime(pdf_path) * 1000)
    filesize = len(content)

    # Step 1: create attachment item.
    attach_payload = {
        "itemType": "attachment",
        "linkMode": "imported_file",
        "parentItem": parent_key,
        "title": filename,
        "filename": filename,
        "contentType": "application/pdf",
        "charset": "",
    }
    _, _, resp = _request("POST", "/items", body=[attach_payload])
    if not resp or "successful" not in resp or "0" not in resp["successful"]:
        raise RuntimeError(f"create_attachment_item failed: {resp}")
    attach_item = resp["successful"]["0"]
    attach_key = attach_item["key"]
    attach_version = attach_item["data"]["version"]

    # Step 2: claim upload authorization.
    auth_body = urllib.parse.urlencode({
        "md5": md5,
        "filename": filename,
        "filesize": str(filesize),
        "mtime": str(mtime),
    })
    _, _, auth_resp = _request(
        "POST", f"/items/{attach_key}/file",
        body=auth_body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "If-None-Match": "*",
            "If-Unmodified-Since-Version": str(attach_version),
        },
    )
    if isinstance(auth_resp, bytes):
        auth_resp = json.loads(auth_resp or b"null")

    if auth_resp and auth_resp.get("exists") == 1:
        return {"attach_key": attach_key, "uploaded": False,
                "md5": md5, "bytes": filesize, "deduplicated": True}

    upload_url = auth_resp["url"]
    prefix = auth_resp["prefix"].encode("utf-8") \
        if isinstance(auth_resp["prefix"], str) else auth_resp["prefix"]
    suffix = auth_resp["suffix"].encode("utf-8") \
        if isinstance(auth_resp["suffix"], str) else auth_resp["suffix"]
    upload_key = auth_resp["uploadKey"]
    upload_ctype = auth_resp.get("contentType",
                                 "multipart/form-data; boundary=----")

    # Step 3: upload to S3-style URL.
    body = prefix + content + suffix
    req = urllib.request.Request(
        upload_url, data=body, method="POST",
        headers={"Content-Type": upload_ctype, "User-Agent": USER_AGENT},
    )
    _throttle()
    with urllib.request.urlopen(req, timeout=120) as upload_resp:
        if upload_resp.status not in (200, 201, 204):
            raise RuntimeError(
                f"S3 upload failed: HTTP {upload_resp.status}"
            )

    # Step 4: register the uploaded file.
    register_body = urllib.parse.urlencode({"upload": upload_key})
    _request(
        "POST", f"/items/{attach_key}/file",
        body=register_body,
        headers={
            "Content-Type": "application/x-www-form-urlencoded",
            "If-Unmodified-Since-Version": str(attach_version),
        },
    )
    return {"attach_key": attach_key, "uploaded": True,
            "md5": md5, "bytes": filesize}


def list_attachments(parent_key, content_type=None):
    """List child attachments of an item. Optionally filter by contentType
    (e.g. 'application/pdf' for PDF-only)."""
    _, _, children = _request("GET", f"/items/{parent_key}/children")
    children = children or []
    attachments = [
        c for c in children
        if (c.get("data") or {}).get("itemType") == "attachment"
    ]
    if content_type:
        attachments = [
            c for c in attachments
            if (c.get("data") or {}).get("contentType") == content_type
        ]
    return attachments


def delete_attachment(attach_key):
    """Delete an attachment item (moves it to Zotero trash)."""
    return delete_item(attach_key)


def add_note(parent_key, html):
    """Add a child note to an item. Note body is HTML."""
    payload = {"itemType": "note", "parentItem": parent_key, "note": html}
    _, _, resp = _request("POST", "/items", body=[payload])
    if not resp or "successful" not in resp or "0" not in resp["successful"]:
        raise RuntimeError(f"add_note failed: {resp}")
    return resp["successful"]["0"]


def update_note(note_key, html):
    """Replace the body of an existing note."""
    return update_item(note_key, {"note": html})


def delete_note(note_key):
    """Delete a note."""
    return delete_item(note_key)


def list_notes(parent_key):
    """List child notes of an item."""
    _, _, children = _request("GET", f"/items/{parent_key}/children")
    return [
        c for c in (children or [])
        if (c.get("data") or {}).get("itemType") == "note"
    ]


def add_tag(item_key, tag):
    """Add a tag to an item. Idempotent (no-op if tag already present)."""
    _, _, item = _request("GET", f"/items/{item_key}")
    data = item["data"]
    tags = list(data.get("tags") or [])
    if any(t.get("tag") == tag for t in tags):
        return False
    tags.append({"tag": tag})
    version = data["version"]
    _request(
        "PATCH", f"/items/{item_key}",
        body={"tags": tags},
        headers={"If-Unmodified-Since-Version": str(version)},
    )
    return True


def remove_tag(item_key, tag):
    """Remove a tag from an item. Idempotent."""
    _, _, item = _request("GET", f"/items/{item_key}")
    data = item["data"]
    tags = list(data.get("tags") or [])
    new_tags = [t for t in tags if t.get("tag") != tag]
    if len(new_tags) == len(tags):
        return False
    version = data["version"]
    _request(
        "PATCH", f"/items/{item_key}",
        body={"tags": new_tags},
        headers={"If-Unmodified-Since-Version": str(version)},
    )
    return True


def list_tags(prefix=None, limit=None):
    """List all tags in the library, with usage counts via numItems.
    Returns: [{"tag": "...", "type": 0/1, "numItems": N}, ...]"""
    params = {}
    if prefix:
        params["q"] = prefix
        params["qmode"] = "startsWith"
    items = _paginate("/tags", params=params)
    out = []
    for t in items:
        data = t.get("links") and t or t
        meta = t.get("meta") or {}
        out.append({
            "tag": t.get("tag") or (data.get("tag") if isinstance(data, dict)
                                    else None),
            "type": (t.get("type") if "type" in t else (meta.get("type"))),
            "numItems": meta.get("numItems"),
        })
        if limit is not None and len(out) >= limit:
            break
    return out


def find_by_tag(tag, limit=None, top_only=True):
    """Return items carrying the given tag. Multiple tags can be ANDed by
    passing 'tag1 && tag2'; see Zotero docs for tag operator syntax."""
    return list_items(tag=tag, limit=limit, top_only=top_only)


def names_to_creators(names, creator_type="author"):
    """Convert a list of full-name strings into Zotero creator dicts.
    'First Middle Last' -> {creatorType, firstName='First Middle', lastName='Last'}.
    Single-token names use the single-field 'name' form."""
    creators = []
    for name in (names or []):
        name = (name or "").strip()
        if not name:
            continue
        parts = name.rsplit(" ", 1)
        if len(parts) == 2:
            creators.append({"creatorType": creator_type,
                             "firstName": parts[0], "lastName": parts[1]})
        else:
            creators.append({"creatorType": creator_type, "name": name})
    return creators


def drop_empty(d):
    """Drop keys whose value is None, empty string, or empty list."""
    return {k: v for k, v in d.items() if v not in (None, "", [])}


def _print_json(obj):
    json.dump(obj, sys.stdout, indent=2, ensure_ascii=False, default=str)
    sys.stdout.write("\n")


def _load_meta(path):
    with open(path) as f:
        meta = json.load(f)
    if isinstance(meta, list):
        if not meta:
            print("ERROR: empty meta list", file=sys.stderr)
            sys.exit(2)
        meta = meta[0]
    return meta


def _read_note_body(args):
    if args.html:
        return args.html
    if args.md:
        with open(args.md) as f:
            md = f.read()
        # Minimal Markdown -> HTML for the simple cases Zotero notes need.
        # For complex Markdown, callers should pass --html with their own
        # rendering.
        return f"<p>{md}</p>" if "\n" not in md.strip() else \
               "<p>" + "</p><p>".join(p.strip() for p in md.split("\n\n")
                                      if p.strip()) + "</p>"
    raise ValueError("must supply --html or --md")


def _build_parser():
    p = argparse.ArgumentParser(prog="zotero_api.py",
                                description=(__doc__ or "").split("\n", 1)[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("library-info", help="Show library type/id/version + key permissions")

    pc = sub.add_parser("list-collections", help="List collections")
    pc.add_argument("--parent", help="List children of this collection key")
    pc.add_argument("--top", action="store_true", help="Top-level only")

    pr = sub.add_parser("resolve-collection",
                        help="Resolve slash path -> key (auto-create)")
    pr.add_argument("--path", required=True)
    pr.add_argument("--no-create", action="store_true",
                    help="Fail instead of creating missing path segments")

    pcc = sub.add_parser("create-collection", help="Create a single collection")
    pcc.add_argument("--name", required=True)
    pcc.add_argument("--parent", help="Parent collection key")

    prn = sub.add_parser("rename-collection", help="Rename a collection")
    prn.add_argument("--key", required=True)
    prn.add_argument("--name", required=True)

    pdc = sub.add_parser("delete-collection", help="Delete a collection (items survive)")
    pdc.add_argument("--key", required=True)

    pci = sub.add_parser("create-item", help="Create item from Zotero JSON")
    pci.add_argument("--meta", required=True)
    pci.add_argument("--collection", help="Collection path or key")

    pgi = sub.add_parser("get-item", help="Fetch full item record")
    pgi.add_argument("--key", required=True)

    pui = sub.add_parser("update-item", help="PATCH an item")
    pui.add_argument("--key", required=True)
    pui.add_argument("--meta", required=True, help="JSON file with patch fields")

    pdi = sub.add_parser("delete-item", help="Move item to trash")
    pdi.add_argument("--key", required=True)

    pli = sub.add_parser("list-items", help="List items with filters")
    pli.add_argument("--collection", help="Collection path or key")
    pli.add_argument("--tag")
    pli.add_argument("--q")
    pli.add_argument("--qmode", choices=["titleCreatorYear", "everything"])
    pli.add_argument("--item-type", dest="item_type")
    pli.add_argument("--limit", type=int)
    pli.add_argument("--top", action="store_true",
                     help="Top-level items only (no notes/attachments)")

    pf = sub.add_parser("find", help="Find existing items by identifier")
    pf.add_argument("--doi")
    pf.add_argument("--arxiv")
    pf.add_argument("--isbn")
    pf.add_argument("--title-hint", dest="title_hint")

    pac = sub.add_parser("add-to-collection", help="Link item into collection")
    pac.add_argument("--key", required=True, help="Item key")
    pac.add_argument("--collection", required=True, help="Path or key")

    prc = sub.add_parser("remove-from-collection", help="Unlink from collection")
    prc.add_argument("--key", required=True, help="Item key")
    prc.add_argument("--collection", required=True, help="Path or key")

    pap = sub.add_parser("attach-pdf", help="Attach PDF to a parent item")
    pap.add_argument("--parent", required=True, help="Parent item key")
    pap.add_argument("--pdf", required=True, help="Local PDF path")
    pap.add_argument("--mode", choices=["hybrid", "upload"], default="hybrid",
                     help="hybrid (default): write file locally for "
                          "third-party file sync. upload: standard 3-step "
                          "S3 upload to Zotero storage.")

    pla = sub.add_parser("list-attachments", help="List child attachments")
    pla.add_argument("--parent", required=True)
    pla.add_argument("--content-type", dest="content_type",
                     help="Filter, e.g. application/pdf")

    pda = sub.add_parser("delete-attachment", help="Delete an attachment")
    pda.add_argument("--key", required=True)

    pan = sub.add_parser("add-note", help="Add note to parent")
    pan.add_argument("--parent", required=True)
    g_an = pan.add_mutually_exclusive_group(required=True)
    g_an.add_argument("--html")
    g_an.add_argument("--md")

    pun = sub.add_parser("update-note", help="Replace note body")
    pun.add_argument("--key", required=True)
    g_un = pun.add_mutually_exclusive_group(required=True)
    g_un.add_argument("--html")
    g_un.add_argument("--md")

    pdn = sub.add_parser("delete-note", help="Delete a note")
    pdn.add_argument("--key", required=True)

    pln = sub.add_parser("list-notes", help="List child notes")
    pln.add_argument("--parent", required=True)

    pat = sub.add_parser("add-tag", help="Add tag(s) to item")
    pat.add_argument("--item", required=True)
    pat.add_argument("--tag", required=True, action="append",
                     help="Tag (repeat for multiple)")

    prt = sub.add_parser("remove-tag", help="Remove tag(s) from item")
    prt.add_argument("--item", required=True)
    prt.add_argument("--tag", required=True, action="append")

    plt = sub.add_parser("list-tags", help="List library-wide tags")
    plt.add_argument("--prefix")
    plt.add_argument("--limit", type=int)

    pft = sub.add_parser("find-by-tag", help="List items carrying a tag")
    pft.add_argument("--tag", required=True)
    pft.add_argument("--limit", type=int)

    return p


def main(argv=None):
    args = _build_parser().parse_args(argv)
    _need_creds()

    if args.cmd == "library-info":
        out = library_info()
    elif args.cmd == "list-collections":
        out = list_all_collections(parent_key=args.parent, top_only=args.top)
    elif args.cmd == "resolve-collection":
        out = resolve_collection(args.path, create_missing=not args.no_create)
    elif args.cmd == "create-collection":
        out = create_collection(args.name, parent_key=args.parent)
    elif args.cmd == "rename-collection":
        out = rename_collection(args.key, args.name)
    elif args.cmd == "delete-collection":
        out = delete_collection(args.key)
    elif args.cmd == "create-item":
        meta = _load_meta(args.meta)
        coll_key = _resolve_collection_arg(args.collection)
        out = create_item(meta, collection_key=coll_key)
    elif args.cmd == "get-item":
        out = get_item(args.key)
    elif args.cmd == "update-item":
        patch = _load_meta(args.meta)
        out = update_item(args.key, patch)
    elif args.cmd == "delete-item":
        out = delete_item(args.key)
    elif args.cmd == "list-items":
        coll_key = _resolve_collection_arg(args.collection)
        out = list_items(
            collection_key=coll_key, tag=args.tag, q=args.q,
            qmode=args.qmode, item_type=args.item_type, limit=args.limit,
            top_only=args.top,
        )
    elif args.cmd == "find":
        out = find_by_identifier(
            doi=args.doi, arxiv=args.arxiv, isbn=args.isbn,
            title_hint=args.title_hint,
        )
    elif args.cmd == "add-to-collection":
        coll_key = _resolve_collection_arg(args.collection)
        out = add_to_collection(args.key, coll_key)
    elif args.cmd == "remove-from-collection":
        coll_key = _resolve_collection_arg(args.collection)
        out = remove_from_collection(args.key, coll_key)
    elif args.cmd == "attach-pdf":
        if args.mode == "hybrid":
            out = attach_pdf_hybrid(args.parent, args.pdf)
        else:
            out = attach_pdf_upload(args.parent, args.pdf)
    elif args.cmd == "list-attachments":
        out = list_attachments(args.parent, content_type=args.content_type)
    elif args.cmd == "delete-attachment":
        out = delete_attachment(args.key)
    elif args.cmd == "add-note":
        out = add_note(args.parent, _read_note_body(args))
    elif args.cmd == "update-note":
        out = update_note(args.key, _read_note_body(args))
    elif args.cmd == "delete-note":
        out = delete_note(args.key)
    elif args.cmd == "list-notes":
        out = list_notes(args.parent)
    elif args.cmd == "add-tag":
        results = {t: add_tag(args.item, t) for t in args.tag}
        out = {"item_key": args.item, "added": results}
    elif args.cmd == "remove-tag":
        results = {t: remove_tag(args.item, t) for t in args.tag}
        out = {"item_key": args.item, "removed": results}
    elif args.cmd == "list-tags":
        out = list_tags(prefix=args.prefix, limit=args.limit)
    elif args.cmd == "find-by-tag":
        out = find_by_tag(args.tag, limit=args.limit)
    else:
        print(f"unknown command: {args.cmd}", file=sys.stderr)
        sys.exit(2)

    _print_json(out)


if __name__ == "__main__":
    main()
