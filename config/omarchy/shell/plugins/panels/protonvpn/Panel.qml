import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "omarchy.protonvpn"
  ipcTarget: "omarchy.protonvpn"
  manageIpc: false

  property string focusSection: "header"
  property int infoIndex: 0
  property int serverIndex: 0
  property bool cursorActive: false

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color iconColor: vpn.active ? foreground : dim
  readonly property color barIconColor: vpn.active ? barForeground : Qt.darker(barForeground, 1.55)
  readonly property color hoverFill: bar ? Style.hoverFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property color selectedFill: bar ? Style.selectedFillFor(bar.foreground, Color.accent) : "transparent"
  readonly property bool hasProfiles: vpn.profiles.length > 0
  readonly property string toggleHint: vpn.active ? "Disconnect" : (vpn.fallback ? "Connect to " + vpn.fallback.name : "")

  readonly property var infoRows: {
    var rows = []
    if (vpn.publicIp !== "") rows.push({ label: vpn.connected ? "Exit IP" : "Public IP", value: vpn.publicIp, copy: true })
    var place = [vpn.publicCountry, vpn.publicIsp].filter(function(s) { return s !== "" }).join(" · ")
    if (place !== "") rows.push({ label: "Location", value: place, copy: false })
    if (vpn.connected) {
      for (var i = 0; i < vpn.addresses.length; i++) rows.push({ label: "Tunnel", value: vpn.addresses[i], copy: true })
      rows.push({ label: "Traffic", value: "↓ " + Model.formatBytes(vpn.rxBytes) + "   ↑ " + Model.formatBytes(vpn.txBytes), copy: false })
    }
    return rows
  }

  function ensureCursor() {
    if (infoIndex >= infoRows.length) infoIndex = Math.max(0, infoRows.length - 1)
    if (serverIndex >= vpn.profiles.length) serverIndex = Math.max(0, vpn.profiles.length - 1)
    if (focusSection === "info" && infoRows.length === 0) focusSection = hasProfiles ? "servers" : "header"
    if (focusSection === "servers" && !hasProfiles) focusSection = infoRows.length > 0 ? "info" : "header"
  }

  function moveCursor(dx, dy) {
    cursorActive = true
    ensureCursor()
    if (dy > 0) {
      if (focusSection === "header") focusSection = infoRows.length > 0 ? "info" : (hasProfiles ? "servers" : "header")
      else if (focusSection === "info") {
        if (infoIndex < infoRows.length - 1) infoIndex++
        else if (hasProfiles) { focusSection = "servers"; serverIndex = 0 }
      } else if (focusSection === "servers" && serverIndex < vpn.profiles.length - 1) serverIndex++
    } else if (dy < 0) {
      if (focusSection === "info") {
        if (infoIndex > 0) infoIndex--
        else focusSection = "header"
      } else if (focusSection === "servers") {
        if (serverIndex > 0) serverIndex--
        else if (infoRows.length > 0) { focusSection = "info"; infoIndex = infoRows.length - 1 }
        else focusSection = "header"
      }
    }
    ensureCursor()
  }

  function activateCursor() {
    ensureCursor()
    if (focusSection === "header") vpn.toggle()
    else if (focusSection === "info") {
      var row = infoRows[infoIndex]
      if (row && row.copy) vpn.copyToClipboard(row.value)
    } else if (focusSection === "servers") vpn.choose(vpn.profiles[serverIndex])
  }

  // Nothing to toggle without a profile, so the widget stays off the bar
  // until one is imported; the nmcli monitor brings it back.
  visible: hasProfiles
  readonly property bool unconfigured: vpn.listed && !hasProfiles
  onUnconfiguredChanged: if (unconfigured) {
    close()
    console.info("protonvpn: no WireGuard profiles in NetworkManager, widget hidden."
      + " Import one: nmcli connection import type wireguard file <name>.conf"
      + " (see plugins/panels/protonvpn/README.md)")
  }

  // A hidden widget has nothing to anchor a popup to.
  function open() { if (hasProfiles) controller.show() }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    cursorActive = false
    vpn.refresh()
    vpn.refreshLocation()
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }
  onInfoRowsChanged: ensureCursor()

  Service {
    id: vpn
    detailed: root.opened
  }

  Connections {
    target: vpn
    function onProfilesChanged() { root.ensureCursor() }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function refresh(): string { vpn.refresh(); return "ok" }
    function up(): string { if (vpn.fallback) vpn.up(vpn.fallback.uuid); return "ok" }
    function down(): string { vpn.down(); return "ok" }
    function toggleVpn(): string { vpn.toggle(); return "ok" }
    function status(): string { return vpn.statusText }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    iconComponent: Component {
      Item {
        ProtonIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.barIconColor
          crossed: !vpn.active
          pulsing: vpn.connecting
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) vpn.toggle()
      else if (buttonCode === Qt.MiddleButton) vpn.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dx, dy)
      }
      onActivateRequested: if (root.cursorActive) root.activateCursor()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "t" || t === "T") vpn.toggle()
        else if (t === "r" || t === "R") { vpn.refresh(); vpn.refreshLocation() }
        else if (t === "c" || t === "C") vpn.copyToClipboard(vpn.publicIp)
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          Item {
            id: header
            width: parent.width
            implicitHeight: hero.implicitHeight
            // The hero's trailingControl resolves `root` to PanelHero, so panel
            // state is reached through `header`.
            readonly property bool ringVisible: root.cursorActive && root.focusSection === "header" && root.hasProfiles
            function focusHero() { root.cursorActive = true; root.focusSection = "header" }

            PanelHero {
              id: hero
              width: parent.width
              title: "Proton VPN"
              detail: vpn.current ? vpn.current.name : ""
              meta: vpn.statusText
              foreground: root.foreground
              fontFamily: root.fontFamily
              iconOpacity: vpn.active ? 1.0 : 0.5
              iconComponent: Component {
                ProtonIcon {
                  iconSize: Style.font.display
                  color: root.iconColor
                  crossed: !vpn.active
                  pulsing: vpn.connecting
                }
              }

              trailingControl: Component {
                ToggleSwitch {
                  id: powerSwitch
                  visible: root.hasProfiles
                  checked: vpn.active
                  busy: vpn.busy
                  hasCursor: header.ringVisible
                  foreground: hero.foreground
                  onHovered: function(on) { if (on) header.focusHero() }
                  onToggled: vpn.toggle()

                  PanelToolTip {
                    visible: powerSwitch.containsMouse && root.toggleHint !== ""
                    text: root.toggleHint
                    fontFamily: hero.fontFamily
                  }
                }
              }
            }
          }

          Text {
            visible: vpn.actionStatus !== ""
            width: parent.width
            text: vpn.actionStatus
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator {
            visible: root.infoRows.length > 0
            foreground: root.foreground
          }

          Column {
            visible: root.infoRows.length > 0
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: vpn.connected ? "CONNECTION" : "EXPOSED"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: root.infoRows
              InfoRow {
                required property var modelData
                required property int index
                width: parent.width
                row: modelData
                rowIndex: index
              }
            }
          }

          PanelSeparator {
            visible: root.hasProfiles
            foreground: root.foreground
          }

          Column {
            visible: root.hasProfiles
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "SERVERS"
              foreground: root.foreground
              fontFamily: root.fontFamily
            }

            Repeater {
              model: vpn.profiles
              ServerRow {
                required property var modelData
                required property int index
                width: parent.width
                profile: modelData
                rowIndex: index
              }
            }
          }
        }
      }
    }
  }

  component InfoRow: CursorSurface {
    id: infoRow
    property var row: null
    property int rowIndex: 0

    hasCursor: root.cursorActive && root.focusSection === "info" && root.infoIndex === rowIndex
    foreground: root.foreground
    fill: root.hoverFill
    implicitHeight: infoInner.implicitHeight + Style.spacing.lg

    RowLayout {
      id: infoInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(10)
      anchors.rightMargin: Style.space(10)
      spacing: Style.space(8)

      Text {
        text: infoRow.row ? infoRow.row.label : ""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.bodySmall
        Layout.preferredWidth: Style.space(72)
      }

      Text {
        Layout.fillWidth: true
        text: infoRow.row ? infoRow.row.value : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        horizontalAlignment: Text.AlignRight
        elide: Text.ElideRight
      }

      Text {
        visible: infoRow.row && infoRow.row.copy
        text: "󰆏"
        color: infoMouse.containsMouse || infoRow.hasCursor ? root.foreground : root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
      }
    }

    MouseArea {
      id: infoMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: infoRow.row && infoRow.row.copy ? Qt.PointingHandCursor : Qt.ArrowCursor
      onEntered: { root.cursorActive = true; root.focusSection = "info"; root.infoIndex = infoRow.rowIndex }
      onClicked: if (infoRow.row && infoRow.row.copy) vpn.copyToClipboard(infoRow.row.value)
    }
  }

  component ServerRow: CursorSurface {
    id: serverRow
    property var profile: null
    property int rowIndex: 0
    readonly property bool isActive: profile && profile.active
    readonly property bool isPending: profile && (vpn.pendingUuid === profile.uuid || profile.state === "activating")

    hasCursor: root.cursorActive && root.focusSection === "servers" && root.serverIndex === rowIndex
    current: isActive || isPending
    foreground: root.foreground
    fill: root.hoverFill
    currentFill: root.selectedFill
    implicitHeight: serverInner.implicitHeight + Style.spacing.xl

    Row {
      id: serverInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      ProtonIcon {
        iconSize: Style.font.body
        color: serverRow.isActive || serverRow.isPending ? root.foreground : root.dim
        pulsing: serverRow.isPending
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: serverRow.profile ? serverRow.profile.name : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.body
        font.bold: serverRow.isActive
        elide: Text.ElideRight
        width: parent.width - Style.font.body - Style.space(8)
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: serverMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onEntered: { root.cursorActive = true; root.focusSection = "servers"; root.serverIndex = serverRow.rowIndex }
      onClicked: vpn.choose(serverRow.profile)
    }

    PanelToolTip {
      visible: serverMouse.containsMouse
      text: serverRow.isActive ? "Disconnect" : "Connect"
      fontFamily: root.fontFamily
    }
  }
}
