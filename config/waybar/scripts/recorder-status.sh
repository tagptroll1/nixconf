#!/usr/bin/env bash
# waybar custom/screenrecord: red dot while screen-record.sh is recording.
# Runs once at startup, then only when the recorder sends SIGRTMIN+8.
STATE="${XDG_RUNTIME_DIR:-/tmp}/screen-record.state"

pid=$([[ -f $STATE ]] && sed -n 1p "$STATE")
if [[ -n ${pid:-} ]] && kill -0 "$pid" 2>/dev/null; then
  printf '{"text":"","tooltip":"Recording - click to stop","class":"recording"}\n'
else
  # Empty text hides the module.
  printf '{"text":"","tooltip":"","class":""}\n'
fi
