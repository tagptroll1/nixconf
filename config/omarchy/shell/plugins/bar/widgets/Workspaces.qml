import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "omarchy.workspaces"

  // mango tags are per-monitor, so each bar surface shows its own output's.
  readonly property var barWindow: root.QsWindow.window
  readonly property string monitorName: barWindow && barWindow.screen ? String(barWindow.screen.name || "") : ""
  readonly property var tags: Mango.tagsFor(root.monitorName)

  function tagAt(index) {
    for (var i = 0; i < tags.length; i++) {
      if (Number(tags[i].index) === index) return tags[i]
    }

    return null
  }

  // Always show the first five, then any further tag holding clients, so a bar
  // stays a fixed width on an idle desktop but still surfaces stray windows.
  function tagIndexes() {
    var indexes = [1, 2, 3, 4, 5]

    for (var i = 0; i < tags.length; i++) {
      var index = Number(tags[i].index)
      if (index > 5 && index <= Mango.tagCount && Mango.tagOccupied(tags[i])) indexes.push(index)
    }

    indexes.sort(function(left, right) { return left - right })
    return indexes
  }

  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)

  implicitWidth: grid.implicitWidth + trailingGap
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: root.trailingGap
    columns: root.vertical ? 1 : root.tagIndexes().length
    columnSpacing: root.vertical ? 0 : Style.space(1)
    rowSpacing: root.vertical ? Style.space(2) : 0

    Repeater {
      model: root.tagIndexes()

      WidgetButton {
        required property int modelData

        readonly property var tag: root.tagAt(modelData)
        readonly property bool occupied: Mango.tagOccupied(tag)
        readonly property bool focused: tag !== null && tag.is_active === true
        readonly property bool urgent: tag !== null && tag.is_urgent === true

        bar: root.bar
        text: focused ? "󱓻" : String(modelData)
        active: urgent
        opacity: occupied || focused ? 1 : 0.5
        horizontalMargin: 6
        verticalPadding: 6
        fixedWidth: root.vertical ? root.barSize : Style.space(20)
        fixedHeight: root.barSize
        onPressed: function() { Mango.viewTag(modelData) }
      }
    }
  }
}
