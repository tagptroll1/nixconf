#!/usr/bin/env bash

# mango-native stand-in for omarchy-monitor-state, which read Hyprland's
# `hyprctl monitors all`. wlr-randr enumerates every output including disabled
# ones (mmsg drops those from all-monitors), mmsg says which one has focus.
#
# Emits the eight lines Panel.qml reads, in order:
#   brightness percent | internal name | external name | enabled internal name
#   mirrored name | focused name | scale | displays JSON

outputs=$(wlr-randr --json 2>/dev/null) || outputs='[]'
monitors=$(mmsg get all-monitors 2>/dev/null) || monitors='{"monitors":[]}'

focused=$(jq -r '[.monitors[] | select(.active == true)][0].name // ""' <<<"$monitors")

# No backlight to drive on a desktop, and DDC is not wired up here.
echo "unavailable"

jq -r --arg focused "$focused" '
  def internal: test("^(eDP|LVDS|DSI)-");

  ([.[] | select(.name | internal)][0].name // ""),
  ([.[] | select((.name | internal) | not)][0].name // ""),
  ([.[] | select((.name | internal) and .enabled == true)][0].name // ""),
  # mango has no mirroring, so nothing is ever mirrored.
  "",
  $focused,
  ((([.[] | select(.name == $focused)][0].scale // 1) * 1000 | round / 1000) | tostring)
' <<<"$outputs"

jq -c '[.[] | {
  name,
  enabled: (.enabled == true),
  width: ([.modes[] | select(.current == true)][0].width // 0),
  height: ([.modes[] | select(.current == true)][0].height // 0)
}]' <<<"$outputs" |
  jq -c --arg focused "$focused" '[.[] | . + { focused: (.name == $focused) }]'
