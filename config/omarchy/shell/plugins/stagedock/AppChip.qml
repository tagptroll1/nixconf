import QtQuick
import qs.Commons

// App chip: icon, plus the title when full.
Row {
  id: chip

  property var dock: null
  property bool full: false
  property string appIcon: ""
  property string label: ""
  property int mentionTotal: 0
  property real maxWidth: 0
  // Tints the title on hover when clicking the chip opens something.
  property bool opensChat: false
  readonly property alias hovered: chipHover.hovered

  spacing: Style.space(8)

  // Passive, so a press here still reaches the body for dragging.
  HoverHandler { id: chipHover }

  Item {
    width: Style.space(24)
    height: width
    anchors.verticalCenter: parent.verticalCenter

    Image {
      id: appIcon
      anchors.fill: parent
      sourceSize.width: width
      sourceSize.height: height
      source: chip.appIcon
    }

    // No themed icon: a lettered badge keeps the tab from reading empty.
    Rectangle {
      visible: appIcon.status !== Image.Ready
      anchors.fill: parent
      radius: width / 2
      color: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 0.1)

      Text {
        anchors.centerIn: parent
        text: chip.dock ? String(chip.dock.appid || chip.dock.title || "?").charAt(0).toUpperCase() : ""
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
        font.bold: true
      }
    }

    // Unread mention count, red like Discord's own badge.
    Rectangle {
      visible: chip.mentionTotal > 0
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.topMargin: -Style.space(4)
      anchors.rightMargin: -Style.space(6)
      height: Style.space(14)
      width: Math.max(height, badgeText.implicitWidth + Style.space(6))
      radius: height / 2
      color: Color.urgent

      Text {
        id: badgeText
        anchors.centerIn: parent
        text: chip.mentionTotal > 99 ? "99+" : String(chip.mentionTotal)
        color: Color.background
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }
  }

  Text {
    visible: chip.full
    width: Math.min(implicitWidth, chip.maxWidth - Style.space(56))
    anchors.verticalCenter: parent.verticalCenter
    text: chip.label
    elide: Text.ElideRight
    color: chip.opensChat && chipHover.hovered ? Color.accent : Color.popups.text
    font.family: Style.font.family
    font.pixelSize: Style.font.body
  }
}
