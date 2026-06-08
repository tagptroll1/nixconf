#!/usr/bin/env bash
# Screenshot straight to clipboard (nothing written to disk).
#   region (default): pick an area with slurp
#   full            : capture all outputs
set -euo pipefail

mode="${1:-region}"

case "$mode" in
  full)
    grim - | wl-copy --type image/png
    notify-send -t 2000 "Screenshot" "Full screen copied to clipboard"
    ;;
  region)
    geometry=$(slurp) || exit 0   # exit cleanly if selection cancelled (Esc)
    grim -g "$geometry" - | wl-copy --type image/png
    notify-send -t 2000 "Screenshot" "Region copied to clipboard"
    ;;
  *)
    echo "usage: $0 [region|full]" >&2
    exit 1
    ;;
esac
