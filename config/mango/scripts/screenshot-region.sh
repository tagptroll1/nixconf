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
    send-notification -t 2000 "Screenshot" "Full screen copied to clipboard"
    ;;
  region)
    geometry=$(slurp) || exit 0   # exit cleanly if selection cancelled (Esc)
    grim -g "$geometry" - | wl-copy --type image/png
    send-notification -t 2000 "Screenshot" "Region copied to clipboard"
    ;;
  save)
    geometry=$(slurp) || exit 0   # exit cleanly if selection cancelled (Esc)
    dir="$HOME/Pictures/Screenshots"
    mkdir -p "$dir"
    file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"
    grim -g "$geometry" - | tee "$file" | wl-copy --type image/png
    # Keep the action listener alive without blocking the screenshot caller.
    (
      action=$(notify-send --app-name send-notification --category info \
        --action default='Open folder' -u normal -i dialog-information \
        -t 5000 -- "Screenshot saved" "$file")
      if [[ $action == default ]]; then
        cosmic-files "$dir"
      fi
    ) &
    ;;
  *)
    echo "usage: $0 [region|full|save]" >&2
    exit 1
    ;;
esac
