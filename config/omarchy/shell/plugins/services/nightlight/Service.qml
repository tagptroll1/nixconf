import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "NightlightModel.js" as NightlightModel

Item {
  id: root

  // Injected by omarchy-shell (the first-party service loader).
  property var shell: null

  // Temperatures the night light toggles between; wlsunset is pinned to one of
  // them at a time (see runApply).
  readonly property int nightTemperature: 4000
  readonly property int dayTemperature: 6500

  property bool stateLoaded: false
  property var temperature: null
  readonly property bool enabled: stateLoaded && NightlightModel.isNightlight(temperature)

  property bool hasPendingTemperature: false
  property int pendingTemperature: 0

  function refresh() {
    if (!statusProbe.running) statusProbe.running = true
  }

  function setNightlight(value) {
    applyTemperature(value ? nightTemperature : dayTemperature)
  }

  function toggle() {
    setNightlight(!enabled)
  }

  function applyTemperature(temp) {
    root.temperature = temp
    root.stateLoaded = true

    if (applyProcess.running) {
      root.pendingTemperature = temp
      root.hasPendingTemperature = true
      return
    }

    runApply(temp)
  }

  // hyprsunset is Hyprland-only; wlsunset drives the same wlr-gamma-control
  // protocol mango implements. It has no query interface and no way to pin one
  // temperature, so pin it by making day and night a single kelvin apart, and
  // keep the chosen value in a state file for the probe to read back. Disabling
  // just stops it — wlsunset restores the identity ramp as it exits.
  readonly property string statePath: Quickshell.env("HOME") + "/.local/state/omarchy/nightlight"

  function runApply(temp) {
    var night = NightlightModel.isNightlight(temp)
    // A dying wlsunset restores gamma as it goes, which would undo a
    // replacement started in the same breath. Let it finish first.
    var stop = "pkill -x wlsunset >/dev/null 2>&1 && sleep 0.3; "

    applyProcess.command = ["bash", "-lc", night
      ? stop + "mkdir -p \"$(dirname " + Util.shellQuote(root.statePath) + ")\"; " +
        "printf '%s\\n' " + Number(temp) + " > " + Util.shellQuote(root.statePath) + "; " +
        "setsid wlsunset -T " + (Number(temp) + 1) + " -t " + Number(temp) + " >/dev/null 2>&1 &"
      : stop + "rm -f " + Util.shellQuote(root.statePath)]
    applyProcess.running = true
  }

  Process {
    id: statusProbe
    command: ["bash", "-lc",
      "pgrep -x wlsunset >/dev/null && cat \"$HOME/.local/state/omarchy/nightlight\" 2>/dev/null || echo 6500"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.temperature = NightlightModel.temperatureFromOutput(text)
        root.stateLoaded = true
      }
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.temperature = null
        root.stateLoaded = true
      }
    }
  }

  Process {
    id: applyProcess
    onExited: function() {
      if (root.hasPendingTemperature) {
        root.hasPendingTemperature = false
        root.runApply(root.pendingTemperature)
        return
      }

      root.refresh()
    }
  }

  Component.onCompleted: refresh()

  IpcHandler {
    target: "nightlight"

    function status(): string {
      return JSON.stringify({ enabled: root.enabled, temperature: root.temperature })
    }

    function refresh(): void {
      root.refresh()
    }

    function enable(): string {
      root.setNightlight(true)
      return "enabled"
    }

    function disable(): string {
      root.setNightlight(false)
      return "disabled"
    }

    function toggle(): string {
      var enabling = !root.enabled
      root.setNightlight(enabling)
      return enabling ? "enabled" : "disabled"
    }
  }
}
