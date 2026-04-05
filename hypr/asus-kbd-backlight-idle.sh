#!/usr/bin/env bash
set -euo pipefail

brightness_path="/sys/class/leds/asus::kbd_backlight/brightness"
state_file="${XDG_RUNTIME_DIR:-/run/user/${UID}}/kbd-backlight.level"

read_level() {
    local level
    IFS= read -r level < "$1"
    printf '%s' "$level"
}

write_level() {
    printf '%s\n' "$1" > "$brightness_path"
}

if [[ ! -e "$brightness_path" ]] || [[ ! -w "$brightness_path" ]]; then
    exit 0
fi

action="${1:-}"

case "$action" in
    off)
        current_level="$(read_level "$brightness_path")"
        if [[ "$current_level" =~ ^[0-9]+$ ]]; then
            printf '%s\n' "$current_level" > "$state_file"
        fi
        write_level 0
        ;;
    restore)
        if [[ -r "$state_file" ]]; then
            saved_level="$(read_level "$state_file")"
            if [[ "$saved_level" =~ ^[0-9]+$ ]] && (( saved_level > 0 )); then
                write_level "$saved_level"
            fi
        fi
        ;;
    *)
        printf 'Usage: %s {off|restore}\n' "$0" >&2
        exit 1
        ;;
esac
