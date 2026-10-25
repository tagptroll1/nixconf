# The shell

One long-running [Quickshell](https://quickshell.org/) instance hosts this
desktop: the bar, the menu, notifications, the background, the overlays and the
panels all live inside it. mango starts it once per session
(`exec-once=quickshell -n` in [config-qs.conf](../../mango/config-qs.conf)) and
`~/.config/quickshell` is a symlink to this directory, so this is quickshell's
default config and `qs ipc call ...` needs no `-p`.

Hosting everything in one process means shared services exist once rather than
once per window, and summoning a panel is an IPC call into something already
running instead of a cold `quickshell -p ...` start.

This is a vendored fork of omarchy's shell, cut down to this machine. The
plugin system it shipped with — manifest discovery, a registry, a `shell.json`
describing the bar, third-party plugin installs — is gone. **Everything is
declared in QML:** [`shell.qml`](shell.qml) names every service, overlay and
panel; [`plugins/bar/Bar.qml`](plugins/bar/Bar.qml) names every widget on the
bar and its settings; [`plugins/menu/MenuTree.js`](plugins/menu/MenuTree.js)
names every static menu row. Adding something means writing it there.

```
shell/
  shell.qml              the desktop: services, overlays, panels, the bar
  Commons/               Colors, Style, Border, Mango (compositor IPC), Util
  Ui/                    shared widgets: BarWidget, Panel, PopupCard, …
  services/
    AppLibrary.qml       desktop entries, icons, launching, uninstalling
  plugins/               the parts, one directory each
    bar/                 the bar, its widgets and its indicators
    menu/                the menu: tree, navigation, Packages section
    notifications/       notification server, history, DND
    background/          wallpaper layer
    calculator/  clipboard/  emojis/  image-picker/  osd/  polkit/
    lock/                session lock and its IPC target
    panels/              audio, bluetooth, network, tailscale, power, monitor,
                         weather, clock, speedtest, keybindings
    services/            media (MPRIS), nightlight, idle
    dev-gallery/         component gallery, summoned on demand
```

The directory is still called `plugins/` because that is what the upstream
layout called it, and renaming it would rewrite every import for no gain.
Nothing in there is discovered: if `shell.qml` or `Bar.qml` does not name it,
it does not run.

## What is not wired up

`plugins/services/idle/` is kept from upstream but nothing mounts it. Stay
Awake runs on the small `idleService` stub in `shell.qml` instead: the bar's
`IdleInhibitor` follows its flag, and swayidle (started by mango) honors that.

## IPC contract

Scripts and keybinds reach the shell over IPC. The `shell` target is the host;
individual parts register their own targets (`background`, `image-selector`,
`notifications`, `nightlight`, `omarchy.clock`, …).

| Method                            | Returns          | Effect                                        |
|-----------------------------------|------------------|-----------------------------------------------|
| `ping`                            | `ok`             | health check                                  |
| `applyTheme <colorsB64> <shellB64>` | `ok`           | repaint with a new palette (`omarchy-theme-set`) |
| `summon <id> <payloadJson>`       | `ok` / `unknown` | open a panel or overlay                       |
| `hide <id>`                       | —                | close it again                                |
| `toggle <id> <payloadJson>`       | —                | summon if closed, hide if open                |
| `call <id> <method> <arg>`        | string           | call a method on a mounted panel              |
| `togglePanelAt <section> <index>` | id / `unknown`   | toggle the Nth panel in a bar section         |
| `debugBarGeometry`                | JSON             | where each bar widget landed                  |

Ids are the addresses used everywhere: `omarchy.menu`, `omarchy.emojis`,
`omarchy.clipboard`, `omarchy.image-picker`, `omarchy.osd`,
`omarchy.calculator`, `omarchy.speedtest`, `omarchy.keybindings`,
`omarchy.dev-gallery`, plus the bar widgets with popups (`omarchy.audio`,
`omarchy.bluetooth`, `omarchy.network`, `omarchy.tailscale`, `omarchy.protonvpn`, `omarchy.power`, `omarchy.monitor`, `omarchy.clock`,
`omarchy.weather`). A bar widget exists once per monitor, so those route to the
copy on the focused output.

```bash
qs ipc call shell toggle omarchy.menu '{"menu":"style.theme"}'
omarchy-shell shell ping            # the same thing, via the wrapper script
```

[`omarchy-shell`](../bin/omarchy-shell) forwards IPC to the running shell; it
does not start one. Both arguments are required for `toggle` and `summon`, and
mango's `spawn` runs commands through `wordexp()`, so the JSON payload has to be
single-quoted in a keybind.

The JSON the shell reads from outside itself (mango clients, docks and
dispatch replies, the Discord bridge socket, networker's HTTP API, MPRIS
matching) is in [CONTRACTS.md](CONTRACTS.md).

## Persisted state

There is no config file. Options are code; only actual state is written, and
each part owns its own file:

| Path                                                   | Owner         |
|--------------------------------------------------------|---------------|
| `~/.cache/cliphist/db`                                 | cliphist (clipboard history) |
| `~/.local/state/omarchy/notifications{.json,/}`        | notifications |
| `~/.local/state/omarchy/settings/clock.json`           | calendar popup (week start, life bar) |
| `~/.local/state/omarchy/settings/tray.json`            | tray pins and hidden icons |
| `~/.local/state/omarchy/settings/weather.json`         | chosen weather location |
| `~/.local/state/omarchy/current/`                      | current theme and background symlinks |

Theme colors come from the active theme's `colors.toml` / `shell.toml` through
`Commons/Colors.qml`, pushed in live by `omarchy-theme-set` over
`shell applyTheme`.

## Working on it

Quickshell 0.3.1 hot-reloads edits to these QML files; `qs log -t 30` shows
`Reloading configuration...` followed by `Configuration Loaded`. Nothing
respawns the process after `qs kill`: a manual restart needs `quickshell -n -d`
(mango only starts it at login). Avoid `qs ipc show` with duplicate per-monitor
targets; read the IPC surface here instead.

`qmllint` needs the Quickshell import paths in [`.qmlls.ini`](.qmlls.ini). The
pure-JS parts (`MenuTree.js`, `MenuModel.js`, `NixPackages.js`, `BarModel.js`)
export through `module.exports`, so node can exercise them directly.
