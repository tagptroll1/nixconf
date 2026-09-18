#!/usr/bin/env bash
# Screenshot straight to clipboard (nothing written to disk).
#   region (default): pick an area with slurp
#   full            : capture all outputs
#   save            : pick an area, write it to ~/Pictures/Screenshots and copy it
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
  save)
    geometry=$(slurp) || exit 0   # exit cleanly if selection cancelled (Esc)
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
    grim -g "$geometry" - | tee "$file" | wl-copy --type image/png
    # --exec rides along as the omarchy-exec-argv hint: clicking the toast opens
    # the folder in COSMIC Files.
    omarchy-notification-send -t 5000 "Screenshot saved" "$file" \
      --exec cosmic-files "$dir"
    ;;
  *)
    echo "usage: $0 [region|full|save]" >&2
    exit 1
    ;;
esac
