import QtQuick
import qs.Commons
import "DockModel.js" as DockModel

// A media tab's content: play/pause alone when compact, cover, track and
// transport when full.
Item {
  id: mediaTab

  property var player: null
  property bool full: false
  property string appid: ""
  property string appIcon: ""
  // Shown while the player has no track title.
  property string title: ""
  // The tab's compact glyph slot, in this item's coordinates.
  property Item glyphSlot: null
  signal act(string action)

  // Compact media: just play/pause, in the app's brand color if known.
  Item {
    visible: !mediaTab.full
    x: mediaTab.glyphSlot ? mediaTab.glyphSlot.x : 0
    y: mediaTab.glyphSlot ? mediaTab.glyphSlot.y : 0
    width: mediaTab.glyphSlot ? mediaTab.glyphSlot.width : 0
    height: mediaTab.glyphSlot ? mediaTab.glyphSlot.height : 0

    Text {
      readonly property string brand: DockModel.brandColor(mediaTab.appid)
      anchors.centerIn: parent
      text: mediaTab.player && mediaTab.player.isPlaying ? DockModel.glyphs.pause : DockModel.glyphs.play
      color: brand !== "" ? brand
        : mediaTab.player && mediaTab.player.isPlaying ? Color.accent : Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.heading
    }
  }

  // Full media: cover, track and transport.
  Row {
    visible: mediaTab.full
    anchors.fill: parent
    anchors.leftMargin: Style.space(10)
    anchors.rightMargin: Style.space(10)
    spacing: Style.space(10)

    Rectangle {
      width: Style.space(56)
      height: width
      anchors.verticalCenter: parent.verticalCenter
      radius: Style.space(8)
      color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.08)
      clip: true

      Text {
        anchors.centerIn: parent
        visible: cover.status !== Image.Ready
        text: DockModel.glyphs.music
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.display
      }

      Image {
        id: cover
        anchors.fill: parent
        fillMode: Image.PreserveAspectCrop
        source: mediaTab.player && mediaTab.player.trackArtUrl ? mediaTab.player.trackArtUrl : ""
        sourceSize.width: width * 2
        sourceSize.height: height * 2
      }

      // Which app plays it, since track art alone looks alike across
      // Spotify and a browser.
      Rectangle {
        visible: sourceIcon.status === Image.Ready
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Style.space(3)
        width: Style.space(20)
        height: width
        radius: width / 2
        color: Color.popups.background

        Image {
          id: sourceIcon
          anchors.centerIn: parent
          width: Style.space(16)
          height: width
          sourceSize.width: width
          sourceSize.height: height
          source: mediaTab.appIcon
        }
      }
    }

    Column {
      width: parent.width - Style.space(56) - Style.space(10) * 2 - controls.width
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Text {
        width: parent.width
        text: mediaTab.player ? (mediaTab.player.trackTitle || mediaTab.title) : ""
        elide: Text.ElideRight
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: mediaTab.player ? (mediaTab.player.trackArtist || "") : ""
        elide: Text.ElideRight
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    Row {
      id: controls
      anchors.verticalCenter: parent.verticalCenter
      spacing: Style.space(2)

      Repeater {
        model: ["previous", "playPause", "next"]

        delegate: TransportButton {
          required property string modelData
          action: modelData
          player: mediaTab.player
          onClicked: mediaTab.act(modelData)
        }
      }
    }
  }
}
