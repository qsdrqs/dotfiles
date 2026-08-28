#!/usr/bin/env bash
set -euo pipefail

prefix="${1:-researcher}"
mkdir -p /tmp/opencode
workdir="$(mktemp -d "/tmp/opencode/${prefix}.XXXXXX")"
echo "$workdir"
