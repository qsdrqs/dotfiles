#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE' >&2
Usage: pdf_to_text.sh <input.pdf> [output.txt]

Converts a PDF to text using `pdftotext` (Poppler). If your system provides `pdftotxt` instead,
this script will use it.

Notes:
- Uses layout-preserving mode for better readability.
- Writes UTF-8 text.
USAGE
}

if [[ $# -lt 1 || $# -gt 2 ]]; then
  usage
  exit 2
fi

in_pdf="$1"
out_txt="${2:-}"

if [[ ! -f "$in_pdf" ]]; then
  echo "[ERROR] Input PDF not found: $in_pdf" >&2
  exit 1
fi

bin=""
if command -v pdftotext >/dev/null 2>&1; then
  bin="pdftotext"
elif command -v pdftotxt >/dev/null 2>&1; then
  bin="pdftotxt"
else
  echo "[ERROR] Need `pdftotext` (Poppler). Neither `pdftotext` nor `pdftotxt` found in PATH." >&2
  exit 1
fi

args=(-layout -enc UTF-8)

if [[ -n "$out_txt" ]]; then
  "$bin" "${args[@]}" -- "$in_pdf" "$out_txt"
  echo "[OK] Wrote: $out_txt" >&2
else
  "$bin" "${args[@]}" -- "$in_pdf" -
fi

