#!/usr/bin/env bash
set -euo pipefail

target=""

for device in /sys/bus/usb/devices/*; do
    [[ -r "$device/idVendor" && -e "$device/authorized" ]] || continue
    [[ "$(<"$device/idVendor")" == "1050" ]] || continue

    if [[ -n "$target" ]]; then
        echo "Multiple Yubico USB devices found; refusing to choose one." >&2
        exit 1
    fi

    target="$device"
done

if [[ -z "$target" ]]; then
    echo "No YubiKey found." >&2
    exit 1
fi

case "$(<"$target/authorized")" in
    0)
        next_state=1
        message="YubiKey authorized"
        ;;
    1)
        next_state=0
        message="YubiKey deauthorized"
        ;;
    *)
        echo "Unexpected USB authorization state: $target" >&2
        exit 1
        ;;
esac

printf '%s\n' "$next_state" | sudo tee "$target/authorized" >/dev/null
echo "$message: $target"
