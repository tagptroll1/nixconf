# Proton VPN widget

Bar widget for Proton VPN, declared in [`Bar.qml`](../../bar/Bar.qml) beside the
Tailscale widget. Each Proton server is a NetworkManager WireGuard profile; the
widget lists every `wireguard` profile NM knows.

## Features

- Proton mark in the bar: dim and crossed when off, pulsing while connecting
- Left click opens the panel, right click toggles, middle click refreshes
- Toggle reconnects the most recently used server (NM's connection timestamp)
- Exit IP, country and ISP from Proton's `api.protonvpn.ch/vpn/location`, and
  your real IP when disconnected
- Tunnel address and live traffic counters while connected
- Click a server to switch to it; the active tunnel is dropped first

## Keyboard shortcuts

- `j` / `k` or arrows: move cursor
- `enter` / `space`: activate row (toggle, copy, connect)
- `t`: toggle
- `c`: copy public IP
- `r`: refresh
- `esc`: close

The widget stays off the bar until NetworkManager has a WireGuard profile, and
logs how to import one to `qs log`. It appears on its own once one exists.

## Adding a server

Download a WireGuard config from account.protonvpn.com → Downloads. The file
name becomes the interface name, so keep it 15 characters or less.

```bash
nmcli connection import type wireguard file ~/Downloads/proton-nl.conf
nmcli connection modify proton-nl connection.autoconnect no \
  ipv4.dns-priority -50 ipv6.dns-priority -50
nmcli connection down proton-nl
```

Import activates the tunnel and enables autoconnect; the modify turns that
off, and the negative DNS priority makes Proton's resolver the only one used
while it is up, so lookups cannot leak to the LAN resolver.

## Requirements

- NetworkManager, with this user in the `networkmanager` group
- `networking.firewall.checkReversePath = "loose"` (currently set by
  `services.tailscale.useRoutingFeatures = "client"`); strict reverse-path
  filtering drops the tunnel's replies
- `curl`, `wl-copy`
