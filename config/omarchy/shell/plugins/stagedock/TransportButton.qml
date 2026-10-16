import QtQuick
import qs.Commons
import "DockModel.js" as DockModel

// Previous, play/pause or next for one MPRIS player.
Rectangle {
  id: transport

  property string action: ""
  property var player: null
  signal clicked()

  width: Style.space(28)
  height: width
  radius: width / 2
  color: button.containsMouse
    ? Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.1)
    : "transparent"

  Text {
    anchors.centerIn: parent
    text: transport.action === "previous" ? DockModel.glyphs.previous
      : transport.action === "next" ? DockModel.glyphs.next
      : transport.player && transport.player.isPlaying ? DockModel.glyphs.pause
      : DockModel.glyphs.play
    color: transport.action === "playPause" && transport.player && transport.player.isPlaying
      ? Color.accent : Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.heading
  }

  MouseArea {
    id: button
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: transport.clicked()
  }
}
