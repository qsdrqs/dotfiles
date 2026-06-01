#!/usr/bin/env bash
# drawio-to-png.sh - Export a drawio diagram to PNG
#
# Usage:
#   scripts/drawio-to-png.sh <input.drawio> <output.png> [width]
#
# Handles NixOS environment issue: unset NIXOS_OZONE_WL to prevent
# Electron from forcing Wayland (Vulkan incompatible in headless mode).

INPUT="$1"
OUTPUT="$2"
WIDTH="${3:-1024}"

if [ -z "$INPUT" ] || [ -z "$OUTPUT" ]; then
    echo "Usage: $0 <input.drawio> <output.png> [width]"
    exit 1
fi

if [ ! -f "$INPUT" ]; then
    echo "Error: input file not found: $INPUT"
    exit 1
fi

unset NIXOS_OZONE_WL
drawio -x -f png -o "$OUTPUT" --width "$WIDTH" "$INPUT" 2>&1

if [ ! -s "$OUTPUT" ]; then
    echo "Error: no output produced from drawio export" >&2
    exit 1
fi

echo "Exported: $INPUT -> $OUTPUT"
