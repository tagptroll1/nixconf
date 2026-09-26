import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// The keybinding sheet: every bind mango has loaded, two columns wide, read
// back from the config each time it opens so it cannot drift from what is
// actually bound.
//
// Display-only — nothing here fires a bind, so there is no selection to track.
// Typing filters, the arrows scroll, Esc leaves.
Item {
  id: root

  property var shell: null

  property bool opened: false
  property string filterText: ""
  property var rows: []

  // Shares the [menu] surface tokens, so a theme that styles the menu styles
  // this too.
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color accent: Color.menu.selectedText
  property color rowBackground: Color.menu.selectedBackground
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int headerHeight: Math.max(Style.space(34), Style.font.title + Style.spacing.controlPaddingY * 2)
  property int contentSpacing: Style.spacing.md

  // Wide by intent: the action column carries full script paths and the qs ipc
  // lines, and eliding those is what made a narrow card useless.
  property int cardWidth: Math.min(Style.space(1100), panel.width - Style.gapsOut * 2)
  property int cardHeight: Math.min(Style.space(760), panel.height - Style.gapsOut * 2)

  property int columns: 2
  property int cellWidth: Math.floor((cardWidth - contentMargin * 2) / columns)
  property int cellHeight: Style.font.body + Style.font.caption + Style.spacing.xs
                           + Style.spacing.controlPaddingY * 2

  function open(payloadJson) {
    root.opened = true
    root.filterText = ""
    // Re-read on every open: editing keybinds.conf and reloading mango must
    // not need a shell restart to show up here.
    loadProc.running = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide("omarchy.keybindings")
  }

  function setFilter(value) {
    root.filterText = value
    root.rebuildDisplay()
    grid.positionViewAtBeginning()
  }

  function rebuildDisplay() {
    var out = Model.filter(root.rows, root.filterText)
    displayModel.clear()
    for (var i = 0; i < out.length; i++) displayModel.append(out[i])
  }

  ListModel { id: displayModel }

  Process {
    id: loadProc
    command: ["bash", "-lc", Model.script()]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.rows = Model.parse(text)
        root.rebuildDisplay()
      }
    }
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-keybindings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) root.setFilter("")
            else root.dismiss()
            event.accepted = true
          } else if (Util.editsFilter(event, root.filterText)) {
            root.setFilter(Util.editedFilter(event, root.filterText))
            event.accepted = true
          } else if (event.key === Qt.Key_Up) {
            grid.flick(0, Style.space(600))
            event.accepted = true
          } else if (event.key === Qt.Key_Down) {
            grid.flick(0, -Style.space(600))
            event.accepted = true
          } else if (event.key === Qt.Key_PageUp) {
            grid.contentY = Math.max(0, grid.contentY - grid.height)
            event.accepted = true
          } else if (event.key === Qt.Key_PageDown) {
            grid.contentY = Math.min(Math.max(0, grid.contentHeight - grid.height),
                                     grid.contentY + grid.height)
            event.accepted = true
          } else if (event.text && event.text.length === 1
                     && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
            root.setFilter(root.filterText + event.text)
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        Item {
          width: parent.width
          height: root.headerHeight

          Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - countLabel.width - Style.spacing.lg
            text: root.filterText || "Search keybindings…"
            color: root.foreground
            opacity: root.filterText ? 1 : 0.58
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            elide: Text.ElideRight
          }

          Text {
            id: countLabel
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: displayModel.count + (root.filterText ? " / " + root.rows.length : "")
            color: root.foreground
            opacity: 0.45
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        Item {
          width: parent.width
          height: parent.height - root.headerHeight - root.contentSpacing

          GridView {
            id: grid
            anchors.fill: parent
            model: displayModel
            clip: true
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            // Column-major: the eye reads one list down the left and continues
            // down the right, rather than zig-zagging across two.
            flow: GridView.FlowTopToBottom
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
              required property string comboDisplay
              required property string action
              required property string combo

              width: root.cellWidth
              height: root.cellHeight

              Rectangle {
                anchors.fill: parent
                anchors.rightMargin: Style.spacing.sm
                anchors.topMargin: Style.spacing.hairline
                anchors.bottomMargin: Style.spacing.hairline
                radius: root.cornerRadius
                color: hover.hovered ? root.rowBackground : "transparent"

                HoverHandler { id: hover }

                Column {
                  anchors.left: parent.left
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                  anchors.leftMargin: Style.spacing.rowPaddingX
                  anchors.rightMargin: Style.spacing.sm
                  spacing: Style.spacing.xs

                  Row {
                    width: parent.width
                    spacing: Style.spacing.lg

                    Text {
                      id: comboText
                      // A fixed share of the row keeps the action column
                      // aligned down the list instead of stepping with every
                      // combo length. Glyph modifiers need much less of it than
                      // the spelled-out names did.
                      width: Math.round(parent.width * 0.28)
                      text: comboDisplay
                      color: root.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      font.bold: true
                      elide: Text.ElideRight
                    }

                    Text {
                      width: parent.width - comboText.width - parent.spacing
                      text: action
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.body
                      elide: Text.ElideRight
                    }
                  }

                  // The spelled-out combo, because the glyph row above says
                  // which keys without naming them.
                  Text {
                    width: parent.width
                    text: combo
                    color: root.foreground
                    opacity: 0.5
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                  }
                }
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: displayModel.count === 0
            text: root.rows.length === 0
              ? "No binds found in the mango config"
              : "No matches for “" + root.filterText + "”"
            color: root.foreground
            opacity: 0.7
            font.family: root.fontFamily
            font.pixelSize: Style.font.title
          }
        }
      }
    }
  }
}
