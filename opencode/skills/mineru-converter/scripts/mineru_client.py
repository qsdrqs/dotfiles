#!/usr/bin/env python3
"""
mineru_client.py - HTTP client for the official MinerU FastAPI server (v3.x).

Targets `mineru-api` from opendatalab/MinerU (>= 3.0). Runs on :8000.

API endpoints used:
    POST /file_parse   multipart files[] -> JSON {results: {name: {md_content}}}
                                         or application/zip when response_format_zip=true
    GET  /docs         OpenAPI docs page (used as health probe)

Default output (one API call, ZIP mode):
    <name>.md               - Markdown with tables (HTML) and formulas (LaTeX)
    images/                 - extracted figures and charts
    <name>_content_list.json - structured content by reading order

Subcommands:
    convert   Run synchronous parse of a single PDF; write content.md + images + content_list.
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
    python mineru_client.py convert --pdf paper.pdf --out ./out --no-images --no-content-list
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
USER_AGENT = "mineru-converter-skill/0.2"
DEFAULT_TIMEOUT = 1800


def _multipart_body(fields, files):
    boundary = f"----MineruBoundary{uuid.uuid4().hex}"
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


def _post_parse(pdf_path, backend, lang, zip_mode, want_content_list,
                start_page, end_page, timeout):
    with open(pdf_path, "rb") as f:
        pdf_bytes = f.read()
    ctype, _ = mimetypes.guess_type(pdf_path)
    fields = [
        ("lang_list", lang),
        ("backend", backend),
        ("parse_method", "auto"),
        ("formula_enable", "true"),
        ("table_enable", "true"),
        ("return_md", "true"),
        ("return_content_list", "true" if want_content_list else "false"),
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
            zip_mode=True, want_content_list=True, timeout=DEFAULT_TIMEOUT):
    backend = backend or DEFAULT_BACKEND
    lang = lang or DEFAULT_LANG
    os.makedirs(out_dir, exist_ok=True)
    data, ctype, _ = _post_parse(pdf_path, backend, lang, zip_mode,
                                 want_content_list, start_page, end_page, timeout)

    result = {"backend": backend, "lang": lang, "out_dir": out_dir}

    if zip_mode or "zip" in ctype.lower():
        with zipfile.ZipFile(io.BytesIO(data)) as zf:
            zf.extractall(out_dir)
        all_files = sorted(_walk(out_dir))
        md_files = sorted(p for p in all_files if p.lower().endswith(".md"))
        img_files = sorted(p for p in all_files if _is_image(p))
        json_files = sorted(p for p in all_files if p.lower().endswith(".json"))
        result["markdown_files"] = md_files
        result["image_files"] = img_files
        result["content_files"] = json_files
        result["files"] = all_files
        return result

    payload = json.loads(data)
    results = payload.get("results") or {}
    md_paths = []
    cl_paths = []
    for name, info in results.items():
        md = info.get("md_content")
        if md:
            md_path = os.path.join(out_dir, f"{name}.md")
            with open(md_path, "w", encoding="utf-8") as f:
                f.write(md)
            md_paths.append(md_path)
        if want_content_list:
            cl = info.get("content_list")
            if cl:
                cl_path = os.path.join(out_dir, f"{name}_content_list.json")
                with open(cl_path, "w", encoding="utf-8") as f:
                    f.write(cl if isinstance(cl, str) else json.dumps(cl, ensure_ascii=False))
                cl_paths.append(cl_path)
    result["markdown_files"] = md_paths
    result["content_files"] = cl_paths
    result["mineru_version"] = payload.get("version")
    return result


def _walk(root):
    out = []
    for dirpath, _, filenames in os.walk(root):
        for fn in filenames:
            full = os.path.join(dirpath, fn)
            out.append(os.path.relpath(full, root))
    return out


def _is_image(path):
    ext = os.path.splitext(path)[1].lower()
    return ext in (".png", ".jpg", ".jpeg", ".gif", ".webp", ".bmp")


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
    pc.add_argument("--no-images", action="store_true",
                    help="Skip image extraction (switches to JSON mode, no images/ dir).")
    pc.add_argument("--no-content-list", action="store_true",
                    help="Skip content_list.json output.")
    pc.add_argument("--zip", action="store_true", dest="_zip_flag",
                    help=argparse.SUPPRESS)

    sub.add_parser("health")

    args = p.parse_args()

    if args.cmd == "health":
        ok = health()
        print(json.dumps({"base_url": BASE_URL, "reachable": ok}))
        sys.exit(0 if ok else 1)

    if not os.path.isfile(args.pdf):
        print(f"ERROR: pdf not found: {args.pdf}", file=sys.stderr)
        sys.exit(2)

    zip_mode = not args.no_images
    want_cl = not args.no_content_list

    t0 = time.monotonic()
    try:
        result = convert(args.pdf, args.out,
                         backend=args.backend, lang=args.lang,
                         start_page=args.start, end_page=args.end,
                         zip_mode=zip_mode, want_content_list=want_cl)
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
