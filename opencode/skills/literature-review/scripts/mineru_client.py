#!/usr/bin/env python3
"""
mineru_client.py - HTTP client for the official MinerU FastAPI server (v3.x).

Targets `mineru-api` from opendatalab/MinerU (>= 3.0). Runs on :8000.

API endpoints used:
    POST /file_parse   multipart files[] -> JSON {results: {name: {md_content}}}
                                         or application/zip when response_format_zip=true
    GET  /docs         OpenAPI docs page (used as health probe)

Subcommands:
    convert   Run synchronous parse of a single PDF; write content.md.
    health    Probe the server; exit 0 if reachable.

Environment:
    MINERU_URL      Base URL, default http://localhost:8000
    MINERU_BACKEND  Parsing backend, default "pipeline".
                    Options: pipeline, hybrid-auto-engine, vlm-auto-engine,
                             hybrid-http-client, vlm-http-client.
    MINERU_LANG     OCR language hint, default "en".
                    Use "ch" for Chinese+English, "en" for English, etc.

Usage:
    python mineru_client.py convert --pdf paper.pdf --out ./out
    python mineru_client.py convert --pdf paper.pdf --out ./out --backend pipeline --lang en
    python mineru_client.py health
"""
import argparse
import io
import json
import mimetypes
import os
import sys
import time
import urllib.error
import urllib.request
import uuid
import zipfile


BASE_URL = os.environ.get("MINERU_URL", "http://localhost:8000").rstrip("/")
DEFAULT_BACKEND = os.environ.get("MINERU_BACKEND", "pipeline")
DEFAULT_LANG = os.environ.get("MINERU_LANG", "en")
USER_AGENT = "literature-review-skill/0.1"
DEFAULT_TIMEOUT = 1800


def _multipart_body(fields, files):
    boundary = f"----LRBoundary{uuid.uuid4().hex}"
    buf = io.BytesIO()
    for name, value in fields:
        buf.write(f"--{boundary}\r\n".encode())
        buf.write(f'Content-Disposition: form-data; name="{name}"\r\n\r\n'.encode())
        buf.write(str(value).encode())
        buf.write(b"\r\n")
    for name, (filename, content, ctype) in files:
        buf.write(f"--{boundary}\r\n".encode())
        buf.write(
            f'Content-Disposition: form-data; name="{name}"; filename="{filename}"\r\n'.encode()
        )
        buf.write(f"Content-Type: {ctype}\r\n\r\n".encode())
        buf.write(content)
        buf.write(b"\r\n")
    buf.write(f"--{boundary}--\r\n".encode())
    return buf.getvalue(), f"multipart/form-data; boundary={boundary}"


def _post_parse(pdf_path, backend, lang, zip_mode, start_page, end_page, timeout):
    with open(pdf_path, "rb") as f:
        pdf_bytes = f.read()
    ctype, _ = mimetypes.guess_type(pdf_path)
    # MinerU /file_parse takes repeated form parts. Encode both "lang_list"
    # and "files" as ordered multipart entries so the server sees them as
    # lists even with a single element.
    fields = [
        ("lang_list", lang),
        ("backend", backend),
        ("parse_method", "auto"),
        ("formula_enable", "true"),
        ("table_enable", "true"),
        ("return_md", "true"),
        ("return_content_list", "true"),
        ("return_images", "true" if zip_mode else "false"),
        ("response_format_zip", "true" if zip_mode else "false"),
        ("start_page_id", str(start_page)),
        ("end_page_id", str(end_page)),
    ]
    files = [("files", (os.path.basename(pdf_path), pdf_bytes, ctype or "application/pdf"))]
    body, content_type = _multipart_body(fields, files)
    req = urllib.request.Request(
        f"{BASE_URL}/file_parse",
        data=body,
        headers={"User-Agent": USER_AGENT, "Content-Type": content_type},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=timeout) as resp:
        return resp.read(), resp.headers.get("Content-Type", ""), resp.status


def convert(pdf_path, out_dir, backend=None, lang=None, start_page=0, end_page=99999,
            zip_mode=False, timeout=DEFAULT_TIMEOUT):
    backend = backend or DEFAULT_BACKEND
    lang = lang or DEFAULT_LANG
    os.makedirs(out_dir, exist_ok=True)
    data, ctype, _ = _post_parse(pdf_path, backend, lang, zip_mode, start_page, end_page, timeout)

    result = {"backend": backend, "lang": lang, "out_dir": out_dir}

    if zip_mode or "zip" in ctype.lower():
        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            zf.extractall(out_dir)
        md_files = sorted(p for p in _walk(out_dir) if p.lower().endswith(".md"))
        result["markdown_files"] = md_files
        result["files"] = sorted(_walk(out_dir))
        return result

    payload = json.loads(data)
    results = payload.get("results") or {}
    md_paths = []
    for name, info in results.items():
        md = info.get("md_content")
        if md:
            md_path = os.path.join(out_dir, f"{name}.md")
            with open(md_path, "w", encoding="utf-8") as f:
                f.write(md)
            md_paths.append(md_path)
        cl = info.get("content_list")
        if cl:
            with open(os.path.join(out_dir, f"{name}_content_list.json"), "w",
                      encoding="utf-8") as f:
                f.write(cl if isinstance(cl, str) else json.dumps(cl, ensure_ascii=False))
    result["markdown_files"] = md_paths
    result["mineru_version"] = payload.get("version")
    return result


def _walk(root):
    out = []
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            out.append(os.path.relpath(full, root))
    return out


def health():
    try:
        req = urllib.request.Request(BASE_URL + "/docs", headers={"User-Agent": USER_AGENT})
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status == 200
    except Exception:
        return False


def main():
    p = argparse.ArgumentParser()
    sub = p.add_subparsers(dest="cmd", required=True)

    pc = sub.add_parser("convert")
    pc.add_argument("--pdf", required=True)
    pc.add_argument("--out", required=True)
    pc.add_argument("--backend", default=None,
                    help=f"default: $MINERU_BACKEND or {DEFAULT_BACKEND}")
    pc.add_argument("--lang", default=None, help="default: $MINERU_LANG or en")
    pc.add_argument("--start", type=int, default=0)
    pc.add_argument("--end", type=int, default=99999)
    pc.add_argument("--zip", action="store_true",
                    help="Request response_format_zip=true (saves images too).")

    sub.add_parser("health")

    args = p.parse_args()

    if args.cmd == "health":
        ok = health()
        print(json.dumps({"base_url": BASE_URL, "reachable": ok}))
        sys.exit(0 if ok else 1)

    if not os.path.isfile(args.pdf):
        print(f"ERROR: pdf not found: {args.pdf}", file=sys.stderr)
        sys.exit(2)

    t0 = time.monotonic()
    try:
        result = convert(args.pdf, args.out,
                         backend=args.backend, lang=args.lang,
                         start_page=args.start, end_page=args.end,
                         zip_mode=args.zip)
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", errors="replace")[:500]
        print(json.dumps({"status": "http_error", "code": e.code, "reason": e.reason,
                          "body": body}), file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(json.dumps({"status": "unreachable", "error": str(e)}), file=sys.stderr)
        sys.exit(1)

    result["elapsed_sec"] = round(time.monotonic() - t0, 2)
    json.dump(result, sys.stdout, indent=2, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
