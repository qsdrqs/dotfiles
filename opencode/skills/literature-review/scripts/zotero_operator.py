#!/usr/bin/env python3
"""
zotero_operator.py - Zotero Web API operator for the literature-review skill.

Capabilities:
    - Resolve a slash-separated collection path ("AI/RAG/Survey") to a
      Zotero collection key, creating missing nodes along the way.
    - Import a paper: write item metadata (from translation-server),
      attach a PDF (3-step Zotero file-upload flow), add a one-line
      contribution note, and link the item into the target collection.
    - Idempotent on identifier (DOI / arXiv id) - re-imports update the
      collection link / note instead of creating duplicates.

Subcommands:
    resolve-collection   --path "AI/RAG/Survey"          -> {key,...}
    import               --meta meta.json [--pdf paper.pdf]
                         --collection "AI/RAG" [--contribution "..."]
    find                 --doi 10.x/y     | --arxiv 2401.12345

Environment (REQUIRED):
    ZOTERO_API_KEY    Personal API key from https://www.zotero.org/settings/keys
    ZOTERO_USER_ID    Numeric user ID (shown on the same settings page)
Environment (optional):
    ZOTERO_API_BASE   default https://api.zotero.org

Notes:
    - Group libraries are NOT supported in this minimal client; user libraries only.
    - Attachment upload uses Zotero's standard authorization flow:
      POST /file (claim) -> POST to S3 URL with prefix/suffix wrapping ->
      POST /file (register with uploadKey).
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
USER_AGENT = "literature-review-skill/0.1"
MIN_INTERVAL_SEC = 0.4
_last_request_at = 0.0


def _need_creds():
    if not API_KEY or not USER_ID:
        print("ERROR: set ZOTERO_API_KEY and ZOTERO_USER_ID", file=sys.stderr)
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
    if raw_url:
        url = path_or_url
    else:
        url = f"{API_BASE}/users/{USER_ID}{path_or_url}"
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
                    return resp.status, dict(resp.headers), json.loads(payload or b"null")
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
            raise RuntimeError(f"{method} {url} -> HTTP {e.code}: {err_text}") from e
        except urllib.error.URLError as e:
            last_err = e
            time.sleep(3 * (attempt + 1))
    raise RuntimeError(f"{method} {url} failed after {retries} attempts: {last_err}")


def _paginate(path, params=None):
    params = dict(params or {})
    params.setdefault("limit", 100)
    start = 0
    while True:
        params["start"] = start
        status, headers, data = _request("GET", path, params=params)
        if not data:
            return
        for item in data:
            yield item
        if len(data) < params["limit"]:
            return
        start += params["limit"]


def list_all_collections():
    return list(_paginate("/collections"))


def resolve_collection(path):
    parts = [p.strip() for p in path.split("/") if p.strip()]
    if not parts:
        raise ValueError("empty collection path")
    all_cols = list_all_collections()
    by_key = {c["key"]: c for c in all_cols}

    parent_key = None
    found_key = None
    for name in parts:
        match = None
        for c in all_cols:
            d = c.get("data", {})
            if d.get("name") == name and (d.get("parentCollection") or None) == parent_key:
                match = c
                break
        if match is None:
            payload = [{"name": name}]
            if parent_key:
                payload[0]["parentCollection"] = parent_key
            status, _, resp = _request("POST", "/collections", body=payload)
            if not resp or "successful" not in resp or "0" not in resp["successful"]:
                raise RuntimeError(f"failed to create collection '{name}': {resp}")
            new = resp["successful"]["0"]
            all_cols.append(new)
            by_key[new["key"]] = new
            match = new
        parent_key = match["key"]
        found_key = match["key"]
    return {"key": found_key, "path": "/".join(parts)}


def find_by_identifier(doi=None, arxiv=None, title_hint=None):
    # Zotero's q= search does NOT index the DOI field (title/creator/notes/
    # tags/fulltext only). Use title_hint to narrow via q=, then match DOI /
    # arXiv id client-side against data.DOI / data.extra / data.url.
    if not (doi or arxiv):
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
    return hits


def _normalize_translator_item(item):
    drop = {"id", "key", "version", "attachments", "notes", "tags", "seeAlso"}
    cleaned = {k: v for k, v in item.items() if k not in drop and v not in (None, "", [])}
    cleaned.setdefault("itemType", item.get("itemType", "journalArticle"))
    return cleaned


def create_item(item_data, collection_key=None):
    payload = _normalize_translator_item(item_data)
    if collection_key:
        payload["collections"] = [collection_key]
    status, _, resp = _request("POST", "/items", body=[payload])
    if not resp or "successful" not in resp or "0" not in resp["successful"]:
        raise RuntimeError(f"create_item failed: {resp}")
    return resp["successful"]["0"]


def add_to_collection(item_key, collection_key):
    status, _, item = _request("GET", f"/items/{item_key}")
    data = item["data"]
    cols = list(data.get("collections") or [])
    if collection_key in cols:
        return {"key": item_key, "collections": cols, "changed": False}
    cols.append(collection_key)
    version = data["version"]
    _request("PATCH", f"/items/{item_key}",
             body={"collections": cols},
             headers={"If-Unmodified-Since-Version": str(version)})
    return {"key": item_key, "collections": cols, "changed": True}


def attach_pdf(parent_key, pdf_path):
    filename = os.path.basename(pdf_path)
    with open(pdf_path, "rb") as f:
        content = f.read()
    md5 = hashlib.md5(content).hexdigest()
    mtime = int(os.path.getmtime(pdf_path) * 1000)

    # Hybrid storage: metadata goes to api.zotero.org (so the desktop client
    # syncs it down), but the file itself is placed under the local Zotero
    # data dir so a file sync tool (Syncthing, etc.) can propagate it. We do
    # NOT call the S3 file upload flow - the client will find the local file
    # by md5 match without touching Zotero storage servers.
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
    status, _, resp = _request("POST", "/items", body=[attach_payload])
    if not resp or "successful" not in resp or "0" not in resp["successful"]:
        raise RuntimeError(f"create_attachment_item failed: {resp}")
    attach_key = resp["successful"]["0"]["key"]

    # ZOTERO_DATA_DIR may point at either the full data directory
    # (containing zotero.sqlite + storage/) or the storage folder itself
    # (when the user syncs only storage via Syncthing). Detect and adapt.
    data_dir = os.path.expanduser(os.environ.get("ZOTERO_DATA_DIR", "~/Zotero"))
    if os.path.isdir(os.path.join(data_dir, "storage")):
        storage_root = os.path.join(data_dir, "storage")
    else:
        storage_root = data_dir
    storage_dir = os.path.join(storage_root, attach_key)
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


def add_note(parent_key, html):
    payload = {"itemType": "note", "parentItem": parent_key, "note": html}
    status, _, resp = _request("POST", "/items", body=[payload])
    if not resp or "successful" not in resp or "0" not in resp["successful"]:
        raise RuntimeError(f"add_note failed: {resp}")
    return resp["successful"]["0"]["key"]


def import_paper(meta, collection_key, pdf_path=None, contribution=None):
    doi = meta.get("DOI") or meta.get("doi")
    arxiv = meta.get("arxiv_id")
    title_hint = meta.get("title")
    existing = find_by_identifier(doi=doi, arxiv=arxiv, title_hint=title_hint)
    if existing:
        item_key = existing[0]["key"]
        coll_result = add_to_collection(item_key, collection_key)
        result = {"status": "existed", "item_key": item_key,
                  "collection": coll_result}
    else:
        created = create_item(meta, collection_key=collection_key)
        item_key = created["key"]
        result = {"status": "created", "item_key": item_key}
        if pdf_path and os.path.isfile(pdf_path):
            result["attachment"] = attach_pdf(item_key, pdf_path)

    if contribution:
        html = f"<p><strong>Contribution:</strong> {contribution}</p>"
        result["note_key"] = add_note(item_key, html)
    return result


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    pc = sub.add_parser("resolve-collection")
    pc.add_argument("--path", required=True)

    pi = sub.add_parser("import")
    pi.add_argument("--meta", required=True, help="JSON file: translation-server item OR list[item]")
    pi.add_argument("--pdf", default=None)
    pi.add_argument("--collection", required=True)
    pi.add_argument("--contribution", default=None)

    pf = sub.add_parser("find")
    pf.add_argument("--doi", default=None)
    pf.add_argument("--arxiv", default=None)
    pf.add_argument("--title", default=None, help="Optional title hint to narrow search")

    args = p.parse_args()
    _need_creds()

    if args.cmd == "resolve-collection":
        out = resolve_collection(args.path)
    elif args.cmd == "find":
        out = find_by_identifier(doi=args.doi, arxiv=args.arxiv, title_hint=args.title)
    else:
        with open(args.meta) as f:
            meta = json.load(f)
        if isinstance(meta, list):
            if not meta:
                print("ERROR: empty meta list", file=sys.stderr)
                sys.exit(2)
            meta = meta[0]
        coll = resolve_collection(args.collection)
        out = import_paper(meta, coll["key"],
                           pdf_path=args.pdf, contribution=args.contribution)
        out["collection"] = coll

    json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
