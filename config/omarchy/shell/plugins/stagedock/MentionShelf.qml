import QtQuick
import Quickshell.Widgets
import qs.Commons

// Mention shelf: newest three unread, click opens that message.
Column {
  id: shelf

  property var mentions: []
  property int total: 0
  property bool open: false
  signal opened(string path)

  spacing: Style.space(2)
  opacity: shelf.open ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 120 } }

  Repeater {
    model: shelf.mentions.slice(0, 3)

    delegate: Rectangle {
      id: mention
      required property var modelData
      width: shelf.width
      height: Style.space(44)
      radius: Style.space(8)
      color: mentionArea.containsMouse
        ? Qt.rgba(Colors.popups.text.r, Colors.popups.text.g, Colors.popups.text.b, 0.08)
        : "transparent"

      ClippingRectangle {
        id: avatar
        x: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        width: Style.space(28)
        height: width
        radius: width / 2
        color: Qt.rgba(Colors.popups.text.r, Colors.popups.text.g, Colors.popups.text.b, 0.1)

        Text {
          anchors.centerIn: parent
          visible: avatarImage.status !== Image.Ready
          text: String(mention.modelData.author || "?").charAt(0).toUpperCase()
          color: Colors.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.body
          font.bold: true
        }

        Image {
          id: avatarImage
          anchors.fill: parent
          source: mention.modelData.avatarUrl || ""
          sourceSize.width: width * 2
          sourceSize.height: height * 2
          asynchronous: true
        }
      }

      Column {
        anchors.left: avatar.right
        anchors.leftMargin: Style.space(8)
        anchors.right: parent.right
        anchors.rightMargin: Style.space(6)
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(1)

        Row {
          width: parent.width
          spacing: Style.space(6)

          Text {
            id: author
            width: Math.min(implicitWidth, parent.width / 2)
            text: mention.modelData.author || ""
            elide: Text.ElideRight
            color: mentionArea.containsMouse ? Colors.accent : Colors.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: true
          }

          Text {
            width: parent.width - author.width - parent.spacing
            anchors.baseline: author.baseline
            text: mention.modelData.where || ""
            elide: Text.ElideRight
            color: Colors.muted
            font.family: Style.font.family
            font.pixelSize: Style.font.caption
          }
        }

        Text {
          width: parent.width
          text: mention.modelData.snippet || ""
          elide: Text.ElideRight
          maximumLineCount: 1
          textFormat: Text.PlainText
          color: Colors.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }
      }

      MouseArea {
        id: mentionArea
        anchors.fill: parent
        enabled: shelf.open
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: shelf.opened(mention.modelData.path)
      }
    }
  }

  Text {
    visible: shelf.total > 3
    x: Style.space(6)
    text: "+" + (shelf.total - 3) + " more"
    color: Colors.muted
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
  }
}
