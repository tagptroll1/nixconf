// NotificationCard shows three body lines.
var MAX_LINES = 3

// Hosts and app names come off the network and out of /proc, and notification
// bodies can be rendered as markup.
function plain(text) {
  return String(text).replace(/[<>&]/g, "")
}

// One notification per app, so a burst of new hosts is one interruption.
function notifications(alerts) {
  var byApp = {}
  var order = []
  for (var i = 0; i < (alerts || []).length; i++) {
    var alert = alerts[i]
    if (!byApp[alert.app]) {
      byApp[alert.app] = []
      order.push(alert.app)
    }
    byApp[alert.app].push(plain(alert.host) + (alert.blocked ? " (blocked)" : ""))
  }
  return order.map(function(app) {
    var hosts = byApp[app]
    var shown = hosts
    if (hosts.length > MAX_LINES) {
      shown = hosts.slice(0, MAX_LINES - 1)
      shown.push("+" + (hosts.length - shown.length) + " more in the network panel")
    }
    return {
      app: app,
      title: plain(app) + (hosts.length === 1 ? " contacted a new host" : " contacted " + hosts.length + " new hosts"),
      body: shown.join("\n")
    }
  })
}

// The sequence restarts with the collector, so being ahead of it means start over.
function nextCursor(cursor, seq) {
  return seq < cursor ? 0 : seq
}

if (typeof module !== "undefined") {
  module.exports = { notifications: notifications, nextCursor: nextCursor, MAX_LINES: MAX_LINES }
}
