import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "DockLayout.js" as DockLayout
import "DockModel.js" as DockModel

// Stage layout docks. mango hides a stashed window released against the outer
// monitor edge and reports it in client IPC; each one is drawn here as a tab on
// that edge. Windows with an MPRIS player get transport controls, the rest an
// icon chip. How hard the window was pushed into the edge picks the compact or
// the full tab. Hovering a compact tab peeks its title (and transport for
// media) away from the edge. Clicking the tab body or that title, or
// right-clicking anywhere, undocks. Dragging the tab body moves it along its
// edge, reordering past other tabs. A docked Discord tab badges its unread
// mentions. Compact, hovering shelves the newest three; clicking one opens it.
// Full, it previews the last chosen chat and hovering opens a chat widget
// (DiscordPanel) to browse, read and reply.
// While a window is dragged into dock range its future tab shows faded with an
// accent border, so the compact or full pick is visible before release.
Item {
  id: root

  property var shell: null
  readonly property var mediaService: shell ? shell.serviceFor("omarchy.media") : null
  readonly property var players: mediaService ? mediaService.players : []
  readonly property var discordService: shell ? shell.serviceFor("omarchy.discord") : null

  property var dockIds: []
  // Window keys: a PanelWindow may not follow an in-place screen change, so a
  // preview crossing monitors gets a new key and a fresh window.
  property var dockKeys: []
  property var docks: ({})

  readonly property int gap: Style.space(8)
  readonly property int miniSize: Style.space(44)
  readonly property int fullMediaWidth: Style.space(300)
  readonly property int fullMediaHeight: Style.space(76)
  readonly property int fullChipMaxWidth: Style.space(260)
  readonly property int shelfWidth: Style.space(300)
  readonly property int messageHeight: Style.space(54)
  // Each tab's surface width, above the widest tab (peek or shelf), so a
  // tab changing width never resizes its surface.
  readonly property int stripWidth: Style.space(320)

  // A full Discord tab keeps the chosen chat's newest messages and its
  // message box under it: DiscordPanel's previewHeight plus the tab's own padding.
  readonly property real chatPreviewHeight: {
    var chat = discordService ? discordService.chat : null
    var n = chat ? DockModel.list(chat.messages).length : 0
    return n > 0 ? n * (messageHeight + Style.space(4)) + Style.space(26) + Style.space(8) + Style.space(8) : 0
  }
  // The preview room tabs are packed with. Held while the chat widget is
  // open, so picking a chat never repacks the tab under the pointer; the new
  // chat's preview takes its room once the widget closes.
  property bool chatOpen: false
  property real reservedPreviewHeight: 0
  onChatPreviewHeightChanged: reserve()
  onChatOpenChanged: reserve()

  // mango centres a tab on its y, so a new preview size would shift the
  // header by half the change. Keeping each chat tab's top and moving mango's
  // y to match grows or shrinks it from the bottom instead.
  function reserve() {
    if (chatOpen || reservedPreviewHeight === chatPreviewHeight) return
    var kept = []
    for (var i = 0; i < dockIds.length; i++) {
      var d = docks[dockIds[i]]
      if (chatWidget(d)) kept.push({ dock: d, top: restTop(d.id) })
    }
    reservedPreviewHeight = chatPreviewHeight

    var next = Object.assign({}, pinned)
    for (var j = 0; j < kept.length; j++) {
      var h = tierHeight(kept[j].dock)
      var screen = screenFor(kept[j].dock.monitor)
      var top = screen ? Math.max(0, Math.min(kept[j].top, screen.height - h)) : kept[j].top
      var y = Math.floor(top + h / 2)
      next[kept[j].dock.id] = { top: top, y: y }
      Quickshell.execDetached(["mmsg", "dispatch", "stage_dock_move," + y, "client," + Number(kept[j].dock.id)])
    }
    pinned = next
    if (kept.length > 0) unpin.restart()
  }

  function chatWidget(dock) {
    return dock && !mini(dock) && discordService !== null && DockModel.isDiscord(dock.appid) && !playerFor(dock)
  }

  function playerFor(dock) {
    var media = root.mediaService
    return DockModel.playerFor(root.players, dock.appid, dock.pid,
      media ? function(name) { return media.pidChain(name) } : null)
  }

  // The height the tier mango picked asks for, before any folding to fit.
  function tierHeight(dock) {
    if (dock.mini) return root.miniSize
    if (playerFor(dock)) return root.fullMediaHeight
    if (discordService !== null && DockModel.isDiscord(dock.appid)) return root.miniSize + root.reservedPreviewHeight
    return root.miniSize
  }

  // Mini as mango set it, or folded because its edge ran out of room.
  function mini(dock) {
    return dock.mini || root.compact[dock.id] === true
  }

  function heightFor(dock) {
    return mini(dock) ? root.miniSize : tierHeight(dock)
  }

  // Tabs packed per monitor edge so they never overlap or leave the screen.
  readonly property var packed: {
    var groups = {}
    for (var i = 0; i < dockIds.length; i++) {
      var d = docks[dockIds[i]]
      if (!d) continue
      var key = d.monitor + "/" + d.edge
      if (!groups[key]) groups[key] = { monitor: d.monitor, list: [], heights: {} }
      groups[key].list.push(d)
      groups[key].heights[d.id] = tierHeight(d)
    }
    var tops = {}
    var compact = {}
    for (var k in groups) {
      var g = groups[k]
      var screen = screenFor(g.monitor)
      var edge = DockLayout.packEdge(g.list, g.heights, screen ? screen.height : 0, root.gap, root.miniSize)
      Object.assign(tops, edge.tops)
      Object.assign(compact, edge.compact)
    }
    return { tops: tops, compact: compact }
  }
  readonly property var tops: packed.tops
  readonly property var compact: packed.compact

  // Tab drag, Chrome style: the dragged tab follows the pointer, and each tab
  // it passes slides into the room it left, so a drop always lands in a gap.
  property int dragId: -1
  property real dragTop: 0
  property real dragHeight: 0
  // Screen bottom of the dragged tab's edge, so a passed tab stays on screen.
  property real dragBottom: Infinity
  property var dragObs: []
  property int dragHome: 0
  property int dragSlot: 0
  // How far the dragged centre must be through a tab to pass it. Measured
  // where that tab sits now, and it slides away once passed, so going back
  // takes a full pass the other way and small wobbles never flip it.
  readonly property real commit: 0.75
  // Tops set by a drop, shown until mango reports the matching y.
  property var pinned: ({})

  function restTop(id) {
    return DockLayout.restTop(pinned, tops, id)
  }

  // The other tabs on a dock's edge, top to bottom, as they sit now.
  function neighbours(id) {
    var tabs = []
    for (var i = 0; i < dockIds.length; i++) {
      var o = docks[dockIds[i]]
      if (o) tabs.push({ id: o.id, monitor: o.monitor, edge: o.edge, top: restTop(o.id), height: heightFor(o) })
    }
    return DockLayout.neighbours(docks[id], tabs)
  }

  function tabTop(id) {
    if (id === dragId) return dragTop
    for (var i = 0; i < dragObs.length; i++) {
      if (dragObs[i].id === id) return DockLayout.obsTop(dragObs[i])
    }
    return restTop(id)
  }

  function beginDrag(id, height) {
    var top = restTop(id)
    dragObs = neighbours(id)
    dragHome = dragObs.filter(function(o) { return o.top < top }).length
    dragSlot = dragHome
    dragHeight = height
    var screen = docks[id] ? screenFor(docks[id].monitor) : null
    dragBottom = screen ? screen.height : Infinity
    dragTop = top
    dragId = id
  }

  function dragState() {
    return { top: dragTop, height: dragHeight, obs: dragObs, home: dragHome, slot: dragSlot, bottom: dragBottom }
  }

  function moveDrag(top, max) {
    var next = DockLayout.move(dragState(), top, max, gap, commit)
    dragTop = next.top
    if (next.obs !== dragObs) dragObs = next.obs
    dragSlot = next.slot
  }

  // Lands the tab in its gap and tells mango where it and every tab it
  // passed now sit, so nothing snaps back to its old spot.
  function endDrag(max) {
    var moves = DockLayout.landing(dragState(), dragId, max, gap)
    var next = Object.assign({}, pinned)
    for (var j = 0; j < moves.length; j++) {
      next[moves[j].id] = { top: moves[j].top, y: moves[j].y }
      Quickshell.execDetached(["mmsg", "dispatch", "stage_dock_move," + moves[j].y, "client," + Number(moves[j].id)])
    }
    pinned = next
    dragId = -1
    dragObs = []
    unpin.restart()
  }

  Timer {
    id: unpin
    interval: 1000
    onTriggered: if (root.dragId < 0) root.pinned = ({})
  }

  function screenFor(name) {
    var screens = Quickshell.screens
    for (var i = 0; i < screens.length; i++) {
      if (screens[i].name === name) return screens[i]
    }
    return null
  }

  function undock(id) {
    Quickshell.execDetached(["mmsg", "dispatch", "stage_undock", "client," + Number(id)])
  }

  function act(player, action) {
    if (!player || !root.mediaService) return
    root.mediaService.runAction(action, false, root.mediaService.playerKey(player))
  }

  function apply(line) {
    var next = DockModel.docksFrom(line)
    if (!next) return
    root.docks = next.byId
    if (JSON.stringify(next.ids) !== JSON.stringify(root.dockIds)) root.dockIds = next.ids
    var keys = next.ids.map(function(id) { return id + "@" + next.byId[id].monitor })
    if (JSON.stringify(keys) !== JSON.stringify(root.dockKeys)) root.dockKeys = keys

    var keep = {}
    var settled = false
    for (var id in root.pinned) {
      var d = next.byId[id]
      if (d && d.y !== root.pinned[id].y) keep[id] = root.pinned[id]
      else settled = true
    }
    if (settled) root.pinned = keep
  }

  Process {
    id: watcher
    command: ["mmsg", "watch", "all-clients"]
    stdout: SplitParser {
      onRead: function(line) { root.apply(line) }
    }
    // mmsg exits with the compositor socket; retry so docks survive a restart.
    onExited: retry.restart()
  }

  Timer {
    id: retry
    interval: 1000
    onTriggered: if (Mango.available) watcher.running = true
  }

  Component.onCompleted: if (Mango.available) watcher.running = true

  Variants {
    model: root.dockKeys

    delegate: Component {
      DockWindow {
        stage: root
      }
    }
  }
}
