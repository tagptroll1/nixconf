function clampIndex(index, length) {
  if (length <= 0) return 0
  return Math.max(0, Math.min(length - 1, index))
}

function selectProfileIndex(index, delta, profiles) {
  var values = Array.isArray(profiles) ? profiles : []
  if (values.length === 0) return 0
  return clampIndex(index + delta, values.length)
}

// Keyed by PowerProfile.toString() names.
function profileIcon(name) {
  if (name === "PowerSaver") return "󰌪"
  if (name === "Balanced") return "󰊚"
  if (name === "Performance") return "󰓅"
  return "󰂄"
}

if (typeof module !== "undefined") {
  module.exports = {
    clampIndex: clampIndex,
    selectProfileIndex: selectProfileIndex,
    profileIcon: profileIcon
  }
}
