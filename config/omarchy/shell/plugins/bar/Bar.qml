import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "BarModel.js" as BarModel
import "widgets"
import "../menu" as MenuPlugin
import "../clipboard" as ClipboardPlugin
import "../panels/clock" as ClockPlugin
import "../panels/weather" as WeatherPlugin
import "../panels/audio" as AudioPlugin
import "../panels/bluetooth" as BluetoothPlugin
import "../panels/network" as NetworkPlugin
import "../panels/tailscale" as TailscalePlugin
import "../panels/protonvpn" as ProtonVpnPlugin
import "../panels/monitor" as MonitorPlugin
import "../panels/power" as PowerPlugin

// One bar per monitor, laid out here and nowhere else: the widgets, their
// order and their settings are all in this file. What remains around them is
// runtime plumbing every widget depends on — tooltips, popup exclusivity, the
// click dispatch, and routing a panel hotkey to the copy on the focused
// output.
Item {
  id: root

  // Injected by the host so widgets can reach shared services and summon
  // panels that live outside the bar.
  property var shell: null
  readonly property var idleService: shell?.firstPartyServiceFor("omarchy.idle")

  // Fixed geometry. Widgets and the shared popup code read these to place
  // themselves, so they stay named rather than assumed.
  readonly property string position: "top"
  readonly property bool vertical: false
  readonly property int barSize: Style.bar.sizeHorizontal

  // Resolves through fontconfig at paint time, so changing the system
  // monospace font updates the bar without a reload.
  property string fontFamily: Style.font.family
  // Bound to the central Color singleton, which tracks the theme's shell.toml.
  property color foreground: Color.bar.text
  property color barForeground: foreground
  property color background: Color.bar.background
  property color urgent: Color.bar.active

  Behavior on barForeground { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on background { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }
  Behavior on urgent { ColorAnimation { duration: 420; easing.type: Easing.InOutCubic } }

  // ------------------------------------------------------------- tooltips

  property var tooltipTarget: null
  property var pendingTooltipTarget: null
  property string tooltipText: ""
  property string pendingTooltipText: ""
  property bool tooltipShown: false
  property int tooltipRequest: 0

  // --------------------------------------------------------- hover reveal

  property bool centerSectionHovered: false
  // One bar surface exists per monitor and each reports into this count, so a
  // pointer crossing from one monitor's bar to another's stays counted however
  // the enter and leave interleave. A single shared bool would be left false by
  // whichever event landed last.
  property int barHoverCount: 0
  readonly property bool barHovered: barHoverCount > 0
  property bool centerSectionRevealHeld: false
  // Set by a center panel while it is open, so the indicators behind it do not
  // peek out from under it.
  property bool centerHoverRevealSuppressed: false

  // ---------------------------------------------------------- registries
  //
  // Live objects, not configuration: the click dispatch and panel routing both
  // need to find what is currently on screen.

  property var activePopout: null
  property var clickTargets: []
  property var moduleSlots: []

  function registerClickTarget(target) {
    if (!target || clickTargets.indexOf(target) !== -1) return
    var next = clickTargets.slice()
    next.push(target)
    clickTargets = next
  }

  function unregisterClickTarget(target) {
    clickTargets = clickTargets.filter(function(item) { return item !== target })
  }

  function registerModuleSlot(slot) {
    if (!slot || moduleSlots.indexOf(slot) !== -1) return
    var next = moduleSlots.slice()
    next.push(slot)
    moduleSlots = next
  }

  function unregisterModuleSlot(slot) {
    moduleSlots = moduleSlots.filter(function(item) { return item !== slot })
  }

  function debugBarGeometry() {
    var out = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem) continue
      var point = { x: slot.x, y: slot.y }
      try {
        point = slot.mapToItem(null, 0, 0)
      } catch (e) {
      }
      out.push({
        id: slot.moduleName,
        section: slot.region,
        x: Math.round(point.x),
        y: Math.round(point.y),
        width: Math.round(slot.width),
        height: Math.round(slot.height),
        visible: slot.visible === true && slot.width > 0 && slot.height > 0,
        itemVisible: slot.activeItem.visible === true,
        itemWidth: Math.round(slot.activeItem.implicitWidth || 0),
        itemHeight: Math.round(slot.activeItem.implicitHeight || 0)
      })
    }
    return out
  }

  function targetWindow(target) {
    return target && target.QsWindow ? target.QsWindow.window : null
  }

  function targetBelongsToWindow(target, window) {
    return !!target && !!window && targetWindow(target) === window
  }

  function slotWindow(slot) {
    if (!slot) return null
    return targetWindow(slot.activeItem) || targetWindow(slot)
  }

  function sameWindow(left, right) {
    if (!left || !right) return false
    if (left === right) return true
    return !!left.screen && !!right.screen && !!left.screen.name && !!right.screen.name && left.screen.name === right.screen.name
  }

  function requestPopout(owner) {
    if (activePopout === owner) return
    if (activePopout) {
      if ("closeForPopoutSwitch" in activePopout) activePopout.closeForPopoutSwitch()
      else if ("close" in activePopout) activePopout.close()
    }
    activePopout = owner
  }

  function releasePopout(owner) {
    if (activePopout === owner) activePopout = null
  }

  // ------------------------------------------------------- panel routing

  // Tab order for the panels in one bar region. Scoped to a single bar surface
  // so tabbing walks the bar the open panel belongs to instead of hopping the
  // panel to another monitor's copy of the same widget.
  function panelNavigationSlots(region, window) {
    var slots = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || slot.region !== region) continue
      if (window && !sameWindow(slotWindow(slot), window)) continue
      var item = slot.activeItem
      if (!item || item.visible !== true || slot.visible !== true || slot.width <= 0 || slot.height <= 0) continue
      if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
      slots.push(slot)
    }
    return slots
  }

  // The Nth panel in a bar region, counted the way the bar reads: layout order,
  // and only the panels actually on screen. A widget with no panel (the tray)
  // and one that is hiding itself are passed over, so the number lands on the
  // Nth panel icon the user can see rather than the Nth widget.
  // One-based, because it exists for hotkeys; anything else lands on no slot.
  function panelWidgetIdAt(region, index) {
    var slots = panelNavigationSlots(String(region || ""), null)
    var slot = slots[Math.round(Number(index)) - 1]
    return slot ? String(slot.moduleName || "") : ""
  }

  function switchPanelFrom(owner, direction) {
    if (!owner) return false

    var currentSlot = null
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (slot && slot.activeItem === owner) {
        currentSlot = slot
        break
      }
    }
    if (!currentSlot) return false

    var slots = panelNavigationSlots(currentSlot.region, slotWindow(currentSlot))
    if (slots.length < 2) return false

    var currentIndex = slots.indexOf(currentSlot)
    if (currentIndex < 0) return false

    var step = direction < 0 ? -1 : 1
    var nextSlot = slots[(currentIndex + step + slots.length) % slots.length]
    if (!nextSlot || !nextSlot.activeItem || nextSlot.activeItem === owner) return false

    nextSlot.activeItem.open()
    return true
  }

  // Every live instance of a widget id. A bar surface is built per monitor, so
  // a widget that appears once in the layout is still live once per screen.
  function moduleWidgets(pluginId) {
    var id = String(pluginId || "")
    var items = []
    if (!id) return items
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem || slot.moduleName !== id) continue
      items.push(slot.activeItem)
    }
    return items
  }

  function slotScreenName(slot) {
    var window = slotWindow(slot)
    return window && window.screen ? String(window.screen.name || "") : ""
  }

  // Resolve the live bar-widget instance for a plugin id. Only widgets that
  // expose popup open/close count; plain indicators (workspaces, tray) return
  // null. Used by shell.summon/toggle so a panel hotkey opens the copy on the
  // output mango has focused.
  function findPanelWidget(pluginId) {
    var id = String(pluginId || "")
    if (!id) return null
    var candidates = []
    for (var i = 0; i < moduleSlots.length; i++) {
      var slot = moduleSlots[i]
      if (!slot || !slot.activeItem || slot.moduleName !== id) continue
      var item = slot.activeItem
      if (typeof item.open !== "function" || typeof item.close !== "function" || item.opened === undefined) continue
      candidates.push({ slot: slot, screenName: slotScreenName(slot), opened: item.opened === true })
    }
    // One copy per monitor, plus a zero-size placeholder for anchored center
    // modules. See BarModel.pickPanelSlot for which one a hotkey acts on.
    var chosen = BarModel.pickPanelSlot(candidates, Mango.focusedMonitor)
    return chosen ? chosen.activeItem : null
  }

  function summonBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item) return false
    item.open()
    return true
  }

  function hideBarWidget(pluginId) {
    var item = findPanelWidget(pluginId)
    if (!item) return false
    item.close()
    return true
  }

  function isBarWidgetOpen(pluginId) {
    var item = findPanelWidget(pluginId)
    return !!item && item.opened === true
  }

  // --------------------------------------------------------- click dispatch
  //
  // A widget paints several pressable marks inside one slot (the workspace
  // tags, the tray icons). The slot takes the press and hands it to whichever
  // mark is under the pointer.

  function moduleTargetClickable(target) {
    return target
      && target.visible !== false
      && target.opacity !== 0
      && target.interactive !== false
      && target.pressable !== false
      && target.concealed !== true
      && typeof target.triggerPress === "function"
  }

  function moduleClickTargetAt(slot, localX, localY) {
    for (var i = clickTargets.length - 1; i >= 0; i--) {
      var target = clickTargets[i]
      if (!moduleTargetClickable(target)) continue

      var targetPoint = { x: localX, y: localY }
      try {
        targetPoint = slot.mapToItem(target, localX, localY)
      } catch (e) {
        continue
      }

      if (targetPoint.x >= 0 && targetPoint.x <= target.width &&
          targetPoint.y >= 0 && targetPoint.y <= target.height) {
        return target
      }
    }

    if (moduleTargetClickable(slot.activeItem)) return slot.activeItem
    return null
  }

  function pressModuleClickTarget(slot, button, localX, localY) {
    var target = moduleClickTargetAt(slot, localX, localY)
    if (!target) return false

    target.triggerPress(button)
    return true
  }

  // ------------------------------------------------------------- helpers

  function run(command) {
    if (!command) return

    Util.execDetached(command)
  }

  function runProcess(process) {
    if (!process.running)
      process.running = true
  }

  // Revealing the indicators widens their section, which can slide a neighbour
  // under a stationary pointer. Collapsing on that un-hover would move it back
  // out and re-open the peek, so hold until the pointer leaves the bar.
  function setCenterSectionHovered(hovered) {
    centerSectionHovered = hovered
    if (hovered) {
      centerSectionRevealTimer.stop()
      centerSectionRevealHeld = true
    } else {
      centerSectionRevealTimer.restart()
    }
  }

  function setBarHovered(hovered) {
    barHoverCount = Math.max(0, barHoverCount + (hovered ? 1 : -1))
    if (barHoverCount === 0) centerSectionRevealTimer.restart()
  }

  Timer {
    id: centerSectionRevealTimer
    interval: 120
    // Collapse only. Opening the peek is the center section's own gesture, done
    // in setCenterSectionHovered, so a timer left pending by a pointer that dipped
    // off the bar and came back cannot reveal indicators it never pointed at.
    onTriggered: if (!root.centerSectionHovered && !root.barHovered) root.centerSectionRevealHeld = false
  }

  function targetTooltipHovered(target) {
    return !!target && target.visible !== false && target.opacity !== 0 && target.tooltipHovered === true
  }

  function clearTooltip() {
    tooltipTimer.stop()
    pendingTooltipTarget = null
    pendingTooltipText = ""
    tooltipTarget = null
    tooltipText = ""
    tooltipShown = false
  }

  function showTooltip(target, text) {
    clearTooltip()

    if (!targetTooltipHovered(target) || !text) {
      tooltipRequest += 1
      return
    }

    var request = tooltipRequest + 1
    tooltipRequest = request
    pendingTooltipTarget = target
    pendingTooltipText = text

    Qt.callLater(function() {
      if (request !== tooltipRequest) return
      if (!targetTooltipHovered(pendingTooltipTarget)) {
        clearTooltip()
        return
      }
      tooltipTarget = pendingTooltipTarget
      tooltipText = pendingTooltipText
      pendingTooltipTarget = null
      pendingTooltipText = ""
      tooltipTimer.restart()
    })
  }

  function hideTooltip(target) {
    if (tooltipTarget !== target && pendingTooltipTarget !== target) return

    tooltipRequest += 1
    clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: 400
    onTriggered: {
      if (root.targetTooltipHovered(root.tooltipTarget)) root.tooltipShown = true
      else root.clearTooltip()
    }
  }

  Timer {
    interval: 100
    running: root.tooltipShown
    repeat: true
    onTriggered: if (!root.targetTooltipHovered(root.tooltipTarget)) root.hideTooltip(root.tooltipTarget)
  }

  // ---------------------------------------------------------- bar surfaces

  Variants {
    model: Quickshell.screens

    delegate: Component {
      BarPanel {
        required property var modelData

        screen: modelData
      }
    }
  }

  component BarPanel: PanelWindow {
    id: barWindow

    visible: !remapGuard.remapping
    anchors { top: true; left: true; right: true }
    implicitHeight: root.barSize
    // Narrowed bars float as a pill, so the surface itself stays clear.
    color: focusWidth < width ? "transparent" : root.background
    surfaceFormat.opaque: false
    WlrLayershell.namespace: "omarchy-bar"
    WlrLayershell.layer: WlrLayer.Top

    // Ultrawide keeps a square focus area in the middle; widgets and clicks stay
    // inside it.
    readonly property int focusWidth: screen && screen.width > 2 * screen.height ? screen.height : width
    mask: Region { item: focusArea }

    IdleInhibitor {
      window: barWindow
      enabled: root.idleService?.inhibit === true
    }

    ScreenMoveRemap {
      id: remapGuard
      window: barWindow
    }

    Item {
      id: focusArea
      anchors.horizontalCenter: parent.horizontalCenter
      width: barWindow.focusWidth
      height: parent.height

      Rectangle {
        anchors.fill: parent
        visible: barWindow.focusWidth < barWindow.width
        color: root.background
        radius: height / 2
      }

      // An ancestor of the sections, not a sibling: it stays hovered while the
      // pointer is over a widget, where a sibling would lose hover to the
      // section the pointer entered.
      HoverHandler {
        onHoveredChanged: root.setBarHovered(hovered)
        // Unplugging a monitor destroys its bar without a leave event, which
        // would strand this surface's tally and hold the peek open for good.
        Component.onDestruction: if (hovered) root.setBarHovered(false)
      }

      CenterModules { anchors.fill: parent }

      LeftModules {
        anchors.left: parent.left
        anchors.leftMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }

      RightModules {
        anchors.right: parent.right
        anchors.rightMargin: Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    PopupWindow {
      id: tooltipWindow

      visible: root.tooltipShown && root.tooltipTarget !== null && root.tooltipText !== "" && root.targetBelongsToWindow(root.tooltipTarget, barWindow)
      color: "transparent"
      implicitWidth: Math.ceil(tooltipBubble.implicitWidth)
      implicitHeight: Math.ceil(tooltipBubble.implicitHeight)

      anchor {
        id: tooltipAnchor
        window: barWindow
        adjustment: PopupAdjustment.Slide
        edges: Edges.Top | Edges.Left
        gravity: Edges.Bottom | Edges.Right
        rect.width: 1
        rect.height: 1

        onAnchoring: {
          var target = root.tooltipTarget
          if (!root.targetBelongsToWindow(target, barWindow)) return

          var point = barWindow.contentItem.mapFromItem(target,
            target.width / 2 - tooltipWindow.implicitWidth / 2,
            target.height + 6)
          tooltipAnchor.rect.x = Math.round(point.x)
          tooltipAnchor.rect.y = Math.round(point.y)
        }
      }

      BorderSurface {
        id: tooltipBubble
        implicitWidth: tooltipLabel.implicitWidth + 20
        implicitHeight: tooltipLabel.implicitHeight + 14
        color: Color.tooltip.background
        borderSpec: Border.surfaceSpec("tooltip", "border", Color.tooltip.border, 1)
        radius: Style.cornerRadius

        Text {
          id: tooltipLabel
          anchors.centerIn: parent
          text: root.tooltipText
          color: Color.tooltip.text
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
          verticalAlignment: Text.AlignVCenter
        }
      }
    }
  }

  // ------------------------------------------------------------- sections
  //
  // The bar itself. Left and right sections sit at their edge; the clock sits
  // dead center, with the rest of the center section packed against it.

  component LeftModules: Row {
    spacing: 0

    Slot {
      region: "left"
      moduleName: "omarchy.menu"
      widget: Component { MenuPlugin.BarWidget { } }
    }

    Slot {
      region: "left"
      moduleName: "omarchy.workspaces"
      widget: Component { Workspaces { } }
    }
  }

  component CenterModules: Item {
    id: centerRoot

    HoverHandler {
      onHoveredChanged: root.setCenterSectionHovered(hovered)
    }

    Row {
      spacing: 0
      anchors.right: clockSlot.left
      anchors.verticalCenter: clockSlot.verticalCenter

      Slot {
        region: "center"
        moduleName: "omarchy.indicators"
        widget: Component { Indicators { } }
      }
    }

    Slot {
      id: clockSlot
      region: "center"
      moduleName: "omarchy.clock"
      anchors.centerIn: parent
      widget: Component {
        ClockPlugin.BarWidget {
          format: "dddd dd.MM.yyyy - HH:mm"
          formatAlt: "d MMMM 'W'ww yyyy"
        }
      }
    }

    Row {
      spacing: 0
      anchors.left: clockSlot.right
      anchors.verticalCenter: clockSlot.verticalCenter

      Slot {
        region: "center"
        moduleName: "omarchy.keyboard-layout"
        widget: Component { KeyboardLayout { } }
      }

      Slot {
        region: "center"
        moduleName: "omarchy.weather"
        widget: Component { WeatherPlugin.BarWidget { } }
      }

      Slot {
        region: "center"
        moduleName: "omarchy.mango-fork"
        widget: Component { MangoFork { } }
      }
    }
  }

  component RightModules: Row {
    spacing: 0

    Slot {
      region: "right"
      moduleName: "omarchy.tray"
      widget: Component { Tray { } }
    }

    Slot {
      region: "right"
      moduleName: "omarchy.bluetooth"
      widget: Component { BluetoothPlugin.Panel { } }
    }

    Slot {
      region: "right"
      moduleName: "omarchy.network"
      widget: Component { NetworkPlugin.Panel { } }
    }

    Slot {
      region: "right"
      moduleName: "omarchy.tailscale"
      widget: Component { TailscalePlugin.Panel { } }
    }

    Slot {
      region: "right"
      moduleName: "omarchy.protonvpn"
      widget: Component { ProtonVpnPlugin.Panel { } }
    }

    Slot {
      region: "right"
      moduleName: "omarchy.audio"
      widget: Component { AudioPlugin.Panel { } }
    }

    Slot {
      region: "right"
      moduleName: "omarchy.monitor"
      widget: Component { MonitorPlugin.Panel { } }
    }

    Slot {
      region: "right"
      moduleName: "omarchy.clipboard-bar"
      widget: Component { ClipboardPlugin.BarWidget { } }
    }

    Slot {
      region: "right"
      moduleName: "omarchy.power"
      widget: Component { PowerPlugin.Panel { } }
    }
  }

  // One widget's place on the bar: it sizes itself to what the widget paints,
  // takes the press on the widget's behalf, and marks the widget while its
  // panel is open.
  component Slot: Item {
    id: slot

    required property string region
    required property string moduleName
    required property Component widget

    readonly property var activeItem: widgetLoader.item
    readonly property bool hovered: moduleHover.hovered
    readonly property bool panelOpen: root.activePopout === slot.activeItem
    // Modules bigger than the mark they want (a text label in a padded slot)
    // can say how long the open-panel dot should be, so it tracks what the
    // module paints instead of a fraction of whatever slot it fills.
    readonly property real panelIndicatorExtent: {
      var hint = activeItem && "openPanelIndicatorWidth" in activeItem ? activeItem.openPanelIndicatorWidth : undefined
      if (hint !== undefined && hint !== null && hint > 0) return Math.round(hint)
      return Math.max(Style.space(10), Math.round(slot.width * 0.55))
    }

    implicitWidth: activeItem && activeItem.visible ? activeItem.implicitWidth : 0
    implicitHeight: activeItem && activeItem.visible ? activeItem.implicitHeight : 0
    width: implicitWidth
    height: implicitHeight

    Component.onCompleted: root.registerModuleSlot(slot)
    Component.onDestruction: root.unregisterModuleSlot(slot)

    HoverHandler { id: moduleHover }

    Loader {
      id: widgetLoader
      anchors.fill: parent
      sourceComponent: slot.widget
      // Handed over after creation rather than bound in every declaration
      // above: every widget takes the same two, and the bindings inside them
      // re-evaluate when the values land.
      onLoaded: {
        if ("bar" in item) item.bar = root
        if ("moduleName" in item) item.moduleName = slot.moduleName
      }
    }

    Rectangle {
      id: openPanelIndicator

      readonly property int inset: Style.space(2)

      visible: opacity > 0
      opacity: slot.panelOpen ? 0.9 : 0
      color: Color.accent
      radius: Math.min(width, height) / 2
      width: slot.panelIndicatorExtent
      height: Style.space(2)
      // The mark sits on the module's inner edge — the one facing the desktop —
      // so it underlines the bar and reads as pointing at the panel below it.
      x: Math.round((parent.width - width) / 2)
      y: parent.height - height - inset
      z: 50

      Behavior on opacity {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
      }
    }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton
      enabled: slot.visible && slot.width > 0 && slot.height > 0
      propagateComposedEvents: true
      cursorShape: root.moduleClickTargetAt(slot, mouseX, mouseY) ? Qt.PointingHandCursor : Qt.ArrowCursor

      onClicked: function(mouse) {
        if (!root.pressModuleClickTarget(slot, mouse.button, mouse.x, mouse.y)) mouse.accepted = false
      }
    }
  }
}
