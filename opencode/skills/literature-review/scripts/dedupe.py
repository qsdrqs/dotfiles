#!/usr/bin/env python3
"""
dedupe.py - Merge multi-source literature search results.

Reads JSONL from a file or stdin. Each line is one search hit from one source
(brave / exa / cited / arxiv_api / s2_api / openreview_api).

De-duplication key priority (first that matches wins):
    1. DOI (normalized lowercase)
    2. arXiv ID (version suffix stripped: 2401.12345v3 -> 2401.12345)
    3. OpenReview forum id
    4. Canonical URL (scheme stripped, lowercased, trailing slash removed)
    5. Normalized title + year (alphanumeric lowercase + 4-digit year)

When multiple entries collapse into the same key:
    - sources list grows with each source name
    - queries list grows with each surfacing query
    - For scalar fields (title, abstract, year, venue, authors, pdf_url):
      structured sources (arxiv_api, s2_api, openreview_api) override
      generic web-search sources.
    - citation_count takes the max across sources.

Usage:
    python dedupe.py raw_search.jsonl > candidates.jsonl
    cat raw.jsonl | python dedupe.py - > candidates.jsonl
"""
import json
import re
import sys
from urllib.parse import urlparse


STRUCTURED_SOURCES = {"arxiv_api", "s2_api", "openreview_api"}

ARXIV_URL_RE = re.compile(
    r"arxiv\.org/(?:abs|pdf|html)/(\d{4}\.\d{4,5})(?:v\d+)?"
)
OPENREVIEW_URL_RE = re.compile(
    r"openreview\.net/(?:forum|pdf|attachment)\?id=([A-Za-z0-9_-]+)"
)
DOI_RE = re.compile(
    r"\b(10\.\d{4,9}/[-._;()/:A-Za-z0-9]+)\b", re.IGNORECASE
)

SCALAR_FIELDS = (
    "title", "abstract", "venue", "pdf_url", "html_url",
    "doi", "arxiv_id", "s2_id", "published", "tldr",
)


def normalize_title(t):
    if not t:
        return ""
    return re.sub(r"[^a-z0-9]+", "", t.lower())


def canonical_key(entry):
    doi = entry.get("doi")
    if doi:
        return ("doi", doi.lower().strip())

    url = entry.get("url", "") or ""

    m = DOI_RE.search(url)
    if m:
        return ("doi", m.group(1).lower())

    arxiv_id = entry.get("arxiv_id")
    if arxiv_id:
        return ("arxiv", re.sub(r"v\d+$", "", str(arxiv_id)))

    m = ARXIV_URL_RE.search(url.lower())
    if m:
        return ("arxiv", m.group(1))

    m = OPENREVIEW_URL_RE.search(url)
    if m:
        return ("openreview", m.group(1))

    if url:
        p = urlparse(url.lower().strip())
        path = p.path.rstrip("/")
        if p.netloc:
            return ("url", f"{p.netloc}{path}")

    title_norm = normalize_title(entry.get("title", ""))
    year = entry.get("year")
    if title_norm and year:
        return ("title_year", f"{title_norm}|{year}")
    return None


def merge_entries(existing, new):
    existing.setdefault("sources", []).append(new.get("source", "unknown"))
    q = new.get("query")
    if q:
        existing.setdefault("queries", []).append(q)

    existing_is_structured = any(
        s in STRUCTURED_SOURCES for s in existing.get("sources", [])[:-1]
    )
    new_is_structured = new.get("source") in STRUCTURED_SOURCES

    for field in SCALAR_FIELDS:
        v_new = new.get(field)
        v_old = existing.get(field)
        if v_new and (
            not v_old
            or (new_is_structured and not existing_is_structured)
        ):
            existing[field] = v_new

    year_new = new.get("year")
    if year_new:
        year_old = existing.get("year")
        if not year_old or (new_is_structured and not existing_is_structured):
            existing["year"] = year_new

    authors_new = new.get("authors")
    if authors_new:
        if not existing.get("authors") or (
            new_is_structured and not existing_is_structured
        ):
            existing["authors"] = authors_new

    for num_field in ("citation_count", "influential_citation_count", "reference_count"):
        v_new = new.get(num_field)
        if v_new is not None:
            v_old = existing.get(num_field)
            existing[num_field] = max(v_new, v_old if v_old is not None else -1)

    return existing


def dedupe(lines):
    buckets = {}
    no_key_entries = []
    for i, line in enumerate(lines, 1):
        line = line.strip()
        if not line:
            continue
        try:
            entry = json.loads(line)
        except json.JSONDecodeError as e:
            print(f"[dedupe] skip line {i}: {e}", file=sys.stderr)
            continue
        key = canonical_key(entry)
        if key is None:
            no_key_entries.append(entry)
            continue
        if key not in buckets:
            entry.setdefault("sources", [entry.get("source", "unknown")])
            q = entry.get("query")
            entry.setdefault("queries", [q] if q else [])
            entry["dedupe_key"] = f"{key[0]}:{key[1]}"
            buckets[key] = entry
        else:
            merge_entries(buckets[key], entry)

    return list(buckets.values()) + no_key_entries


def main():
    if len(sys.argv) < 2 or sys.argv[1] == "-":
        source = sys.stdin
        close_after = False
    else:
        source = open(sys.argv[1], "r", encoding="utf-8")
        close_after = True

    try:
        merged = dedupe(source)
    finally:
        if close_after:
            source.close()

    stats = {}
    for e in merged:
        kind = e.get("dedupe_key", "no_key").split(":", 1)[0]
        stats[kind] = stats.get(kind, 0) + 1

    summary = f'''
[dedupe] merged {len(merged)} unique entries
        key-kind breakdown: {stats}
'''.strip()
    print(summary, file=sys.stderr)

    for e in merged:
        print(json.dumps(e, ensure_ascii=False))


if __name__ == "__main__":
    main()
