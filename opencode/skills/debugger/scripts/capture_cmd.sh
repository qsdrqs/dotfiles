#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage:
  capture_cmd.sh [--workdir <dir>] [--prefix <name>] -- <command> [args...]

Runs a command, captures combined stdout/stderr to a file, writes exit code,
and prints the workdir path.

Examples:
  capture_cmd.sh -- make test
  capture_cmd.sh --prefix repro -- pytest -q
  capture_cmd.sh --workdir /tmp/my-debug -- ./app --flag
EOF
}

workdir=""
prefix="debugger"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --workdir)
      workdir="${2:-}"
      shift 2
      ;;
    --prefix)
      prefix="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    *)
      echo "error: unexpected argument: $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ $# -lt 1 ]]; then
  usage
  exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -z "$workdir" ]]; then
  workdir="$("$script_dir/mk_workdir.sh" "$prefix")"
fi

mkdir -p "$workdir"

printf '%q ' "$@" >"$workdir/command.sh"
echo >>"$workdir/command.sh"

{
  echo "date: $(date -Is 2>/dev/null || date)"
  echo "pwd: $(pwd)"
  echo "user: $(id -un 2>/dev/null || true)"
  echo "hostname: $(hostname 2>/dev/null || true)"
} >"$workdir/meta.txt" || true

set +e
"$@" >"$workdir/output.txt" 2>&1
exit_code=$?
set -e

echo "$exit_code" >"$workdir/exit_code.txt"

echo "$workdir"
exit "$exit_code"

