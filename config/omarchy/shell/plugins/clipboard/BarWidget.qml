import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "ClipboardHistory.js" as ClipboardHistory

// Bar dropdown over the same cliphist history the menu's overlay searches:
// pick an entry to paste it, or drop one that should not linger.
Panel {
  id: root
  moduleName: "omarchy.clipboard-bar"

  property var history: []
  property bool loaded: false
  property int selectedIndex: 0
  property bool cursorActive: false

  readonly property string helper: Quickshell.shellDir + "/plugins/clipboard/history.sh"
  readonly property string cacheDir: Quickshell.env("XDG_RUNTIME_DIR") + "/omarchy-clipboard"
  readonly property var rows: ClipboardHistory.displayRows(history, "", 50)

  function runHelper(verb, id) {
    Quickshell.execDetached(["bash", root.helper, verb, String(id)])
  }

  function moveCursor(dy) {
    if (rows.length === 0 || dy === 0) return
    selectedIndex = Math.max(0, Math.min(rows.length - 1, selectedIndex + dy))
    list.positionViewAtIndex(selectedIndex, ListView.Contain)
  }

  function paste(index) {
    if (index < 0 || index >= rows.length) return
    var id = rows[index].id
    root.close()
    root.runHelper("paste", id)
  }

  function remove(index) {
    if (index < 0 || index >= rows.length) return
    var id = rows[index].id
    root.runHelper("delete", id)
    root.history = root.history.filter(function(entry) { return entry.id !== id })
    if (selectedIndex >= rows.length) selectedIndex = Math.max(0, rows.length - 1)
  }

  onOpenedChanged: {
    if (opened) {
      selectedIndex = 0
      cursorActive = false
      listProc.running = true
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Process {
    id: listProc
    command: ["bash", root.helper, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.history = ClipboardHistory.parseList(text, root.cacheDir)
    }
    // An empty history prints nothing, and no output means no stream event.
    onExited: root.loaded = true
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰅌"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        root.moveCursor(dy)
      }
      onActivateRequested: if (root.cursorActive) root.paste(root.selectedIndex)
      onDeleteRequested: if (root.cursorActive) root.remove(root.selectedIndex)
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
          title: "Clipboard"
          meta: root.rows.length === 1 ? "1 entry" : root.rows.length + " entries"
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          iconComponent: Component {
            Text {
              text: "󰅌"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.display
            }
          }
        }

        Text {
          visible: root.loaded && root.rows.length === 0
          width: parent.width
          text: "Clipboard is empty"
          color: Qt.darker(root.bar.foreground, 1.4)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.body
          horizontalAlignment: Text.AlignHCenter
        }

        ListView {
          id: list
          visible: root.rows.length > 0
          width: parent.width
          height: Math.min(contentHeight, Style.space(440))
          interactive: contentHeight > height
          clip: true
          spacing: Style.space(2)
          boundsBehavior: Flickable.StopAtBounds
          model: root.rows

          delegate: EntryRow {
            required property var modelData
            required property int index

            width: ListView.view.width
            entry: modelData
            rowIndex: index
          }
        }
      }
    }
  }

  component EntryRow: CursorSurface {
    id: row
    required property var entry
    required property int rowIndex

    readonly property bool selected: root.cursorActive && root.selectedIndex === rowIndex

    hasCursor: selected
    foreground: root.bar.foreground
    implicitHeight: Style.space(40)

    MouseArea {
      id: rowMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: if (containsMouse) {
        root.cursorActive = true
        root.selectedIndex = row.rowIndex
      }
      onClicked: root.paste(row.rowIndex)
    }

    Item {
      anchors.fill: parent
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(6)

      Item {
        id: glyph
        width: Style.space(28)
        height: Style.space(28)
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        Image {
          visible: row.entry.previewImage !== ""
          anchors.fill: parent
          source: row.entry.previewImage ? Util.fileUrl(row.entry.previewImage) : ""
          fillMode: Image.PreserveAspectFit
          asynchronous: true
          smooth: true
        }

        Text {
          visible: row.entry.previewImage === ""
          anchors.centerIn: parent
          text: row.entry.entryType === "file" ? "󰈔" : "󰦨"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
        }
      }

      Text {
        anchors.left: glyph.right
        anchors.leftMargin: Style.space(10)
        anchors.right: removeButton.visible ? removeButton.left : parent.right
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        text: row.entry.previewText
        color: root.bar.foreground
        font.family: root.bar.fontFamily
        font.pixelSize: Style.font.body
        elide: Text.ElideRight
        maximumLineCount: 1
      }

      PanelActionButton {
        id: removeButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: row.selected || rowMouse.containsMouse
        iconText: "󰅙"
        tooltipText: "Remove from history (x)"
        foreground: root.bar.foreground
        hoverColor: root.bar.urgent
        fontFamily: root.bar.fontFamily
        onClicked: root.remove(row.rowIndex)
        onHovered: function(h) {
          if (h) {
            root.cursorActive = true
            root.selectedIndex = row.rowIndex
          }
        }
      }
    }
  }
}
