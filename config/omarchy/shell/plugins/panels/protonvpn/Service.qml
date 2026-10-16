import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// Proton servers are NetworkManager WireGuard profiles, so the networkmanager
// group is all the privilege a toggle needs and NM owns routing and DNS.
Item {
  id: root

  // Panel binds this to its open state; traffic counters only poll then.
  property bool detailed: false

  property var profiles: []
  // False until the first list returns, so "no profiles" is not guessed.
  property bool listed: false
  readonly property var activeList: Model.activeProfiles(profiles)
  readonly property var current: activeList.length > 0 ? activeList[0] : null
  readonly property var fallback: Model.lastUsed(profiles)

  // Optimistic state so the icon flips on click instead of after nmcli
  // returns. -1 follows reality, 0/1 while a toggle catches up.
  property int _desired: -1
  readonly property bool active: _desired === -1 ? current !== null : _desired === 1
  readonly property bool connecting: (current !== null && current.state === "activating") || pendingUuid !== ""
  readonly property bool connected: current !== null && current.state === "activated"
  readonly property bool busy: actionProcess.running
  property string pendingUuid: ""

  property var addresses: []
  property string publicIp: ""
  property string publicCountry: ""
  property string publicIsp: ""
  property double rxBytes: 0
  property double txBytes: 0

  property string actionStatus: ""
  property string lastError: ""

  readonly property string statusText: {
    if (profiles.length === 0) return "No profiles"
    if (connecting) return "Connecting…"
    if (connected) return "Connected"
    return "Disconnected"
  }

  function refresh() {
    if (!listProcess.running) listProcess.running = true
  }

  function refreshLocation() {
    if (locationProcess.running) return
    locationProcess.running = true
  }

  function toggle() {
    if (active) down()
    else if (fallback) up(fallback.uuid)
  }

  // Switching drops whatever tunnel is up first: two full-tunnel profiles at
  // once would fight over the default route.
  function up(uuid) {
    if (!uuid || actionProcess.running) return
    _desired = 1
    pendingUuid = uuid
    var argv = ["sh", "-c",
      'target=$1; shift; for u in "$@"; do nmcli connection down uuid "$u" >/dev/null 2>&1; done; exec nmcli --wait 30 connection up uuid "$target"',
      "protonvpn-up", uuid]
    for (var i = 0; i < activeList.length; i++) if (activeList[i].uuid !== uuid) argv.push(activeList[i].uuid)
    run(argv)
  }

  function down() {
    if (actionProcess.running || activeList.length === 0) return
    _desired = 0
    var argv = ["sh", "-c", 'for u in "$@"; do nmcli connection down uuid "$u" || exit; done', "protonvpn-down"]
    for (var i = 0; i < activeList.length; i++) argv.push(activeList[i].uuid)
    run(argv)
  }

  function choose(profile) {
    if (!profile) return
    if (profile.active) down()
    else up(profile.uuid)
  }

  function copyToClipboard(value) {
    var text = String(value || "")
    if (text !== "") Util.execArgv(["wl-copy", text])
  }

  function run(argv) {
    actionStatus = ""
    lastError = ""
    actionProcess.command = argv
    actionProcess.running = true
  }

  function applyProfiles(raw) {
    var previous = current ? current.uuid + current.state : ""
    profiles = Model.parseProfiles(raw)
    if (_desired !== -1 && (current !== null) === (_desired === 1)) _desired = -1
    var now = current ? current.uuid + current.state : ""
    if (now === previous) return
    addresses = []
    if (current && current.state === "activated") {
      addressProcess.command = ["nmcli", "-t", "-f", "IP4.ADDRESS,IP6.ADDRESS", "connection", "show", "uuid", current.uuid]
      addressProcess.running = true
    }
    // The exit address changes with the tunnel; ask once routing settled.
    if (current === null || current.state === "activated") locationDelay.restart()
  }

  Timer {
    // Safety net only; the nmcli monitor below drives normal updates.
    interval: 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Timer {
    id: monitorDebounce
    interval: 250
    onTriggered: root.refresh()
  }

  Timer {
    id: monitorRestart
    interval: 2000
    onTriggered: monitorProcess.running = true
  }

  Timer {
    id: locationDelay
    interval: 1500
    onTriggered: root.refreshLocation()
  }

  Timer {
    // Stop overriding shortly after nmcli returns even if no list matched,
    // so a missed monitor event cannot pin the icon wrong.
    id: settleTimer
    interval: 1000
    onTriggered: root._desired = -1
  }

  Timer {
    id: actionStatusTimer
    interval: 4000
    onTriggered: root.actionStatus = ""
  }

  Timer {
    interval: 2000
    repeat: true
    running: root.detailed && root.connected
    triggeredOnStart: true
    onTriggered: {
      if (statsProcess.running || !root.current) return
      var dir = "/sys/class/net/" + root.current.device + "/statistics/"
      statsProcess.command = ["cat", dir + "rx_bytes", dir + "tx_bytes"]
      statsProcess.running = true
    }
  }

  Process {
    id: monitorProcess
    running: true
    command: ["nmcli", "monitor"]
    stdout: SplitParser { onRead: monitorDebounce.restart() }
    onExited: monitorRestart.restart()
  }

  Process {
    id: listProcess
    command: ["nmcli", "-t", "-f", "NAME,UUID,TYPE,ACTIVE,DEVICE,TIMESTAMP,STATE", "connection", "show"]
    stdout: StdioCollector { id: listOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      root.applyProfiles(listOut.text)
      root.listed = true
    }
  }

  Process {
    id: addressProcess
    stdout: StdioCollector { id: addressOut; waitForEnd: true }
    onExited: function(exitCode) {
      root.addresses = exitCode === 0 ? Model.parseAddresses(addressOut.text) : []
    }
  }

  Process {
    id: locationProcess
    command: ["curl", "-fsS", "--max-time", "6", "https://api.protonvpn.ch/vpn/location"]
    stdout: StdioCollector { id: locationOut; waitForEnd: true }
    onExited: function(exitCode) {
      var loc = exitCode === 0 ? Model.parseLocation(locationOut.text) : { ip: "", country: "", isp: "" }
      root.publicIp = loc.ip
      root.publicCountry = loc.country
      root.publicIsp = loc.isp
    }
  }

  Process {
    id: statsProcess
    stdout: StdioCollector { id: statsOut; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) return
      var parts = String(statsOut.text).trim().split(/\s+/)
      root.rxBytes = Number(parts[0]) || 0
      root.txBytes = Number(parts[1]) || 0
    }
  }

  Process {
    id: actionProcess
    stdout: StdioCollector { id: actionOut; waitForEnd: true }
    stderr: StdioCollector { id: actionErr; waitForEnd: true }
    onExited: function(exitCode) {
      root.pendingUuid = ""
      if (exitCode !== 0) {
        root._desired = -1
        var text = String(actionErr.text || actionOut.text || "nmcli failed").replace(/\s+/g, " ").trim()
        root.lastError = text.length > 160 ? text.substring(0, 157) + "…" : text
        root.actionStatus = root.lastError
        actionStatusTimer.restart()
      } else {
        settleTimer.restart()
      }
      root.refresh()
    }
  }
}
