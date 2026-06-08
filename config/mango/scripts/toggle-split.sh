#!/usr/bin/env bash
# Toggle the focused monitor's tile split orientation:
#   tile          -> master left, stack right  (splits left-right)
#   vertical_tile -> master top,  stack bottom  (splits top-bottom)
# setlayout acts on the focused monitor's current tag, so this only affects
# whatever tag you're looking at on the focused output.
set -euo pipefail

cur=$(mmsg get all-monitors \
  | jq -r '.monitors[] | select(.active==true) | .layout_symbol')

case "$cur" in
  VT) mmsg dispatch setlayout,tile ;;          # currently vertical -> go horizontal
  *)  mmsg dispatch setlayout,vertical_tile ;; # anything else -> go vertical
esac
