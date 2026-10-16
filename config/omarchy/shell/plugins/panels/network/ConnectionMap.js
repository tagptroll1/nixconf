.pragma library

// Markers closer than this (px) would overlap, so they share one marker.
var NODE_SPACING = 12
var BADGE_PAD_X = 4
var BADGE_PAD_Y = 1
var BADGE_GAP = 7
var EDGE = 3
var BADGE_CHARS = 20

// Equirectangular, matching World.js's 1000x500 box.
function project(latitude, longitude) {
  return { x: (longitude + 180) * 1000 / 360, y: (90 - latitude) * 500 / 180 }
}

function traffic(flow) {
  return flow.sent_bytes + flow.received_bytes
}

// One route per located outbound destination; many sockets to one CDN edge
// would otherwise stack into a single thick line.
function destinations(flows) {
  var grouped = {}
  var result = []
  for (var i = 0; i < (flows || []).length; i++) {
    var flow = flows[i]
    if (!flow.location || flow.direction !== "outbound") continue
    var key = flow.location.latitude.toFixed(3) + ":" + flow.location.longitude.toFixed(3)
    var group = grouped[key]
    if (!group) {
      var point = project(flow.location.latitude, flow.location.longitude)
      group = grouped[key] = { key: key, x: point.x, y: point.y, location: flow.location,
                               flows: [], primary: flow, sent: 0, received: 0 }
      result.push(group)
    }
    group.flows.push(flow)
    group.sent += flow.sent_bytes
    group.received += flow.received_bytes
    if (traffic(flow) > traffic(group.primary)) group.primary = flow
  }
  return result
}

// Destinations in map pixels. Only those whose markers would physically
// overlap share one, so zoomed-out Europe does not become a smear.
function nodes(groups, width) {
  var result = []
  var sorted = groups.slice().sort(function(a, b) { return a.key < b.key ? -1 : a.key > b.key ? 1 : 0 })
  for (var i = 0; i < sorted.length; i++) {
    var group = sorted[i]
    var x = group.x * width / 1000
    var y = group.y * width / 1000
    var node = null
    for (var j = 0; j < result.length && !node; j++) {
      var dx = Math.abs(result[j].x - x)
      if (Math.hypot(Math.min(dx, width - dx), result[j].y - y) < NODE_SPACING) node = result[j]
    }
    if (!node) {
      node = { key: group.key, x: x, y: y, location: group.location, flows: [], primary: group.primary, sent: 0, received: 0 }
      result.push(node)
    }
    node.flows = node.flows.concat(group.flows)
    node.sent += group.sent
    node.received += group.received
    if (traffic(group.primary) > traffic(node.primary)) node.primary = group.primary
  }
  return result
}

function formatBytes(bytes) {
  if (bytes < 1024) return bytes + " B"
  var unit = Math.min(Math.floor(Math.log(bytes) / Math.log(1024)), 4)
  var value = bytes / Math.pow(1024, unit)
  return (value < 10 ? value.toFixed(1) : Math.round(value)) + " " + ["B", "KiB", "MiB", "GiB", "TiB"][unit]
}

// Nix wrappers exec `.name-wrapped`, which is what the kernel reports.
function appName(flow) {
  if (!flow.app || flow.app === "unknown") return "unknown app"
  return flow.app.replace(/^\.(.+)-wrapped$/, "$1")
}

function remoteIP(socket) {
  if (socket.charAt(0) === "[") return socket.slice(1, socket.lastIndexOf("]"))
  return socket.slice(0, socket.lastIndexOf(":"))
}

function destinationName(flow) {
  return flow.domain || remoteIP(flow.remote)
}

function place(location) {
  return [location.city, location.country].filter(Boolean).join(", ") || "Approximate location"
}

function clip(text, max) {
  return text.length > max ? text.slice(0, Math.max(1, max - 1)) + "…" : text
}

// "firefox +3 1.2 MiB": the busiest app, how many more sockets, total bytes.
function badgeText(node) {
  var extra = node.flows.length > 1 ? " +" + (node.flows.length - 1) : ""
  var total = formatBytes(node.sent + node.received)
  return clip(appName(node.primary), BADGE_CHARS - extra.length - total.length - 1) + extra + " " + total
}

// Distinct apps behind a node, busiest first.
function apps(node) {
  var totals = {}
  for (var i = 0; i < node.flows.length; i++) {
    var name = appName(node.flows[i])
    totals[name] = (totals[name] || 0) + traffic(node.flows[i])
  }
  return Object.keys(totals).sort(function(a, b) { return totals[b] - totals[a] })
}

function overlaps(a, b) {
  return a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height
}

// Spots around a marker, most readable first.
function candidates(x, y, width, height) {
  var d = BADGE_GAP * 0.7
  return [
    { x: x + BADGE_GAP, y: y - height / 2 },
    { x: x - BADGE_GAP - width, y: y - height / 2 },
    { x: x + d, y: y - d - height },
    { x: x + d, y: y + d },
    { x: x - d - width, y: y - d - height },
    { x: x - d - width, y: y + d },
    { x: x - width / 2, y: y - BADGE_GAP - height },
    { x: x - width / 2, y: y + BADGE_GAP }
  ]
}

// Gives the busiest markers a badge first, each in the first spot that stays
// on the map and clear of markers, other badges and obstacles. Markers left
// without room keep their details on hover.
function placeBadges(list, width, charWidth, lineHeight, obstacles) {
  var height = width / 2
  var markers = list.map(function(node) {
    return { x: node.x - NODE_SPACING / 2, y: node.y - NODE_SPACING / 2, width: NODE_SPACING, height: NODE_SPACING }
  })
  var order = list.map(function(node, index) { return index }).sort(function(a, b) {
    return (list[b].sent + list[b].received) - (list[a].sent + list[a].received) || (list[a].key < list[b].key ? -1 : 1)
  })
  var placed = []
  for (var o = 0; o < order.length; o++) {
    var index = order[o]
    var node = list[index]
    var text = badgeText(node)
    var w = Math.ceil(text.length * charWidth + BADGE_PAD_X * 2 + 2)
    var h = Math.ceil(lineHeight + BADGE_PAD_Y * 2 + 2)
    var spots = candidates(node.x, node.y, w, h)
    for (var s = 0; s < spots.length; s++) {
      var spot = { x: Math.round(spots[s].x), y: Math.round(spots[s].y), width: w, height: h }
      if (spot.x < EDGE || spot.y < EDGE || spot.x + w > width - EDGE || spot.y + h > height - EDGE) continue
      var blocked = obstacles.some(function(rect) { return overlaps(spot, rect) })
        || markers.some(function(rect, other) { return other !== index && overlaps(spot, rect) })
        || placed.some(function(badge) { return overlaps(spot, badge) })
      if (blocked) continue
      spot.key = node.key
      spot.text = text
      placed.push(spot)
      break
    }
  }
  return placed
}

// Quadratic arc lifted towards the pole. Takes the short way round, so a
// route may leave one edge; callers draw it again shifted by +-1000.
function arc(from, to) {
  var x = to.x
  if (x - from.x > 500) x -= 1000
  if (x - from.x < -500) x += 1000
  var lift = Math.min(75, Math.abs(x - from.x) * 0.16)
  return { ax: from.x, ay: from.y, cx: (from.x + x) / 2, cy: (from.y + to.y) / 2 - lift, bx: x, by: to.y }
}
