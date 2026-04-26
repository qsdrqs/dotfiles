#!/usr/bin/env python3
"""
citation_enricher.py - Backfill citation_count for candidate JSONL via S2.

Phase 1.5 step. Walks a JSONL stream and, for any entry missing
`citation_count`, queries Semantic Scholar by ARXIV id, DOI, or title
(in that priority order) and merges back: citation_count,
influential_citation_count, year, venue, abstract (if missing). Also
computes `cite_velocity = citation_count / max(1, current_year - year + 1)`.

Cache: $LITREV_WORKDIR/.citation_cache.json (keyed by lookup token like
"ARXIV:2401.12345"), so re-runs skip lookups. Cache writes are atomic
(temp file + rename).

Inputs:  JSONL on stdin or --in PATH.
Outputs: JSONL on stdout, every line annotated with cite_velocity (None if
         year missing) and citation_lookup status (hit/cached/not_found/skipped).

Environment:
    S2_API_KEY    Optional, propagates to s2_client (higher quota).
    LITREV_WORKDIR  Used to locate .citation_cache.json. If unset, cache is
                    in-process only.

Usage:
    python citation_enricher.py --in candidates.jsonl > enriched.jsonl
    cat candidates.jsonl | python citation_enricher.py - > enriched.jsonl
"""
import argparse
import datetime
import json
import os
import sys


SKILL_SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
if SKILL_SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SKILL_SCRIPTS_DIR)

import s2_client


CURRENT_YEAR = datetime.date.today().year


def _cache_path():
    workdir = os.environ.get("LITREV_WORKDIR")
    if workdir and os.path.isdir(workdir):
        return os.path.join(workdir, ".citation_cache.json")
    return None


def _load_cache(path):
    if path and os.path.exists(path):
        try:
            with open(path) as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def _save_cache(path, cache):
    if not path:
        return
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cache, f, ensure_ascii=False)
    os.replace(tmp, path)


def _lookup_token(entry):
    if entry.get("arxiv_id"):
        return f"ARXIV:{entry['arxiv_id']}"
    if entry.get("doi"):
        return f"DOI:{entry['doi']}"
    return None


def _velocity(cc, year):
    if cc is None or year is None:
        return None
    age = max(1, CURRENT_YEAR - year + 1)
    return round(cc / age, 2)


def _enrich_one(entry, cache):
    if entry.get("citation_count") is not None:
        entry.setdefault("citation_lookup", "already_present")
        if entry.get("citation_source") is None:
            entry["citation_source"] = "preexisting"
        entry["cite_velocity"] = _velocity(
            entry.get("citation_count"), entry.get("year"),
        )
        return entry

    token = _lookup_token(entry)
    if not token:
        entry["citation_lookup"] = "skipped_no_id"
        entry["cite_velocity"] = None
        return entry

    if token in cache:
        cached = cache[token]
        entry["citation_lookup"] = "cached" if cached else "cached_not_found"
        if cached:
            for k in ("citation_count", "influential_citation_count",
                      "year", "venue"):
                if entry.get(k) is None and cached.get(k) is not None:
                    entry[k] = cached[k]
            if not entry.get("abstract") and cached.get("abstract"):
                entry["abstract"] = cached["abstract"]
            entry.setdefault("citation_source", "s2")
        entry["cite_velocity"] = _velocity(
            entry.get("citation_count"), entry.get("year"),
        )
        return entry

    try:
        result = s2_client.fetch(token)
    except Exception as e:
        msg = str(e)
        if "404" in msg or "not found" in msg.lower():
            cache[token] = None
            entry["citation_lookup"] = "not_found"
        else:
            entry["citation_lookup"] = f"error: {msg[:80]}"
        entry["cite_velocity"] = _velocity(
            entry.get("citation_count"), entry.get("year"),
        )
        return entry

    cached = {
        "citation_count": result.get("citation_count"),
        "influential_citation_count": result.get("influential_citation_count"),
        "year": result.get("year"),
        "venue": result.get("venue"),
        "abstract": result.get("abstract"),
    }
    cache[token] = cached
    for k in ("citation_count", "influential_citation_count", "year", "venue"):
        if entry.get(k) is None and cached.get(k) is not None:
            entry[k] = cached[k]
    if not entry.get("abstract") and cached.get("abstract"):
        entry["abstract"] = cached["abstract"]
    entry.setdefault("citation_source", "s2")
    entry["citation_lookup"] = "hit"
    entry["cite_velocity"] = _velocity(
        entry.get("citation_count"), entry.get("year"),
    )
    return entry


def main():
    p = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    p.add_argument("--in", dest="infile", default="-",
                   help="JSONL input file (default: stdin)")
    p.add_argument("--no-cache", action="store_true",
                   help="Do not read or write the persistent cache.")
    args = p.parse_args()

    src = sys.stdin if args.infile == "-" else open(args.infile)
    cache_path = None if args.no_cache else _cache_path()
    cache = _load_cache(cache_path)

    counts = {"hit": 0, "cached": 0, "cached_not_found": 0,
              "not_found": 0, "already_present": 0,
              "skipped_no_id": 0, "error": 0}
    flushed = 0
    try:
        for line in src:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
            except json.JSONDecodeError as e:
                print(f"[enricher] bad JSON: {e}", file=sys.stderr)
                continue
            entry = _enrich_one(entry, cache)
            status = entry.get("citation_lookup", "unknown")
            key = "error" if status.startswith("error") else status
            counts[key] = counts.get(key, 0) + 1
            print(json.dumps(entry, ensure_ascii=False))
            flushed += 1
            if flushed % 25 == 0 and not args.no_cache:
                _save_cache(cache_path, cache)
    finally:
        if src is not sys.stdin:
            src.close()
        if not args.no_cache:
            _save_cache(cache_path, cache)

    print(f"[enricher] processed={flushed} {counts}", file=sys.stderr)


if __name__ == "__main__":
    main()
