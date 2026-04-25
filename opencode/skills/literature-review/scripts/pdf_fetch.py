#!/usr/bin/env python3
"""
pdf_fetch.py - Resolve and download a PDF for a paper, with fallback chain.

Resolution order (stops at first success):
    1. arxiv_id     -> https://arxiv.org/pdf/<id>.pdf
    2. pdf_url      -> direct download (e.g. Semantic Scholar openAccessPdf.url)
    3. doi + Unpaywall API (https://api.unpaywall.org/v2/<doi>?email=...)

Output:
    Writes <out_dir>/paper.pdf and <out_dir>/manifest.json (source, url, bytes).
    Exits 0 on success, 3 on paywall (no OA copy), 1 on hard error.

Environment:
    UNPAYWALL_EMAIL   Required to query Unpaywall (their ToS asks for an email).
                      Without it, the Unpaywall step is skipped.

Input JSON (from stdin or --meta <file>):
    {"arxiv_id": "...", "doi": "...", "pdf_url": "...", "title": "...", "id": "..."}
    All fields optional except at least one of arxiv_id / doi / pdf_url.

Usage:
    echo '{"arxiv_id":"2401.12345"}' | python pdf_fetch.py --out ./out
    python pdf_fetch.py --meta meta.json --out ./out
"""
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


USER_AGENT = "literature-review-skill/0.1 (+https://github.com/)"
MIN_INTERVAL_SEC = 1.0
_last_request_at = 0.0


def _throttle():
    global _last_request_at
    elapsed = time.monotonic() - _last_request_at
    if elapsed < MIN_INTERVAL_SEC:
        time.sleep(MIN_INTERVAL_SEC - elapsed)
    _last_request_at = time.monotonic()


def _download(url, dest, retries=3, timeout=120):
    last_err = None
    for attempt in range(retries):
        _throttle()
        req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(req, timeout=timeout) as resp:
                ctype = resp.headers.get("Content-Type", "")
                # Reject HTML pages masquerading as PDF (common paywall behavior).
                if "pdf" not in ctype.lower() and not url.lower().endswith(".pdf"):
                    sniff = resp.read(512)
                    if not sniff.startswith(b"%PDF"):
                        return False, f"not a pdf (content-type={ctype})"
                    rest = resp.read()
                    with open(dest, "wb") as f:
                        f.write(sniff)
                        f.write(rest)
                    return True, len(sniff) + len(rest)
                data = resp.read()
                if not data.startswith(b"%PDF"):
                    return False, "downloaded bytes are not a PDF"
                with open(dest, "wb") as f:
                    f.write(data)
                return True, len(data)
        except urllib.error.HTTPError as e:
            last_err = f"HTTP {e.code}"
            if e.code in (429, 500, 502, 503, 504):
                time.sleep(5 * (attempt + 1))
                continue
            return False, last_err
        except urllib.error.URLError as e:
            last_err = str(e)
            time.sleep(5 * (attempt + 1))
    return False, f"failed after {retries} attempts: {last_err}"


def try_arxiv(meta, out_pdf):
    aid = meta.get("arxiv_id")
    if not aid:
        return None
    url = f"https://arxiv.org/pdf/{aid}.pdf"
    ok, info = _download(url, out_pdf)
    return {"source": "arxiv", "url": url, "ok": ok, "info": info}


def try_direct(meta, out_pdf):
    url = meta.get("pdf_url")
    if not url:
        return None
    ok, info = _download(url, out_pdf)
    return {"source": "direct", "url": url, "ok": ok, "info": info}


def try_unpaywall(meta, out_pdf):
    doi = meta.get("doi")
    if not doi:
        return None
    email = os.environ.get("UNPAYWALL_EMAIL")
    if not email:
        return {"source": "unpaywall", "ok": False, "info": "UNPAYWALL_EMAIL not set"}
    api = f"https://api.unpaywall.org/v2/{urllib.parse.quote(doi, safe='')}?email={urllib.parse.quote(email)}"
    _throttle()
    try:
        req = urllib.request.Request(api, headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=30) as resp:
            payload = json.loads(resp.read().decode("utf-8"))
    except Exception as e:
        return {"source": "unpaywall", "ok": False, "info": f"api error: {e}"}
    best = payload.get("best_oa_location") or {}
    pdf_url = best.get("url_for_pdf") or best.get("url")
    if not pdf_url:
        return {"source": "unpaywall", "ok": False, "info": "no OA copy",
                "is_oa": payload.get("is_oa", False)}
    ok, info = _download(pdf_url, out_pdf)
    return {"source": "unpaywall", "url": pdf_url, "ok": ok, "info": info,
            "host_type": best.get("host_type"), "license": best.get("license")}


def fetch(meta, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    out_pdf = os.path.join(out_dir, "paper.pdf")
    attempts = []
    for fn in (try_arxiv, try_direct, try_unpaywall):
        result = fn(meta, out_pdf)
        if result is None:
            continue
        attempts.append(result)
        if result.get("ok"):
            manifest = {
                "status": "ok",
                "source": result["source"],
                "url": result.get("url"),
                "bytes": result.get("info"),
                "pdf_path": out_pdf,
                "input_meta": meta,
                "attempts": attempts,
            }
            with open(os.path.join(out_dir, "manifest.json"), "w") as f:
                json.dump(manifest, f, indent=2, ensure_ascii=False)
            return manifest
    manifest = {
        "status": "paywalled" if attempts else "no_identifier",
        "input_meta": meta,
        "attempts": attempts,
    }
    with open(os.path.join(out_dir, "manifest.json"), "w") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    return manifest


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--meta", help="JSON file with paper metadata; default reads stdin.")
    p.add_argument("--out", required=True)
    args = p.parse_args()

    if args.meta:
        with open(args.meta) as f:
            meta = json.load(f)
    else:
        meta = json.load(sys.stdin)

    if not any(meta.get(k) for k in ("arxiv_id", "doi", "pdf_url")):
        print(json.dumps({"status": "no_identifier", "input_meta": meta}), file=sys.stderr)
        sys.exit(1)

    manifest = fetch(meta, args.out)
    json.dump(manifest, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")
    if manifest["status"] == "ok":
        sys.exit(0)
    if manifest["status"] == "paywalled":
        sys.exit(3)
    sys.exit(1)


if __name__ == "__main__":
    main()
