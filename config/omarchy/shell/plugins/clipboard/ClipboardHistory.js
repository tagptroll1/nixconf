// Reads `cliphist list`: one "<id>\t<preview>" line per entry, newest first.
// cliphist has already collapsed whitespace and cut the preview short, so
// searching it stays cheap however large the entry behind it is.

var imagePattern = /^\[\[ binary data (.+) ([a-z]+) (\d+x\d+) \]\]$/

function parseList(raw, cacheDir) {
  var lines = String(raw || "").split("\n")
  var entries = []
  for (var i = 0; i < lines.length; i++) {
    var tab = lines[i].indexOf("\t")
    if (tab <= 0) continue
    var id = lines[i].substring(0, tab)
    var preview = lines[i].substring(tab + 1)
    var image = imagePattern.exec(preview)
    if (image) {
      entries.push({
        id: id,
        type: "image",
        preview: "Image · " + image[1] + " · " + image[3],
        path: cacheDir + "/" + id + "." + image[2]
      })
    } else if (preview.trim().length > 0) {
      entries.push({ id: id, type: "text", preview: preview, path: "" })
    }
  }
  return entries
}

function decodeFileUri(uri) {
  var value = String(uri || "").trim()
  if (value.indexOf("file://") !== 0) return ""

  var path = value.substring(7)
  if (path.indexOf("localhost/") === 0) path = path.substring(9)
  if (path.charAt(0) !== "/") return ""

  try { return decodeURIComponent(path) } catch (e) { return path }
}

// A file manager copy arrives as file:// URIs; name the files instead.
function filePaths(entry) {
  if (!entry || entry.type !== "text") return []
  var words = entry.preview.split(" ")
  var paths = []
  for (var i = 0; i < words.length; i++) {
    var path = decodeFileUri(words[i])
    if (!path) return []
    paths.push(path)
  }
  return paths
}

function fileName(path) {
  var parts = String(path || "").split("/")
  return parts[parts.length - 1]
}

function isImagePath(path) {
  return /\.(png|jpe?g|webp|gif|bmp|tiff?)$/i.test(String(path || ""))
}

function displayRows(entries, query, limit) {
  var values = Array.isArray(entries) ? entries : []
  var needle = String(query || "").trim().toLowerCase()
  var rows = []

  for (var i = 0; i < values.length && rows.length < limit; i++) {
    var entry = values[i]
    var paths = filePaths(entry)
    var label = paths.length === 1 ? fileName(paths[0])
      : (paths.length > 1 ? paths.length + " files" : entry.preview)
    if (needle && (label + " " + entry.preview).toLowerCase().indexOf(needle) < 0) continue

    rows.push({
      id: entry.id,
      entryType: paths.length > 0 ? "file" : entry.type,
      previewText: label,
      previewImage: entry.type === "image" ? entry.path
        : (paths.length === 1 && isImagePath(paths[0]) ? paths[0] : "")
    })
  }

  return rows
}

if (typeof module !== "undefined") {
  module.exports = {
    parseList: parseList,
    filePaths: filePaths,
    displayRows: displayRows
  }
}
