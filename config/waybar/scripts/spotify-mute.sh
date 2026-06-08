#!/usr/bin/env bash
# Toggle mute on Spotify's audio stream (pipewire node via wireplumber).
set -euo pipefail
id=$(pw-dump | jq -r '
  .[] | select(.info.props["media.class"]=="Stream/Output/Audio")
       | select((.info.props["application.name"] // "") | ascii_downcase | test("spotify"))
       | .id' | head -n1)
[ -n "${id:-}" ] && exec wpctl set-mute "$id" toggle
