import QtQuick
import QtQuick.Shapes
import qs.Commons
import "ConnectionMap.js" as Model
import "World.js" as World

// Where this machine's live connections go. Polls the networker collector
// (modules/features/networker.nix) only while `active`, and keeps nothing.
Item {
  id: root

  property bool active: false
  property color foreground: Colors.foreground
  property color background: Colors.popups.background
  property color accent: Colors.accent
  property string fontFamily: Style.font.family

  // networker-live's -listen in modules/features/networker.nix.
  readonly property string endpoint: "http://127.0.0.1:8766"
  property var origin: null
  property var routes: []
  property bool reachable: true
  property bool configLoaded: false
  property var pendingRequest: null
  // Collector health; times are the server's clock so local skew cannot fake staleness.
  property real serverNow: 0
  property real lastPollOk: 0
  property string collectorError: ""
  property string dnsError: ""
  readonly property bool stale: reachable && lastPollOk > 0 && (serverNow - lastPollOk) > 5000
  readonly property string status: {
    var lines = []
    if (stale)
      lines.push("Data stale for " + Math.round((serverNow - lastPollOk) / 1000) + "s"
        + (collectorError ? ": " + collectorError : ""))
    else if (collectorError) lines.push("Collector error: " + collectorError)
    else if (lastPollOk === 0) lines.push("Waiting for first collection")
    if (dnsError) lines.push("DNS names unavailable")
    if (configLoaded && origin === null) lines.push("No map origin configured")
    return lines.join(" · ")
  }
  property real dashOffset: 0
  property string hoveredKey: ""
  readonly property real mapScale: width / 1000
  readonly property var originPoint: origin ? Model.project(origin.latitude, origin.longitude) : null
  readonly property var nodes: Model.nodes(routes, width)
  readonly property var badges: {
    // The origin marker stays readable, so badges keep off it.
    var obstacles = []
    if (originPoint)
      obstacles.push({ x: originPoint.x * mapScale - 6, y: originPoint.y * mapScale - 6, width: 12, height: 12 })
    return Model.placeBadges(nodes, width, badgeMetrics.advanceWidth("M"), badgeMetrics.height, obstacles)
  }
  readonly property var hoveredNode: {
    for (var i = 0; i < nodes.length; i++) if (nodes[i].key === hoveredKey) return nodes[i]
    return null
  }

  implicitHeight: width / 2 + (statusLine.visible ? statusLine.height + 4 : 0)

  onActiveChanged: {
    if (active) configLoaded = false
    else {
      cancelRequest()
      routes = []
      hoveredKey = ""
      clearHealth()
    }
  }
  onNodesChanged: routeCanvas.requestPaint()
  onOriginChanged: routeCanvas.requestPaint()

  function get(path, done) {
    var request = new XMLHttpRequest()
    root.pendingRequest = request
    request.onreadystatechange = function() {
      if (request.readyState !== XMLHttpRequest.DONE || root.pendingRequest !== request) return
      root.pendingRequest = null
      requestTimeout.stop()
      if (request.status !== 200) { unavailable(); return }
      try { done(JSON.parse(request.responseText)) } catch (e) { unavailable() }
    }
    request.open("GET", root.endpoint + path)
    requestTimeout.restart()
    request.send()
  }

  function cancelRequest() {
    var request = root.pendingRequest
    root.pendingRequest = null
    requestTimeout.stop()
    if (request) request.abort()
  }

  function unavailable() {
    cancelRequest()
    root.reachable = false
    root.routes = []
    root.configLoaded = false
    clearHealth()
  }

  function clearHealth() {
    root.serverNow = 0
    root.lastPollOk = 0
    root.collectorError = ""
    root.dnsError = ""
  }

  function poll() {
    if (!root.active || root.pendingRequest) return
    // Refresh after reopening or reconnecting, including a valid null origin.
    if (!root.configLoaded) {
      get("/api/config", function(config) {
        root.origin = config.origin
        root.configLoaded = true
        root.poll()
      })
      return
    }
    get("/api/flows", function(flows) {
      root.routes = Model.destinations(flows)
      root.reachable = true
      get("/api/health", function(health) {
        root.serverNow = health.now
        root.lastPollOk = health.last_poll_ok
        root.collectorError = health.last_error || ""
        root.dnsError = health.dns_error || ""
      })
    })
  }

  Timer {
    id: requestTimeout
    interval: 5000
    onTriggered: root.unavailable()
  }

  // Marker under the pointer, or the marker whose badge is under it.
  function nodeAt(x, y) {
    for (var i = 0; i < badges.length; i++) {
      var b = badges[i]
      if (x >= b.x && x <= b.x + b.width && y >= b.y && y <= b.y + b.height) return b.key
    }
    var best = ""
    var bestDistance = Model.NODE_SPACING / 2 + 2
    for (var j = 0; j < nodes.length; j++) {
      var distance = Math.hypot(nodes[j].x - x, nodes[j].y - y)
      if (distance < bestDistance) { best = nodes[j].key; bestDistance = distance }
    }
    return best
  }

  function alpha(color, a) {
    return Qt.rgba(color.r, color.g, color.b, a)
  }

  FontMetrics {
    id: badgeMetrics
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  // The collector's own live view refreshes every second.
  Timer {
    interval: 2000
    repeat: true
    triggeredOnStart: true
    running: root.active
    onTriggered: root.poll()
  }

  Timer {
    interval: 50
    repeat: true
    running: root.active && root.routes.length > 0 && root.origin !== null
    onTriggered: {
      root.dashOffset = (root.dashOffset - 0.5) % 17
      routeCanvas.requestPaint()
    }
  }

  Rectangle {
    width: parent.width
    height: parent.width / 2
    color: root.alpha(root.foreground, 0.03)
    radius: Style.cornerRadius
  }

  Item {
    width: 1000
    height: 500
    transform: Scale { xScale: root.mapScale; yScale: root.mapScale }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        fillColor: root.alpha(root.foreground, 0.1)
        strokeColor: root.alpha(root.foreground, 0.22)
        strokeWidth: 0.6 / Math.max(root.mapScale, 0.01)
        PathSvg { path: World.land }
      }
    }
  }

  Canvas {
    id: routeCanvas
    anchors.fill: parent
    onWidthChanged: requestPaint()

    function stroke(ctx, route, style, width, dash, offset) {
      ctx.strokeStyle = style
      ctx.lineWidth = width
      ctx.setLineDash(dash)
      ctx.lineDashOffset = offset
      for (var shift = -1000; shift <= 1000; shift += 1000) {
        ctx.beginPath()
        ctx.moveTo(route.ax + shift, route.ay)
        ctx.quadraticCurveTo(route.cx + shift, route.cy, route.bx + shift, route.by)
        ctx.stroke()
      }
    }

    function dot(ctx, x, y, radius, style) {
      ctx.fillStyle = style
      ctx.beginPath()
      ctx.arc(x, y, radius, 0, 2 * Math.PI)
      ctx.fill()
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      if (!root.originPoint) return
      var s = root.mapScale
      var from = root.originPoint
      var a = root.accent
      var f = root.foreground
      ctx.save()
      ctx.scale(s, s)
      ctx.lineCap = "round"
      // Widths and dashes are in pixels, so undo the map scale for them.
      for (var i = 0; i < root.routes.length; i++) {
        var target = root.routes[i]
        var route = Model.arc(from, target)
        stroke(ctx, route, root.alpha(a, 0.55), 0.85 / s, [], 0)
        if (target.received > 0)
          stroke(ctx, route, root.alpha(f, 0.5), 0.65 / s, [2, 7], 0)
        stroke(ctx, route, root.alpha(a, 0.9), 1.6 / s, [3, 14], root.dashOffset)
      }
      ctx.restore()
      ctx.setLineDash([])
      for (var j = 0; j < root.nodes.length; j++) {
        var node = root.nodes[j]
        var hovered = node.key === root.hoveredKey
        if (node.flows.length > 1 || hovered) dot(ctx, node.x, node.y, hovered ? 5 : 4, root.alpha(hovered ? f : a, 0.3))
        dot(ctx, node.x, node.y, 2.2, hovered ? f : a)
      }
      dot(ctx, from.x * s, from.y * s, 6, root.alpha(f, 0.18))
      dot(ctx, from.x * s, from.y * s, 2.5, f)
    }
  }

  Repeater {
    model: root.badges

    Rectangle {
      required property var modelData
      readonly property bool hovered: modelData.key === root.hoveredKey
      x: modelData.x
      y: modelData.y
      width: modelData.width
      height: modelData.height
      radius: 3
      color: root.alpha(root.background, 0.85)
      border.width: 1
      border.color: root.alpha(hovered ? root.foreground : root.accent, hovered ? 0.5 : 0.3)

      Text {
        anchors.centerIn: parent
        text: modelData.text
        color: root.alpha(root.foreground, hovered ? 1 : 0.8)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
    onPositionChanged: function(mouse) { root.hoveredKey = root.nodeAt(mouse.x, mouse.y) }
    onExited: root.hoveredKey = ""
  }

  onHoveredKeyChanged: routeCanvas.requestPaint()

  // A few insights for the hovered marker; the badge only fits the busiest app.
  Rectangle {
    id: card
    readonly property var node: root.hoveredNode
    readonly property var appNames: node ? Model.apps(node) : []
    visible: node !== null
    width: Math.min(root.width - 8, cardText.implicitWidth + 12)
    height: cardText.implicitHeight + 8
    x: node ? (node.x + 10 + width <= root.width - 4 ? node.x + 10 : Math.max(4, node.x - 10 - width)) : 0
    y: node ? Math.max(4, Math.min(root.height - height - 4, node.y - height / 2)) : 0
    radius: 4
    color: root.alpha(root.background, 0.95)
    border.width: 1
    border.color: root.alpha(root.foreground, 0.35)

    Column {
      id: cardText
      x: 6
      y: 4
      spacing: 1

      Text {
        text: card.node ? Model.place(card.node.location) : ""
        color: root.foreground
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
      Text {
        text: card.appNames.slice(0, 3).join(", ") + (card.appNames.length > 3 ? " +" + (card.appNames.length - 3) : "")
        color: root.alpha(root.foreground, 0.85)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Text {
        text: card.node ? Model.clip(Model.destinationName(card.node.primary), 34) : ""
        color: root.alpha(root.foreground, 0.7)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
      Text {
        text: card.node
          ? "↑ " + Model.formatBytes(card.node.sent) + "  ↓ " + Model.formatBytes(card.node.received)
            + " · " + card.node.flows.length + (card.node.flows.length === 1 ? " conn" : " conns")
          : ""
        color: root.alpha(root.accent, 0.9)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
      }
    }
  }

  Text {
    anchors.centerIn: parent
    visible: root.active && !root.reachable
    text: "networker collector unavailable"
    color: root.alpha(root.foreground, 0.6)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }

  Text {
    id: statusLine
    y: root.width / 2 + 4
    width: parent.width
    visible: root.active && root.reachable && root.status !== ""
    text: root.status
    horizontalAlignment: Text.AlignHCenter
    elide: Text.ElideRight
    color: root.alpha(root.foreground, 0.6)
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
  }
}
