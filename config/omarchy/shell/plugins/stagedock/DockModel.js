.pragma library

// Docked windows from one `mmsg watch all-clients` line, keyed by client id so
// the view keeps its windows while unrelated clients change. A window being
// dragged into dock range comes as a preview of the tab its release makes.
function docksFrom(line) {
  var payload
  try {
    payload = JSON.parse(String(line || ""))
  } catch (e) {
    return null
  }
  var list = payload && Array.isArray(payload.clients) ? payload.clients : null
  if (!list) return null

  var ids = []
  var byId = {}
  for (var i = 0; i < list.length; i++) {
    var c = list[i]
    var dock = c ? c.stage_dock || c.stage_dock_preview : null
    if (!dock) continue
    ids.push(Number(c.id))
    byId[Number(c.id)] = {
      id: Number(c.id),
      appid: String(c.appid || ""),
      pid: Number(c.pid) || 0,
      title: String(c.title || ""),
      // A preview names the monitor the drop lands on.
      monitor: String(dock.monitor || c.monitor || ""),
      edge: dock.edge === "left" ? "left" : "right",
      mini: dock.tier === "mini",
      y: Number(dock.y) || 0,
      preview: !c.stage_dock
    }
  }
  ids.sort(function(a, b) { return a - b })
  return { ids: ids, byId: byId }
}

// MPRIS names its player after the desktop entry or bus suffix, which is how
// a docked window finds the player it should control. An app whose player
// names itself otherwise needs an appid alias here.
function playerMatches(player, appid) {
  var a = String(appid || "").toLowerCase()
  if (!player || a === "") return false
  var entry = String(player.desktopEntry || "").toLowerCase()
  var identity = String(player.identity || "").toLowerCase()
  var bus = String(player.dbusName || "").toLowerCase()
  return entry === a || identity === a ||
    bus.slice(-(a.length + 1)) === "." + a || bus.indexOf("." + a + ".") !== -1
}

// playerctld forwards whichever player was active last, so binding it would
// let a tab steer another window's player.
function isProxyPlayer(player) {
  var bus = String(player && player.dbusName || "").toLowerCase()
  var entry = String(player && player.desktopEntry || "").toLowerCase()
  return bus.indexOf("playerctld") !== -1 || entry === "playerctld"
}

// Several players for one app (two instances) go to the one owned by the
// window's process or a child of it. pidOf(dbusName) gives the bus owner's
// pid chain up to init, or null while it is still being looked up.
function playerFor(players, appid, pid, pidOf) {
  var list = players || []
  var matches = []
  for (var i = 0; i < list.length; i++) {
    if (!isProxyPlayer(list[i]) && playerMatches(list[i], appid)) matches.push(list[i])
  }
  if (matches.length === 0) return null
  if (matches.length > 1 && pid > 0 && pidOf) {
    for (i = 0; i < matches.length; i++) {
      var chain = pidOf(matches[i].dbusName)
      if (chain && chain.indexOf(pid) !== -1) return matches[i]
    }
  }
  return matches[0]
}

// The docked window whose tab carries the Discord mention shelf.
function isDiscord(appid) {
  var a = String(appid || "").toLowerCase()
  return a === "vesktop" || a === "discord"
}

function list(value) {
  return Array.isArray(value) ? value : []
}

var glyphs = {
  play: String.fromCodePoint(0xF040A),
  pause: String.fromCodePoint(0xF03E4),
  next: String.fromCodePoint(0xF04AD),
  previous: String.fromCodePoint(0xF04AE),
  music: String.fromCodePoint(0xF075A),
  back: String.fromCodePoint(0xF0141),
  send: String.fromCodePoint(0xF0142),
  openExternal: String.fromCodePoint(0xF03CC),
  retry: String.fromCodePoint(0xF0450)
}

// Brand tint for the compact media button, so the tab says which player it is.
var brandColors = { spotify: "#1DB954" }

function brandColor(appid) {
  return brandColors[String(appid || "").toLowerCase()] || ""
}
