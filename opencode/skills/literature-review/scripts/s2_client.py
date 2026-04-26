#!/usr/bin/env python3
"""
s2_client.py - Semantic Scholar Graph API client.

Subcommands:
    search   Full-text search (paginated), emit JSONL of normalized entries.
    fetch    Fetch metadata for one paper by identifier.
    refs     Fetch backward references (papers this paper cites).
    cites    Fetch forward citations (papers that cite this paper).

Environment:
    S2_API_KEY   Optional. Without it, quota is ~100 req / 5 min.
                 With a key, quota is much higher. Get one at:
                 https://www.semanticscholar.org/product/api

Identifier formats accepted by fetch/refs/cites:
    S2 corpus id     649dad58...
    DOI:<doi>        DOI:10.1038/s41586-021-12345-6
    ARXIV:<id>       ARXIV:2401.12345
    MAG:<id>         MAG:112233
    ACL:<id> / PMID:<id> / etc.

Usage:
    python s2_client.py search --query "diffusion alignment" --max 100 > s2.jsonl
    python s2_client.py fetch DOI:10.1038/nature.xxx
    python s2_client.py refs ARXIV:2401.12345 --max 50
    python s2_client.py cites ARXIV:2401.12345 --max 50

Normalized JSON fields:
    source                    "s2_api"
    s2_id, doi, arxiv_id      identifiers (any may be null)
    url, pdf_url              links
    title, abstract, tldr     strings
    year, published           int / "YYYY-MM-DD"
    venue                     string (from publicationVenue.name or venue)
    venue_type                "conference" | "journal" | null - from
                              publicationVenue.type, the most reliable
                              conference-vs-journal signal (lowercase)
    publication_types         [string, ...] - paper-level S2 classification
                              ("Conference", "JournalArticle", ...). Less
                              reliable than venue_type because S2 sometimes
                              tags NeurIPS proceedings as "JournalArticle".
    authors                   [string, ...]
    citation_count, influential_citation_count, reference_count
    open_access               bool
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


API_BASE = "https://api.semanticscholar.org/graph/v1"

DEFAULT_FIELDS = ",".join([
    "paperId", "externalIds", "url", "title", "abstract", "year",
    "venue", "publicationVenue", "publicationTypes", "publicationDate",
    "authors.name", "authors.authorId",
    "citationCount", "influentialCitationCount", "referenceCount",
    "openAccessPdf", "isOpenAccess",
    "tldr",
])

USER_AGENT = "literature-review-skill/0.1"

MIN_INTERVAL_WITH_KEY = 1.1
MIN_INTERVAL_NO_KEY = 3.1
_last_request_at = 0.0
_warned_no_key = False

# Default short backoff (5/15/30/60 = 110s total). Set
# S2_BACKOFF_TOLERANT=1 to use the long schedule (30/60/90/120 = 300s)
# when the network is flaky and short retries aren't clearing 429.
BACKOFF_SHORT = (5, 15, 30, 60)
BACKOFF_LONG = (30, 60, 90, 120)


def _throttle():
    global _last_request_at
    interval = MIN_INTERVAL_WITH_KEY if os.environ.get("S2_API_KEY") else MIN_INTERVAL_NO_KEY
    elapsed = time.monotonic() - _last_request_at
    if elapsed < interval:
        time.sleep(interval - elapsed)
    _last_request_at = time.monotonic()


def _warn_no_key_once():
    global _warned_no_key
    if _warned_no_key or os.environ.get("S2_API_KEY"):
        return
    _warned_no_key = True
    print(
        "[s2] WARNING: S2_API_KEY not set. Quota limited to ~100 req/5min "
        "and 429s will be common.\n"
        "      Free key: https://www.semanticscholar.org/product/api",
        file=sys.stderr,
    )


def _request(url, params=None, retries=4):
    _warn_no_key_once()
    if params:
        url = f"{url}?{urllib.parse.urlencode(params)}"
    headers = {"User-Agent": USER_AGENT}
    key = os.environ.get("S2_API_KEY")
    if key:
        headers["x-api-key"] = key

    schedule = BACKOFF_LONG if os.environ.get("S2_BACKOFF_TOLERANT") else BACKOFF_SHORT
    last_err = None
    for attempt in range(retries):
        _throttle()
        req = urllib.request.Request(url, headers=headers)
        try:
            with urllib.request.urlopen(req, timeout=30) as r:
                return json.loads(r.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            last_err = e
            if e.code in (429, 503) and attempt < retries - 1:
                wait = schedule[min(attempt, len(schedule) - 1)]
                print(
                    f"[s2] HTTP {e.code}, sleeping {wait}s "
                    f"(attempt {attempt + 1}/{retries})",
                    file=sys.stderr,
                )
                time.sleep(wait)
                continue
            raise
    if last_err:
        raise last_err


def _normalize(paper, query=None):
    ext = paper.get("externalIds") or {}
    pub_venue = paper.get("publicationVenue") or {}
    result = {
        "source": "s2_api",
        "s2_id": paper.get("paperId"),
        "doi": ext.get("DOI"),
        "arxiv_id": ext.get("ArXiv"),
        "url": paper.get("url"),
        "title": paper.get("title"),
        "abstract": paper.get("abstract"),
        "year": paper.get("year"),
        "published": paper.get("publicationDate"),
        "venue": pub_venue.get("name") or paper.get("venue"),
        "venue_type": (pub_venue.get("type") or "").lower() or None,
        "publication_types": paper.get("publicationTypes"),
        "authors": [
            a.get("name") for a in (paper.get("authors") or []) if a.get("name")
        ],
        "citation_count": paper.get("citationCount"),
        "influential_citation_count": paper.get("influentialCitationCount"),
        "reference_count": paper.get("referenceCount"),
        "open_access": paper.get("isOpenAccess"),
        "pdf_url": (paper.get("openAccessPdf") or {}).get("url"),
        "tldr": (paper.get("tldr") or {}).get("text"),
    }
    if query:
        result["query"] = query
    return result


def search(query, max_results=100, fields=DEFAULT_FIELDS):
    results = []
    limit = 100
    offset = 0
    while len(results) < max_results:
        batch = min(limit, max_results - len(results))
        data = _request(
            f"{API_BASE}/paper/search",
            {"query": query, "offset": offset, "limit": batch, "fields": fields},
        )
        papers = data.get("data", [])
        if not papers:
            break
        for p in papers:
            results.append(_normalize(p, query=query))
        if len(papers) < batch:
            break
        offset += batch
    return results


def fetch(identifier, fields=DEFAULT_FIELDS):
    data = _request(f"{API_BASE}/paper/{identifier}", {"fields": fields})
    return _normalize(data)


def _nested(identifier, endpoint, max_results):
    inner_key = "citedPaper" if endpoint == "references" else "citingPaper"
    # S2 nested endpoints (/references, /citations) reject `authors.name` and
    # `tldr`. Request `authors` (returns full objects with name+authorId) and
    # drop `tldr`; the _normalize function tolerates both absences.
    prefixed = ",".join(
        f"{inner_key}.{f}"
        for f in [
            "paperId", "externalIds", "url", "title", "abstract", "year",
            "venue", "publicationVenue", "publicationDate",
            "authors",
            "citationCount", "influentialCitationCount",
            "openAccessPdf", "isOpenAccess",
        ]
    )
    results = []
    limit = 100
    offset = 0
    while len(results) < max_results:
        batch = min(limit, max_results - len(results))
        data = _request(
            f"{API_BASE}/paper/{identifier}/{endpoint}",
            {"offset": offset, "limit": batch, "fields": prefixed},
        )
        papers = data.get("data", [])
        if not papers:
            break
        for p in papers:
            inner = p.get(inner_key)
            if inner:
                results.append(_normalize(inner))
        if len(papers) < batch:
            break
        offset += batch
    return results


def refs(identifier, max_results=50):
    return _nested(identifier, "references", max_results)


def cites(identifier, max_results=50):
    return _nested(identifier, "citations", max_results)


def main():
    parser = argparse.ArgumentParser(description="Semantic Scholar Graph API client")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_search = sub.add_parser("search", help="Full-text search")
    p_search.add_argument("--query", required=True)
    p_search.add_argument("--max", type=int, default=100)

    p_fetch = sub.add_parser("fetch", help="Fetch single paper metadata")
    p_fetch.add_argument("identifier")

    p_refs = sub.add_parser("refs", help="Backward references")
    p_refs.add_argument("identifier")
    p_refs.add_argument("--max", type=int, default=50)

    p_cites = sub.add_parser("cites", help="Forward citations")
    p_cites.add_argument("identifier")
    p_cites.add_argument("--max", type=int, default=50)

    args = parser.parse_args()

    if args.cmd == "search":
        entries = search(args.query, max_results=args.max)
    elif args.cmd == "fetch":
        entries = [fetch(args.identifier)]
    elif args.cmd == "refs":
        entries = refs(args.identifier, max_results=args.max)
    elif args.cmd == "cites":
        entries = cites(args.identifier, max_results=args.max)
    else:
        parser.error(f"unknown subcommand {args.cmd}")

    for e in entries:
        print(json.dumps(e, ensure_ascii=False))
    print(f"[s2_client] emitted {len(entries)} entries", file=sys.stderr)


if __name__ == "__main__":
    main()
