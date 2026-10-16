import QtQuick
import qs.Commons

// Peek: clickable title (undocks), plus transport and seek bar for media.
Row {
  id: peek

  property var player: null
  property bool media: false
  property string label: ""
  property bool leftEdge: false
  property bool peeking: false
  signal undock()
  signal act(string action)

  layoutDirection: peek.leftEdge ? Qt.LeftToRight : Qt.RightToLeft
  spacing: Style.space(6)
  opacity: peek.peeking ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 120 } }

  Row {
    visible: peek.media
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.space(2)
    TransportButton {
      action: "previous"
      player: peek.player
      onClicked: peek.act(action)
    }
    TransportButton {
      action: "next"
      player: peek.player
      onClicked: peek.act(action)
    }
  }

  Column {
    anchors.verticalCenter: parent.verticalCenter
    width: Math.max(peekTitle.width, seek.visible ? Style.space(120) : 0)
    spacing: Style.space(4)

    Text {
      id: peekTitle
      width: Math.min(implicitWidth, Style.space(180))
      text: peek.label
      elide: Text.ElideRight
      color: titleArea.containsMouse ? Color.accent : Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body

      MouseArea {
        id: titleArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: peek.undock()
      }
    }

    // Seek bar; a taller hit area than the drawn line.
    Item {
      id: seek
      readonly property real length: peek.player ? peek.player.length : 0
      visible: peek.media && peek.player.lengthSupported && length > 0
      width: parent.width
      height: Style.space(8)

      // MPRIS position isn't reactive; poll while it's on screen.
      Timer {
        running: peek.peeking && seek.visible && peek.player.isPlaying
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: peek.player.positionChanged()
      }

      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: Style.space(3)
        radius: height / 2
        color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.15)

        Rectangle {
          width: seek.visible ? parent.width * Math.min(1, peek.player.position / seek.length) : 0
          height: parent.height
          radius: parent.radius
          color: Color.accent
        }
      }

      MouseArea {
        anchors.fill: parent
        enabled: peek.player && peek.player.canSeek && peek.player.positionSupported
        cursorShape: Qt.PointingHandCursor
        onClicked: function(mouse) {
          peek.player.position = seek.length * Math.max(0, Math.min(1, mouse.x / width))
        }
      }
    }
  }
}
