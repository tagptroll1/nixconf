// Display logic for the snitch view; pure so node can test it.

function ago(iso, nowMs) {
  var seconds = Math.max(0, Math.round((nowMs - Date.parse(iso)) / 1000))
  if (seconds < 60) return "now"
  if (seconds < 3600) return Math.floor(seconds / 60) + "m"
  if (seconds < 86400) return Math.floor(seconds / 3600) + "h"
  return Math.floor(seconds / 86400) + "d"
}

// Blocked traffic is what the view exists to surface, so it sorts first.
function byAttention(items) {
  return (items || []).slice().sort(function(a, b) {
    if (!a.blocked !== !b.blocked) return a.blocked ? -1 : 1
    return Date.parse(b.last_seen) - Date.parse(a.last_seen)
  })
}

function policyLabel(rules) {
  if (!rules) return ""
  var count = (rules.rules || []).length
  if (count === 0) return "watching, no rules"
  return (rules.enforcing ? "blocking" : "dry run") + " · " + count + (count === 1 ? " rule" : " rules")
}

// A rule only refuses when enforcing; otherwise it just says what would.
function ruleLabel(destination, enforcing) {
  if (destination.blocked > 0) return "blocked ×" + destination.blocked
  if (destination.rule) return enforcing ? "rule" : "would block"
  return ""
}

if (typeof module !== "undefined") {
  module.exports = { ago: ago, byAttention: byAttention, policyLabel: policyLabel, ruleLabel: ruleLabel }
}
