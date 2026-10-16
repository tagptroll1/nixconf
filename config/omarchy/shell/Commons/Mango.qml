pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// mango's IPC, standing in for Quickshell.Hyprland. One `mmsg watch
// all-monitors` stream carries every output's tags, focus flag and keyboard
// layout, so the bar, the workspaces widget and the keyboard-layout widget
// share a single subscription instead of polling.
//
// mango calls Hyprland's workspaces "tags": they are per-monitor, numbered
// from 1, and a tag is occupied when its client_count is above zero.
QtObject {
  id: root

  readonly property string socket: Quickshell.env("MANGO_INSTANCE_SIGNATURE") || ""
  readonly property bool available: socket !== ""

  // Latest all-monitors payload, one entry per output, verbatim from mmsg.
  property var monitors: []
  property string focusedMonitor: ""
  property string keyboardLayout: ""
  property int tagCount: 9

  function monitorFor(name) {
    var wanted = String(name || "")
    for (var i = 0; i < monitors.length; i++) {
      if (String(monitors[i].name || "") === wanted) return monitors[i]
    }
    return null
  }

  // Tag list for one output, or the focused output's when unnamed; fields in CONTRACTS.md.
  function tagsFor(name) {
    var monitor = monitorFor(name || focusedMonitor)
    return monitor && Array.isArray(monitor.tags) ? monitor.tags : []
  }

  function tagOccupied(tag) {
    return !!tag && Number(tag.client_count || 0) > 0
  }

  // Fire and forget: nothing in the shell reads a dispatch back, and mmsg
  // exits on its own once the compositor has answered.
  function dispatch(command) {
    if (!available) return
    Quickshell.execDetached(["mmsg", "dispatch", String(command)])
  }

  function viewTag(index) {
    dispatch("view," + Number(index))
  }

  function focusClient(id) {
    if (!available) return
    Quickshell.execDetached(["mmsg", "dispatch", "focusid", "client," + Number(id)])
  }

  function cycleKeyboardLayout() {
    dispatch("switch_keyboard_layout,0")
  }

  function applyMonitors(line) {
    var payload
    try {
      payload = JSON.parse(String(line || ""))
    } catch (e) {
      return
    }

    var list = payload && Array.isArray(payload.monitors) ? payload.monitors : null
    if (!list) return

    root.monitors = list

    var focused = ""
    for (var i = 0; i < list.length; i++) {
      if (list[i].active === true) focused = String(list[i].name || "")
    }
    root.focusedMonitor = focused

    var reference = focused ? monitorFor(focused) : list[0]
    if (reference) {
      if (reference.keyboardlayout !== undefined) root.keyboardLayout = String(reference.keyboardlayout || "")
      var count = Number(reference.tag_num)
      if (isFinite(count) && count > 0) root.tagCount = count
    }
  }

  property Process watcher: Process {
    id: watcherProc
    command: ["mmsg", "watch", "all-monitors"]
    stdout: SplitParser {
      onRead: function(line) { root.applyMonitors(line) }
    }
    // mmsg exits when the compositor socket goes away (a mango restart), which
    // would otherwise freeze the bar on the last payload it saw.
    onExited: watchRetryTimer.restart()
  }

  property Timer watchRetryTimer: Timer {
    id: watchRetryTimer
    interval: 1000
    repeat: false
    onTriggered: if (root.available) watcherProc.running = true
  }

  Component.onCompleted: if (available) watcherProc.running = true
}
