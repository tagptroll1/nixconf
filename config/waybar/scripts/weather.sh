#!/usr/bin/env bash
# Bergen, Norway weather for waybar. Emits JSON: nerd-font icon + temp °C.
# WWO weather codes from wttr.in mapped to condition glyphs.
# Icons set via \u escapes — pasted glyphs get stripped on save.
set -euo pipefail

# nf-weather glyphs (U+E3xx).
I_SUN=$''; I_PCLOUD=$''; I_CLOUD=$''; I_FOG=$''
I_THUNDER=$''; I_SNOW=$''; I_SLEET=$''; I_RAIN=$''
I_WIND=$''; I_OFF=$''

# Retry on failure (startup network race, wttr.in flakiness): 3 attempts, 5s apart.
json=""
for attempt in 1 2 3; do
  if json=$(curl -sf --max-time 8 'https://wttr.in/Bergen?format=j1' 2>/dev/null); then
    break
  fi
  [ "$attempt" -lt 3 ] && sleep 5
done
if [ -z "$json" ]; then
  printf '{"text":"%s","tooltip":"vær: frakoblet"}\n' "$I_OFF"
  exit 0
fi

cur=$(echo "$json" | jq -r '.current_condition[0]')
code=$(echo "$cur"  | jq -r '.weatherCode')
temp=$(echo "$cur"  | jq -r '.temp_C')
kmph=$(echo "$cur"  | jq -r '.windspeedKmph')

# wttr.in lang_nb is unreliable (returns English), so map the WWO code to a
# Norwegian description and a condition glyph ourselves.
case "$code" in
  113)                     icon="$I_SUN";     desc="Klart" ;;
  116)                     icon="$I_PCLOUD";  desc="Delvis skyet" ;;
  119|122)                 icon="$I_CLOUD";   desc="Skyet" ;;
  143|248|260)             icon="$I_FOG";     desc="Tåke" ;;
  200|386|389)             icon="$I_THUNDER"; desc="Torden" ;;
  392|395)                 icon="$I_THUNDER"; desc="Torden med snø" ;;
  179|227|230|323|326|329|332|335|338|368|371) icon="$I_SNOW"; desc="Snø" ;;
  182|185|281|284|311|314|317|320|350|362|365|374|377)  icon="$I_SLEET"; desc="Sludd/is" ;;
  176|263|266|293|296|299|302|305|308|353|356|359)      icon="$I_RAIN";  desc="Regn" ;;
  *)                       icon="$I_CLOUD";   desc="Skyet" ;;
esac

# km/h -> m/s, rounded.
wind=$(awk -v k="$kmph" 'BEGIN{printf "%.0f", k/3.6}')

# High wind (>=11 m/s) overrides the condition glyph with a wind icon.
if [ "$wind" -ge 11 ] 2>/dev/null; then icon="$I_WIND"; fi

printf '{"text":"%s %s°","tooltip":"Bergen: %s, %s°C, vind %s m/s"}\n' \
  "$icon" "$temp" "$desc" "$temp" "$wind"
