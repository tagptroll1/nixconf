// nmcli -t escapes ':' and '\' inside fields, so a plain split breaks on
// profile names that contain either.
function splitTerse(line) {
  var fields = []
  var current = ""
  var text = String(line || "")
  for (var i = 0; i < text.length; i++) {
    var ch = text.charAt(i)
    if (ch === "\\" && i + 1 < text.length) {
      current += text.charAt(++i)
    } else if (ch === ":") {
      fields.push(current)
      current = ""
    } else {
      current += ch
    }
  }
  fields.push(current)
  return fields
}

// Input: `nmcli -t -f NAME,UUID,TYPE,ACTIVE,DEVICE,TIMESTAMP,STATE connection show`.
// Every WireGuard profile counts as a server; the import filename names it.
function parseProfiles(raw) {
  var lines = String(raw || "").split(/\r?\n/)
  var result = []
  for (var i = 0; i < lines.length; i++) {
    if (lines[i] === "") continue
    var f = splitTerse(lines[i])
    if (f.length < 7 || f[2] !== "wireguard") continue
    result.push({
      name: f[0],
      uuid: f[1],
      active: f[3] === "yes",
      device: f[4],
      timestamp: parseInt(f[5], 10) || 0,
      state: f[6]
    })
  }
  result.sort(function(a, b) { return a.name.localeCompare(b.name) })
  return result
}

// Right click brings back whichever server was used last.
function lastUsed(profiles) {
  var best = null
  for (var i = 0; i < profiles.length; i++) {
    if (!best || profiles[i].timestamp > best.timestamp) best = profiles[i]
  }
  return best
}

function activeProfiles(profiles) {
  var result = []
  for (var i = 0; i < profiles.length; i++) if (profiles[i].active) result.push(profiles[i])
  return result
}

// Input: `nmcli -t -f IP4.ADDRESS,IP6.ADDRESS connection show uuid <uuid>`.
function parseAddresses(raw) {
  var lines = String(raw || "").split(/\r?\n/)
  var result = []
  for (var i = 0; i < lines.length; i++) {
    var idx = lines[i].indexOf(":")
    if (idx < 0) continue
    var value = lines[i].substring(idx + 1).replace(/\\:/g, ":")
    if (value !== "") result.push(value)
  }
  return result
}

// Proton's own endpoint, so the lookup never tells a third party the address.
function parseLocation(raw) {
  try {
    var data = JSON.parse(String(raw || ""))
    return { ip: String(data.IP || ""), country: String(data.Country || ""), isp: String(data.ISP || "") }
  } catch (e) {
    return { ip: "", country: "", isp: "" }
  }
}

function formatBytes(n) {
  var value = Number(n) || 0
  var units = ["B", "KB", "MB", "GB", "TB"]
  var i = 0
  while (value >= 1024 && i < units.length - 1) { value /= 1024; i++ }
  return (i === 0 ? String(Math.round(value)) : value.toFixed(value < 10 ? 1 : 0)) + " " + units[i]
}

if (typeof module !== "undefined") {
  module.exports = {
    splitTerse: splitTerse,
    parseProfiles: parseProfiles,
    lastUsed: lastUsed,
    activeProfiles: activeProfiles,
    parseAddresses: parseAddresses,
    parseLocation: parseLocation,
    formatBytes: formatBytes
  }
}
