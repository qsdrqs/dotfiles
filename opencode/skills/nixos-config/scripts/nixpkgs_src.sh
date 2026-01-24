#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: nixpkgs_src.sh

Print the nixpkgs source path pointed to by $NIX_PATH (expects an entry like: nixpkgs=/nix/store/...-source).
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

nix_path="${NIX_PATH:-}"
if [[ -z "$nix_path" ]]; then
  echo "error: NIX_PATH is empty; cannot locate nixpkgs source" >&2
  exit 1
fi

nixpkgs_src="$(
  printf '%s' "$nix_path" \
    | tr ':' '\n' \
    | sed -n 's/^nixpkgs=//p' \
    | head -n 1
)"

if [[ -z "$nixpkgs_src" ]]; then
  echo "error: NIX_PATH does not contain a nixpkgs=... entry" >&2
  exit 1
fi

if [[ ! -d "$nixpkgs_src" ]]; then
  echo "error: nixpkgs source path does not exist: $nixpkgs_src" >&2
  exit 1
fi

printf '%s\n' "$nixpkgs_src"
