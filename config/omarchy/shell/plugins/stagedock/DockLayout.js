.pragma library

// Tops for the tabs on one monitor edge, and which must fold to compact. Each
// tab centres on its y where it can, pushed below the tab above it, then back
// up off the screen bottom. A group taller than the screen closes its gaps,
// then folds tabs from the bottom up; tabs overlap only when even compact
// ones cannot fit.
function packEdge(list, heights, screenHeight, gap, mini) {
  var docks = list.slice().sort(function(a, b) { return a.y - b.y })
  var n = docks.length
  var bottom = screenHeight > 0 ? screenHeight : Infinity
  var h = []
  var total = 0
  for (var i = 0; i < n; i++) {
    h.push(heights[docks[i].id])
    total += h[i]
  }

  var tops = {}
  var compact = {}
  if (total + (n - 1) * gap <= bottom) {
    var top = []
    var floor = 0
    for (i = 0; i < n; i++) {
      top.push(Math.max(Math.round(docks[i].y - h[i] / 2), floor))
      floor = top[i] + h[i] + gap
    }
    var ceil = bottom
    for (i = n - 1; i >= 0; i--) {
      top[i] = Math.min(top[i], ceil - h[i])
      ceil = top[i] - gap
      tops[docks[i].id] = top[i]
    }
    return { tops: tops, compact: compact }
  }

  for (i = n - 1; i >= 0 && total > bottom; i--) {
    if (h[i] <= mini) continue
    total -= h[i] - mini
    h[i] = mini
    compact[docks[i].id] = true
  }
  var room = n > 1 ? (bottom - total) / (n - 1) : 0
  var step = room < 0 ? room : Math.min(gap, Math.floor(room))
  var at = 0
  for (i = 0; i < n; i++) {
    tops[docks[i].id] = Math.round(at)
    at += h[i] + step
  }
  return { tops: tops, compact: compact }
}

// Tops set by a drop are shown until mango reports the matching y.
function restTop(pinned, tops, id) {
  return pinned[id] !== undefined ? pinned[id].top : (tops[id] || 0)
}

// The other tabs on a dock's edge, top to bottom, as they sit now. Each tab
// is { id, monitor, edge, top, height }.
function neighbours(dock, tabs) {
  var out = []
  for (var i = 0; i < tabs.length; i++) {
    var o = tabs[i]
    if (!dock || !o || o.id === dock.id || o.monitor !== dock.monitor || o.edge !== dock.edge) continue
    out.push({ id: o.id, top: o.top, height: o.height })
  }
  return out.sort(function(a, b) { return a.top - b.top })
}

function obsTop(o) {
  return o.passed !== undefined ? o.passed : o.top
}

// A passed tab stops one gap clear of the dragged tab as it is passed, not
// a whole tab away; passing back sends it home. Returns the new obstacles.
function pass(obs, i, top, down, home, gap, bottom) {
  var next = obs.slice()
  var o = Object.assign({}, next[i])
  if (down ? i < home : i >= home) {
    delete o.passed
  } else {
    var lo = i === 0 ? 0 : obsTop(next[i - 1]) + next[i - 1].height + gap
    var hi = i === next.length - 1 ? bottom - o.height : obsTop(next[i + 1]) - gap - o.height
    o.passed = Math.round(Math.max(lo, Math.min(top, hi)))
  }
  next[i] = o
  return next
}

// The dragged tab at a new pointer top, and the tabs its centre passed. drag
// is { height, obs, home, slot, bottom }; commit is how far the centre must be
// through a tab to pass it.
function move(drag, top, max, gap, commit) {
  var t = Math.max(0, Math.min(top, max))
  var obs = drag.obs
  var slot = drag.slot
  var c = t + drag.height / 2
  while (slot < obs.length && c > obsTop(obs[slot]) + obs[slot].height * commit) {
    obs = pass(obs, slot, t - gap - obs[slot].height, true, drag.home, gap, drag.bottom)
    slot++
  }
  while (slot > 0 && c < obsTop(obs[slot - 1]) + obs[slot - 1].height * (1 - commit)) {
    obs = pass(obs, slot - 1, t + drag.height + gap, false, drag.home, gap, drag.bottom)
    slot--
  }
  return { top: t, obs: obs, slot: slot }
}

// Where a drop lands: the dragged tab in its gap, plus every tab it passed,
// each with the y mango should centre it on.
function landing(drag, id, max, gap) {
  var obs = drag.obs
  var slot = drag.slot
  var lo = slot === 0 ? 0 : obsTop(obs[slot - 1]) + obs[slot - 1].height + gap
  var hi = slot === obs.length ? max : obsTop(obs[slot]) - gap - drag.height
  var moves = [{ id: id, top: Math.max(lo, Math.min(drag.top, hi)), height: drag.height }]
  for (var i = 0; i < obs.length; i++) {
    if (obsTop(obs[i]) !== obs[i].top) moves.push({ id: obs[i].id, top: obsTop(obs[i]), height: obs[i].height })
  }

  var out = []
  for (var j = 0; j < moves.length; j++) {
    var top = Math.round(moves[j].top)
    // floor, not round: packEdge rounds y - h/2 back to exactly this top, so
    // an odd height can't nudge a touching neighbour.
    out.push({ id: moves[j].id, top: top, y: Math.floor(top + moves[j].height / 2) })
  }
  return out
}
