#!/usr/bin/env python3
"""
paywall_browser.py - Thin helper for the Stage C chrome-devtools fallback.

This script does NOT drive Chrome. The main agent drives the chrome-devtools
MCP directly because:
  - Only the main agent has MCP tool access.
  - Navigation state (cookies, login) is sticky inside the MCP session.
  - Detecting and clicking the right download element requires reasoning.

This script is a thin helper that:
  - prepare : turns a paywalled manifest into a navigation recipe for the
              main agent (picks publisher strategy + landing URL).
  - verify  : confirms a downloaded file is a real PDF and rewrites
              manifest.json so the rest of the pipeline (MinerU, section
              split, Zotero import) sees status=ok.

Usage:
    python paywall_browser.py prepare --manifest papers/<id>/manifest.json
    python paywall_browser.py verify  --manifest papers/<id>/manifest.json \\
                                       --pdf     papers/<id>/paper.pdf

See references/paywall-fallback.md for publisher-specific strategies.
"""
import argparse
import json
import os
import re
import sys
import urllib.parse


PUBLISHER_MAP = [
    (r"^10\.1109/", "ieee_xplore", "ieee",
     "Landing URL: ieeexplore.ieee.org/document/<arnumber>. "
     "Click the 'Download PDF' button; real PDF served via "
     "/stamp/stamp.jsp?arnumber=... Requires institutional cookie."),
    (r"^10\.1145/", "acm_dl", "acm",
     "Direct PDF: https://dl.acm.org/doi/pdf/<doi>. "
     "Some DOIs redirect through a license check; follow redirects."),
    (r"^10\.1007/", "springer", "springer",
     "Direct PDF: https://link.springer.com/content/pdf/<doi>.pdf. "
     "If 403, the paper is not OA and fallback should stop."),
    (r"^10\.1016/", "elsevier", "elsevier",
     "sciencedirect.com/science/article/pii/<pii>. Most not OA; skip if no "
     "institutional session is detected."),
    (r"^10\.1038/", "nature", "nature",
     "nature.com/articles/<id>. Check open-access badge; if closed, skip."),
    (r"^10\.1002/", "wiley", "wiley",
     "onlinelibrary.wiley.com/doi/<doi>. Click 'PDF' tab; download link "
     "opens in modal."),
    (r"^10\.1080/", "taylor_francis", "taylor_francis",
     "tandfonline.com/doi/pdf/<doi>. Requires session cookie."),
]


GENERIC_HINT = (
    "Generic strategy: navigate to the landing URL, then look for an <a> "
    "element whose href ends with .pdf or whose text contains 'Download' / "
    "'PDF'. Fall back to scanning network requests for a PDF content-type."
)


def match_strategy(doi):
    for regex, name, strategy_id, hint in PUBLISHER_MAP:
        if re.search(regex, doi):
            return name, strategy_id, hint
    return "unknown", "generic", GENERIC_HINT


def _landing_url(doi):
    return f"https://doi.org/{urllib.parse.quote(doi, safe='/')}"


def prepare(args):
    with open(args.manifest) as f:
        manifest = json.load(f)
    if manifest.get("status") == "ok":
        print(f"[paywall] {args.manifest} already ok, nothing to prepare",
              file=sys.stderr)
        return 0
    meta = manifest.get("input_meta") or {}
    doi = meta.get("doi")
    if not doi:
        print(f"[paywall] {args.manifest} has no DOI; paywall fallback not applicable",
              file=sys.stderr)
        return 1
    publisher, strategy_id, hint = match_strategy(doi)
    recipe = {
        "doi": doi,
        "landing_url": _landing_url(doi),
        "publisher": publisher,
        "strategy": strategy_id,
        "hint": hint,
        "paper_dir": os.path.dirname(os.path.abspath(args.manifest)),
        "expected_output": os.path.join(
            os.path.dirname(os.path.abspath(args.manifest)), "paper.pdf"
        ),
        "arxiv_id_if_any": meta.get("arxiv_id"),
        "title": meta.get("title"),
    }
    json.dump(recipe, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


def verify(args):
    if not os.path.exists(args.pdf):
        print(f"[paywall] missing {args.pdf}", file=sys.stderr)
        return 1
    with open(args.pdf, "rb") as f:
        head = f.read(512)
    if not head.startswith(b"%PDF"):
        print(f"[paywall] {args.pdf} is not a PDF (first 4 bytes: {head[:4]!r})",
              file=sys.stderr)
        return 1
    size = os.path.getsize(args.pdf)
    if size < 10_000:
        print(f"[paywall] {args.pdf} suspiciously small ({size} bytes); "
              f"likely a denied-access stub",
              file=sys.stderr)
        return 2
    with open(args.manifest) as f:
        manifest = json.load(f)
    manifest["status"] = "ok"
    manifest["source"] = "chrome-devtools"
    manifest["via"] = "paywall_fallback"
    manifest["bytes"] = size
    manifest["pdf_path"] = os.path.abspath(args.pdf)
    with open(args.manifest, "w") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
    json.dump(
        {"status": "ok", "pdf_path": manifest["pdf_path"], "bytes": size},
        sys.stdout, ensure_ascii=False, indent=2,
    )
    sys.stdout.write("\n")
    return 0


def main():
    parser = argparse.ArgumentParser(description="Stage C paywall helper.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    p_prep = sub.add_parser("prepare", help="Emit a navigation recipe for chrome-devtools")
    p_prep.add_argument("--manifest", required=True)
    p_prep.set_defaults(fn=prepare)

    p_ver = sub.add_parser("verify", help="Verify a downloaded PDF and update manifest")
    p_ver.add_argument("--manifest", required=True)
    p_ver.add_argument("--pdf", required=True)
    p_ver.set_defaults(fn=verify)

    args = parser.parse_args()
    sys.exit(args.fn(args))


if __name__ == "__main__":
    main()
