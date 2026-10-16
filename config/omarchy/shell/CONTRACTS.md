# Shell contracts

Every JSON contract the shell reads or writes outside its own process. Field lists
come from the producer code named in each section; when they disagree, the code wins
and this file is out of date.

Three channels, kept apart:

| Channel | Goes to | Used for |
|---|---|---|
| `mmsg get/watch/dispatch ...` | the compositor (Mango IPC socket) | client and monitor state, dock commands |
| `qs ipc call shell ...` | this shell | summon/hide/toggle panels, see [README.md](README.md#ipc-contract) |
| `shell.serviceFor(id)` | a service inside this shell | in-process only, no wire format |

The Discord bridge and networker are separate sockets, described below.

## Mango

Producer: [tagptroll1/mango](https://github.com/tagptroll1/mango)
[`src/ipc/ipc.c`](https://github.com/tagptroll1/mango/blob/main/src/ipc/ipc.c)
(`build_client_json`, `build_monitor_json`, `handle_command`),
[`src/ipc/stage.c`](https://github.com/tagptroll1/mango/blob/main/src/ipc/stage.c)
(`stage_client_json`) and
[`src/dispatch/stage.c`](https://github.com/tagptroll1/mango/blob/main/src/dispatch/stage.c)
(dock dispatches).
Consumers: [`Commons/Mango.qml`](Commons/Mango.qml),
[`plugins/stagedock/`](plugins/stagedock/) (`DockModel.js`, `StageDock.qml`).

### Transport

- Socket: `$MANGO_INSTANCE_SIGNATURE`, which Mango sets to
  `$XDG_RUNTIME_DIR/mango-<pid>.sock`. The shell only talks to it through `mmsg`.
- One request per connection, one line, newline terminated.
- `get ...` and `dispatch ...`: one JSON line back, then the socket closes.
- `watch ...`: the current state as one line, then one full line per change until
  either side closes. `mmsg` exits when Mango does; the shell restarts the watch
  after 1 s.
- Request errors are `{"error":"<text>"}`: `monitor not found`, `client not found`,
  `no client found` (dispatch `client,<id>` names no client), `unknown function`,
  `unknown command`.

### Client object

From `get all-clients` / `watch all-clients` (as `{"clients":[...]}`), `get client <id>`,
`watch client <id>`, `get focusing-client`.

| Field | Type | Meaning |
|---|---|---|
| `id` | int | Mango client id, stable for the window's life |
| `pid` | int | owning process |
| `foreign_toplevel_id` | string | ext-foreign-toplevel identifier |
| `title`, `appid` | string | window title, Wayland app id or X11 class |
| `monitor` | string | output name (`DP-1`), `""` when the window has none |
| `tags` | int[] | tag numbers from 1; `0` for the special workspace |
| `is_xwayland`, `is_swallowing`, `is_swallowedby`, `is_group`, `is_visible`, `is_focused`, `is_fullscreen`, `is_floating`, `is_maximized`, `is_global`, `is_unglobal`, `is_overlay`, `is_fakefullscreen`, `is_minimized`, `is_urgent`, `is_scratchpad`, `is_namedscratchpad` | bool | window flags |
| `x`, `y`, `width`, `height` | int | window box in global layout coordinates (logical px), border included |
| `scroller_proportion` | number | scroller layout share |
| `is_staged` | bool | stashed at the side of the stage layout |
| `stage_dock` | object or null | the window's dock tab; null when not docked |
| `stage_dock_preview` | object or null | the dock a release would make during a drag; null when not dragging into dock range, and always null while docked |

`watch focusing-client` sends `{"id":null,"title":null,"appid":null}` when nothing
is focused.

Dock object (`stage_dock` and `stage_dock_preview`):

| Field | Type | Meaning |
|---|---|---|
| `edge` | `"left"` or `"right"` | monitor side edge |
| `tier` | `"mini"` or `"full"` | compact widget or full tab |
| `y` | int | tab centre in logical px from the monitor top, `0..monitor height` |
| `monitor` | string | preview only: the output the drop lands on, which can differ from the client's `monitor`. A dock lives on the client's `monitor`. |

Drop rule: when a stashed window is released with its nearer side edge within
`stage_dock_zone` logical px (default 48) of the monitor side, it docks there; within
`stage_dock_mini_zone` px (default 8) the tier is `mini`, otherwise `full`. Both are
mango config keys. On dock `y` starts
at the window centre. Preview changes along one edge are sent at most every 16 ms,
each as a full `all-clients` line.

Every dock, undock, move and preview change is pushed to both `watch all-clients`
and `watch client <id>`.

Sample, one docked client from `mmsg get all-clients` (flags trimmed):

```json
{
  "id": 8, "pid": 235755, "foreign_toplevel_id": "5c7975cc25b9d129a6f7e4c36b619221",
  "title": "Spotify Premium", "appid": "spotify", "monitor": "DP-1", "tags": [1],
  "is_visible": false, "is_floating": true, "is_minimized": true,
  "x": 1463, "y": 1242, "width": 390, "height": 242, "scroller_proportion": 0.800000011920929,
  "is_staged": true,
  "stage_dock": { "edge": "left", "tier": "full", "y": 863 },
  "stage_dock_preview": null
}
```

A preview looks like `{"edge":"right","tier":"mini","y":540,"monitor":"HDMI-A-1"}`.

### Monitor object

From `watch all-monitors` (as `{"monitors":[...]}`), read by `Commons/Mango.qml`.

| Field | Type | Meaning |
|---|---|---|
| `name` | string | output name |
| `active` | bool | the focused output |
| `is_hdr`, `is_vrr` | bool | output modes |
| `x`, `y`, `width`, `height` | int | output box in layout coordinates |
| `scale` | number | output scale |
| `layout_index`, `layout_symbol` | int, string | current tag's layout |
| `last_open_surface` | string | |
| `tag_num` | int | tags per monitor |
| `hide_clients` | int | |
| `tags` | object[] | `{index, is_active, is_urgent, layout, client_count}`, index from 1; a tag is occupied when `client_count > 0` |
| `active_tags` | int[] | selected tags, `[0]` in overview |
| `active_client` | object | `{id, title, appid}`, all null when none |
| `keymode`, `keyboardlayout` | string | |

### Dispatch commands

`mmsg dispatch <func>[,<arg>] [client,<id>]`. `client,<id>` targets a window;
without it most commands act on the focused one.

| Command | Target | Does |
|---|---|---|
| `stage_dock,left` / `,right` / `,nearest` | client or focused | docks a stashed window on that edge (full tier), or moves an existing dock to it keeping tier and `y`. `nearest` picks the edge nearer the window centre; for a docked window it is a no-op. |
| `stage_undock` | client or focused | returns a docked window to the stage beside its edge |
| `stage_dock_toggle` | client or focused | undock when docked, else `stage_dock,nearest` (the keybind form) |
| `stage_dock_move,<y>` | client, required | sets the dock's `y`, clamped to `0..monitor height` |
| `stage_flip` | focused monitor | flips the stage centre grid of the current tag |

Replies:

- `{"success":true}`: the command ran and does not report its effect (`stage_flip`
  and every non-stage dispatch).
- `{"success":true,"changed":<bool>}`: a dock command ran; `changed` is whether any
  state changed. Repeating a command gives `changed:false`.
- `{"success":true,"changed":false,"reason":"<r>"}`: nothing done, because:

| `reason` | When |
|---|---|
| `no-client` | no target or focused window, or it has no monitor |
| `not-staged` | `stage_dock` on a window that is not stashed, or its monitor is not on the stage layout |
| `not-docked` | `stage_undock` / `stage_dock_move` on a window that is not docked |
| `bad-edge` | `stage_dock` with an edge other than `left`, `right`, `nearest` |

The shell sends these fire-and-forget (`Quickshell.execDetached`) and trusts the next
`watch all-clients` line, not the reply.

## Discord bridge

Producer: the ShellMentions Vencord plugin,
[`config/vesktop/userplugins/shellMentions/`](../../vesktop/userplugins/shellMentions/):
`native.ts` owns the socket in Vesktop's main process, `index.ts` answers in the
renderer. Consumer: [`plugins/services/discord/Service.qml`](plugins/services/discord/Service.qml)
with [`Bridge.js`](plugins/services/discord/Bridge.js).

### Transport

- Socket: `$XDG_RUNTIME_DIR/vesktop-mentions.sock` (`/tmp` when unset), a unix stream
  socket created while Vesktop runs.
- Newline-delimited JSON, UTF-8, one object per line, both ways.
- On connect the bridge sends, in order: `ready`, the last `status` if any, the last
  `mentions` if any.
- `generation` counts renderer loads. A Discord reload keeps the socket and sends a
  new `ready` with a higher generation; the command the old renderer held goes back
  on the queue, and mentions and status are resent by the new renderer. Vesktop
  quitting sends `ready` with `generation: 0`, then closes every client.

### Commands (shell to bridge)

Every command needs `id`, a positive safe integer unique per connection. A line that
is not valid JSON or fails validation is dropped without a reply. Ids ("snowflakes")
are strings of 1 to 20 digits.

| Command | Reply |
|---|---|
| `{"id":1,"jump":"/channels/<guildId or @me>/<channelId>[/<messageId>]"}` | none; Vesktop navigates there |
| `{"id":2,"list":"dms"}` / `{"id":3,"list":"guilds"}` | `dms` / `guilds` |
| `{"id":4,"list":"channels","guildId":"<id>"}` | `channels` |
| `{"id":5,"open":"<channelId>"}` | `chat` with `status:"loading"`, then `ready` or `error` |
| `{"id":6,"open":null}` | `chat` with `channelId:null`, `status:"ready"`, no messages |
| `{"id":7,"send":"<channelId>","content":"text"}` | `sent`; content is trimmed and must be 1 to 2000 characters |

### Messages (bridge to shell)

Every line except `ready` and `mentions` carries `id` and `generation`. `id` is the
command being answered, or `null` for a live update sent to every client.

| `type` | Fields | When |
|---|---|---|
| `ready` | `generation` | connect, renderer load, Vesktop quit (`0`) |
| `status` | `state` (`"ok"` or `"incompatible"`), `missing` (string[], incompatible only) | after each renderer load checks Discord's internals; `id` is null |
| `mentions` | `total` (int), `items` (mention[], at most 20) | on connect and whenever unread mentions change; no `id` or `generation` |
| `dms`, `guilds` | `items` (entry[], DMs at most 40) | answer to `list`; live update while the list stays open |
| `channels` | `guildId`, `title`, `items` (entry[]) | same |
| `chat` | `channelId` (string or null), `status` (`loading`, `ready`, `error`), `error`?, `title`?, `path`?, `messages` (mention[], oldest first, at most 2) | answer to `open`; live update on new, edited or deleted messages and after a gateway reconnect |
| `sent` | `channelId`, `ok` (bool), `error`? | answer to `send` |
| `error` | `reason`, `error`? | the command was not run, see below |

Mention item: `{id, channelId, path, author, avatarUrl, where, snippet, ts}`.
`path` is a `/channels/...` jump path to the message, `where` is `"DM"`, the group
name or `#channel · Server`, `ts` is Unix ms (0 when unknown), `avatarUrl` a Discord
CDN URL.

List entry: `{id, name, iconUrl, unread, mentions}`. `iconUrl` is `""` when there is
none, `unread` is bool, `mentions` an int.

A `chat` with `status:"error"` and `error:"Channel not available"` has no `title`,
`path` or messages. Any other `chat` error, and a `sent` with `ok:false`, carries
Discord's error text in `error`.

Error reasons:

| `reason` | When |
|---|---|
| `renderer-unavailable` | no renderer is listening (generation 0) |
| `incompatible` | status is `incompatible`; every command gets this |
| `command-failed` | the renderer threw while running it; `error` has the text |

Synthetic sample session (the greeting was checked against a live socket; messages
are made up):

```json
{"type":"ready","generation":1}
{"type":"status","state":"ok","id":null,"generation":1}
{"type":"mentions","total":1,"items":[{"id":"1300000000000000001","channelId":"1200000000000000001","path":"/channels/@me/1200000000000000001/1300000000000000001","author":"alice","avatarUrl":"https://cdn.discordapp.com/embed/avatars/0.png","where":"DM","snippet":"hello","ts":1790540000000}]}
> {"id":5,"open":"1200000000000000001"}
{"type":"chat","channelId":"1200000000000000001","status":"loading","title":"alice","path":"/channels/@me/1200000000000000001","messages":[],"id":5,"generation":1}
{"type":"chat","channelId":"1200000000000000001","status":"ready","title":"alice","path":"/channels/@me/1200000000000000001","messages":[{"id":"1300000000000000001","channelId":"1200000000000000001","path":"/channels/@me/1200000000000000001/1300000000000000001","author":"alice","avatarUrl":"https://cdn.discordapp.com/embed/avatars/0.png","where":"DM","snippet":"hello","ts":1790540000000}],"id":5,"generation":1}
> {"id":6,"send":"1200000000000000001","content":"hi"}
{"type":"sent","channelId":"1200000000000000001","ok":true,"id":6,"generation":1}
```

### Single owner

Vesktop keeps one open chat and one browse list for the whole bridge. Any client's
`open` or `list` replaces them, and their live updates go to every client. So one
interactive client, the shell's Discord service, sends `open`, `list` and `send`;
other clients only read `mentions`. Replies to a command still reach only the client
that sent it.

### Limits

| Limit | Value | On overflow |
|---|---|---|
| Clients | 8 | new client is closed |
| Unterminated input line | 64 KiB | client is closed |
| Unread output per client | 1 MiB | client is closed |
| Commands queued for a busy renderer | 32 | oldest dropped, never answered |
| Commands awaiting a reply | 64 | oldest forgotten, its reply dropped |
| Message content | 2000 characters | command rejected |

The shell gives up on a `send` after 15 s ("Delivery unknown", draft kept) and
retries the socket from 2 s, doubling to 30 s.

## networker

Producer: [`patches/networker-live/cmd/networker-live/main.go`](../../../patches/networker-live/cmd/networker-live/main.go),
with `Flow` from networker's `internal/tracker` and `Location` from `internal/geo`
(pinned in [`modules/features/networker.nix`](../../../modules/features/networker.nix)).
Consumer: [`plugins/panels/network/ConnectionMap.qml`](plugins/panels/network/ConnectionMap.qml)
and `ConnectionMap.js`.

HTTP `GET` on `http://127.0.0.1:8766`, loopback only, JSON bodies.

### `/api/config`

`{"origin": {"latitude": <deg>, "longitude": <deg>}}`, or `{"origin": null}` when
`services.networker.origin` is unset. Null is valid: the map shows no routes.

### `/api/flows`

Array of flows seen in the last 30 s, most recent `last_seen` first.

| Field | Type | Meaning |
|---|---|---|
| `id` | int | unique while the service runs; restarts from 1 with it |
| `started_at`, `last_seen` | string | RFC 3339 with nanoseconds |
| `app` | string | process name, `"unknown"` when unattributed |
| `pid`, `executable`, `unit` | int, string, string | owning process and systemd unit; omitted when unknown |
| `local`, `remote` | string | `ip:port`, IPv6 as `[ip]:port` |
| `protocol` | `"tcp"` or `"udp"` | |
| `direction` | `"outbound"` or `"inbound"` | |
| `status` | `"established"` or `"observed"` | `established` when the kernel reports an outbound connection established |
| `sent_bytes`, `received_bytes` | int | bytes over the flow's life |
| `source` | string | always `"host"` here; networker-live collects no router flows, so `device` never appears |
| `location` | object or null | null for private, loopback, link-local, multicast or unknown addresses |
| `domain` | string | outbound only, from observed DNS answers; omitted when unknown |

Location: `{latitude, longitude, accuracy_km, city?, country, asn?, organization?}`,
`country` an ISO code, optional fields omitted when empty.

Sample (`curl http://127.0.0.1:8766/api/flows`, one entry, path shortened):

```json
{
  "id": 412,
  "started_at": "2026-09-27T22:53:50.969054645+02:00",
  "last_seen": "2026-09-27T22:55:27.337163261+02:00",
  "app": ".claude-wrapped", "pid": 264977,
  "executable": "/nix/store/...-claude-code-2.1.280/bin/.claude-wrapped",
  "unit": "app-ghostty-surface-transient-240589.scope",
  "local": "192.168.0.179:49292", "remote": "34.149.66.165:443",
  "protocol": "tcp", "direction": "outbound", "status": "established",
  "sent_bytes": 586124, "received_bytes": 26102, "source": "host",
  "location": { "latitude": 39.0997, "longitude": -94.5786, "accuracy_km": 0,
    "city": "Kansas City", "country": "US", "asn": 396982, "organization": "Google LLC" },
  "domain": "http-intake.logs.us5.datadoghq.com"
}
```

### `/api/health`

| Field | Type | Meaning |
|---|---|---|
| `now` | int | server clock, Unix ms |
| `last_poll_ok` | int | Unix ms of the last successful collector poll, `0` before the first |
| `last_error` | string or null | last poll error, null once a poll succeeds |
| `dns_error` | string or null | set when the DNS reader stops; no new names until restart |

```json
{"now":1790542528343,"last_poll_ok":1790542527340,"last_error":null,"dns_error":null}
```

### Freshness rule

The collector polls every second and HTTP keeps answering while polls fail. The map
polls every 2 s (`/api/config` once per connect, then `/api/flows`, then
`/api/health`):

- unreachable: a request gets no answer within 5 s; the map clears.
- stale: reachable, `last_poll_ok > 0` and `now - last_poll_ok > 5000`. Both times
  come from the server, so local clock skew cannot fake staleness.
- `dns_error` set: "DNS names unavailable"; flows still show, without `domain`.

## MPRIS player for a dock tab

Consumer rule in [`plugins/stagedock/DockModel.js`](plugins/stagedock/DockModel.js)
(`playerFor`), with bus-owner PIDs from
[`plugins/services/media/Service.qml`](plugins/services/media/Service.qml) (`pidChain`).

1. Skip `playerctld`, a proxy for whichever player was active last.
2. A player matches the dock's `appid` (case-insensitive) when its `desktopEntry` or
   `identity` equals it, or its D-Bus name ends in `.<appid>` or contains
   `.<appid>.` (`org.mpris.MediaPlayer2.spotify`,
   `org.mpris.MediaPlayer2.firefox.instance_1_23`).
3. Several matches: take the one whose bus owner PID, or a parent of it, is the
   client's `pid`. The chain comes from `GetConnectionUnixProcessID` and `/proc/<pid>/status`
   `PPid`, and is null until resolved.
4. Otherwise the first match. No match: the tab has no media controls. An app whose
   player names itself differently needs an alias in `playerMatches`.
