#!/usr/bin/env bash
# Act on the player waybar currently displays, not just spotify.
# Selection mirrors mediaplayer.py: prefer the most recently added Playing
# player, else fall back to the first player. If no player exists, launch spotify.
set -euo pipefail

action="${1:-play-pause}"

# Launch spotify hidden (mango windowrule isnamedscratchpad:1), then poll until its
# MPRIS interface accepts play. Avoids the "No player could handle this command"
# race on cold start. ~10s budget.
launch_spotify() {
  setsid -f spotify >/dev/null 2>&1
  for _ in $(seq 1 40); do
    playerctl -p spotify play 2>/dev/null && exit 0
    sleep 0.25
  done
  exit 0
}

mapfile -t players < <(playerctl -l 2>/dev/null || true)

# focus-spotify: pause every other player, then play/launch spotify
if [ "$action" = "focus-spotify" ]; then
  for p in "${players[@]}"; do
    [ "$p" = "spotify" ] && continue
    [ "$(playerctl -p "$p" status 2>/dev/null || true)" = "Playing" ] && playerctl -p "$p" pause 2>/dev/null || true
  done
  if printf '%s\n' "${players[@]}" | grep -qx "spotify"; then
    exec playerctl -p spotify play
  fi
  launch_spotify
fi

if [ "${#players[@]}" -eq 0 ]; then
  # nothing running: only meaningful for play/pause -> launch spotify hidden
  [ "$action" = "play-pause" ] && launch_spotify
  exit 0
fi

target=""
for (( i=${#players[@]}-1; i>=0; i-- )); do
  if [ "$(playerctl -p "${players[$i]}" status 2>/dev/null || true)" = "Playing" ]; then
    target="${players[$i]}"
    break
  fi
done

# none playing. mopidy runs as a persistent idle player, so "no players" is never
# true here; key off resumability instead. play-pause: resume a Paused player
# (prefer the one waybar shows), or launch spotify if nothing is resumable.
# next/previous: just act on the displayed player, falling back to the first.
if [ -z "$target" ]; then
  displayed=""
  state="${XDG_RUNTIME_DIR:-/tmp}/waybar-media-displayed"
  [ -r "$state" ] && displayed="$(cat "$state")"
  printf '%s\n' "${players[@]}" | grep -qx "$displayed" || displayed=""

  if [ "$action" = "play-pause" ]; then
    if [ -n "$displayed" ] && [ "$(playerctl -p "$displayed" status 2>/dev/null || true)" = "Paused" ]; then
      target="$displayed"
    else
      for p in "${players[@]}"; do
        [ "$(playerctl -p "$p" status 2>/dev/null || true)" = "Paused" ] && { target="$p"; break; }
      done
    fi
    # nothing playing or paused (e.g. only idle mopidy) -> start spotify
    [ -z "$target" ] && launch_spotify
  else
    target="${displayed:-${players[0]}}"
  fi
fi

exec playerctl -p "$target" "$action"
