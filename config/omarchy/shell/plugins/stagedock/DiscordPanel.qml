import QtQuick
import Quickshell.Widgets
import qs.Commons
import qs.Ui
import "DockModel.js" as DockModel

// Chat widget under a full Discord tab. Collapsed it previews the newest
// messages of the last chosen chat; expanded it browses mentions, DMs and
// server channels, reads a chat and replies to it.
Item {
  id: root

  required property var service
  property bool expanded: false
  signal openInVesktop(string path)

  // The tab's header row, and the part of it left beside the app chip.
  required property Item titleParent
  property real titleX: 0
  property real titleWidth: 0

  // Typing keeps the panel open after the pointer leaves; losing keyboard
  // focus to another window lets it close.
  readonly property bool focused: Window.active
  readonly property bool holding: input.activeFocus && focused
  readonly property bool inChat: current.view === "chat"
  // Socket up but no renderer behind it; lists and fetches would never answer.
  readonly property bool restarting: service.connected && !service.ready
  // Why lists and chat can't be shown, or "" when they can.
  readonly property string blocked: restarting ? "Discord is restarting"
    : service.bridgeState === "incompatible" ? "Discord bridge incompatible: " + service.missing.join(", ")
    : ""

  readonly property int rowHeight: Style.space(34)
  property int messageHeight: Style.space(54)
  readonly property int maxRows: 6
  readonly property int navHeight: Style.space(28)
  readonly property var messages: service.chat ? DockModel.list(service.chat.messages) : []
  // What the collapsed preview needs, so the dock can reserve it: the
  // messages and the message box, spaced as `view` spaces them.
  readonly property real previewHeight: messages.length > 0
    ? messages.length * (messageHeight + Style.space(4)) + Style.space(26) + Style.space(8) : 0

  property var trail: [{ view: "home" }]
  readonly property var current: trail[trail.length - 1]
  readonly property string title: current.view === "dms" ? "Direct messages"
    : current.view === "guilds" ? "Servers"
    : current.view === "channels" ? (service.channelsTitle || current.title || "")
    : current.view === "chat" && service.chat ? service.chat.title : ""
  // The shown chat can open in Vesktop; the tab's app chip does that.
  readonly property bool canOpen: inChat && service.chat !== null

  function openChat() {
    if (canOpen) openInVesktop(service.chat.path)
  }

  implicitHeight: expanded ? view.implicitHeight + Style.space(8) : previewHeight

  function tint(alpha) {
    return Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, alpha)
  }

  function load(step) {
    if (step.view === "dms" || step.view === "guilds") service.browse(step.view)
    else if (step.view === "channels") service.browse("channels", step.guildId)
    else if (step.view === "chat" && !shown(step.channelId)) service.open(step.channelId)
  }

  // The plugin pushes live messages for the open chat, so re-opening it on
  // every hover only refetches what is already on screen.
  function shown(channelId) {
    return channelId === service.chatId && service.chat !== null && service.chatStatus !== "error"
  }

  function go(step) {
    input.focus = false
    trail = trail.concat([step])
    load(step)
  }

  function back() {
    input.focus = false
    if (trail.length > 1) trail = trail.slice(0, -1)
    load(current)
  }

  // Each hover starts at the chosen chat, one step above home.
  function reset() {
    input.focus = false
    trail = service.chatId ? [{ view: "home" }, { view: "chat", channelId: service.chatId }] : [{ view: "home" }]
  }

  function submit() {
    if (!input.text.trim() || service.sending) return
    service.reply(input.text)
  }

  onExpandedChanged: {
    if (expanded) {
      load(current)
      return
    }
    // Leaving from anywhere but a chat means backing out of it, so the tab
    // stops previewing it. Done on close, not on back, so the tab's packed
    // size never changes under the pointer.
    if (!inChat && service.chatId) service.open("")
    reset()
  }
  onFocusedChanged: if (!focused) input.focus = false
  Component.onCompleted: reset()

  Connections {
    target: root.service
    function onChatIdChanged() {
      input.text = ""
      input.focus = false
    }
    function onSent(channelId) {
      if (channelId !== root.service.chatId) return
      input.text = ""
      input.focus = false
    }
    function onConnectedChanged() {
      if (!root.service.connected) root.reset()
    }
  }

  // Clicks between the controls would otherwise reach the tab body and undock.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.AllButtons
  }

  component Glyph: Rectangle {
    id: glyph
    property string icon: ""
    property string label: ""
    signal clicked()

    height: Style.space(26)
    width: label ? glyphRow.implicitWidth + Style.space(16) : height
    radius: height / 2
    color: glyphArea.containsMouse ? root.tint(0.1) : "transparent"

    Row {
      id: glyphRow
      anchors.centerIn: parent
      spacing: Style.space(4)
      Text {
        visible: glyph.icon !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: glyph.icon
        color: glyphArea.containsMouse ? Color.accent : Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.body
      }
      Text {
        visible: glyph.label !== ""
        anchors.verticalCenter: parent.verticalCenter
        text: glyph.label
        color: glyphArea.containsMouse ? Color.accent : Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
        font.bold: true
      }
    }

    MouseArea {
      id: glyphArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: glyph.clicked()
    }
  }

  component Avatar: ClippingRectangle {
    id: avatar
    property string source: ""
    property string name: ""
    width: Style.space(24)
    height: width
    radius: width / 2
    color: root.tint(0.1)

    Text {
      anchors.centerIn: parent
      visible: avatarImage.status !== Image.Ready
      text: String(avatar.name || "?").replace(/^#/, "").charAt(0).toUpperCase()
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: true
    }

    Image {
      id: avatarImage
      anchors.fill: parent
      source: avatar.source
      sourceSize.width: width * 2
      sourceSize.height: height * 2
      asynchronous: true
    }
  }

  // A DM, server or channel; unread shows as a dot, mentions as a count.
  component Entry: Rectangle {
    id: entry
    required property var modelData
    property bool icon: true
    signal picked()

    width: ListView.view ? ListView.view.width : 0
    height: root.rowHeight
    radius: Style.space(8)
    color: entryArea.containsMouse ? root.tint(0.08) : "transparent"

    Avatar {
      id: entryIcon
      visible: entry.icon
      x: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      source: entry.modelData.iconUrl || ""
      name: entry.modelData.name || ""
    }

    Text {
      anchors.left: entry.icon ? entryIcon.right : parent.left
      anchors.leftMargin: Style.space(8)
      anchors.right: marker.left
      anchors.rightMargin: Style.space(6)
      anchors.verticalCenter: parent.verticalCenter
      text: entry.modelData.name || ""
      elide: Text.ElideRight
      textFormat: Text.PlainText
      color: entryArea.containsMouse ? Color.accent
        : entry.modelData.unread || entry.modelData.mentions ? Color.popups.text : Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      font.bold: !!(entry.modelData.unread || entry.modelData.mentions)
    }

    Rectangle {
      id: marker
      anchors.right: parent.right
      anchors.rightMargin: Style.space(8)
      anchors.verticalCenter: parent.verticalCenter
      visible: entry.modelData.mentions > 0 || entry.modelData.unread
      height: entry.modelData.mentions > 0 ? Style.space(14) : Style.space(6)
      width: entry.modelData.mentions > 0 ? Math.max(height, count.implicitWidth + Style.space(6)) : height
      radius: height / 2
      color: entry.modelData.mentions > 0 ? Color.urgent : Color.popups.text

      Text {
        id: count
        anchors.centerIn: parent
        visible: entry.modelData.mentions > 0
        text: entry.modelData.mentions > 99 ? "99+" : String(entry.modelData.mentions)
        color: Color.background
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    MouseArea {
      id: entryArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: entry.picked()
    }
  }

  component Message: Item {
    id: message
    required property var modelData
    required property int index
    property string where: ""
    property bool clickable: false
    signal picked()

    height: root.messageHeight

    Rectangle {
      anchors.fill: parent
      radius: Style.space(8)
      color: message.clickable && messageArea.containsMouse ? root.tint(0.08) : "transparent"
    }

    Avatar {
      id: messageAvatar
      x: Style.space(6)
      y: Style.space(8)
      source: message.modelData.avatarUrl || ""
      name: message.modelData.author || ""
    }

    Column {
      anchors.left: messageAvatar.right
      anchors.leftMargin: Style.space(8)
      anchors.right: parent.right
      anchors.rightMargin: Style.space(6)
      y: Style.space(6)
      spacing: Style.space(1)

      Row {
        width: parent.width
        spacing: Style.space(6)

        Text {
          id: author
          width: Math.min(implicitWidth, parent.width / 2)
          text: message.modelData.author || ""
          elide: Text.ElideRight
          textFormat: Text.PlainText
          color: message.clickable && messageArea.containsMouse ? Color.accent : Color.popups.text
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
          font.bold: true
        }

        Text {
          width: parent.width - author.width - parent.spacing
          anchors.baseline: author.baseline
          text: message.where
          elide: Text.ElideRight
          textFormat: Text.PlainText
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        width: parent.width
        text: message.modelData.snippet || ""
        wrapMode: Text.Wrap
        elide: Text.ElideRight
        maximumLineCount: 2
        textFormat: Text.PlainText
        color: Color.popups.text
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    MouseArea {
      id: messageArea
      anchors.fill: parent
      enabled: message.clickable
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: message.picked()
    }
  }

  // Back and the view's title, drawn in the tab's own header row beside the
  // app chip, so the panel spends no row on them.
  Item {
    parent: root.titleParent
    x: root.titleX
    width: root.titleWidth
    height: parent ? parent.height : 0
    clip: true

    Glyph {
      id: backButton
      visible: root.trail.length > 1
      anchors.verticalCenter: parent.verticalCenter
      icon: DockModel.glyphs.back
      onClicked: root.back()
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      x: backButton.visible ? backButton.width + Style.space(4) : 0
      width: parent.width - x
      text: root.title
      elide: Text.ElideRight
      textFormat: Text.PlainText
      color: Color.popups.text
      font.family: Style.font.family
      font.pixelSize: Style.font.body
      font.bold: true
    }
  }

  // Collapsed, the chosen chat's newest messages; expanded, the same rows
  // stay put and the rest appends below, so hovering never moves what was
  // already shown.
  Column {
    id: view
    width: parent.width
    visible: root.expanded || root.messages.length > 0
    spacing: Style.space(4)

    // The two ways in from home.
    Row {
      visible: root.expanded && root.current.view === "home"
      height: root.navHeight
      spacing: Style.space(4)

      Glyph {
        anchors.verticalCenter: parent.verticalCenter
        label: "DMs"
        onClicked: root.go({ view: "dms" })
      }
      Glyph {
        anchors.verticalCenter: parent.verticalCenter
        label: "Servers"
        onClicked: root.go({ view: "guilds" })
      }
    }

    Text {
      visible: root.expanded && root.blocked !== "" && !root.inChat
      x: Style.space(6)
      width: parent.width - x
      height: Math.max(root.rowHeight, implicitHeight)
      verticalAlignment: Text.AlignVCenter
      text: root.blocked
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      color: Color.muted
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
    }

    // Exact message links keep older mentions reachable.
    Column {
      visible: root.expanded && root.current.view === "home" && root.blocked === ""
      width: parent.width
      spacing: Style.space(2)

      Repeater {
        model: root.current.view === "home" ? root.service.items.slice(0, 3) : []
        delegate: Message {
          width: parent.width
          where: modelData.where || ""
          clickable: true
          onPicked: root.openInVesktop(modelData.path)
        }
      }

      Text {
        visible: root.service.items.length === 0
        x: Style.space(6)
        height: root.rowHeight
        verticalAlignment: Text.AlignVCenter
        text: "No unread mentions"
        color: Color.muted
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    ListView {
      id: entries
      readonly property var rows: root.current.view === "dms" ? root.service.dms
        : root.current.view === "guilds" ? root.service.guilds
        : root.current.view === "channels" && root.service.channelsGuild === root.current.guildId ? root.service.channels
        : []
      visible: root.expanded && root.blocked === "" && (root.current.view === "dms" || root.current.view === "guilds" || root.current.view === "channels")
      width: parent.width
      height: visible ? Math.max(1, Math.min(count, root.maxRows)) * (root.rowHeight + spacing) : 0
      spacing: Style.space(2)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: rows

      delegate: Entry {
        icon: root.current.view !== "channels"
        onPicked: {
          if (root.current.view === "guilds") root.go({ view: "channels", guildId: modelData.id, title: modelData.name })
          else root.go({ view: "chat", channelId: modelData.id })
        }
      }

      onRowsChanged: positionViewAtBeginning()
    }

    // Chat: the newest messages and a message box.
    Column {
      visible: root.inChat
      width: parent.width
      spacing: Style.space(4)

      Repeater {
        model: root.inChat ? root.messages : []
        delegate: Message { width: parent.width }
      }

      Item {
        readonly property bool failed: root.blocked === "" && root.service.chatStatus === "error"
        visible: root.expanded && root.messages.length === 0
        width: parent.width
        height: root.rowHeight

        Text {
          id: emptyText
          x: Style.space(6)
          width: Math.min(implicitWidth, parent.width - x - (retryButton.visible ? retryButton.width + Style.space(4) : 0))
          anchors.verticalCenter: parent.verticalCenter
          text: root.blocked !== "" ? root.blocked
            : parent.failed ? root.service.chatError
            : root.service.chatStatus === "ready" ? "No messages yet" : "Loading…"
          elide: Text.ElideRight
          textFormat: Text.PlainText
          color: Color.muted
          font.family: Style.font.family
          font.pixelSize: Style.font.bodySmall
        }

        Glyph {
          id: retryButton
          visible: parent.failed
          anchors.left: emptyText.right
          anchors.leftMargin: Style.space(4)
          anchors.verticalCenter: parent.verticalCenter
          icon: DockModel.glyphs.retry
          onClicked: root.service.open(root.service.chatId)
        }
      }

      Text {
        visible: root.expanded && root.service.sendError !== ""
        width: parent.width
        x: Style.space(6)
        text: root.service.sendError
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        color: Color.urgent
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }

      // Shown collapsed too, so hovering adds no row and the tab never grows.
      TextField {
        id: input
        enabled: !root.service.sending
        width: parent.width
        height: Style.space(26)
        verticalPadding: 0
        rightPadding: sendButton.width + Style.space(4)
        verticalAlignment: TextInput.AlignVCenter
        placeholderText: "Message " + (root.service.chat ? root.service.chat.title : "")
        foreground: Color.popups.text
        font.pixelSize: Style.font.bodySmall
        onAccepted: root.submit()
        Keys.onEscapePressed: input.focus = false

        Glyph {
          id: sendButton
          anchors.right: parent.right
          anchors.rightMargin: Style.space(2)
          anchors.verticalCenter: parent.verticalCenter
          height: parent.height - Style.space(4)
          icon: DockModel.glyphs.send
          onClicked: root.submit()
        }
      }
    }
  }
}
