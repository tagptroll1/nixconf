# The bar

A single horizontal bar across the top of every monitor, mounted for the whole
session by [`shell.qml`](../../shell.qml).

[`Bar.qml`](Bar.qml) *is* the layout: the widgets, their order and their
settings are declared in its `LeftModules`, `CenterModules` and `RightModules`
sections. There is no layout file, no drag-to-reorder, and no settings panel —
changing the bar means editing that file.

```
Left    menu · workspaces
Center  indicators · [clock] · keyboard-layout · weather · mango-fork
Right   tray · bluetooth · network · audio · monitor · clipboard · power
```

The clock is pinned to the exact center of the screen and the rest of the center
section packs against it, so the time does not shift as its neighbours change
width. Inactive indicators stay folded away until the pointer is over the center
section.

Everything else in `Bar.qml` is runtime plumbing the widgets depend on:

- **Slots.** One per widget. A slot sizes itself to what the widget paints,
  takes the press and hands it to whichever mark is under the pointer (the
  workspace tags and tray icons are several targets in one slot), and draws the
  dot under a widget whose panel is open.
- **Panel routing.** A widget exists once per monitor. `shell summon
  omarchy.audio` has to open the copy on the output mango has focused, and
  `hide` has to reach the one that is actually open — see
  [`BarModel.js`](BarModel.js).
- **Tooltips** and **popup exclusivity**: one shared tooltip window per bar
  surface, and one open popup at a time.

## Widgets

| Id | What it does | Interactions |
|---|---|---|
| `omarchy.menu` | menu launcher | left = menu · right = terminal |
| `omarchy.workspaces` | mango tag switcher, per output | left = focus tag |
| `omarchy.indicators` | nightlight, DND, stay-awake, Spotify | left = indicator action |
| `omarchy.clock` | date/time label, calendar popup with ISO weeks | left = popup · right = cycle format |
| `omarchy.keyboard-layout` | current layout, hidden while there is only one | left = next layout |
| `omarchy.weather` | conditions icon, forecast popup | left = popup · right = notification |
| `omarchy.mango-fork` | mangowm/mango releases missing from tagptroll1/mango, checked every 30 min, hidden at 0; popup lists them with description and commits | left = popup |
| `omarchy.tray` | system tray, drawer reveals on hover | hover = drawer · right = manage |
| `omarchy.bluetooth` | devices, connect/disconnect, battery | left = popup · right = toggle radio |
| `omarchy.network` | Wi-Fi scan and connect | left = popup |
| `omarchy.audio` | master slider, output picker, per-app mixer | left = popup · right = mute · scroll = volume |
| `omarchy.monitor` | brightness and display controls | left = popup |
| `omarchy.clipboard-bar` | clipboard history dropdown: paste an entry, x or 󰅙 removes one | left = popup |
| `omarchy.power` | system: power profile, then suspend/hibernate/logout/reboot/shutdown | left = popup |

The clock's two label formats are set where `Bar.qml` declares it; right click
walks the ring for the session and the declared format is what it starts on
again. Tray pins and the calendar's own state (week start, the life bar's birth
year) are state rather than options, so those are written to
`~/.local/state/omarchy/settings/`.

## What a widget gets

Its slot sets `bar` and `moduleName`; the base types in
[`qs.Ui`](../../Ui/BarWidget.qml) add the rest. From `bar`:

- `bar.foreground`, `bar.barForeground`, `bar.background`, `bar.urgent` — live theme colors
- `bar.fontFamily` — the system monospace family, resolved at paint time
- `bar.barSize`, `bar.position` (`"top"`), `bar.vertical` (`false`)
- `bar.run(command)` — fire-and-forget bash (quote arguments with `Util.shellQuote`)
- `bar.showTooltip(target, text)` / `bar.hideTooltip(target)`
- `bar.requestPopout(owner)` / `bar.releasePopout(owner)` — one popup at a time
- `bar.moduleWidgets(id)` — every live copy of a widget, one per monitor
- `bar.shell` — the host, for summoning something off the bar

`position` and `vertical` are constants now. The widgets still read them, and
their vertical branches are still in there; nothing sets them to anything else.
