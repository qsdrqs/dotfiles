#!/usr/bin/env python3
"""
openreview_client.py - OpenReview API v2 client (read-only).

Anonymous access to api2.openreview.net. Fetches accepted submissions and
forum threads (reviews, rebuttals, decisions, meta-reviews) for venues like
ICLR 2024, NeurIPS 2024.

Subcommands:
    venues    List known recent venue IDs (hardcoded index).
    search    Fetch accepted submissions for a venue; emit JSONL.
              Optional client-side keyword filter over title + keywords.
    forum     Fetch the full forum thread for one submission; emit JSON.

Notes:
    - API v2 has NO server-side full-text search. Keyword filter is client-side
      after fetching all accepted submissions.
    - Observed practical rate limit: ~60 req/min unauthenticated. We throttle
      at 1 req / 1.1 s.
    - Venues from 2024+ use API v2 (api2.openreview.net). Older venues are on
      api.openreview.net (API v1); this client targets v2 only.

Usage:
    python openreview_client.py venues
    python openreview_client.py search --venue ICLR.cc/2024/Conference \\
        --keyword diffusion --max 200 > openreview.jsonl
    python openreview_client.py forum --id <note_id> > forum.json

Emitted JSON per accepted submission:
    {
      "source": "openreview",
      "venue_id": "ICLR.cc/2024/Conference",
      "note_id": "...",
      "forum_id": "...",
      "title": "...",
      "authors": ["..."],
      "abstract": "...",
      "keywords": ["..."],
      "tldr": "...",
      "pdf_url": "https://openreview.net/pdf?id=...",
      "url": "https://openreview.net/forum?id=...",
      "decision": "Accept (Poster) | Reject | ...",
      "year": 2024
    }
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


API_BASE = "https://api2.openreview.net"
USER_AGENT = "literature-review-skill/0.1"

MIN_INTERVAL_SEC = 1.1
_last_request_at = 0.0


KNOWN_VENUES = {
    "ICLR.cc/2024/Conference": 2024,
    "ICLR.cc/2025/Conference": 2025,
    "NeurIPS.cc/2023/Conference": 2023,
    "NeurIPS.cc/2024/Conference": 2024,
    "NeurIPS.cc/2025/Conference": 2025,
    "ICML.cc/2024/Conference": 2024,
    "ICML.cc/2025/Conference": 2025,
    "COLM/2024/Conference": 2024,
}


def _throttle():
    global _last_request_at
    elapsed = time.monotonic() - _last_request_at
    if elapsed < MIN_INTERVAL_SEC:
        time.sleep(MIN_INTERVAL_SEC - elapsed)
    _last_request_at = time.monotonic()


def _request(path, params=None, retries=4):
    url = f"{API_BASE}{path}"
    if params:
        url = f"{url}?{urllib.parse.urlencode(params, doseq=True)}"
    headers = {"User-Agent": USER_AGENT}
    token = os.environ.get("OPENREVIEW_TOKEN")
    if token:
        headers["Authorization"] = f"Bearer {token}"
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
                wait = 30 * (attempt + 1)
                print(
                    f"[openreview] HTTP {e.code}, sleeping {wait}s "
                    f"(attempt {attempt + 1}/{retries})",
                    file=sys.stderr,
                )
                time.sleep(wait)
                continue
            raise
    if last_err:
        raise last_err


def _content_value(content, field):
    """API v2 wraps content fields as {'value': ...}. Handle both shapes."""
    v = content.get(field)
    if isinstance(v, dict) and "value" in v:
        return v["value"]
    return v


def _normalize_submission(note, venue_id):
    content = note.get("content", {}) or {}
    title = _content_value(content, "title") or ""
    abstract = _content_value(content, "abstract") or ""
    authors = _content_value(content, "authors") or []
    keywords = _content_value(content, "keywords") or []
    tldr = _content_value(content, "TLDR") or _content_value(content, "tldr") or ""
    pdf_rel = _content_value(content, "pdf") or ""
    venueid = _content_value(content, "venueid") or venue_id
    venue = _content_value(content, "venue") or ""
    year = None
    for token in venue_id.split("/"):
        if token.isdigit() and len(token) == 4:
            year = int(token)
            break
    note_id = note.get("id")
    return {
        "source": "openreview",
        "venue_id": venueid,
        "venue_display": venue,
        "note_id": note_id,
        "forum_id": note.get("forum") or note_id,
        "title": title,
        "authors": authors,
        "abstract": abstract,
        "keywords": keywords,
        "tldr": tldr,
        "pdf_url": (
            f"https://openreview.net{pdf_rel}"
            if pdf_rel and pdf_rel.startswith("/")
            else f"https://openreview.net/pdf?id={note_id}"
        ),
        "url": f"https://openreview.net/forum?id={note_id}",
        "year": year,
    }


def fetch_submissions(venue_id, max_results=500, keyword=None):
    """Fetch accepted submissions for a venue. Keyword filter is client-side."""
    results = []
    offset = 0
    limit = 100
    while len(results) < max_results:
        batch = min(limit, max_results - len(results) + 100)
        data = _request(
            "/notes",
            {
                "content.venueid": venue_id,
                "offset": offset,
                "limit": batch,
            },
        )
        notes = data.get("notes", [])
        if not notes:
            break
        for n in notes:
            norm = _normalize_submission(n, venue_id)
            if keyword:
                haystack = " ".join([
                    norm["title"] or "",
                    " ".join(norm.get("keywords") or []),
                    norm.get("abstract") or "",
                ]).lower()
                if keyword.lower() not in haystack:
                    continue
            results.append(norm)
            if len(results) >= max_results:
                break
        if len(notes) < batch:
            break
        offset += batch
    return results


def fetch_forum(forum_id):
    data = _request("/notes", {"forum": forum_id, "details": "replies"})
    notes = data.get("notes", [])

    out = {"forum_id": forum_id, "paper": None, "replies": [], "decision": None}
    for note in notes:
        invitations = note.get("invitations") or []
        content = note.get("content", {}) or {}
        if note.get("id") == forum_id:
            out["paper"] = {
                "title": _content_value(content, "title"),
                "abstract": _content_value(content, "abstract"),
                "authors": _content_value(content, "authors"),
            }
            continue
        kind = "other"
        for inv in invitations:
            lower = inv.lower()
            if lower.endswith("official_review") or "review" in lower.split("/")[-1]:
                kind = "review"
                break
            if lower.endswith("decision"):
                kind = "decision"
                break
            if lower.endswith("meta_review"):
                kind = "meta_review"
                break
            if lower.endswith("rebuttal"):
                kind = "rebuttal"
                break
            if lower.endswith("comment"):
                kind = "comment"
                break
        item = {
            "note_id": note.get("id"),
            "kind": kind,
            "invitations": invitations,
            "content": {k: _content_value(content, k) for k in content.keys()},
            "signatures": note.get("signatures"),
            "cdate": note.get("cdate"),
        }
        out["replies"].append(item)
        if kind == "decision":
            out["decision"] = _content_value(content, "decision")
    return out


def main():
    parser = argparse.ArgumentParser(description="OpenReview API v2 client (read-only)")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("venues", help="Print hardcoded list of known recent venue IDs")

    p_search = sub.add_parser("search", help="Fetch accepted submissions for a venue")
    p_search.add_argument("--venue", required=True, help="e.g. ICLR.cc/2024/Conference")
    p_search.add_argument("--keyword", help="Client-side filter over title+keywords+abstract")
    p_search.add_argument("--max", type=int, default=500)

    p_forum = sub.add_parser("forum", help="Fetch full thread for one forum_id")
    p_forum.add_argument("--id", required=True, help="Forum/note id")

    args = parser.parse_args()

    if args.cmd == "venues":
        for v, yr in sorted(KNOWN_VENUES.items(), key=lambda x: (-x[1], x[0])):
            print(f"{v}\t{yr}")
        return
    if args.cmd == "search":
        entries = fetch_submissions(args.venue, max_results=args.max, keyword=args.keyword)
        for e in entries:
            print(json.dumps(e, ensure_ascii=False))
        print(
            f"[openreview] venue={args.venue} keyword={args.keyword!r} -> "
            f"{len(entries)} entries",
            file=sys.stderr,
        )
        return
    if args.cmd == "forum":
        out = fetch_forum(args.id)
        json.dump(out, sys.stdout, ensure_ascii=False, indent=2)
        sys.stdout.write("\n")
        return


if __name__ == "__main__":
    main()
