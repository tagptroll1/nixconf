#!/usr/bin/env bash
# waybar custom/ps4battery: DualShock charge level, hidden when no pad connected.
# hid_playstation creates this node only while the controller is connected and
# names it after the pad's MAC, so glob rather than hardcode.
shopt -s nullglob

for dir in /sys/class/power_supply/ps-controller-battery-*; do
  cap=$(<"$dir/capacity")
  status=$(<"$dir/status")

  icon="󰊴"
  class=""
  [[ $status == Charging || $status == Full ]] && icon="󰂄"
  ((cap <= 20)) && class="critical"

  printf '{"text":"%s %s%%","tooltip":"PS4 controller - %s","class":"%s"}\n' \
    "$icon" "$cap" "$status" "$class"
  exit 0
done

# Empty text hides the module.
printf '{"text":"","tooltip":"","class":""}\n'
