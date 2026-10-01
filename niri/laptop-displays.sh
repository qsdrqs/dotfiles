#!/usr/bin/env bash
set -euo pipefail

output_exists() {
    jq -e --arg name "$1" 'has($name)' >/dev/null <<< "$outputs"
}

case "${1:-}" in
    start)
        outputs="$(niri msg --json outputs)"
        created=()
        for output in laptop-edp1 laptop-edp2; do
            if ! output_exists "$output"; then
                if ! niri msg create-virtual-output --name "$output" --width 2880 --height 1800 --refresh-rate 60; then
                    for previous in "${created[@]}"; do
                        niri msg remove-virtual-output "$previous"
                    done
                    exit 1
                fi
                created+=("$output")
            fi
        done
        if ! systemctl --user start sunshine-laptop-1.service sunshine-laptop-2.service; then
            systemctl --user stop sunshine-laptop-1.service sunshine-laptop-2.service
            for output in "${created[@]}"; do
                niri msg remove-virtual-output "$output"
            done
            exit 1
        fi
        ;;
    stop)
        systemctl --user stop sunshine-laptop-1.service sunshine-laptop-2.service
        outputs="$(niri msg --json outputs)"
        for output in laptop-edp2 laptop-edp1; do
            if output_exists "$output"; then
                niri msg remove-virtual-output "$output"
            fi
        done
        ;;
    *)
        printf 'Usage: %s {start|stop}\n' "$0" >&2
        exit 1
        ;;
esac
