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
    # Zotero's POST /items rejects unknown fields with HTTP 400. Drop:
    #   - Translator scaffolding (id, key, version, attachments, notes, tags,
    #     seeAlso) - these are response-side fields, not request-side.
    #   - Citation enrichment fields injected by crossref_client / s2_client /
    #     citation_enricher (citation_count, influential_citation_count,
    #     cite_velocity, citation_source) - useful internally for Phase 2
    #     triage and Phase 3 chasing, but not part of the Zotero schema.
    #   - arxiv-only fields (arxiv_id, journal_ref) that are folded into
    #     'extra' upstream by _arxiv_to_zotero; if they leak through here
    #     (e.g. via direct CLI input), drop them silently.
    drop = {
        "id", "key", "version", "attachments", "notes", "tags", "seeAlso",
        "citation_count", "influential_citation_count", "cite_velocity",
        "citation_source", "arxiv_id", "journal_ref",
    }
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


UNVERIFIED_WARNING = "[UNVERIFIED METADATA: manually constructed, not API-fetched]"
UNVERIFIED_TAG = "literature-review-unverified-metadata"
NO_PDF_TAG = "literature-review-no-pdf"
SKILL_SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
ARXIV_FETCH = os.path.join(SKILL_SCRIPTS_DIR, "arxiv_fetch.py")
CROSSREF_CLIENT = os.path.join(SKILL_SCRIPTS_DIR, "crossref_client.py")
S2_CLIENT = os.path.join(SKILL_SCRIPTS_DIR, "s2_client.py")
OPENREVIEW_CLIENT = os.path.join(SKILL_SCRIPTS_DIR, "openreview_client.py")


def _add_tag(item_key, tag):
    _, _, item = _request("GET", f"/items/{item_key}")
    data = item["data"]
    tags = list(data.get("tags") or [])
    if any(t.get("tag") == tag for t in tags):
        return False
    tags.append({"tag": tag})
    version = data["version"]
    _request("PATCH", f"/items/{item_key}",
             body={"tags": tags},
             headers={"If-Unmodified-Since-Version": str(version)})
    return True


def _names_to_creators(names):
    creators = []
    for name in (names or []):
        name = (name or "").strip()
        if not name:
            continue
        parts = name.rsplit(" ", 1)
        if len(parts) == 2:
            creators.append({"creatorType": "author",
                             "firstName": parts[0], "lastName": parts[1]})
        else:
            creators.append({"creatorType": "author", "name": name})
    return creators


def _drop_empty(d):
    return {k: v for k, v in d.items() if v not in (None, "", [])}


def _arxiv_to_zotero(arxiv_meta):
    aid = arxiv_meta.get("arxiv_id") or ""
    out = {
        "itemType": "preprint",
        "title": arxiv_meta.get("title") or "",
        "creators": _names_to_creators(arxiv_meta.get("authors")),
        "date": (arxiv_meta.get("published")
                 or (str(arxiv_meta["year"]) if arxiv_meta.get("year") else "")),
        "url": arxiv_meta.get("url"),
        "abstractNote": arxiv_meta.get("abstract") or "",
        "extra": f"arXiv:{aid}" if aid else "",
        "arxiv_id": aid or None,
    }
    return _drop_empty(out)


def _s2_pick_item_type(s2_meta):
    # Priority order:
    #   T1: publicationVenue.type (venue-level signal, most reliable for
    #       conference vs journal because it comes from the venue record
    #       itself - "conference" / "journal").
    #   T2: publicationTypes (paper-level S2 classifier; can mis-tag e.g.
    #       NeurIPS proceedings as "JournalArticle"). Conference wins over
    #       JournalArticle when both present.
    #   T3: default conferencePaper (most ML/CS venues without DOIs are
    #       conferences; journals usually have DOIs and never reach this
    #       cascade tier).
    venue_type = (s2_meta.get("venue_type") or "").lower()
    if venue_type == "conference":
        return "conferencePaper", "proceedingsTitle"
    if venue_type == "journal":
        return "journalArticle", "publicationTitle"
    pub_types = s2_meta.get("publication_types") or []
    if "Conference" in pub_types:
        return "conferencePaper", "proceedingsTitle"
    if "JournalArticle" in pub_types:
        return "journalArticle", "publicationTitle"
    return "conferencePaper", "proceedingsTitle"


def _s2_to_zotero(s2_meta):
    venue = s2_meta.get("venue")
    if not venue:
        return None
    item_type, venue_field = _s2_pick_item_type(s2_meta)
    aid = s2_meta.get("arxiv_id") or ""
    year = s2_meta.get("year")
    out = {
        "itemType": item_type,
        "title": s2_meta.get("title") or "",
        "creators": _names_to_creators(s2_meta.get("authors")),
        "date": s2_meta.get("published") or (str(year) if year else ""),
        venue_field: venue,
        "abstractNote": s2_meta.get("abstract") or "",
        "url": s2_meta.get("url") or "",
        "extra": f"arXiv:{aid}" if aid else "",
    }
    return _drop_empty(out)


def _venue_id_to_display(venue_id):
    parts = [p for p in (venue_id or "").split("/") if p]
    if not parts:
        return venue_id or ""
    name = parts[0].replace(".cc", "")
    year = next((p for p in parts if p.isdigit() and len(p) == 4), "")
    return f"{name} {year}".strip()


def _openreview_to_zotero(or_meta):
    venue_display = or_meta.get("venue_display") or ""
    venue_id = or_meta.get("venue_id") or ""
    proceedings = venue_display or _venue_id_to_display(venue_id)
    forum_id = or_meta.get("forum_id") or ""
    year = or_meta.get("year")
    out = {
        "itemType": "conferencePaper",
        "title": or_meta.get("title") or "",
        "creators": _names_to_creators(or_meta.get("authors")),
        "date": str(year) if year else "",
        "proceedingsTitle": proceedings,
        "abstractNote": or_meta.get("abstract") or "",
        "url": or_meta.get("url") or "",
        "extra": f"OpenReview: {forum_id}" if forum_id else "",
    }
    return _drop_empty(out)


def _run_subprocess_json(cmd, client_name, timeout=600):
    import subprocess
    proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    if proc.returncode != 0:
        raise RuntimeError(
            f"{client_name} failed (rc={proc.returncode}): {proc.stderr.strip()[:500]}"
        )
    if not proc.stdout.strip():
        raise RuntimeError(f"{client_name} returned empty stdout")
    return json.loads(proc.stdout)


def _try_crossref(doi, source_label):
    cmd = [sys.executable, CROSSREF_CLIENT, "fetch", "--doi", doi]
    cr_meta = _run_subprocess_json(cmd, "crossref_client.py")
    print(f"[zotero_operator] {source_label} -> CrossRef {doi}", file=sys.stderr)
    return cr_meta


def _try_s2(arxiv_id):
    cmd = [sys.executable, S2_CLIENT, "fetch", f"ARXIV:{arxiv_id}"]
    return _run_subprocess_json(cmd, "s2_client.py")


def _resolve_metadata_via_api(doi=None, arxiv_id=None, openreview_id=None):
    # Cascade for the arxiv-id branch (each tier falls through on failure):
    #   T1: arxiv:doi populated -> CrossRef (formally published)
    #   T2: S2 lookup by ARXIV:<id>
    #     T2a: S2 returns DOI       -> CrossRef
    #     T2b: S2 returns venue      -> conferencePaper / journalArticle
    #   T3: arxiv preprint fallback (always succeeds, last resort)
    if doi:
        return _try_crossref(doi, "direct DOI")
    if openreview_id:
        cmd = [sys.executable, OPENREVIEW_CLIENT, "fetch", "--id", openreview_id]
        or_meta = _run_subprocess_json(cmd, "openreview_client.py")
        zotero_meta = _openreview_to_zotero(or_meta)
        print(f"[zotero_operator] openreview {openreview_id} -> "
              f"conferencePaper ({or_meta.get('venue_display') or 'unknown venue'})",
              file=sys.stderr)
        return zotero_meta
    if arxiv_id:
        cmd = [sys.executable, ARXIV_FETCH, "fetch", arxiv_id]
        arxiv_meta = _run_subprocess_json(cmd, "arxiv_fetch.py")
        published_doi = arxiv_meta.get("doi")
        if published_doi:
            try:
                cr_meta = _try_crossref(published_doi,
                                        f"arxiv {arxiv_id} (arxiv:doi)")
                jref = arxiv_meta.get("journal_ref") or "unknown venue"
                print(f"[zotero_operator]   formally published: {jref}",
                      file=sys.stderr)
                return cr_meta
            except Exception as e:
                print(f"[zotero_operator] CrossRef upgrade failed for arxiv "
                      f"{arxiv_id} (doi={published_doi}): {e}; trying S2 fallback",
                      file=sys.stderr)
        try:
            s2_meta = _try_s2(arxiv_id)
            s2_doi = s2_meta.get("doi")
            if s2_doi:
                try:
                    return _try_crossref(s2_doi, f"arxiv {arxiv_id} (S2 doi)")
                except Exception as e:
                    print(f"[zotero_operator] S2-routed CrossRef failed: {e}",
                          file=sys.stderr)
            zotero_meta = _s2_to_zotero(s2_meta)
            if zotero_meta:
                print(f"[zotero_operator] arxiv {arxiv_id} -> S2 venue "
                      f"'{s2_meta.get('venue')}' -> {zotero_meta['itemType']}",
                      file=sys.stderr)
                return zotero_meta
        except Exception as e:
            print(f"[zotero_operator] S2 lookup failed for arxiv {arxiv_id}: "
                  f"{e}; falling back to preprint metadata", file=sys.stderr)
        print(f"[zotero_operator] arxiv {arxiv_id} -> preprint fallback "
              f"(no DOI / venue resolved)", file=sys.stderr)
        return _arxiv_to_zotero(arxiv_meta)
    raise ValueError("must supply --doi, --arxiv-id, or --openreview")


def _mark_unverified(meta):
    meta = dict(meta)
    existing_extra = meta.get("extra") or ""
    if UNVERIFIED_WARNING not in existing_extra:
        meta["extra"] = (
            (existing_extra + "\n" + UNVERIFIED_WARNING) if existing_extra
            else UNVERIFIED_WARNING
        )
    return meta


def import_paper(meta, collection_key, pdf_path=None, contribution=None,
                 unverified=False):
    if unverified:
        meta = _mark_unverified(meta)
        if contribution and not contribution.startswith("[UNVERIFIED"):
            contribution = f"[UNVERIFIED METADATA] {contribution}"

    doi = meta.get("DOI") or meta.get("doi")
    arxiv = meta.get("arxiv_id")
    title_hint = meta.get("title")
    pdf_attached = False
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
            pdf_attached = True

    if unverified:
        try:
            _add_tag(item_key, UNVERIFIED_TAG)
            result["unverified"] = True
        except Exception as e:
            print(f"WARNING: failed to add unverified tag: {e}", file=sys.stderr)

    if not pdf_attached and result.get("status") == "created":
        try:
            _add_tag(item_key, NO_PDF_TAG)
            result["no_pdf"] = True
            print(
                f"[zotero_operator] no PDF attached for {item_key}; tagged "
                f"'{NO_PDF_TAG}'. Filter in Zotero with tag:{NO_PDF_TAG} "
                f"to find papers needing PDF backfill.",
                file=sys.stderr,
            )
        except Exception as e:
            print(f"WARNING: failed to add no-pdf tag: {e}", file=sys.stderr)

    if contribution:
        html = f"<p><strong>Contribution:</strong> {contribution}</p>"
        result["note_key"] = add_note(item_key, html)
    return result


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    pc = sub.add_parser("resolve-collection")
    pc.add_argument("--path", required=True)

    pi = sub.add_parser("import",
                        help="DISCOURAGED: manual JSON import. Prefer 'import-by-id'. "
                             "Caller MUST self-attest provenance via --unverified.")
    pi.add_argument("--meta", required=True,
                    help="JSON file with paper metadata.")
    pi.add_argument("--unverified", required=True, choices=["true", "false"],
                    help="Provenance attestation (LLM signature). 'true' = some/any "
                         "field was constructed by LLM rather than fetched from a "
                         "deterministic API; the Zotero item will be tagged "
                         f"'{UNVERIFIED_TAG}' and the contribution prefixed. "
                         "'false' = caller GUARANTEES every field came from a "
                         "deterministic API parse (e.g. cached arxiv_meta.json "
                         "from Phase 1, exported BibTeX from a verified pipeline). "
                         "There is no default - the caller must consciously sign.")
    pi.add_argument("--pdf", default=None)
    pi.add_argument("--collection", required=True)
    pi.add_argument("--contribution", default=None)

    pid = sub.add_parser("import-by-id",
                         help="Preferred path: resolves metadata via deterministic "
                              "API subprocess (arxiv/CrossRef/S2/OpenReview). "
                              "LLM-supplied metadata cannot reach Zotero.")
    pid_grp = pid.add_mutually_exclusive_group(required=True)
    pid_grp.add_argument("--doi")
    pid_grp.add_argument("--arxiv-id", dest="arxiv_id")
    pid_grp.add_argument("--openreview", dest="openreview_id",
                         help="OpenReview forum_id, e.g. rhgIgTSSxW")
    pid.add_argument("--pdf", default=None)
    pid.add_argument("--collection", required=True)
    pid.add_argument("--contribution", default=None)

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
    elif args.cmd == "import-by-id":
        try:
            meta = _resolve_metadata_via_api(
                doi=args.doi,
                arxiv_id=args.arxiv_id,
                openreview_id=args.openreview_id,
            )
        except Exception as e:
            print(f"ERROR: API metadata resolution failed: {e}", file=sys.stderr)
            print("HINT: rate limits clear after a few minutes. Defer this paper "
                  "or retry later. DO NOT manually construct metadata - that "
                  "produces unverifiable Zotero entries.", file=sys.stderr)
            sys.exit(4)
        coll = resolve_collection(args.collection)
        out = import_paper(meta, coll["key"], pdf_path=args.pdf,
                           contribution=args.contribution, unverified=False)
        out["collection"] = coll
    else:
        unverified = (args.unverified == "true")
        if unverified:
            print(f"WARNING: --unverified=true (LLM signature). Item will be "
                  f"tagged '{UNVERIFIED_TAG}' and contribution prefixed "
                  f"[UNVERIFIED METADATA]. Prefer 'import-by-id' when possible.",
                  file=sys.stderr)
        else:
            print(f"NOTE: --unverified=false (LLM signature). Caller attests "
                  f"every metadata field came from a deterministic API parse. "
                  f"If this is wrong, the resulting Zotero entry will be "
                  f"silently fabricated - re-import via 'import-by-id'.",
                  file=sys.stderr)
        with open(args.meta) as f:
            meta = json.load(f)
        if isinstance(meta, list):
            if not meta:
                print("ERROR: empty meta list", file=sys.stderr)
                sys.exit(2)
            meta = meta[0]
        coll = resolve_collection(args.collection)
        out = import_paper(meta, coll["key"], pdf_path=args.pdf,
                           contribution=args.contribution, unverified=unverified)
        out["collection"] = coll

    json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
