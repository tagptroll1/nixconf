#!/usr/bin/env bash
# Rofi confirm prompt for shutdown. Yes -> poweroff, else abort.
choice=$(printf 'No\nYes' | rofi -dmenu -p "Are you sure?")

[ "$choice" = "Yes" ] && systemctl poweroff
