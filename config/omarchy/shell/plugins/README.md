# The parts

One directory per part of the desktop. Nothing here is discovered or
registered: [`shell.qml`](../shell.qml) instantiates what runs, and
[`bar/Bar.qml`](bar/Bar.qml) instantiates what sits on the bar. A directory
nobody names is dead code.

| Directory | Id | What it is | How it runs |
|---|---|---|---|
| `bar/` | — | the bar, one surface per monitor | mounted at startup |
| `bar/widgets/` | `omarchy.workspaces`, `omarchy.indicators`, `omarchy.keyboard-layout`, `omarchy.tray` | simple bar widgets | declared in `Bar.qml` |
| `bar/indicators/` | — | the marks the indicators widget shows | NightLight, Dnd, StayAwake, Spotify |
| `menu/` | `omarchy.menu` | the menu, plus its bar button | kept loaded |
| `notifications/` | `omarchy.notifications` | notification server, history, DND | service |
| `background/` | `omarchy.background` | wallpaper layer | service |
| `polkit/` | `omarchy.polkit` | authentication agent | service |
| `services/media/` | `omarchy.media` | shared MPRIS/PipeWire state | service |
| `services/discord/` | `omarchy.discord` | unread Discord mentions and the stage dock chat widget, via the ShellMentions Vencord plugin | service |
| `services/nightlight/` | `omarchy.nightlight` | wlsunset control | service |
| `clipboard/` | `omarchy.clipboard`, `omarchy.clipboard-bar` | clipboard history over cliphist: the menu's search overlay and the bar dropdown | overlay kept loaded; dropdown declared in `Bar.qml` |
| `emojis/` | `omarchy.emojis` | emoji picker | kept loaded |
| `image-picker/` | `omarchy.image-picker` | image selector for `omarchy-menu-images` | kept loaded |
| `osd/` | `omarchy.osd` | volume/brightness overlay | kept loaded |
| `stagedock/` | — | edge tabs for windows docked by the mango stage layout | kept loaded (watches `mmsg watch all-clients`) |
| `lock/` | `omarchy.lock` | session lock | service |
| `calculator/` | `omarchy.calculator` | calculator overlay | kept loaded (keeps its history) |
| `panels/audio/` … `power/` | `omarchy.audio`, `omarchy.bluetooth`, `omarchy.network`, `omarchy.tailscale`, `omarchy.protonvpn`, `omarchy.monitor`, `omarchy.power`, `omarchy.weather`, `omarchy.clock` | bar widgets with popups | declared in `Bar.qml` |
| `panels/speedtest/` | `omarchy.speedtest` | one-shot panel | built on summon, torn down on hide |
| `panels/keybindings/` | `omarchy.keybindings` | keybinding cheat sheet | built on summon, torn down on hide |
| `dev-gallery/` | `omarchy.dev-gallery` | component gallery | built on summon |

Not mounted, kept from upstream: `services/idle/`. See
[../README.md](../README.md#what-is-not-wired-up).

## What the host hands a part

A part is an `Item` whose children are the windows it draws. The host sets only
what a part declares:

- `shell` — the host, for `shell.summon(id, payload)`, `shell.hide(id)`,
  `shell.serviceFor(id)` and `shell.appLibrary`
- `omarchyPath` — `$OMARCHY_PATH`, for themes and templates

A panel or overlay the host summons implements `open(payloadJson)`, `close()`
and an `opened` property. A bar widget extends [`Ui/BarWidget`](../Ui/BarWidget.qml)
or [`Ui/Panel`](../Ui/Panel.qml) and is handed `bar` and `moduleName` by its
slot; anything else it needs is set where `Bar.qml` declares it.

Browser media dock controls are shared per browser instance: every window using the
same MPRIS player shows its advertised track and controls that player. Separate
instances are matched by process when several players match the app id; individual
windows or tabs within one instance do not have independent playback controls.

Parts that read another process (`stagedock/`, `services/discord/`,
`panels/network/`) follow the wire formats in [../CONTRACTS.md](../CONTRACTS.md).
