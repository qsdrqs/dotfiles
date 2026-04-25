#!/usr/bin/env python3
"""
core_detector.py - Heuristic ranker for [core] paper candidates (Stage C).

Reads the Stage A/B matrix + candidate pool, scores each paper for "core-ness"
using graph-plus-metadata signals, and emits a ranked list. The main agent
reviews the output, assigns matrix roles (baseline / method-anchor /
dataset-anchor / theory-anchor / opposing-approach), and asks the user to
confirm via mcp_Question. Heuristics alone do NOT finalize cores.

Signals (cumulative score; higher = more likely core):

    user_seed                          +10  paper is in scope.json seeds
    matrix_citation_hub                 +5  cited by >= 30% of other matrix rows (*)
    citation_percentile_90               +3  top 10% citation_count within matrix
    influential_citation_count_20        +2  S2 "influential" metric >= 20
    foundational_classic                 +2  oldest 20% AND citation_count >= 50
    top_tier_venue                       +1  NeurIPS/ICML/ICLR/ACL/CVPR/Nature/Science

    (*) Requires references[] data from S2. If the matrix has no reference
        graph, this signal is skipped and logged to stderr.

Inputs:
    --matrix PATH    JSONL of Stage A/B matrix rows (one paper per line) with
                     fields: paper_id (s2/doi/arxiv), title, year, venue,
                     citation_count, influential_citation_count, authors,
                     abstract, arxiv_id, doi, references (optional).
    --scope PATH     scope.json from Phase 0 (reads seeds + time_window).

Output:
    JSON list to stdout, sorted by score desc:
        [{"paper_id", "title", "score", "signals": [...],
          "suggested_role", "evidence": {...}}, ...]

Usage:
    python core_detector.py --matrix $LITREV_WORKDIR/matrix.jsonl \
                            --scope   $LITREV_WORKDIR/scope.json \
                          > $LITREV_WORKDIR/core_candidates.json
"""
import argparse
import json
import sys
from collections import defaultdict


TOP_VENUES = {
    "neurips", "nips", "icml", "iclr", "aaai", "ijcai", "uai", "aistats",
    "cvpr", "iccv", "eccv", "wacv", "bmvc",
    "acl", "emnlp", "naacl", "coling", "eacl",
    "osdi", "sosp", "sigmod", "vldb", "atc",
    "nature", "science",
    "ccs", "sp", "usenix security", "ndss",
}


def _normalize_venue(venue):
    if not venue:
        return ""
    v = str(venue).lower().strip()
    for prefix in ("proc. ", "proceedings of ", "proceedings of the "):
        if v.startswith(prefix):
            v = v[len(prefix):]
    for tok in ("conference", "workshop", "symposium", "journal"):
        v = v.replace(tok, "")
    for word in v.split():
        if word in TOP_VENUES:
            return word
    return v


def _paper_id(row):
    for key in ("s2_id", "paper_id", "doi", "arxiv_id"):
        v = row.get(key)
        if v:
            return f"{key}:{v}"
    t = (row.get("title") or "").strip().lower()
    return f"title:{t}" if t else None


def _all_ids(row):
    ids = set()
    for key in ("s2_id", "paper_id", "doi", "arxiv_id"):
        v = row.get(key)
        if v:
            ids.add(f"{key}:{v}")
    t = (row.get("title") or "").strip().lower()
    if t:
        ids.add(f"title:{t}")
    return ids


def _ref_ids(row):
    """Extract normalized reference paper_ids from a matrix row (if present).

    Accepts `references` as either a list of dicts (with s2_id/doi/arxiv_id)
    or a list of strings.
    """
    refs = row.get("references") or []
    ids = set()
    for r in refs:
        if isinstance(r, str):
            ids.add(r)
        elif isinstance(r, dict):
            for key in ("s2_id", "doi", "arxiv_id"):
                v = r.get(key)
                if v:
                    ids.add(f"{key}:{v}")
                    break
    return ids


def _percentile_threshold(values, percentile):
    vs = sorted([v for v in values if v is not None])
    if not vs:
        return None
    idx = int(len(vs) * percentile / 100)
    idx = min(idx, len(vs) - 1)
    return vs[idx]


def score_paper(row, ctx):
    signals = []
    score = 0
    pid = _paper_id(row)

    if _all_ids(row) & ctx["seed_ids"]:
        signals.append("user_seed")
        score += 10

    if ctx["graph_available"]:
        cited_by = ctx["cited_by_count"].get(pid, 0)
        other_count = max(ctx["matrix_size"] - 1, 1)
        rate = cited_by / other_count
        if rate >= 0.30:
            signals.append(f"matrix_citation_hub(rate={rate:.2f})")
            score += 5

    cc = row.get("citation_count")
    if cc is not None and ctx["cite_p90"] is not None and cc >= ctx["cite_p90"]:
        signals.append(f"citation_percentile_90(cc={cc})")
        score += 3

    ic = row.get("influential_citation_count")
    if ic is not None and ic >= 20:
        signals.append(f"influential_citation_count({ic})")
        score += 2

    yr = row.get("year")
    if (yr is not None and ctx["year_p20"] is not None
            and yr <= ctx["year_p20"] and cc is not None and cc >= 50):
        signals.append(f"foundational_classic(year={yr},cc={cc})")
        score += 2

    vn = _normalize_venue(row.get("venue"))
    if vn in TOP_VENUES:
        signals.append(f"top_tier_venue({vn})")
        score += 1

    # suggested_role is advisory; the main agent re-labels each core with an
    # authoritative matrix role (baseline/method-anchor/etc.) before confirm.
    suggested_role = None
    if "matrix_citation_hub" in " ".join(signals):
        suggested_role = "method-anchor"
    elif "foundational_classic" in " ".join(signals):
        suggested_role = "theory-anchor"
    elif "user_seed" in signals:
        suggested_role = "user-seed"

    evidence = {
        "year": yr,
        "venue": row.get("venue"),
        "citation_count": cc,
        "influential_citation_count": ic,
        "authors": row.get("authors", [])[:3],
    }
    return score, signals, suggested_role, evidence


def build_context(matrix_rows, scope):
    seeds = scope.get("seeds") or []
    seed_ids = set()
    for s in seeds:
        if isinstance(s, dict):
            seed_ids |= _all_ids(s)
        elif isinstance(s, str):
            seed_ids.add(s)

    cited_by = defaultdict(int)
    graph_available = False
    for row in matrix_rows:
        refs = _ref_ids(row)
        if refs:
            graph_available = True
            for r in refs:
                cited_by[r] += 1

    if not graph_available:
        print(
            "[core_detector] no references[] fields in matrix rows; "
            "matrix_citation_hub signal will be skipped",
            file=sys.stderr,
        )

    cite_counts = [r.get("citation_count") for r in matrix_rows]
    years = [r.get("year") for r in matrix_rows]
    return {
        "seed_ids": seed_ids,
        "cited_by_count": cited_by,
        "graph_available": graph_available,
        "matrix_size": len(matrix_rows),
        "cite_p90": _percentile_threshold(cite_counts, 90),
        "year_p20": _percentile_threshold(years, 20),
    }


def load_jsonl(path):
    rows = []
    with open(path) as f:
        for i, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError as e:
                print(f"[core_detector] {path}:{i} bad JSON: {e}", file=sys.stderr)
    return rows


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--matrix", required=True, help="JSONL of matrix rows")
    parser.add_argument("--scope", required=True, help="scope.json path")
    parser.add_argument("--top-k", type=int, default=20,
                        help="emit only top-K by score (0 = all)")
    args = parser.parse_args()

    matrix_rows = load_jsonl(args.matrix)
    with open(args.scope) as f:
        scope = json.load(f)

    ctx = build_context(matrix_rows, scope)
    ranked = []
    for row in matrix_rows:
        pid = _paper_id(row)
        if not pid:
            continue
        score, signals, suggested_role, evidence = score_paper(row, ctx)
        if score <= 0:
            continue
        ranked.append({
            "paper_id": pid,
            "title": row.get("title"),
            "score": score,
            "signals": signals,
            "suggested_role": suggested_role,
            "evidence": evidence,
        })

    ranked.sort(key=lambda r: (-r["score"], r["title"] or ""))
    if args.top_k and args.top_k > 0:
        ranked = ranked[:args.top_k]

    json.dump(ranked, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    print(
        f"[core_detector] scored {len(matrix_rows)} rows, emitted {len(ranked)} candidates "
        f"(graph_available={ctx['graph_available']})",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
