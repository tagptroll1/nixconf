# omarchy shell (vendored, ported to mango)

Quickshell desktop lifted out of [basecamp/omarchy](https://github.com/basecamp/omarchy),
rev `946704f30950576731d91a732b743f7c7fa8b188` (version 4.0.0.alpha), with its
Hyprland dependencies rewritten against mango / wlroots.

Layout mirrors upstream so a refresh is an rsync from a fresh checkout:

| path                        | upstream         | notes                                    |
|-----------------------------|------------------|------------------------------------------|
| `shell/`                    | `shell/`         | the quickshell config, patched (below)   |
| `default/omarchy/`          | same             | launcher hide list (the menu definition is QML now) |
| `themes/`                   | same             | all 22 upstream themes, backgrounds and previews included |
| `default/themed/`           | same             | the `*.tpl` `omarchy-theme-set` renders per theme |
| `bin/`                      | `bin/`           | only the helpers the shell actually calls, taken one at a time |

Not vendored: the rest of `bin/` (~440 Arch/Hyprland bash helpers), `install/`,
the rest of `default/` (including `default/fonts/`).

## Wiring

- `~/.config/quickshell` -> `shell/`, so `shell.qml` sits at the root of it and
  quickshell treats it as the **default** config: `quickshell -n` starts it and
  `qs ipc call <target> <method>` reaches it, no `-c`/`-p` needed.
- `~/.config/omarchy` -> this directory; `config-qs.conf` sets `OMARCHY_PATH` to it.
- `~/.local/state/omarchy/current/` is mutable state, owned by
  `omarchy-theme-set` exactly as upstream: it stages the picked theme there,
  renders `default/themed/*.tpl` into it and repoints `background`. Nothing in
  nix manages those paths; the home module only seeds `tokyo-night` on the
  first activation that finds no theme staged.
- The two symlinks are made in `modules/features/omarchy.nix`, which also packages the
  vendored `bin/` helpers into `environment.systemPackages` so they land on PATH
  with their runtime deps pinned (upstream instead relies on `$OMARCHY_PATH/bin`
  being on PATH).

The shell has no config file: the bar, the menu and every option are declared in
QML under `shell/`. What it does write is actual state, under
`~/.local/state/omarchy/` — never into this directory. See
[shell/README.md](shell/README.md).

## Idle and lock

`shell/shell.qml` mounts the Wayland session lock service. `SUPER+l` locks;
`SUPER+SHIFT+m` closes the session and returns to SDDM. `SUPER+m` toggles Spotify.
Password authentication uses `/etc/pam.d/omarchy-lock-password`, declared in
`modules/features/omarchy.nix`; the lock refuses to start until PAM is configured.

The Quickshell idle timers stay disabled. swayidle keeps blank-at-15-min and
hibernate-at-30-min (`config/mango/execonce.conf`); locking adds no separate
display-blanking timer. The bar's Stay Awake indicator uses Wayland idle
inhibition to pause both swayidle timers for the current shell session. Idle and
hibernate do not automatically lock the session.

## Themes

`Style > Theme` in the menu runs `omarchy-theme-switcher` (the image-picker
overlay plugin, driven over IPC) and feeds the pick to `omarchy-theme-set`,
which stages `themes/<name>/` into `~/.local/state/omarchy/current/theme`,
renders `default/themed/*.tpl` from the theme's `colors.toml`, repoints the
`background` link and pushes the new palette into the running shell with
`shell applyTheme`. `Style > Background` is the same picker over that theme's
`backgrounds/`.

What retints, and how it is hooked up:

| target | how |
|---|---|
| quickshell | `omarchy-shell shell applyTheme`, in-process, no restart |
| ghostty | `config-file = ?~/.local/state/omarchy/current/theme/ghostty.conf` at the end of `config/ghostty/config`; an included file overrides the file that includes it, so it wins over the hand-tuned palette there. `omarchy-restart-terminal` SIGUSR2s running instances |
| tmux | `omarchy-theme-set-tmux` sets options and pushes OSC sequences into live panes. `config/tmux` still hardcodes a Rose Pine palette, which wins on the next `source-file` |
| btop | `btop.theme` is rendered into the staged theme, but nothing points btop at it: add `color_theme = "/home/tagp/.local/state/omarchy/current/theme/btop.theme"` to `~/.config/btop/btop.conf` (not in this repo) |
| Claude Code | `omarchy-theme-set-claude` copies `claude.json` to `~/.claude/themes/omarchy.json`, which Claude Code hot-reloads. `omarchyActivateClaudeTheme` in `modules/features/omarchy.nix` runs it once with `--activate` to point `~/.claude/settings.json` at it, stashing whatever theme it replaced in `settings.json.omarchy-previous` |
| neovim | `default/themed/neovim.lua.tpl` renders the palette as a bare table; `config/nvim/init.lua` `dofile()`s it into `aether.nvim` from `_G.OmarchyTheme()`, falling back to `catppuccin-mocha` when nothing is staged. `omarchy-theme-set-nvim` calls that function over each running instance's socket, so open editors retint without a restart |
| Vesktop | `default/themed/vesktop.css.tpl` renders the palette as the variable block the vendored [midnight](https://github.com/refact0r/midnight-discord) theme reads (`vendor/midnight-discord/`, MIT, verbatim). `omarchy-theme-set-vesktop` concatenates the two into `~/.config/vesktop/themes/omarchy.css`; Vencord watches that directory and hot-applies, so Discord retints without a restart. Enable `Omarchy` once under `Settings > Themes`. midnight is a dark theme, so a light Omarchy theme comes out readable but not light |
| COSMIC apps (cosmic-files) | `default/themed/cosmic.ron.tpl` renders the whole libcosmic palette as one file of `### <key>` sections; `omarchy-theme-set-cosmic` splits it into `~/.config/cosmic/com.system76.CosmicTheme.{Dark,Light}/v2/<key>`, sets `CosmicTheme.Mode/v1/is_dark` from the theme's `mode` and points `CosmicTk/v1/icon_theme` at the theme's `icons.theme` (a `Yaru-*` variant, from `yaru-theme`; the two themes naming a grey variant that doesn't exist fall back to `Yaru`/`Yaru-dark`). The config is global, so any libcosmic app follows. libcosmic only takes a live theme change over a dbus signal from the COSMIC settings daemon, which does not run in this session, so the hook relaunches each running app with the command line and working directory it had |

Not wired: librewolf. Upstream only themes Chromium-family browsers, by writing
a managed-policy JSON into `/etc/<browser>/policies/managed`, which is read-only
on NixOS anyway. Theming a Firefox fork means generating `userChrome.css` from
`colors.toml`, which is a separate piece of work.

## Local patches

Reapply these after any refresh from upstream.

**NixOS**

- The three helper scripts in `shell/` had `#!/bin/bash`, which is ENOENT on
  NixOS (`/bin` holds only `sh`). Rewritten to `#!/usr/bin/env bash`. Same for
  everything vendored into `bin/`; that shebang line is their only local edit,
  which is why the nix wrapper turns shellcheck off rather than fixing its
  notes in place.
- `bin/omarchy-restart-terminal` gated its signals on `pgrep -x ghostty` /
  `pgrep -x kitty`, which never match here: a nix wrapper renames the binary, so
  ghostty's `comm` is `.ghostty-wrappe` (truncated by the kernel at 15 chars).
  Replaced with a single `pkill -x` per terminal on the wrapped-or-plain name.
- `plugins/menu/BarWidget.qml` drew U+E900 out of upstream's own `omarchy` icon
  font (`default/fonts/omarchy/omarchy.ttf`), which is not vendored, so it came
  out as tofu. Swapped for the nerd-fonts menu glyph U+F035C, which
  `nerd-fonts.jetbrains-mono` already covers.
- `bin/omarchy-shell` dropped its `-p "$OMARCHY_PATH/shell"`. The shell here runs
  as quickshell's default config out of `~/.config/quickshell`, and `qs` matches
  instances by the config path they were launched with — a second path to the
  same directory matches nothing, so every IPC call failed.
- `bin/omarchy-theme-set`'s `post_theme_commands` is trimmed to the hooks whose
  target exists on this box (terminal, btop, tmux, Claude Code) and extended with
  the local `omarchy-theme-set-nvim`, `omarchy-theme-set-vesktop` and
  `omarchy-theme-set-cosmic`. The rest are
  hyprctl/gnome/vscode/obsidian/pi/browser/RGB-keyboard and were dropped rather
  than vendored.

**Removed features**

- Three bar indicators are gone, with the systems behind them:
  `bar/indicators/{Dictation,ScreenRecording,Reminder}.qml`, their entries in
  `bar/widgets/Indicators.qml`.s `indicatorEntries`, the `plugins/reminders/`
  overlay, and their menu rows. All three drove `omarchy-*` helpers that are not
  vendored; screen recording here is `config/mango/scripts/screen-record.sh`
  (wf-recorder, `CTRL+SHIFT+S`), not `gpu-screen-recorder`.
- `panels/audio/Panel.qml` lost `volumeSinkName`, `resolveVolumeSink()`,
  `volumeSinkProc` and its 15s timer; `volumeSink` is now just `sink`. See the
  comment left in its place — `omarchy-audio-output-sink` cannot do anything here
  because EasyEffects never becomes the default sink, and the poll was the bulk of
  this shell's log noise (~16.5k warnings/day across two outputs).
- The 15 themes that shipped their own `themes/*/neovim.lua` had them removed. Each
  was a LazyVim spec naming a different colorscheme plugin (tokyonight, gruvbox,
  nightfox, …), and a theme's own file wins over the rendered template
  (`omarchy-theme-set-templates` skips a filename the theme already staged). With
  them gone every theme renders through `neovim.lua.tpl` into `aether.nvim`.

**Added features**

- `bar/indicators/Spotify.qml`, plus its entry in `bar/widgets/Indicators.qml`.s
  `indicatorEntries`. Replaces the waybar
  session's `custom/media` module: click launches spotify (the mango windowrule
  `appid:Spotify,isnamedscratchpad:1` keeps it hidden) or toggles play/pause,
  scroll skips. Deliberately spotify-only - mopidy runs as a permanent MPRIS
  player here, so the generic `omarchy.media` widget would show and control it
  instead. It reads `plugins/services/media` unmodified.

**Hyprland -> mango**

`Commons/Mango.qml` is a new singleton standing in for `Quickshell.Hyprland`. It
holds one `mmsg watch all-monitors` subscription — mango's IPC pushes every
output's tags, focus flag and keyboard layout down it — plus `dispatch` helpers.

| what | was | now |
|---|---|---|
| workspaces widget | `Quickshell.Hyprland` workspaces | `Mango.tagsFor(screen)`, click dispatches `view,<tag>` |
| bar's focused output | `Hyprland.focusedMonitor` | `Mango.focusedMonitor` |
| popup outside-click | `HyprlandFocusGrab` | `PopupWindow.grabFocus` (the compositor's own xdg-popup grab) |
| corner radius / edge gap | `hyprctl getoption` | `border_radius` / `gappoh` read out of `~/.config/mango/*.conf` |
| keyboard layout | `hyprctl devices` + `switchxkblayout` | `Mango.keyboardLayout`, `dispatch switch_keyboard_layout,0` |
| idle: screensaver window tracking | Hyprland `openwindow`/`closewindow` events | `mmsg watch all-clients`, diffed by client id |
| idle/lock: lock the session | `omarchy-system-lock` | the lock service in-process via `shell.serviceFor` |
| idle/lock: blank + wake displays | `omarchy-brightness-*` | `wlopm --off/--on` (wlr-output-power-management) |
| lock: orphaned-lock recovery | `omarchy-hyprland-session-locked` | removed; mango exposes no equivalent state |
| night light | `hyprsunset` | `wlsunset` (wlr-gamma-control), pinned via a state file |
| monitor panel: enable/disable | `hyprctl keyword monitor` | `mmsg dispatch enable_monitor,<name>` |
| monitor panel: scale | `omarchy-hyprland-monitor-scaling` | `wlr-randr --output ... --scale` |
| monitor panel: state | `omarchy-monitor-state` | `plugins/panels/monitor/monitor-state.sh` (wlr-randr + mmsg) |
| notification click -> focus app | `omarchy-hyprland-focus-app` | `mmsg get all-clients` + `dispatch focusid` |

The `[hyprland]` section name in `default/themed/shell.toml.tpl` is left alone:
it is a theme-file key that `Commons/Border.qml` reads, not a compositor call.

## Still missing

Every `omarchy-*` CLI the widgets shell out to that is not in `bin/`. They are
Arch/Hyprland bash and were not vendored, so most of the menu's actions, weather,
agents, system-update, tailscale, dropbox, speedtests, clipboard paste, emoji
insert, theme/background *install* and *remove*, the Wi-Fi band pills
(`omarchy-network-band`) and the bluetooth/network panels' *write* paths
are inert. Reading works, since that comes from quickshell's own
Pipewire/Bluetooth/Networking bindings, plus `bin/omarchy-network-status` for the
network panel's link details.

Audio is the exception: it is wired end to end. Volume, mute, per-app streams and
the device lists are quickshell's Pipewire bindings, switching the default output
or input is `Pipewire.preferredDefaultAudioSink`/`Source` (WirePlumber persists
it), and `bin/omarchy-audio-sink-availability` is vendored so unplugged jacks drop
out of the list — this box's onboard ALC4080 presents front, rear and S/PDIF as
three separate sinks. `omarchy-audio-{output,input}-set-default` are deliberately
*not* vendored: they move every non-EasyEffects stream onto the newly picked sink,
which fights `processAllOutputs` (see below) instead of helping it.

EasyEffects is pinned to intercept everything: `easyeffectsAlwaysEqualize` in
`modules/hosts/tagp/home/home.nix` forces `processAllOutputs=true` and
`useDefaultOutputDevice=true` into `~/.config/easyeffects/db/easyeffectsrc` on
every activation, so every output stream is equalized and `easyeffects_sink`
follows the default sink when the panel switches device. EasyEffects owns that
file at runtime, so a GUI toggle of either will not survive a rebuild.

`OMARCHY_PATH` is `~/.config/omarchy`, so upstream's "system themes"
(`$OMARCHY_PATH/themes`) and "user themes" (`~/.config/omarchy/themes`) are the
same directory here. Harmless — `omarchy-theme-list` dedupes and
`omarchy-theme-set` just copies the theme twice — but it means there is nowhere
to drop a theme that is not in git.
