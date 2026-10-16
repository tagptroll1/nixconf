#!/usr/bin/env bash
# The picker's one door into cliphist, which records the history itself
# (services.cliphist in modules/features/omarchy.nix).
set -o pipefail

cache="${XDG_RUNTIME_DIR:?}/omarchy-clipboard"

case "${1:-}" in
  list)
    mkdir -p "$cache"
    list=$(cliphist -preview-width 500 list) || exit 1
    # Thumbnails need a file. cliphist never reuses an id, so each image is
    # decoded once and the cache cannot show a stale picture.
    while IFS=$'\t' read -r id preview; do
      [[ $preview =~ ^\[\[\ binary\ data\ .*\ ([a-z]+)\ [0-9]+x[0-9]+\ \]\]$ ]] || continue
      file="$cache/$id.${BASH_REMATCH[1]}"
      [[ -s $file ]] || cliphist decode "$id" >"$file"
    done <<<"$list"
    printf '%s\n' "$list"
    ;;
  preview) cliphist decode "$2" | head -c 8192 ;;
  copy) cliphist decode "$2" | wl-copy ;;
  paste)
    cliphist decode "$2" | wl-copy || exit 1
    # The picker holds the keyboard until its surface is gone.
    sleep 0.15
    wtype -M shift -k Insert -m shift
    ;;
  delete)
    printf '%s\t\n' "$2" | cliphist delete
    rm -f "$cache/$2".*
    ;;
  wipe) cliphist wipe && rm -rf "$cache" ;;
  *)
    echo "usage: history.sh {list|preview|copy|paste|delete|wipe} [id]" >&2
    exit 2
    ;;
esac
