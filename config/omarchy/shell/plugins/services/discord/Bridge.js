.pragma library

// Commands the shell waits on, keyed by id. Answered, superseded or timed out
// commands have no entry, so their late replies are dropped.
function track(pending, id, kind, channelId) {
  pending[id] = { kind: kind, channelId: String(channelId || "") }
}

// The pending entry a reply answers, null for a live update (no id), or
// undefined when nothing waits on it.
function claim(pending, msg) {
  if (!msg || msg.id === undefined || msg.id === null) return null
  var entry = pending[msg.id]
  if (!entry) return undefined
  // A chat answer comes as loading first; only its final status closes it.
  if (!(msg.type === "chat" && msg.status === "loading")) delete pending[msg.id]
  return entry
}
