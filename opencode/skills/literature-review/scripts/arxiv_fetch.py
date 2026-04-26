#!/usr/bin/env python3
"""
arxiv_fetch.py - arXiv API client and HTML fetcher.

Subcommands:
    search   Query arXiv API by text, emit JSONL of entries.
    fetch    Fetch metadata for a single arxiv_id.
    html     Fetch rendered HTML (ar5iv-style). Exits 3 with no output if
             HTML is not available for this paper (common for pre-2022 papers).

arXiv asks for ~1 request per 3 seconds; we do not parallelize arxiv calls.

Usage:
    python arxiv_fetch.py search --query "diffusion alignment" --max 50 > arxiv.jsonl
    python arxiv_fetch.py fetch 2401.12345
    python arxiv_fetch.py html 2401.12345 > paper.html

Emitted JSON fields:
    source      "arxiv_api"
    arxiv_id    "2401.12345"
    url         https://arxiv.org/abs/...
    pdf_url     https://arxiv.org/pdf/...
    html_url    https://arxiv.org/html/...
    title       string
    authors     [string, ...]
    abstract    string
    year        int | null
    published   "YYYY-MM-DD" | null
    categories  [string, ...]   e.g. ["cs.LG", "cs.AI"]
    doi         string | null   arxiv:doi - present when authors deposited
                                a published-version DOI back to arXiv
    journal_ref string | null   arxiv:journal_ref - venue / pages free-text,
                                e.g. "Nature 596 (2021) 583-589"
"""
import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET


ATOM_NS = "{http://www.w3.org/2005/Atom}"
ARXIV_NS = "{http://arxiv.org/schemas/atom}"

API_ENDPOINT = "http://export.arxiv.org/api/query"
ABS_ENDPOINT = "https://arxiv.org/abs/"
PDF_ENDPOINT = "https://arxiv.org/pdf/"
HTML_ENDPOINT = "https://arxiv.org/html/"

USER_AGENT = "literature-review-skill/0.1 (+github.com/qsdrqs/dotfiles)"

MIN_INTERVAL_SEC = 3.1
_last_request_at = 0.0


def _throttle():
    global _last_request_at
    elapsed = time.monotonic() - _last_request_at
    if elapsed < MIN_INTERVAL_SEC:
        time.sleep(MIN_INTERVAL_SEC - elapsed)
    _last_request_at = time.monotonic()


BACKOFF_SHORT = (5, 15, 30, 60)
BACKOFF_LONG = (30, 60, 90, 120)


def _request(url, timeout=30, retries=4):
    schedule = BACKOFF_LONG if os.environ.get("LITREV_BACKOFF_TOLERANT") else BACKOFF_SHORT
    last_err = None
    for attempt in range(retries):
        _throttle()
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read().decode("utf-8")
        except urllib.error.HTTPError as e:
            last_err = e
            if e.code in (429, 503) and attempt < retries - 1:
                wait = schedule[min(attempt, len(schedule) - 1)]
                print(
                    f"[arxiv] HTTP {e.code}, sleeping {wait}s "
                    f"(attempt {attempt + 1}/{retries})",
                    file=sys.stderr,
                )
                time.sleep(wait)
                continue
            raise
    if last_err:
        raise last_err


def _strip_version(arxiv_id):
    return re.sub(r"v\d+$", "", str(arxiv_id).strip())


def _parse_entry(entry):
    def _find(tag):
        e = entry.find(ATOM_NS + tag)
        return e.text.strip() if e is not None and e.text else ""

    id_text = _find("id")
    m = re.search(r"arxiv\.org/abs/([\d.]+)(?:v\d+)?", id_text)
    arxiv_id = m.group(1) if m else ""

    published = _find("published")
    year = None
    if published:
        try:
            year = int(published[:4])
        except ValueError:
            year = None

    authors = [
        a.findtext(ATOM_NS + "name", "").strip()
        for a in entry.findall(ATOM_NS + "author")
    ]
    categories = [
        c.get("term", "")
        for c in entry.findall(ATOM_NS + "category")
        if c.get("term")
    ]

    pdf_link = None
    for link in entry.findall(ATOM_NS + "link"):
        if link.get("title") == "pdf":
            pdf_link = link.get("href")
            break

    # arxiv:doi and arxiv:journal_ref are namespaced fields populated when
    # the paper authors deposit published-version metadata back to arXiv.
    # When present, the published version takes precedence over the preprint
    # downstream (zotero_operator import-by-id auto-upgrades to CrossRef).
    doi_el = entry.find(ARXIV_NS + "doi")
    doi = (doi_el.text.strip() if doi_el is not None and doi_el.text else "") or None
    jref_el = entry.find(ARXIV_NS + "journal_ref")
    journal_ref = (jref_el.text.strip() if jref_el is not None and jref_el.text else "") or None
    if journal_ref:
        journal_ref = re.sub(r"\s+", " ", journal_ref)

    return {
        "source": "arxiv_api",
        "arxiv_id": arxiv_id,
        "url": f"{ABS_ENDPOINT}{arxiv_id}" if arxiv_id else id_text,
        "pdf_url": pdf_link or (f"{PDF_ENDPOINT}{arxiv_id}" if arxiv_id else None),
        "html_url": f"{HTML_ENDPOINT}{arxiv_id}" if arxiv_id else None,
        "title": re.sub(r"\s+", " ", _find("title")),
        "authors": authors,
        "abstract": re.sub(r"\s+", " ", _find("summary")),
        "year": year,
        "published": published[:10] if published else None,
        "categories": categories,
        "doi": doi,
        "journal_ref": journal_ref,
    }


def search(query, max_results=50, start=0,
           sort_by="relevance", sort_order="descending"):
    params = {
        "search_query": query,
        "start": start,
        "max_results": max_results,
        "sortBy": sort_by,
        "sortOrder": sort_order,
    }
    url = f"{API_ENDPOINT}?{urllib.parse.urlencode(params)}"
    xml_text = _request(url)
    root = ET.fromstring(xml_text)
    entries = []
    for entry in root.findall(ATOM_NS + "entry"):
        parsed = _parse_entry(entry)
        parsed["query"] = query
        entries.append(parsed)
    return entries


def fetch_metadata(arxiv_id):
    arxiv_id = _strip_version(arxiv_id)
    params = {"id_list": arxiv_id, "max_results": 1}
    url = f"{API_ENDPOINT}?{urllib.parse.urlencode(params)}"
    xml_text = _request(url)
    root = ET.fromstring(xml_text)
    entry = root.find(ATOM_NS + "entry")
    if entry is None:
        raise SystemExit(f"[arxiv_fetch] no entry for id={arxiv_id}")
    return _parse_entry(entry)


def fetch_html(arxiv_id):
    arxiv_id = _strip_version(arxiv_id)
    url = f"{HTML_ENDPOINT}{arxiv_id}"
    try:
        return _request(url, timeout=60)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def main():
    parser = argparse.ArgumentParser(description="arXiv API client")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_search = sub.add_parser("search", help="Search arXiv by query text")
    p_search.add_argument("--query", required=True,
                          help='e.g. "diffusion alignment" or cat:cs.LG AND ti:LoRA')
    p_search.add_argument("--max", type=int, default=50)
    p_search.add_argument("--start", type=int, default=0)
    p_search.add_argument(
        "--sort-by", default="relevance",
        choices=["relevance", "lastUpdatedDate", "submittedDate"],
    )

    p_fetch = sub.add_parser("fetch", help="Fetch metadata for one arxiv_id")
    p_fetch.add_argument("arxiv_id")

    p_html = sub.add_parser("html", help="Fetch rendered HTML for one arxiv_id")
    p_html.add_argument("arxiv_id")

    args = parser.parse_args()

    if args.cmd == "search":
        entries = search(args.query, max_results=args.max,
                         start=args.start, sort_by=args.sort_by)
        for e in entries:
            print(json.dumps(e, ensure_ascii=False))
        print(
            f"[arxiv_fetch] {len(entries)} entries for query={args.query!r}",
            file=sys.stderr,
        )
    elif args.cmd == "fetch":
        meta = fetch_metadata(args.arxiv_id)
        print(json.dumps(meta, ensure_ascii=False, indent=2))
    elif args.cmd == "html":
        html = fetch_html(args.arxiv_id)
        if html is None:
            print(f"[arxiv_fetch] no HTML available for {args.arxiv_id}",
                  file=sys.stderr)
            sys.exit(3)
        sys.stdout.write(html)


if __name__ == "__main__":
    main()
