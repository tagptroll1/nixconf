import QtQuick
import Quickshell
import Quickshell.Io
import "Bridge.js" as Bridge

// Unread Discord mentions plus a one-channel chat, streamed by the
// ShellMentions Vencord userplugin (config/vesktop/userplugins) over a unix
// socket. Mentions are empty while Vesktop is down; the chosen chat is kept
// and reopened when it comes back.
Item {
  id: root

  property var shell: null

  property int total: 0
  property var items: []

  readonly property bool connected: link.item !== null && link.item.connected
  // Renderer behind the socket; a reload bumps it without dropping the socket
  // and 0 means Discord is restarting.
  property int generation: 0
  readonly property bool ready: connected && generation > 0
  // "incompatible" when the renderer found Discord internals it relies on
  // gone; `missing` names them and every command is refused.
  property string bridgeState: "ok"
  property var missing: []

  // Browse lists, filled by list().
  property var dms: []
  property var guilds: []
  property var channels: []
  property string channelsGuild: ""
  property string channelsTitle: ""

  // The chosen chat: { channelId, title, path, messages }, oldest first.
  property string chatId: ""
  property var chat: null
  // loading, ready or error for the newest open of chatId.
  property string chatStatus: ""
  property string chatError: ""
  property string sendError: ""
  // Commands awaiting a reply, see Bridge.js; the ids below are 0 when idle.
  property var pending: ({})
  property int lastId: 0
  property int openId: 0
  property int sendId: 0
  readonly property bool sending: sendId !== 0
  signal sent(string channelId)

  readonly property string socketPath: Quickshell.env("XDG_RUNTIME_DIR") + "/vesktop-mentions.sock"
  property int retryDelay: 2000

  function list(value) {
    return Array.isArray(value) ? value : []
  }

  function apply(line) {
    var msg
    try {
      msg = JSON.parse(String(line || ""))
    } catch (e) {
      return
    }
    var entry = Bridge.claim(root.pending, msg)
    if (entry === undefined) return
    var id = entry ? Number(msg.id) : 0
    if (msg.type === "ready") {
      var generation = Number(msg.generation) || 0
      if (generation === root.generation) return
      root.generation = generation
      // Each renderer checks Discord again and reports its own status.
      root.bridgeState = "ok"
      root.missing = []
      // A new renderer knows nothing of the chosen chat.
      if (generation > 0) {
        if (root.chatId) root.requestChat()
        return
      }
      root.dropPending("Discord restarting; delivery unknown")
    } else if (msg.type === "status") {
      root.bridgeState = msg.state === "incompatible" ? "incompatible" : "ok"
      root.missing = list(msg.missing)
    } else if (msg.type === "dms") {
      root.dms = list(msg.items)
    } else if (msg.type === "guilds") {
      root.guilds = list(msg.items)
    } else if (msg.type === "channels") {
      root.channelsGuild = String(msg.guildId || "")
      root.channelsTitle = String(msg.title || "")
      root.channels = list(msg.items)
    } else if (msg.type === "chat") {
      if (String(msg.channelId || "") !== root.chatId) return
      if (entry && msg.status !== "loading") root.openId = 0
      root.chatStatus = String(msg.status || "ready")
      root.chatError = root.chatStatus === "error" ? String(msg.error || "Could not load messages") : ""
      // A channel Discord can't resolve has no title or messages to show.
      if (!msg.channelId) root.chat = null
      else if (msg.path) root.chat = msg
    } else if (msg.type === "sent") {
      if (!entry || id !== root.sendId) return
      root.finishSend()
      if (entry.channelId !== root.chatId) return
      if (msg.ok) {
        root.sendError = ""
        root.sent(entry.channelId)
      } else {
        root.sendError = String(msg.error || "Send failed")
      }
    } else if (msg.type === "error") {
      if (!entry) return
      var text = msg.reason === "renderer-unavailable" ? "Discord is restarting"
        : msg.reason === "incompatible" ? "Discord bridge incompatible"
        : String(msg.error || "Discord could not do that")
      if (id === root.sendId) {
        root.finishSend()
        if (entry.channelId === root.chatId) root.sendError = text
      } else if (id === root.openId) {
        root.openId = 0
        root.chatStatus = "error"
        root.chatError = text
      }
    } else if (msg.type === "mentions" || msg.type === undefined) {
      root.total = Number(msg.total) || 0
      root.items = list(msg.items)
    }
  }

  // Returns the command's id, or 0 when it could not be sent. A `kind` means
  // the reply is awaited.
  function command(payload, kind) {
    var socket = link.item
    if (!socket || !root.ready) return 0
    var id = ++root.lastId
    payload.id = id
    if (kind) Bridge.track(root.pending, id, kind, payload.send || payload.open)
    socket.write(JSON.stringify(payload) + "\n")
    socket.flush()
    return id
  }

  // Opens Vesktop at a channel or message; the plugin only accepts /channels/... paths.
  function jump(path) {
    if (path) command({ jump: String(path) })
  }

  function browse(scope, guildId) {
    if (scope === "channels") command({ list: "channels", guildId: String(guildId) }, "list")
    else command({ list: scope }, "list")
  }

  function open(channelId) {
    var id = String(channelId || "")
    if (id !== root.chatId) root.chat = null
    root.chatId = id
    root.sendError = ""
    root.requestChat()
  }

  // Only the newest open's answer matters.
  function requestChat() {
    delete root.pending[root.openId]
    root.openId = root.command({ open: root.chatId || null }, "open")
    root.chatStatus = "loading"
    root.chatError = ""
  }

  function reply(text) {
    var content = String(text || "").trim()
    if (!root.chatId || !content || root.sending) return
    if (content.length > 2000) {
      root.sendError = "Messages must be 2000 characters or fewer"
      return
    }
    root.sendError = ""
    root.sendId = command({ send: root.chatId, content: content }, "send")
    if (root.sendId) sendTimeout.restart()
    else root.sendError = "Vesktop is disconnected"
  }

  function finishSend() {
    root.sendId = 0
    sendTimeout.stop()
  }

  // Nothing pending will be answered any more.
  function dropPending(reason) {
    var send = root.pending[root.sendId]
    if (send && send.channelId === root.chatId) root.sendError = reason
    root.pending = ({})
    root.openId = 0
    root.finishSend()
  }

  // A failed connect leaves Socket holding a dead QLocalSocket that setting
  // `connected` again never replaces, so each retry builds a fresh Socket.
  Loader {
    id: link
    sourceComponent: Socket {
      path: root.socketPath
      connected: true
      parser: SplitParser {
        onRead: function(line) { root.apply(line) }
      }
      onConnectedChanged: {
        if (connected) {
          retry.stop()
          root.retryDelay = 2000
          return
        }
        root.generation = 0
        root.bridgeState = "ok"
        root.missing = []
        root.dropPending("Connection lost; delivery unknown")
        root.total = 0
        root.items = []
        root.dms = []
        root.guilds = []
        root.channels = []
        retry.restart()
      }
      onError: retry.restart()
    }
  }

  // Silence leaves the send's fate unknown; the draft stays and nothing resends.
  Timer {
    id: sendTimeout
    interval: 15000
    onTriggered: {
      var send = root.pending[root.sendId]
      delete root.pending[root.sendId]
      root.sendId = 0
      if (send && send.channelId === root.chatId) root.sendError = "Delivery unknown"
    }
  }

  // Vesktop starts after the shell and restarts on its own; keep knocking.
  Timer {
    id: retry
    interval: root.retryDelay
    onTriggered: {
      root.retryDelay = Math.min(root.retryDelay * 2, 30000)
      link.active = false
      link.active = true
    }
  }
}
