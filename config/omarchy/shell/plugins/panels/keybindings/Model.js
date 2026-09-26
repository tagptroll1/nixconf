// The binds this desktop has, read back from the mango config at runtime
// rather than duplicated in QML.
//
// Only the two files the quickshell session loads: config-qs.conf, which holds
// the hotkeys that drive this shell, and the keybinds.conf it sources. The
// sibling config.conf belongs to the rofi/waybar session and would list a
// second, contradictory SUPER+space. mango owns every bind either way - the
// shell registers no shortcuts of its own.

function script() {
  return "cat $HOME/.config/mango/config-qs.conf $HOME/.config/mango/keybinds.conf 2>/dev/null | awk '" + awk() + "'"
}

// Emits `combo<TAB>action` per bind.
//
// mango's grammar is `<bind|mousebind|axisbind>=<mods>,<key>,<action>[,<args>]`,
// split on the first two commas only: an action's arguments carry commas of
// their own (`view,1,0`) and a spawned command may too.
//
// What a row says is annotated in the config, in a comment directly above the
// bind:
//
//   # action: Screenshot a region
//   bind=none,Print,spawn,~/.config/mango/scripts/screenshot-region.sh region
//
// It belongs to that one bind and is consumed by it. Without it the row falls
// back to the command itself, which reads fine for `focusdir up` and not at all
// for a script path, so only the latter are annotated.
function awk() {
  return [
    '/^[[:space:]]*#/ {',
    '  c = $0; sub(/^[[:space:]]*#+[[:space:]]*/, "", c)',
    '  gsub(/[[:space:]]+$/, "", c)',
    '  if (c ~ /^[Aa]ction:/) { sub(/^[^:]*:[[:space:]]*/, "", c); label = c }',
    '  next',
    '}',
    '/^[[:space:]]*$/ { label = ""; next }',
    '/^[[:space:]]*(bind|mousebind|axisbind)=/ {',
    '  line = $0',
    // " #" rather than "#": a spawned command may contain a bare hash, but a
    // comment is always separated from the bind by whitespace. Only stripped so
    // it cannot end up inside the action.
    '  h = index(line, " #"); if (h > 0) line = substr(line, 1, h - 1)',
    '  rest = substr(line, index(line, "=") + 1)',
    '  c = index(rest, ","); if (c == 0) next',
    '  mods = substr(rest, 1, c - 1); tail = substr(rest, c + 1)',
    '  c = index(tail, ",")',
    '  if (c == 0) { key = tail; act = "" }',
    '  else { key = substr(tail, 1, c - 1); act = substr(tail, c + 1) }',
    // A modless bind (Print on its own) is written `none` in the config.
    '  if (tolower(mods) == "none") combo = key',
    '  else combo = toupper(mods) "+" key',
    // Single-letter keys are written both ways (SUPER,q and SUPER+SHIFT,Q);
    // upper-case them so the column does not look ragged.
    '  if (length(key) == 1) sub(/.$/, toupper(key), combo)',
    '  gsub(/,/, " ", act)',
    '  gsub(/[[:space:]]+$/, "", act)',
    '  if (act == "") next',
    '  if (label != "") act = label',
    '  label = ""',
    '  print combo "\\t" act',
    '}'
  ].join("\n")
}

// Modifiers carry their own glyph, so a combo reads as a shape rather than a
// sentence and the column stays narrow. The Nerd Font control-key set is one
// matched family, which keeps the four aligned; the arrows and Return/Tab are
// plain Unicode, already in every font here.
var MOD_GLYPHS = {
  super: "󰘳",
  ctrl: "󰘴",
  alt: "󰘵",
  shift: "󰘶"
}

var KEY_GLYPHS = {
  return: "󰌑",
  tab: "󰌒",
  left: "←",
  right: "→",
  up: "↑",
  down: "↓",
  space: "␣"
}

// Spaced rather than run together: the control glyphs are dense enough that
// SUPER+SHIFT reads as one mark without a gap between them. Anything unmapped
// keeps its name and its "+", so a bind on an exotic key still reads correctly.
function display(combo) {
  var parts = String(combo || "").split("+")
  var key = parts.pop()
  var out = []
  for (var i = 0; i < parts.length; i++) {
    var g = MOD_GLYPHS[parts[i].toLowerCase()]
    out.push(g ? g : parts[i] + "+")
  }
  var k = KEY_GLYPHS[String(key).toLowerCase()]
  out.push(k ? k : key)
  return out.join(" ")
}

function parse(raw) {
  var out = []
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    if (!lines[i]) continue
    var parts = lines[i].split("\t")
    if (!parts[0] || !parts[1]) continue
    // The raw combo is both the second line of the row and what makes "super"
    // searchable once the modifier is only ever drawn as a glyph.
    out.push({
      combo: parts[0],
      comboDisplay: display(parts[0]),
      action: parts[1]
    })
  }
  return out
}

// Both fields are searchable: "spotify" should find the bind that launches it
// just as "super" finds the modifier.
function filter(rows, query) {
  var q = String(query || "").trim().toLowerCase()
  if (!q) return rows
  var terms = q.split(/\s+/)
  var out = []
  for (var i = 0; i < rows.length; i++) {
    var hay = (rows[i].combo + " " + rows[i].action).toLowerCase()
    var all = true
    for (var t = 0; t < terms.length; t++) {
      if (hay.indexOf(terms[t]) < 0) { all = false; break }
    }
    if (all) out.push(rows[i])
  }
  return out
}

if (typeof module !== "undefined") {
  module.exports = { script: script, awk: awk, parse: parse, filter: filter, display: display }
}
