import QtQuick
import Quickshell.Io
import qs.Commons
import qs.Ui

// The shared gauge-cluster overlay (SpeedTestOverlay) dressed for the
// internet speed test: download and upload dials in Mbps, titled with the
// connection under test.
//
// Standalone panel plugin: summoning it starts a fresh run, dismissing it
// kills the test, so it never keeps saturating the link behind a closed
// overlay. The payload may carry the connection's display name --
// {"connection": "MyWifi"} -- and the panel looks it up itself via
// omarchy-network-status when the caller doesn't know it.
//
// speedtest-go (our fork) streams {"type":"download"|"upload","mbps":N}
// while it runs and ends with its full result line, whose dl_speed and
// ul_speed (bytes/s) replace the last live reading.
Item {
  id: root

  property var shell: null

  property bool opened: false
  property string connectionName: ""

  property bool running: false
  property bool expectedStop: false
  property bool pendingRun: false
  property string phase: ""        // "down" | "up" | ""
  property string stderrText: ""
  property real downloadValue: 0
  property real uploadValue: 0
  property string error: ""

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    if (payload.connection !== undefined) root.connectionName = String(payload.connection)
    else refreshConnectionName()
    root.opened = true
    runSpeedTest()
  }

  function close() {
    root.opened = false
    root.pendingRun = false
    root.phase = ""
    root.running = false
    if (speedTestProc.running) {
      root.expectedStop = true
      speedTestProc.running = false
    }
  }

  function dismiss() {
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide("omarchy.speedtest")
    else close()
  }

  function refreshConnectionName() {
    root.connectionName = ""
    statusProc.running = false
    statusProc.running = true
  }

  function readLine(line) {
    var event = null
    try { event = JSON.parse(line) } catch (e) { return }
    if (!event) return

    if (event.type === "download") {
      root.phase = "down"
      root.downloadValue = Math.max(0, Number(event.mbps) || 0)
    } else if (event.type === "upload") {
      root.phase = "up"
      root.uploadValue = Math.max(0, Number(event.mbps) || 0)
    } else if (event.server) {
      root.downloadValue = Math.max(0, (Number(event.server.dl_speed) || 0) * 8 / 1e6)
      root.uploadValue = Math.max(0, (Number(event.server.ul_speed) || 0) * 8 / 1e6)
    }
  }

  function runSpeedTest() {
    if (speedTestProc.running) {
      // A dismissal's SIGTERM is still in flight; Process.running stays true
      // until the child exits, so queue the fresh run for onExited.
      if (expectedStop) pendingRun = true
      return
    }
    error = ""
    stderrText = ""
    downloadValue = 0
    uploadValue = 0
    expectedStop = false
    running = true
    // Server selection and ping come first; the download dial is next up.
    phase = "down"
    speedTestProc.running = true
  }

  Process {
    id: speedTestProc
    command: ["speedtest-go", "--jsonl", "--progress"]
    stdout: SplitParser { onRead: function(line) { root.readLine(line) } }
    // Exit and stream-finished have no guaranteed order: when a failed exit
    // beat the collector and published the generic message, replace it with
    // the specific one once it lands.
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.stderrText = String(text || "").trim()
        if (root.error !== "" && root.stderrText !== "") root.error = root.stderrText
      }
    }
    onExited: function(exitCode) {
      if (root.pendingRun) {
        root.pendingRun = false
        root.expectedStop = false
        if (root.opened) Qt.callLater(root.runSpeedTest)
        return
      }

      if (!root.expectedStop && exitCode !== 0) root.error = root.stderrText || "Speed test failed"
      root.expectedStop = false
      root.phase = ""
      root.running = false
    }
  }

  // Names the connection under test when the summoner didn't. First tab
  // field is the kind, second the SSID (wifi) or device (ethernet).
  Process {
    id: statusProc
    command: ["omarchy-network-status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var fields = String(text || "").trim().split("\t")
        if (fields[0] === "wifi") root.connectionName = fields[1] || "Wi-Fi"
        else if (fields[0] === "ethernet") root.connectionName = "Ethernet"
      }
    }
  }

  SpeedTestOverlay {
    fontFamily: Style.font.family
    layerNamespace: "omarchy-network-speedtest"
    title: root.connectionName
    leftLabel: "DOWNLOAD"
    rightLabel: "UPLOAD"
    runAgainTooltip: "Measure again via speedtest.net"
    running: root.running
    leftValue: root.downloadValue
    rightValue: root.uploadValue
    leftLive: root.running && root.phase === "down"
    rightLive: root.running && root.phase === "up"
    error: root.error
    open: root.opened
    onCloseRequested: root.dismiss()
    onRunAgainRequested: root.runSpeedTest()
  }
}
