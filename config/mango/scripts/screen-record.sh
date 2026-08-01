#!/usr/bin/env bash
# Toggle screen recording of a slurp-picked region (no audio).
# Selects compression / encoding based on length to fit discord 10MB limit.

set -euo pipefail

DIR="$HOME/screencaptures"
# Per-user runtime dir: cleared on logout, so no stale pid files across sessions.
STATE="${XDG_RUNTIME_DIR:-/tmp}/screen-record.state"
# Video max size (10MB)
MAX_BYTES="${SCREEN_RECORD_MAX_BYTES:-10000000}"
# Aim under the cap so container overhead and ABR drift can't push us over.
BUDGET=$(( MAX_BYTES * 92 / 100 ))
# Bits per pixel per frame that still looks clean on x264 slow. Desktop capture
# is mostly static, so it needs far less than the ~0.1 rule of thumb for camera
# video. Below this the picture turns to mush and downscaling wins instead.
BPP=0.045

# 5s notification
notify() { notify-send -a "Screen recording" -t 5000 "$@"; }
# custom/screenrecord in waybar listens on SIGRTMIN+8
refresh_waybar() { pkill -RTMIN+8 waybar || true; }
# Evaluate an arithmetic expression, rounded to an integer.
calc() { awk "BEGIN{ printf \"%.0f\", $* }"; }
probe() { ffprobe -v error -of default=nw=1:nk=1 "$@"; }

recording_pid() {
  [[ -f $STATE ]] || return 1
  local pid
  pid=$(sed -n 1p "$STATE")
  [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null && printf '%s' "$pid"
}

start() {
  local sel x y w h raw
  sel=$(slurp -f "%x %y %w %h") || exit 0   # exit cleanly if cancelled (Esc)
  read -r x y w h <<<"$sel"
  # h264 needs even dimensions; slurp happily returns odd ones.
  w=$((w / 2 * 2))
  h=$((h / 2 * 2))
  ((w >= 2 && h >= 2)) || { notify -u critical "Selection too small"; exit 1; }

  mkdir -p "$DIR"
  raw="$DIR/recording_$(date +%Y%m%d_%H%M%S).mkv"

  wf-recorder -y -D -g "$x,$y ${w}x${h}" -c h264_nvenc -x yuv420p \
    -p preset=p5 -p rc=vbr -p cq=23 -f "$raw" &
  printf '%s\n%s\n' "$!" "$raw" >"$STATE"

  # Encoder init failures kill wf-recorder immediately; say so instead of
  # leaving a dead indicator behind.
  sleep 1
  if ! recording_pid >/dev/null; then
    rm -f "$STATE" "$raw"
    notify -u critical "Failed to start" "codec rejected"
    exit 1
  fi

  notify "Recording started" "${w}x${h}"
  refresh_waybar
}

# Largest resolution/framerate the bitrate can carry at BPP quality.
# Resolution is dropped before framerate: legible text beats smooth motion for
# screen capture. Echoes "width height fps".
pick_format() {
  local src_w=$1 src_h=$2 src_fps=$3 bitrate=$4
  local th tw tf

  for th in "$src_h" 2160 1440 1080 900 720 540 480 360; do
    ((th <= src_h)) || continue
    tw=$(calc "int($src_w * $th / $src_h / 2) * 2")
    for tf in "$src_fps" 30 24; do
      ((tf <= src_fps)) || continue
      if (( $(calc "$bitrate >= $BPP * $tw * $th * $tf") )); then
        echo "$tw $th $tf"
        return
      fi
    done
  done

  # Nothing fits the quality target - take the floor and let it be soft.
  echo "$(calc "int($src_w * 360 / $src_h / 2) * 2") 360 24"
}

# Two-pass x264 at a bitrate computed from the duration. Two-pass because a
# single CRF pass cannot hit a size target, and x264 beats NVENC by a wide
# margin once the bitrate is this constrained.
compress() {
  local src=$1 out=$2 dur=$3
  local src_w src_h src_fps bitrate tw th tf tmp attempt size

  src_w=$(probe -select_streams v:0 -show_entries stream=width "$src")
  src_h=$(probe -select_streams v:0 -show_entries stream=height "$src")
  # avg_frame_rate, not r_frame_rate: wf-recorder writes VFR timestamps and
  # r_frame_rate reports the timebase tick rate, not the real framerate.
  src_fps=$(probe -select_streams v:0 -show_entries stream=avg_frame_rate "$src" |
    awk -F/ '{ print ($2 > 0) ? int($1 / $2 + 0.5) : 0 }')
  ((src_fps >= 1 && src_fps <= 240)) || src_fps=60

  bitrate=$(calc "$BUDGET * 8 / $dur")
  read -r tw th tf <<<"$(pick_format "$src_w" "$src_h" "$src_fps" "$bitrate")"

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' RETURN

  notify "Compressing" "${tw}x${th} @ ${tf}fps, $(calc "$bitrate / 1000") kbps"

  # ABR lands within a few percent, but "a few percent" of the cap is still
  # over the cap. Measure and retake if so.
  for attempt in 1 2 3; do
    ffmpeg -nostdin -y -v error -i "$src" -an \
      -vf "fps=$tf,scale=$tw:$th:flags=lanczos" \
      -c:v libx264 -preset slow -pix_fmt yuv420p \
      -b:v "$bitrate" -passlogfile "$tmp/pass" -pass 1 -f null /dev/null
    ffmpeg -nostdin -y -v error -i "$src" -an \
      -vf "fps=$tf,scale=$tw:$th:flags=lanczos" \
      -c:v libx264 -preset slow -pix_fmt yuv420p \
      -b:v "$bitrate" -passlogfile "$tmp/pass" -pass 2 \
      -movflags +faststart "$out"

    size=$(stat -c %s "$out")
    ((size > MAX_BYTES)) || return 0
    bitrate=$(calc "$bitrate * $MAX_BYTES / $size * 0.9")
  done

  notify -u critical "Still over limit" "$(calc "$size / 1000000") MB after $attempt tries"
  return 1
}

stop() {
  local pid raw out dur size
  pid=$1
  raw=$(sed -n 2p "$STATE")
  rm -f "$STATE"

  # SIGINT, not SIGTERM/KILL: wf-recorder only flushes the encoder and closes
  # the container on interrupt. Anything else leaves an unplayable file.
  kill -INT "$pid" 2>/dev/null || true
  while kill -0 "$pid" 2>/dev/null; do sleep 0.1; done
  refresh_waybar

  [[ -s $raw ]] || { notify -u critical "Nothing recorded" "no output file"; exit 1; }

  out="${raw%.mkv}.mp4"
  size=$(stat -c %s "$raw")
  dur=$(probe -show_entries format=duration "$raw")
  [[ $dur =~ ^[0-9.]+$ ]] || dur=0

  if ((size <= BUDGET)) || (( $(calc "$dur <= 0") )); then
    # Already small enough - stream copy, no generation loss.
    ffmpeg -nostdin -y -v error -i "$raw" -c copy -movflags +faststart "$out" \
      || { notify -u critical "Remux failed" "kept ${raw##*/}"; exit 1; }
  else
    compress "$raw" "$out" "$dur" || exit 1
  fi

  rm -f "$raw"
  wl-copy --type text/uri-list "file://$out"
  notify "Saved" "${out##*/} ($(calc "$(stat -c %s "$out") / 1000000") MB) copied to clipboard"
}

if pid=$(recording_pid); then
  stop "$pid"
else
  rm -f "$STATE"
  start
fi
