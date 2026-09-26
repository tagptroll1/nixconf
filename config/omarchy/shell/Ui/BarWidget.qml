import QtQuick
import qs.Commons

// Base item every bar widget extends. Codifies the three properties the
// bar host injects into each widget slot:
//   bar         - the host Bar instance (foreground/background/run/etc).
//   moduleName  - the widget id the bar knows it by, used for panel routing
//                 and IPC targets.
//   settings    - per-widget overrides, set where the widget is declared.
//
// Widgets are free to add their own properties, signals, and child items.
Item {
  id: root

  property QtObject bar: null
  property string moduleName: ""
  property var settings: ({})

  // Bar geometry, lifted off the host. Widgets read these constantly to pick
  // between horizontal/vertical layouts; defining them on the base keeps the
  // `bar ? bar.x : fallback` ternary out of every widget body.
  readonly property bool vertical: bar ? bar.vertical : false
  readonly property int barSize: bar ? bar.barSize : Style.bar.sizeHorizontal

  // Run `method` on every live instance of this widget. An IPC target only
  // ever routes to one handler, but a bar surface exists per monitor, so the
  // instance that owns the target relays the call to its peers — otherwise a
  // refresh would land on a single screen and leave the others stale.
  function broadcast(method) {
    var items = bar && typeof bar.moduleWidgets === "function"
      ? bar.moduleWidgets(moduleName) : [root]
    for (var i = 0; i < items.length; i++) {
      if (items[i] && typeof items[i][method] === "function") items[i][method]()
    }
  }

  // Read a single value out of `settings`, with a fallback for missing/null
  // values.
  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }
}
