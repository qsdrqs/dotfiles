#!/usr/bin/env python3
"""
crossref_client.py - CrossRef API -> Zotero-compatible metadata.

Resolves a DOI via https://api.crossref.org/works/{doi} and emits a JSON
object ready for POST /items on the Zotero Web API. Replaces the optional
zotero/translation-server container for DOI-indexed papers (most journal
articles, conference papers, books with ISBNs).

Subcommands:
    fetch     --doi 10.xxxx/yyyy    -> single Zotero item
    search    --query "..."          -> list of matches (paginated)
    health                           -> probe api.crossref.org reachability

Environment:
    UNPAYWALL_EMAIL   If set, used for CrossRef polite-pool identification
                      (no rate limit). Otherwise falls back to anonymous use
                      (rate limited, but usable).

Usage:
    python crossref_client.py fetch --doi 10.1038/s41586-021-03819-2
    python crossref_client.py search --query "attention is all you need" --rows 5
    python crossref_client.py health
"""
import argparse
import html
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


API_BASE = "https://api.crossref.org"
USER_AGENT_BASE = "literature-review-skill/0.1"
MIN_INTERVAL_SEC = 1.0
_last_request_at = 0.0

_CROSSREF_TYPE_TO_ZOTERO = {
    "journal-article": "journalArticle",
    "proceedings-article": "conferencePaper",
    "book-chapter": "bookSection",
    "book": "book",
    "monograph": "book",
    "edited-book": "book",
    "reference-book": "book",
    "posted-content": "preprint",
    "report": "report",
    "dissertation": "thesis",
    "dataset": "dataset",
    "standard": "standard",
    "peer-review": "journalArticle",
}


def _user_agent():
    email = os.environ.get("UNPAYWALL_EMAIL")
    if email:
        return f"{USER_AGENT_BASE} (mailto:{email})"
    return USER_AGENT_BASE


def _throttle():
    global _last_request_at
    elapsed = time.monotonic() - _last_request_at
    if elapsed < MIN_INTERVAL_SEC:
        time.sleep(MIN_INTERVAL_SEC - elapsed)
    _last_request_at = time.monotonic()


def _request(url, retries=4, timeout=30):
    last_err = None
    for attempt in range(retries):
        _throttle()
        req = urllib.request.Request(url, headers={"User-Agent": _user_agent()})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code == 404:
                raise
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(5 * (attempt + 1))
                last_err = e
                continue
            raise
        except urllib.error.URLError as e:
            last_err = e
            time.sleep(3 * (attempt + 1))
    raise RuntimeError(f"CrossRef GET {url} failed after {retries} attempts: {last_err}")


def _strip_html(s):
    if not s:
        return ""
    s = re.sub(r"<[^>]+>", "", s)
    return html.unescape(s).strip()


def _join_date_parts(date_obj):
    if not date_obj:
        return None
    parts = date_obj.get("date-parts")
    if not parts or not parts[0]:
        return None
    nums = [f"{n:02d}" if i > 0 else str(n) for i, n in enumerate(parts[0])]
    return "-".join(nums)


def _creators(work):
    result = []
    for role_key, zotero_role in [("author", "author"), ("editor", "editor"),
                                   ("translator", "translator")]:
        for person in work.get(role_key) or []:
            entry = {"creatorType": zotero_role}
            given = (person.get("given") or "").strip()
            family = (person.get("family") or "").strip()
            if family or given:
                entry["firstName"] = given
                entry["lastName"] = family
            elif person.get("name"):
                entry["name"] = person["name"].strip()
            else:
                continue
            result.append(entry)
    return result


def to_zotero(work):
    item_type = _CROSSREF_TYPE_TO_ZOTERO.get(work.get("type", ""), "journalArticle")
    out = {"itemType": item_type}

    titles = work.get("title") or []
    if titles:
        out["title"] = titles[0]

    creators = _creators(work)
    if creators:
        out["creators"] = creators

    date = (_join_date_parts(work.get("published-print"))
            or _join_date_parts(work.get("published-online"))
            or _join_date_parts(work.get("issued"))
            or _join_date_parts(work.get("created")))
    if date:
        out["date"] = date

    container = work.get("container-title") or []
    if container:
        ct = container[0]
        if item_type == "journalArticle":
            out["publicationTitle"] = ct
        elif item_type == "conferencePaper":
            out["proceedingsTitle"] = ct
        elif item_type == "bookSection":
            out["bookTitle"] = ct
        else:
            out["publicationTitle"] = ct

    if work.get("volume"):
        out["volume"] = str(work["volume"])
    if work.get("issue"):
        out["issue"] = str(work["issue"])
    if work.get("page"):
        out["pages"] = str(work["page"])
    if work.get("publisher"):
        out["publisher"] = work["publisher"]
    if work.get("DOI"):
        out["DOI"] = work["DOI"]
    if work.get("URL"):
        out["url"] = work["URL"]

    abstract = _strip_html(work.get("abstract", ""))
    if abstract:
        out["abstractNote"] = abstract

    issns = work.get("ISSN") or []
    if issns:
        out["ISSN"] = ", ".join(issns)
    isbns = work.get("ISBN") or []
    if isbns:
        out["ISBN"] = ", ".join(isbns)

    subjects = work.get("subject") or []
    if subjects:
        out["extra"] = "Subjects: " + "; ".join(subjects[:5])

    # CrossRef "is-referenced-by-count" is CrossRef-only graph cite count.
    # Lower fidelity than S2 (no influential subset, no cross-source reconciliation),
    # but useful as a fallback signal for non-arXiv non-S2 papers. dedupe.py
    # max-merges with S2 so this gets overridden when S2 also surfaces the paper.
    cc = work.get("is-referenced-by-count")
    if cc is not None:
        out["citation_count"] = int(cc)
        out["citation_source"] = "crossref"

    return out


def fetch(doi):
    url = f"{API_BASE}/works/{urllib.parse.quote(doi, safe='')}"
    payload = _request(url)
    if payload.get("status") != "ok":
        raise RuntimeError(f"CrossRef returned non-ok: {payload.get('status')}")
    return to_zotero(payload["message"])


def search(query, rows=10):
    params = {"query.bibliographic": query, "rows": rows}
    url = f"{API_BASE}/works?{urllib.parse.urlencode(params)}"
    payload = _request(url)
    if payload.get("status") != "ok":
        raise RuntimeError(f"CrossRef returned non-ok: {payload.get('status')}")
    return [to_zotero(w) for w in payload["message"].get("items", [])]


def health():
    try:
        _request(f"{API_BASE}/works?rows=0&query=test", retries=1, timeout=5)
        return True
    except Exception:
        return False


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    pf = sub.add_parser("fetch")
    pf.add_argument("--doi", required=True)

    ps = sub.add_parser("search")
    ps.add_argument("--query", required=True)
    ps.add_argument("--rows", type=int, default=10)

    sub.add_parser("health")

    args = p.parse_args()

    if args.cmd == "health":
        ok = health()
        print(json.dumps({"api_base": API_BASE, "reachable": ok}))
        sys.exit(0 if ok else 1)

    try:
        if args.cmd == "fetch":
            out = fetch(args.doi)
        else:
            out = search(args.query, rows=args.rows)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            print(json.dumps({"status": "not_found", "doi": getattr(args, "doi", None)}),
                  file=sys.stderr)
            sys.exit(3)
        raise
    json.dump(out, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
