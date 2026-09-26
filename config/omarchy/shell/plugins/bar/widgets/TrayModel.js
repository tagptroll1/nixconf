function text(value) {
  return String(value || "").toLowerCase()
}

function itemNamed(item, name) {
  if (!item) return false
  return text(item.id).indexOf(name) !== -1
    || text(item.title).indexOf(name) !== -1
    || text(item.tooltipTitle).indexOf(name) !== -1
}

// LocalSend.s item shows no state, offers only Open and Quit, and its primary
// click is a no-op. Hiding it by hand doesn.t stick either: LocalSend picks a
// fresh tray id every launch.
function ownedByOmarchy(item) {
  return itemNamed(item, "localsend")
}

if (typeof module !== "undefined") {
  module.exports = {
    itemNamed: itemNamed,
    ownedByOmarchy: ownedByOmarchy
  }
}
