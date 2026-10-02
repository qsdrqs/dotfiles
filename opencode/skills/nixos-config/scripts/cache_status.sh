#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat >&2 <<'EOF'
Usage: cache_status.sh [--cache <url>]... <path-or-installable>...

Report which binary caches serve each store path by requesting
<cache>/<hash>.narinfo directly. This does not use the local narinfo cache
database, so it is not affected by an unwritable ~/.cache/nix.

Arguments:
  /nix/store/... or any path resolving into the store (e.g. /run/current-system)
  *.drv            checks every output of the derivation (drv must be in the store)
  <installable>    resolved with `nix eval --raw <installable>.outPath`

Caches default to the http(s) entries of `nix config show substituters`.
Result per cache: present (HTTP 200), absent (HTTP 404), or the HTTP code
for anything else (auth errors, timeouts = 000), which is not a miss.

Examples:
  cache_status.sh /run/current-system
  cache_status.sh 'path:.#nixosConfigurations.desktop.pkgs.onnxruntime'
  cache_status.sh --cache https://cache.nixos-cuda.org /nix/store/...-foo.drv
EOF
}

caches=()
args=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --cache)
            caches+=("${2:?--cache needs a URL}")
            shift 2
            ;;
        *)
            args+=("$1")
            shift
            ;;
    esac
done

if [[ ${#args[@]} -eq 0 ]]; then
    usage
    exit 2
fi

if [[ ${#caches[@]} -eq 0 ]]; then
    read -r -a configured <<<"$(nix config show substituters)"
    for c in "${configured[@]}"; do
        if [[ "$c" == http://* || "$c" == https://* ]]; then
            caches+=("$c")
        fi
    done
fi

resolve() {
    local arg="$1" real
    if [[ "$arg" == *.drv && -e "$arg" ]]; then
        nix-store -q --outputs "$arg"
    elif [[ -e "$arg" ]]; then
        real="$(realpath "$arg")"
        if [[ "$real" != /nix/store/* ]]; then
            echo "error: $arg does not resolve into /nix/store" >&2
            return 1
        fi
        echo "$real" | cut -d/ -f1-4
    elif [[ "$arg" == /* ]]; then
        echo "error: $arg does not exist" >&2
        return 1
    else
        nix eval --raw "${arg}.outPath" && echo
    fi
}

status=0
for arg in "${args[@]}"; do
    if ! paths="$(resolve "$arg")"; then
        status=1
        continue
    fi
    while read -r path; do
        [[ -z "$path" ]] && continue
        base="$(basename "$path")"
        hash="${base:0:32}"
        present=()
        other=()
        for cache in "${caches[@]}"; do
            url="${cache%/}"
            code="$(curl -s -o /dev/null -w '%{http_code}' -m 30 "$url/$hash.narinfo" || true)"
            host="${url#*://}"
            case "$code" in
                200) present+=("$host") ;;
                404) ;;
                *) other+=("$host=HTTP$code") ;;
            esac
        done
        if [[ ${#present[@]} -gt 0 ]]; then
            line="${base:33}: ${present[*]}"
        elif [[ ${#other[@]} -gt 0 ]]; then
            line="${base:33}: not confirmed"
        else
            line="${base:33}: MISS"
        fi
        if [[ ${#other[@]} -gt 0 ]]; then
            line="$line (unknown: ${other[*]})"
        fi
        echo "$line"
    done <<<"$paths"
done
exit "$status"
