# TODO: migrate notifications off `omarchy-notification-send`

Goal: every script under `bin/` sends notifications with plain `notify-send`.
`bin/omarchy-notification-send` (211 lines) gets deleted, along with the
omarchy-private D-Bus hints only it produces.

Now that `NotificationCard.qml` classifies emoji and Nerd Font characters
straight out of the standard icon fields, the wrapper's main reason to exist
(`-g <glyph>`) is gone: `notify-send -i 🔥` reaches the same slot.

## Call sites

Three, all trivial:

- `bin/omarchy-theme-set:111` - `omarchy-notification-send "No background was found for theme" -t 2000`
- `bin/omarchy-theme-bg-next:19` - same call
- `shell/plugins/panels/weather/BarWidget.qml:78` - `omarchy-notification-send "$(omarchy-weather-status)"`

The first two map 1:1:

```bash
notify-send -t 2000 'No background was found for theme'
```

Note the flag has to move ahead of the message - `notify-send` takes options
before positionals, the wrapper accepted them anywhere.

The weather one calls `omarchy-weather-status`, which is not in `bin/` and not
on PATH, so that binding is already dead. Decide whether the weather panel
should shell out at all or render its own toast before porting it.

## Flags to map

| wrapper | notify-send |
| --- | --- |
| `-u <low\|normal\|critical>` | `-u` (same) |
| `-t <ms>` | `-t` (same) |
| `-r <id>` | `-r` (same) |
| `-p` | `-p` (same) |
| `-i <icon>` | `-i` (same) |
| `--app-name <name>` | `-a <name>` |
| `--image <path-or-uri>` | `-i <path>` - both land on the `image-path` hint |
| `-g <glyph>` | `-i <glyph>` - handled by `isTextIcon()` now |
| `--exec <argv...>` | **no equivalent** - see below |

No caller in the repo uses `-g`, `--image` or `--exec` today, so nothing blocks
the swap.

## The one real gap: `--exec`

`--exec` serializes an argv into the `omarchy-exec-argv` hint so a toast stays
clickable after a shell restart (`NotificationLogic.js:66-93`). A libnotify
action can't do that - its sender is gone by then.

Nothing sends it, so the simplest move is to delete the hint with the wrapper.
If click-to-run is wanted later, build it on standard libnotify actions
(`notify-send -A key=Label`, then `ActionInvoked`) and accept that it dies with
the sender, or design a replacement deliberately rather than inheriting this one.

## Steps

1. Rewrite the two `bin/` call sites as `notify-send`.
2. Resolve or drop the weather panel binding.
3. Delete `bin/omarchy-notification-send`.
4. Drop `glyphFromHints` / `execArgvFromHints` / `parseExecArgv` from
   `NotificationLogic.js` and the `glyph` property chain in
   `NotificationCard.qml` (`iconText` keeps working - it falls through to the
   image and app-icon fields).
5. Check `default/omarchy/omarchy-menu.jsonc` for any `action:` that still
   names the wrapper.

## Wider sweep

The same audit applies to the other 27 scripts in `bin/`. Most are theme
plumbing (`omarchy-theme-*`, 20 files, ~1900 lines) with no upstream
equivalent, so they stay for now - but the notification migration is the
template: find the omarchy-private mechanism, check whether a standard one
covers it, and delete rather than wrap.
