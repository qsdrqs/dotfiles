#!/usr/bin/env bash
set -euo pipefail

prefix="${1:-debugger}"
workdir="$(mktemp -d "/tmp/${prefix}.XXXXXX")"
echo "$workdir"

