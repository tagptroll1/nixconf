import QtQuick
import Quickshell
import Quickshell.Io
import "SnitchAlerts.js" as Alerts

// Announces hosts an app has not contacted before; clicking one opens that app
// in the network panel. The collector runs as a system service with no session
// bus, so the notification has to start here.
Item {
  id: root

  property var shell: null

  // services.networker.listen in modules/features/networker.nix.
  readonly property string endpoint: "http://127.0.0.1:8766"

  property real cursor: 0
  // Alerts from before this shell started were never ours to announce.
  property bool caughtUp: false

  // notify-send stays running until the notification closes, since an action
  // only fires while its sender is alive, then prints the action chosen.
  Component {
    id: notification

    Process {
      id: sender

      property string app: ""
      running: true

      stdout: StdioCollector {
        waitForEnd: true
        onStreamFinished: {
          if (text.trim() === "default")
            root.shell.callPanel("omarchy.network", "showSnitchApp", sender.app)
          sender.destroy()
        }
      }
    }
  }

  function announce(item) {
    notification.createObject(root, {
      app: item.app,
      command: ["notify-send", "-a", "Networker", "-A", "default=Open", item.title, item.body]
    })
  }

  function poll() {
    var request = new XMLHttpRequest()
    request.onreadystatechange = function() {
      // Absent when the snitch is off or the collector is down; both can change.
      if (request.readyState !== XMLHttpRequest.DONE || request.status !== 200) return
      var result
      try { result = JSON.parse(request.responseText) } catch (e) { return }
      if (root.caughtUp) Alerts.notifications(result.alerts).forEach(root.announce)
      root.caughtUp = true
      root.cursor = Alerts.nextCursor(root.cursor, result.seq)
    }
    request.open("GET", root.endpoint + "/api/snitch/alerts?after=" + root.cursor)
    request.send()
  }

  Timer {
    interval: 10000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.poll()
  }
}
