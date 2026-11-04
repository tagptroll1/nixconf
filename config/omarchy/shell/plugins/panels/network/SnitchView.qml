import QtQuick
import QtQuick.Controls
import qs.Commons
import "SnitchModel.js" as Model
import "ConnectionMap.js" as MapModel

// Which apps have talked to which hosts. Polls the networker collector only
// while `active`, and hides itself when the snitch is off. Rules are declared
// in services.networker.snitch, so this view only reports them. Collapsed until
// asked for, and then a fixed height: the record only grows, and the panel fits
// itself to its content.
Column {
  id: root

  property bool active: false
  property color foreground: Colors.foreground
  property color accent: Colors.accent
  property string fontFamily: Style.font.family

  // services.networker.listen in modules/features/networker.nix.
  readonly property string endpoint: "http://127.0.0.1:8766"
  readonly property int listHeight: Style.space(200)

  property bool available: false
  property bool expanded: false
  property var rules: null
  property var apps: []
  property string selectedApp: ""
  property var destinations: []
  property real nowMs: 0

  visible: available
  spacing: Style.spacing.sm

  onActiveChanged: {
    if (active) return
    expanded = false
    selectedApp = ""
    destinations = []
  }
  onSelectedAppChanged: {
    destinations = []
    list.contentY = 0
    poll()
  }

  function showApp(app) {
    expanded = true
    selectedApp = app
  }

  function alpha(color, opacity) {
    return Qt.rgba(color.r, color.g, color.b, opacity)
  }

  function get(path, done) {
    var request = new XMLHttpRequest()
    request.onreadystatechange = function() {
      if (request.readyState !== XMLHttpRequest.DONE || request.status !== 200) return
      try { done(JSON.parse(request.responseText)) } catch (e) {}
    }
    request.open("GET", root.endpoint + path)
    request.send()
  }

  function poll() {
    get("/api/config", function(config) {
      root.available = config.snitch === true
      if (!root.available) return
      get("/api/snitch/rules", function(result) { root.rules = result })
      get("/api/snitch/apps", function(result) {
        root.nowMs = Date.now()
        root.apps = Model.byAttention(result)
      })
      var app = root.selectedApp
      if (app === "") return
      get("/api/snitch/apps/" + encodeURIComponent(app), function(result) {
        // A slow answer must not paint over a newer selection.
        if (app === root.selectedApp) root.destinations = Model.byAttention(result)
      })
    })
  }

  Timer {
    interval: 5000
    repeat: true
    triggeredOnStart: true
    running: root.active
    onTriggered: root.poll()
  }

  Item {
    width: parent.width
    height: heading.implicitHeight

    Text {
      id: heading
      text: root.selectedApp !== "" ? "‹ " + root.selectedApp
        : (root.expanded ? "▾" : "▸") + " Apps · " + root.apps.length
      textFormat: Text.PlainText
      width: parent.width - policy.implicitWidth - Style.spacing.sm
      elide: Text.ElideRight
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (root.selectedApp !== "") root.selectedApp = ""
          else root.expanded = !root.expanded
        }
      }
    }

    Text {
      id: policy
      anchors.right: parent.right
      text: Model.policyLabel(root.rules)
      color: root.rules && root.rules.enforcing ? root.accent : root.alpha(root.foreground, 0.6)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Flickable {
    id: list
    visible: root.expanded
    width: parent.width
    height: root.listHeight
    contentHeight: rows.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Text {
      visible: root.apps.length === 0
      text: "Nothing recorded yet"
      color: root.alpha(root.foreground, 0.6)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Column {
      id: rows
      width: parent.width
      spacing: 2

      Repeater {
        model: root.selectedApp === "" ? root.apps : []

        Row_ {
          required property var modelData
          width: rows.width
          title: modelData.app
          detail: modelData.destinations + (modelData.destinations === 1 ? " host" : " hosts")
            + " · ↑ " + MapModel.formatBytes(modelData.sent_bytes)
            + " ↓ " + MapModel.formatBytes(modelData.received_bytes)
            + " · " + Model.ago(modelData.last_seen, root.nowMs)
          flag: modelData.blocked > 0 ? "blocked ×" + modelData.blocked : ""
          clickable: true
          onClicked: root.selectedApp = modelData.app
        }
      }

      Repeater {
        model: root.selectedApp === "" ? [] : root.destinations

        Row_ {
          required property var modelData
          width: rows.width
          title: modelData.host
          detail: "↑ " + MapModel.formatBytes(modelData.sent_bytes)
            + " ↓ " + MapModel.formatBytes(modelData.received_bytes)
            + " · first " + Model.ago(modelData.first_seen, root.nowMs)
            + " · last " + Model.ago(modelData.last_seen, root.nowMs)
          flag: Model.ruleLabel(modelData, root.rules && root.rules.enforcing)
          tooltip: modelData.rule || ""
        }
      }
    }
  }

  component Row_: Item {
    id: row

    property string title: ""
    property string detail: ""
    property string flag: ""
    property string tooltip: ""
    property bool clickable: false
    signal clicked()

    height: titleText.implicitHeight + detailText.implicitHeight + 4

    Rectangle {
      anchors.fill: parent
      radius: 3
      color: root.alpha(root.foreground, area.containsMouse && row.clickable ? 0.08 : 0)
    }

    Text {
      id: titleText
      x: 2
      y: 2
      width: parent.width - flagText.implicitWidth - Style.spacing.sm - 4
      // Names come off the network and out of /proc, so never as markup.
      text: row.title
      textFormat: Text.PlainText
      elide: Text.ElideMiddle
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    Text {
      id: flagText
      y: 2
      anchors.right: parent.right
      anchors.rightMargin: 2
      text: row.flag
      textFormat: Text.PlainText
      color: root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
    }

    Text {
      id: detailText
      x: 2
      y: titleText.y + titleText.implicitHeight
      width: parent.width - 4
      text: row.detail
      textFormat: Text.PlainText
      elide: Text.ElideRight
      color: root.alpha(root.foreground, 0.6)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: row.clickable
      enabled: row.clickable
      cursorShape: row.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: row.clicked()
    }
  }
}
