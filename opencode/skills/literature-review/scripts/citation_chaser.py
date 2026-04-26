#!/usr/bin/env python3
"""
citation_chaser.py - Stage C 1-hop snowball expansion.

Given a list of confirmed [core] papers, fetches backward references and
forward citations from Semantic Scholar (via s2_client), normalizes, dedupes
while preserving multi-core provenance, applies per-core + total caps, scores
priority, and emits:

    citation_candidates.jsonl  : normalized paper per line, with related_to[]
    provenance_edges.jsonl     : {candidate_id, core_id, relation} edges
    dispatch_batches.json      : advisory triage-batch plan (<=6 batches)

The main agent then dispatches up to 6 subagents (run_in_background=true)
using dispatch_batches.json and collects their JSONL triage results into
triage_results/ before running the `merge` subcommand.

Subcommands:
    chase   Expansion step: cores in, candidate pool + batches out.
    merge   Post-triage step: reconciles subagent outputs with the candidate
            pool, applies the score threshold, updates matrix.jsonl.

Environment:
    S2_API_KEY   Optional. Propagated to s2_client subprocess calls.

Inputs for `chase`:
    --core      JSON file listing confirmed cores. Each entry has at least
                paper_id and one of s2_id / arxiv_id / doi. May include
                matrix_role (for downstream prompts).
    --scope     scope.json (Phase 0) for time_window + keywords.
    --workdir   $LITREV_WORKDIR. All outputs land here.
    --per-core-refs    default 50
    --per-core-cites   default 50
    --total-cap        default 300
    --max-batches      default 6

Inputs for `merge`:
    --workdir   $LITREV_WORKDIR. Reads citation_candidates.jsonl + every
                triage_results/*.jsonl and writes matrix_updated.jsonl.
    --score-threshold  default 5
    --matrix           existing matrix.jsonl to merge into (optional; if
                       absent, only citation survivors are emitted).

Exit codes:
    0 success
    1 hard error (missing cores, no S2 connectivity on all cores, etc.)
    2 partial (some cores failed, but pool has >= 1 candidate)
"""
import argparse
import datetime
import json
import math
import os
import sys


SKILL_SCRIPTS_DIR = os.path.dirname(os.path.abspath(__file__))
if SKILL_SCRIPTS_DIR not in sys.path:
    sys.path.insert(0, SKILL_SCRIPTS_DIR)

import s2_client

CURRENT_YEAR = datetime.date.today().year


def _s2_identifier(entry):
    if entry.get("s2_id"):
        return entry["s2_id"]
    if entry.get("doi"):
        return f"DOI:{entry['doi']}"
    if entry.get("arxiv_id"):
        return f"ARXIV:{entry['arxiv_id']}"
    return None


def _canonical_id(entry):
    for key in ("s2_id", "doi", "arxiv_id"):
        v = entry.get(key)
        if v:
            return f"{key}:{v}"
    t = (entry.get("title") or "").strip().lower()
    return f"title:{t}" if t else None


def _neighbor_cache_path(workdir):
    if workdir and os.path.isdir(workdir):
        return os.path.join(workdir, ".s2_neighbor_cache.json")
    return None


def _load_neighbor_cache(path):
    if path and os.path.exists(path):
        try:
            with open(path) as f:
                return json.load(f)
        except (json.JSONDecodeError, OSError):
            print(f"[chase] neighbor cache at {path} unreadable, starting fresh",
                  file=sys.stderr)
    return {}


def _save_neighbor_cache(path, cache):
    if not path:
        return
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(cache, f, ensure_ascii=False)
    os.replace(tmp, path)


def _run_s2(identifier, kind, max_results, cache):
    cache_key = f"{identifier}:{kind}:{max_results}"
    if cache_key in cache:
        return cache[cache_key], "cached"
    fn = s2_client.refs if kind == "refs" else s2_client.cites
    try:
        results = fn(identifier, max_results=max_results)
    except Exception as e:
        print(f"[chase] s2 {kind} failed for {identifier}: {e}",
              file=sys.stderr)
        return [], "error"
    cache[cache_key] = results
    return results, "fetched"


def _scope_keywords(scope):
    kws = scope.get("keywords") or []
    return [k.lower() for k in kws if isinstance(k, str)]


def _priority_score(entry, scope_keywords, time_window, median_cites):
    score = 0
    related = entry.get("related_to", [])
    score += 2 * len(related)
    relations = {r.get("relation") for r in related}
    if {"reference", "citation"}.issubset(relations):
        score += 1
    if time_window and entry.get("year") is not None:
        lo, hi = time_window
        if (lo is None or entry["year"] >= lo) and (hi is None or entry["year"] <= hi):
            score += 1
    ic = entry.get("influential_citation_count")
    if ic is not None and ic >= 5:
        score += 2
    velocity = entry.get("cite_velocity")
    if velocity is not None and velocity >= 10:
        score += 1
    cc = entry.get("citation_count")
    if cc is not None and median_cites is not None and cc >= median_cites:
        score += 1
    ab = (entry.get("abstract") or "").lower()
    hits = sum(1 for k in scope_keywords if k and k in ab)
    if hits >= 2:
        score += 1
    return score


def _est_tokens(entry):
    t = len((entry.get("title") or "")) + len((entry.get("abstract") or ""))
    return max(200, int(t / 4))


def _balanced_batches(entries, max_batches):
    n = len(entries)
    if n == 0:
        return []
    num_batches = max(1, min(max_batches, math.ceil(n / 50)))
    buckets = [[] for _ in range(num_batches)]
    loads = [0] * num_batches
    for e in sorted(entries, key=lambda x: -_est_tokens(x)):
        i = loads.index(min(loads))
        buckets[i].append(e)
        loads[i] += _est_tokens(e)
    return [
        {"batch_id": i, "candidate_ids": [_canonical_id(e) for e in b],
         "est_tokens": loads[i], "size": len(b)}
        for i, b in enumerate(buckets) if b
    ]


def chase(args):
    with open(args.core) as f:
        cores = json.load(f)
    if not cores:
        print("[chase] core list is empty", file=sys.stderr)
        return 1

    with open(args.scope) as f:
        scope = json.load(f)
    scope_keywords = _scope_keywords(scope)
    tw = scope.get("time_window") or {}
    time_window = (tw.get("from"), tw.get("to")) if tw else None

    os.makedirs(args.workdir, exist_ok=True)
    candidates_path = os.path.join(args.workdir, "citation_candidates.jsonl")
    edges_path = os.path.join(args.workdir, "provenance_edges.jsonl")
    batches_path = os.path.join(args.workdir, "dispatch_batches.json")
    cache_path = _neighbor_cache_path(args.workdir)
    cache = _load_neighbor_cache(cache_path)

    core_ids = {_canonical_id(c) for c in cores if _canonical_id(c)}
    pool = {}
    edges = []
    cores_ok = 0
    cores_failed = 0
    cache_stats = {"cached": 0, "fetched": 0, "error": 0}

    for core in cores:
        s2id = _s2_identifier(core)
        core_canonical = _canonical_id(core)
        if not s2id or not core_canonical:
            print(f"[chase] skipping core without identifier: {core.get('title')!r}",
                  file=sys.stderr)
            cores_failed += 1
            continue

        refs, refs_status = _run_s2(s2id, "refs", args.per_core_refs, cache)
        cites, cites_status = _run_s2(s2id, "cites", args.per_core_cites, cache)
        cache_stats[refs_status] += 1
        cache_stats[cites_status] += 1
        _save_neighbor_cache(cache_path, cache)
        if not refs and not cites:
            cores_failed += 1
            continue
        cores_ok += 1

        for relation, batch in (("reference", refs), ("citation", cites)):
            for entry in batch:
                cid = _canonical_id(entry)
                if not cid or cid in core_ids:
                    continue
                if cid not in pool:
                    pool[cid] = dict(entry)
                    pool[cid]["paper_id"] = cid
                    pool[cid]["related_to"] = []
                existing_rels = {
                    (r["core_id"], r["relation"]) for r in pool[cid]["related_to"]
                }
                pair = (core_canonical, relation)
                if pair not in existing_rels:
                    pool[cid]["related_to"].append(
                        {"core_id": core_canonical, "relation": relation}
                    )
                    edges.append({
                        "candidate_id": cid,
                        "core_id": core_canonical,
                        "relation": relation,
                    })

    if not pool:
        print("[chase] empty candidate pool after expansion", file=sys.stderr)
        return 1

    cite_counts = [e.get("citation_count") for e in pool.values() if e.get("citation_count")]
    median_cites = sorted(cite_counts)[len(cite_counts) // 2] if cite_counts else None

    for e in pool.values():
        if e.get("cite_velocity") is None and e.get("citation_count") is not None and e.get("year"):
            age = max(1, CURRENT_YEAR - e["year"] + 1)
            e["cite_velocity"] = round(e["citation_count"] / age, 2)
        e["priority_score"] = _priority_score(
            e, scope_keywords, time_window, median_cites,
        )

    sorted_pool = sorted(pool.values(), key=lambda e: -e["priority_score"])
    capped = sorted_pool[: args.total_cap]

    with open(candidates_path, "w") as f:
        for e in capped:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")

    with open(edges_path, "w") as f:
        for e in edges:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")

    batches = _balanced_batches(capped, args.max_batches)
    with open(batches_path, "w") as f:
        json.dump(batches, f, ensure_ascii=False, indent=2)

    summary = {
        "cores_total": len(cores),
        "cores_ok": cores_ok,
        "cores_failed": cores_failed,
        "pool_before_cap": len(pool),
        "pool_after_cap": len(capped),
        "num_batches": len(batches),
        "s2_calls": cache_stats,
        "candidates_path": candidates_path,
        "edges_path": edges_path,
        "batches_path": batches_path,
        "cache_path": cache_path,
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    if cores_failed and cores_ok == 0:
        return 1
    if cores_failed:
        return 2
    return 0


def merge(args):
    candidates_path = os.path.join(args.workdir, "citation_candidates.jsonl")
    if not os.path.exists(candidates_path):
        print(f"[merge] missing {candidates_path}", file=sys.stderr)
        return 1

    pool = {}
    with open(candidates_path) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            e = json.loads(line)
            pool[e["paper_id"]] = e

    triage_dir = os.path.join(args.workdir, "triage_results")
    if not os.path.isdir(triage_dir):
        print(f"[merge] missing {triage_dir}", file=sys.stderr)
        return 1

    triage = {}
    for fname in sorted(os.listdir(triage_dir)):
        if not fname.endswith(".jsonl"):
            continue
        with open(os.path.join(triage_dir, fname)) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    r = json.loads(line)
                except json.JSONDecodeError:
                    continue
                pid = r.get("paper_id")
                if not pid:
                    continue
                prev = triage.get(pid)
                if prev is None or r.get("keep_score", 0) > prev.get("keep_score", 0):
                    triage[pid] = r

    survivors = []
    for pid, t in triage.items():
        if pid not in pool:
            continue
        score = t.get("keep_score", 0)
        conf = (t.get("confidence") or "").lower()
        if score < args.score_threshold or conf == "low":
            continue
        candidate = dict(pool[pid])
        candidate["keep_score"] = score
        candidate["confidence"] = conf
        candidate["one_line_contribution"] = t.get("one_line_contribution")
        candidate["relation_to_core"] = t.get("relation_to_core")
        candidate["needs_fulltext"] = bool(t.get("needs_fulltext"))
        candidate["via_core"] = [r["core_id"] for r in candidate.get("related_to", [])]
        candidate["source"] = "citation_chase"
        survivors.append(candidate)

    survivors.sort(key=lambda e: (-e.get("keep_score", 0), -e.get("priority_score", 0)))

    out_path = os.path.join(args.workdir, "matrix_updated.jsonl")
    existing = []
    existing_ids = set()
    if args.matrix and os.path.exists(args.matrix):
        with open(args.matrix) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                e = json.loads(line)
                existing.append(e)
                pid = None
                for key in ("paper_id", "s2_id", "doi", "arxiv_id"):
                    v = e.get(key)
                    if v:
                        pid = f"paper_id:{v}" if key == "paper_id" else f"{key}:{v}"
                        break
                if pid:
                    existing_ids.add(pid)

    merged = list(existing)
    appended = 0
    for s in survivors:
        if s["paper_id"] in existing_ids:
            continue
        merged.append(s)
        appended += 1

    with open(out_path, "w") as f:
        for e in merged:
            f.write(json.dumps(e, ensure_ascii=False) + "\n")

    summary = {
        "candidates": len(pool),
        "triage_entries": len(triage),
        "survivors": len(survivors),
        "appended_to_matrix": appended,
        "matrix_out": out_path,
        "needs_fulltext": sum(1 for s in survivors if s["needs_fulltext"]),
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2))
    return 0


def main():
    parser = argparse.ArgumentParser(description="Stage C 1-hop citation chase.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_chase = sub.add_parser("chase", help="Expand cores via S2 refs/cites")
    p_chase.add_argument("--core", required=True)
    p_chase.add_argument("--scope", required=True)
    p_chase.add_argument("--workdir", required=True)
    p_chase.add_argument("--per-core-refs", type=int, default=50)
    p_chase.add_argument("--per-core-cites", type=int, default=50)
    p_chase.add_argument("--total-cap", type=int, default=300)
    p_chase.add_argument("--max-batches", type=int, default=6)
    p_chase.set_defaults(fn=chase)

    p_merge = sub.add_parser("merge", help="Reconcile subagent triage outputs")
    p_merge.add_argument("--workdir", required=True)
    p_merge.add_argument("--matrix", help="Existing matrix.jsonl to merge into")
    p_merge.add_argument("--score-threshold", type=int, default=5)
    p_merge.set_defaults(fn=merge)

    args = parser.parse_args()
    sys.exit(args.fn(args))


if __name__ == "__main__":
    main()
