import QtQuick
import Quickshell.Services.UPower
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "../../menu/MenuTree.js" as MenuTree

Panel {
  id: root
  moduleName: "omarchy.power"
  ipcTarget: "omarchy.power"
  property int profileIndex: 0
  property int actionIndex: 0
  // "profile" walks the profile buttons, "actions" the system rows below.
  property string focusSection: "profile"
  property bool cursorActive: false

  readonly property var profiles: PowerProfiles.hasPerformanceProfile
    ? [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
    : [PowerProfile.PowerSaver, PowerProfile.Balanced]
  readonly property int activeProfile: PowerProfiles.profile
  readonly property string degradationReason: PowerProfiles.degradationReason === PerformanceDegradationReason.None
    ? ""
    : PerformanceDegradationReason.toString(PowerProfiles.degradationReason)

  // Read from the menu's System section so both surfaces offer the same
  // actions and a change lands in one place.
  readonly property var systemNode: {
    var nodes = MenuTree.tree()
    for (var i = 0; i < nodes.length; i++) {
      if (nodes[i].id === "system") return nodes[i]
    }
    return null
  }
  readonly property var systemActions: systemNode ? systemNode.children : []

  function profileLabel(profile) {
    return PowerProfile.toString(profile)
  }

  function profileIcon(profile) {
    return Model.profileIcon(profileLabel(profile))
  }

  function moveCursor(dx, dy) {
    if (focusSection === "profile") {
      if (dx !== 0) profileIndex = Model.selectProfileIndex(profileIndex, dx, profiles)
      else if (dy > 0 && systemActions.length > 0) {
        focusSection = "actions"
        actionIndex = 0
      }
      return
    }
    if (dy === 0) return
    if (dy < 0 && actionIndex === 0) {
      focusSection = "profile"
      return
    }
    actionIndex = Model.clampIndex(actionIndex + dy, systemActions.length)
  }

  function activateCursor() {
    if (focusSection === "profile") {
      if (profileIndex >= 0 && profileIndex < profiles.length) setProfile(profiles[profileIndex])
    } else if (actionIndex >= 0 && actionIndex < systemActions.length) {
      runAction(systemActions[actionIndex])
    }
  }

  function setProfile(profile) {
    PowerProfiles.profile = profile
  }

  function runAction(node) {
    if (!node || !node.action) return
    root.close()
    Util.execDetached(node.action)
  }

  onOpenedChanged: {
    if (opened) {
      var idx = profiles.indexOf(activeProfile)
      profileIndex = idx >= 0 ? idx : 0
      focusSection = "profile"
      actionIndex = 0
      cursorActive = false
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.systemNode ? root.systemNode.icon : ""
    tooltipText: ""
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

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

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        PanelHero {
          width: parent.width
          title: "Power profile"
          meta: root.degradationReason !== ""
            ? "Degraded: " + root.degradationReason
            : root.profileLabel(root.activeProfile)
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          iconComponent: Component {
            Text {
              text: root.profileIcon(root.activeProfile)
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        Row {
          id: profileRow
          width: parent.width
          spacing: Style.space(6)

          readonly property real cellWidth: (width - spacing * (root.profiles.length - 1)) / root.profiles.length

          Repeater {
            model: root.profiles
            Button {
              required property var modelData
              required property int index
              width: profileRow.cellWidth
              iconText: root.profileIcon(modelData)
              iconSize: Style.font.title
              text: root.profileLabel(modelData)
              fontSize: Style.font.bodySmall
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              active: root.activeProfile === modelData
              hasCursor: root.cursorActive && root.focusSection === "profile" && root.profileIndex === index
              onClicked: root.setProfile(modelData)
              onHovered: function(h) {
                if (h) {
                  root.cursorActive = true
                  root.focusSection = "profile"
                  root.profileIndex = index
                }
              }
            }
          }
        }

        PanelSeparator {
          foreground: root.bar.foreground
        }

        Column {
          width: parent.width
          spacing: Style.space(4)

          Repeater {
            model: root.systemActions

            ActionRow {
              required property var modelData
              required property int index

              width: parent.width
              node: modelData
              rowIndex: index
            }
          }
        }
      }
    }
  }

  component ActionRow: CursorSurface {
    id: actionRow
    required property var node
    required property int rowIndex

    hasCursor: root.cursorActive && root.focusSection === "actions" && root.actionIndex === rowIndex
    foreground: root.bar.foreground
    implicitHeight: actionInner.implicitHeight + Style.spacing.xl

    Row {
      id: actionInner
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: Style.space(6)
      anchors.rightMargin: Style.space(6)
      spacing: Style.space(8)

      Text {
        text: actionRow.node.icon
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.title
        width: Style.space(22)
        horizontalAlignment: Text.AlignHCenter
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: actionRow.node.label
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        width: parent.width - Style.space(22) - parent.spacing
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.focusSection = "actions"
        root.actionIndex = actionRow.rowIndex
      }
      onClicked: root.runAction(actionRow.node)
    }
  }
}
