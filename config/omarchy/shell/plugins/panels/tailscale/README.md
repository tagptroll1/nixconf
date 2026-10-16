# Tailscale widget

Bar widget for Tailscale, declared in [`Bar.qml`](../../bar/Bar.qml) beside the
network widget.

## Features

- Shows Tailscale connection state in the bar
- Left click opens a keyboard-friendly panel
- Right click toggles Tailscale on/off
- Switch between available Tailscale connections when multiple are available
- Browse machines from `tailscale status --json`
- Copy a machine's Tailscale IP, host name, or DNS name
- Pick an exit node, including Mullvad regions when the tailnet has them

## Keyboard shortcuts

Inside the panel:

- `j` / `k` or arrows: move cursor
- `enter` / `space`: activate current row
- `c`: copy selected peer IP
- `n`: copy selected peer name
- `d`: copy selected peer DNS name
- `t`: toggle Tailscale
- `r`: refresh status
- `esc`: close

## Requirements

- `services.tailscale` in the host config, with this user as `--operator` so
  the CLI can toggle it without root
- `wl-copy` for clipboard copy actions

## Icon

Renders the Tailscale mark natively as a theme-colored 3×3 dot grid, matching the official SVG silhouette while avoiding tiny-SVG rendering quirks in the bar.
