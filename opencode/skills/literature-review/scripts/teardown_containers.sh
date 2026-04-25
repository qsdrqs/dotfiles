#!/usr/bin/env bash
set -e
CONTAINER_CMD=$(command -v podman || command -v docker || true)
if [ -z "$CONTAINER_CMD" ]; then
    echo "ERROR: neither podman nor docker found" >&2
    exit 1
fi
if $CONTAINER_CMD rm -f mineru >/dev/null 2>&1; then
    echo "[ok ] removed mineru"
else
    echo "[--] mineru not present"
fi
