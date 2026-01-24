#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: find_nixos_option.sh <option-path> [--dotfiles <path>]

Examples:
  find_nixos_option.sh services.openssh.enable
  find_nixos_option.sh programs.ssh.startAgent --dotfiles ~/dotfiles

This script is a helper for quickly locating:
  1) Option definitions in nixpkgs' NixOS modules (best-effort)
  2) Option usage in nixpkgs modules and (optionally) your dotfiles repo

It relies on nixpkgs source pointed to by $NIX_PATH (nixpkgs=/nix/store/...-source).
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || $# -lt 1 ]]; then
  usage
  exit 2
fi

option_path="$1"
shift

prefix_path="$option_path"
leaf_key="$option_path"
if [[ "$option_path" == *.* ]]; then
  prefix_path="${option_path%.*}"
  leaf_key="${option_path##*.}"
fi

dotfiles_path=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dotfiles)
      dotfiles_path="${2:-}"
      shift 2
      ;;
    *)
      echo "error: unknown argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
nixpkgs_src="$("$script_dir/nixpkgs_src.sh")"
modules_dir="$nixpkgs_src/nixos/modules"

echo "nixpkgs: $nixpkgs_src"
echo "modules: $modules_dir"
echo "option:  $option_path"
echo "prefix:  $prefix_path"
echo "leaf:    $leaf_key"
echo

echo "[1/3] Locate likely module definitions (best-effort anchors)"
rg -n --no-heading -S -F "${prefix_path} = {" "$modules_dir" || true
rg -n --no-heading -S -F "${prefix_path} =" "$modules_dir" || true
echo

echo "[2/3] Locate leaf mkOption declarations (usually within the module found above; can be noisy)"
mapfile -t candidate_files < <(
  rg -l -S -F "${prefix_path} = {" "$modules_dir" || true
)
if [[ ${#candidate_files[@]} -eq 0 ]]; then
  mapfile -t candidate_files < <(
    rg -l -S -F "${prefix_path} =" "$modules_dir" || true
  )
fi

if [[ ${#candidate_files[@]} -eq 0 ]]; then
  echo "note: no candidate files found for prefix; skipping leaf mkOption search"
else
  rg -n --no-heading -S -F "${leaf_key} = lib.mkOption" "${candidate_files[@]}" || true
  rg -n --no-heading -S -F "${leaf_key} = mkOption" "${candidate_files[@]}" || true
fi
echo

echo "[3/3] Search for option usage in nixpkgs modules"
rg -n --no-heading -S -F "${option_path}" "$modules_dir" || true
echo

if [[ -n "$dotfiles_path" ]]; then
  echo "[dotfiles] Search for option usage in dotfiles"
  if [[ ! -d "$dotfiles_path" ]]; then
    echo "error: --dotfiles path does not exist: $dotfiles_path" >&2
    exit 2
  fi
  rg -n --no-heading -S -F "${option_path}" "$dotfiles_path" || true
  echo
fi
