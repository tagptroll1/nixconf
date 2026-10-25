import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Commons
import "DockModel.js" as DockModel

// One docked window's tab on its monitor edge: the layer surface, the tab
// frame with its drag and click handling, and the content for its kind.
// Dock state and actions come from the StageDock that owns it.
PanelWindow {
  id: win

  required property var stage

  required property var modelData
  readonly property int dockId: Number(String(modelData).split("@")[0])
  readonly property var liveDock: stage.docks[dockId] || null
  // mango drops a dock before its window is torn down. Hidden then, with
  // the last dock held so edge and screen never flip, mango's close
  // animation slides out the last real frame, not a right-edge tab caught
  // mid-move across the screen.
  property var heldDock: null
  onLiveDockChanged: if (liveDock) heldDock = liveDock
  Component.onCompleted: heldDock = liveDock
  readonly property var dock: liveDock || heldDock
  readonly property bool onLeft: dock ? dock.edge === "left" : false
  readonly property var player: dock ? stage.playerFor(dock) : null
  readonly property bool media: player !== null
  readonly property string appIcon: {
    if (!dock || !stage.shell || !stage.shell.appLibrary) return ""
    var entry = DesktopEntries.heuristicLookup(dock.appid)
    return stage.shell.appLibrary.iconSource(entry ? entry.icon : dock.appid)
  }
  readonly property bool full: dock ? !stage.mini(dock) : false
  // A window dragged into dock range, shown as the tab its release makes.
  readonly property bool preview: dock ? dock.preview : false
  readonly property bool discord: dock !== null && stage.discordService !== null && DockModel.isDiscord(dock.appid)
  readonly property int mentionTotal: discord ? stage.discordService.total : 0
  // Vesktop's window title names whatever page it has open, not the
  // chat this tab shows, so its tab just names the app.
  readonly property string label: !dock ? "" : discord ? "Vesktop" : (dock.title || dock.appid || "")
  readonly property bool chatWidget: stage.chatWidget(dock)
  readonly property var chat: chatLoader.item
  // mango reports overview as active tag 0; it lists docks itself then.
  readonly property bool overview: {
    var monitor = dock ? Mango.monitorFor(dock.monitor) : null
    var tags = monitor ? monitor.active_tags : null
    return Array.isArray(tags) && tags.length === 1 && tags[0] === 0
  }

  visible: !overview && liveDock !== null
  screen: dock ? stage.screenFor(dock.monitor) : null
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  // Lifted while dragged or hovered so it passes, or expands, over the
  // other tabs, not under.
  WlrLayershell.layer: stage.dragId === win.dockId || hover.hovered || tab.shelfOpen ? WlrLayer.Overlay : WlrLayer.Top
  WlrLayershell.namespace: "omarchy-stage-dock"
  // mango hands an on-demand layer the keyboard on click, so the reply
  // box can type; back to None returns it to the focused window.
  WlrLayershell.keyboardFocus: win.chat && win.chat.expanded && win.chat.inChat
    ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

  // A full-height strip that never moves; the tab moves inside it. A
  // moving surface lags behind mango's move animation, and pointer y
  // measured against it fed back into the drag as jitter.
  anchors { top: true; bottom: true; left: win.onLeft; right: !win.onLeft }
  // Plain geometry, not `item: tab`: an item region maps through the
  // slide-in transform but only refreshes on geometry changes, so a new
  // tab kept its off-screen mask and ignored the pointer.
  mask: Region { x: tab.x; y: tab.y; width: tab.width; height: tab.height }

  readonly property real screenHeight: screen ? screen.height : 0

  // Fixed, with the tab pinned to the edge inside: a right-anchored
  // surface resized every frame lands late, pulling a shrinking tab
  // off the edge.
  implicitWidth: Math.max(stage.stripWidth, tab.width)

  Rectangle {
    id: tab

    x: win.onLeft ? 0 : win.width - width

    // Eased on its own, not through y, so a shelf growing upward moves
    // in step with the height and the header never wobbles.
    property real packedTop: stage.tabTop(win.dockId)
    Behavior on packedTop {
      enabled: !body.live
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }
    // The packed top already fits the collapsed tab. An upward shelf
    // sits above the header, so the header stays on its packed top; an
    // open preview tab still lifts off the screen bottom as a whole.
    y: {
      var top = packedTop - headerY
      return win.screenHeight > 0 ? Math.max(0, Math.min(top, win.screenHeight - height)) : top
    }

    readonly property real radius2: win.full ? Style.space(14) : stage.miniSize / 2
    // Compact tabs peek their title on hover, growing away from the edge.
    readonly property bool peeking: !win.full && hover.hovered && win.label !== ""
    // The mention shelf, or on a full tab the chat widget, hangs below
    // the tab (above it when `up`); `tops` keeps the collapsed height so
    // opening it never shoves the other tabs.
    readonly property bool shelfOpen: win.chatWidget
      ? hover.hovered || (win.chat !== null && win.chat.holding)
      : win.mentionTotal > 0 && !win.media && hover.hovered
    onShelfOpenChanged: if (win.chatWidget) stage.chatOpen = shelfOpen
    Component.onDestruction: if (shelfOpen && win.chatWidget) stage.chatOpen = false
    readonly property real baseHeight: win.full && win.media ? stage.fullMediaHeight : stage.miniSize
    readonly property real baseWidth: !win.full ? stage.miniSize + (peeking ? peek.width + Style.space(14) : 0)
      : win.media ? stage.fullMediaWidth
      : Math.min(stage.fullChipMaxWidth, chipRow.implicitWidth + Style.space(24))
    readonly property real chatHeight: win.chat && win.chat.implicitHeight > 0 ? win.chat.implicitHeight + Style.space(8) : 0
    // What the tab takes on its edge, preview included.
    readonly property real dockHeight: win.dock ? stage.heightFor(win.dock) : baseHeight

    // On a Discord chat tab the app chip opens the shown chat in Vesktop.
    readonly property bool chipOpensChat: win.chat !== null && win.chat.canOpen
    readonly property real shelfHeight: win.chatWidget ? chatHeight
      : shelfOpen ? shelf.implicitHeight + Style.space(10) : 0

    // At the screen bottom a shelf opening onto a bare header grows
    // upward instead, so the header stays under the pointer. A preview
    // tab keeps its messages below; moving them above would be the
    // bigger jump. Latched until the shelf has closed, so a height
    // animation or a later list load cannot flip it back and forth.
    property bool up: false
    readonly property bool overflows: shelfOpen && win.screenHeight > 0
      && (!win.chat || win.chat.previewHeight === 0)
      && stage.tabTop(win.dockId) + baseHeight + shelfHeight > win.screenHeight
    onOverflowsChanged: if (overflows) up = true
    readonly property bool settled: !shelfOpen && Math.abs(height - baseHeight - shelfHeight) < 0.5
    onSettledChanged: if (settled) up = false
    readonly property real headerY: up ? height - baseHeight : 0

    width: shelfOpen || chatHeight > 0 ? Math.max(stage.shelfWidth, baseWidth) : baseWidth
    height: baseHeight + shelfHeight

    // A tab grows out of its edge: only the inner corners are round.
    topLeftRadius: win.onLeft ? 0 : radius2
    bottomLeftRadius: win.onLeft ? 0 : radius2
    topRightRadius: win.onLeft ? radius2 : 0
    bottomRightRadius: win.onLeft ? radius2 : 0

    color: Colors.popups.background
    border.color: win.preview ? Colors.accent : Colors.popups.border
    border.width: 1
    clip: true
    opacity: win.preview ? 0.6 : 1
    Behavior on opacity { NumberAnimation { duration: 120 } }

    Behavior on width {
      enabled: !win.full || win.discord
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
    Behavior on height {
      enabled: win.discord
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }

    // Slides out of the edge when it appears.
    // `from`, not a binding on x: a bound x re-applies when a peek changes the width.
    transform: Translate { id: slide }
    Component.onCompleted: slideIn.start()
    NumberAnimation {
      id: slideIn
      target: slide; property: "x"; from: win.onLeft ? -tab.width : tab.width; to: 0
      duration: 220; easing.type: Easing.OutCubic
    }

    Rectangle {
      anchors.fill: parent
      topLeftRadius: parent.topLeftRadius
      bottomLeftRadius: parent.bottomLeftRadius
      topRightRadius: parent.topRightRadius
      bottomRightRadius: parent.bottomRightRadius
      color: Colors.popups.text
      opacity: body.containsMouse ? 0.06 : 0
      Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    // Body: left click undocks, or toggles playback on the compact media
    // tab; right click always undocks; the wheel skips tracks. A left
    // drag past a small threshold moves the tab instead of clicking it.
    MouseArea {
      id: body
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      cursorShape: Qt.PointingHandCursor

      property real grabY: 0
      property bool moved: false
      // Set by hand, before the drop moves y, so the tab tracks the
      // pointer unanimated but eases into its landing spot.
      property bool live: false
      readonly property real maxTop: win.screenHeight - tab.dockHeight

      onPressed: function(mouse) {
        grabY = mouse.y
        moved = false
      }
      // mango keeps pointer focus on the tab while the button is held,
      // so y stays relative to the tab even off its edges.
      onPositionChanged: function(mouse) {
        if (!(mouse.buttons & Qt.LeftButton)) return
        if (!moved) {
          if (Math.abs(mouse.y - grabY) < Style.space(6)) return
          moved = true
          live = true
          stage.beginDrag(win.dockId, tab.dockHeight)
        }
        // Measured from the header, which an upward shelf sits above.
        stage.moveDrag(Math.round(tab.y + tab.headerY + mouse.y - grabY), maxTop)
      }
      onReleased: function(mouse) {
        if (!live || mouse.button !== Qt.LeftButton) return
        live = false
        stage.endDrag(maxTop)
      }
      onCanceled: {
        if (!live) return
        live = false
        stage.endDrag(maxTop)
      }
      onClicked: function(mouse) {
        if (moved) return
        if (mouse.button === Qt.LeftButton && win.media && !win.full)
          stage.act(win.player, "playPause")
        else if (mouse.button === Qt.LeftButton && tab.chipOpensChat && chipRow.hovered)
          win.chat.openChat()
        else
          stage.undock(win.dockId)
      }
      onWheel: function(wheel) {
        if (!win.media) return
        stage.act(win.player, wheel.angleDelta.y > 0 ? "previous" : "next")
      }
    }

    // Compact glyph slot, pinned to the edge so a peek never moves it.
    Item {
      id: slot
      x: win.onLeft ? 0 : tab.width - width
      y: tab.headerY
      width: stage.miniSize
      height: stage.miniSize
    }

    // The tab's own row, so its content stays put while the shelf is open.
    Item {
      id: header
      y: tab.headerY
      width: tab.width
      height: tab.baseHeight
    }

    // Passive, so the peek's own buttons don't end the hover under them.
    HoverHandler { id: hover }

    PeekRow {
      id: peek
      x: win.onLeft ? stage.miniSize : tab.width - stage.miniSize - width
      anchors.verticalCenter: header.verticalCenter
      visible: !win.full
      player: win.player
      media: win.media
      label: win.label
      leftEdge: win.onLeft
      peeking: tab.peeking
      onUndock: stage.undock(win.dockId)
      onAct: function(action) { stage.act(win.player, action) }
    }

    MediaTab {
      anchors.fill: parent
      visible: win.media
      player: win.player
      full: win.full
      appid: win.dock ? win.dock.appid : ""
      appIcon: win.appIcon
      title: win.dock ? win.dock.title : ""
      glyphSlot: slot
      onAct: function(action) { stage.act(win.player, action) }
    }

    // A full chip keeps its resting spot by the edge, so a shelf
    // widening the tab never slides it under the pointer.
    AppChip {
      id: chipRow
      visible: !win.media
      x: !win.full ? slot.x + (slot.width - width) / 2
        : win.onLeft ? Style.space(12) : tab.width - width - Style.space(12)
      y: win.full ? header.y + (header.height - height) / 2 : slot.y + (slot.height - height) / 2
      dock: win.dock
      full: win.full
      appIcon: win.appIcon
      label: win.label
      mentionTotal: win.mentionTotal
      maxWidth: stage.fullChipMaxWidth
      opensChat: tab.chipOpensChat
    }

    // Full Discord tab: chat preview, and on hover the chat widget.
    Loader {
      id: chatLoader
      active: win.chatWidget
      x: Style.space(8)
      y: tab.up ? tab.headerY - (win.chat ? win.chat.implicitHeight : 0) : tab.baseHeight
      width: tab.width - Style.space(16)
      sourceComponent: DiscordPanel {
        service: stage.discordService
        // The header row on the side away from the edge, up to the chip.
        titleParent: header
        titleX: win.onLeft ? chipRow.x + chipRow.width + Style.space(8) : Style.space(12)
        titleWidth: Math.max(0, win.onLeft ? tab.width - titleX - Style.space(12)
          : chipRow.x - Style.space(8) - titleX)
        expanded: tab.shelfOpen
        messageHeight: stage.messageHeight
        onOpenInVesktop: function(path) {
          stage.discordService.jump(path)
          stage.undock(win.dockId)
        }
      }
    }

    MentionShelf {
      id: shelf
      visible: !win.chatWidget
      x: Style.space(8)
      y: tab.up ? tab.headerY - implicitHeight : tab.baseHeight
      width: tab.width - Style.space(16)
      mentions: win.discord ? stage.discordService.items : []
      total: win.mentionTotal
      open: tab.shelfOpen
      onOpened: function(path) {
        stage.discordService.jump(path)
        stage.undock(win.dockId)
      }
    }
  }
}
