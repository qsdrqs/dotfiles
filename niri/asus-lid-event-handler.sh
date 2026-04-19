#!/usr/bin/env bash
set -euo pipefail

# ASUS Zenbook Duo detachable keyboard USB id
kbd_vendor="0b05"
kbd_product="1bf2"

keyboard_attached() {
    local dev
    for dev in /sys/bus/usb/devices/*; do
        [[ -r "$dev/idVendor" && -r "$dev/idProduct" ]] || continue
        if [[ "$(<"$dev/idVendor")" == "$kbd_vendor" && "$(<"$dev/idProduct")" == "$kbd_product" ]]; then
            return 0
        fi
    done
    return 1
}

action="${1:-}"

case "$action" in
    close)
        niri msg output eDP-1 off
        if ! keyboard_attached; then
            niri msg output eDP-2 off
        fi
        loginctl lock-session
        ;;
    open)
        niri msg output eDP-1 on
        if ! keyboard_attached; then
            niri msg output eDP-2 on
        fi
        ;;
    *)
        printf 'Usage: %s {open|close}\n' "$0" >&2
        exit 1
        ;;
esac
