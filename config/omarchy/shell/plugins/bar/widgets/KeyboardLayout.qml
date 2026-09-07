import QtQuick
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons
import "KeyboardLayoutModel.js" as KeyboardLayoutModel

BarWidget {
  id: root
  moduleName: "omarchy.keyboard-layout"

  // mango binds every physical keyboard into one group with one effective
  // layout, so there is no per-device reading to reconcile the way Hyprland
  // needed: the compositor reports a single description and switches the
  // whole group. Mango streams it off `watch all-monitors`.
  readonly property string layoutFull: Mango.keyboardLayout

  // Nothing to read or switch on the single-layout install most people run, so
  // the widget ships on the bar and stays out of the way until there are two.
  // mango has no IPC for the layout list, so read the same `xkb_rules_layout`
  // it read: more than one layout means a comma-separated value.
  property bool multipleLayouts: false

  // Short language code per layout description ("English (US)": "en"), read from
  // xkb's own table rather than maintained by hand.
  property var layoutBriefs: ({})
  readonly property string layoutLabel: KeyboardLayoutModel.shortLabel(layoutFull, layoutBriefs)

  function cycleLayout() {
    Mango.cycleKeyboardLayout()
  }

  Component.onCompleted: {
    briefsProc.running = true
    layoutsProc.running = true
  }

  // The table only changes when xkb data is upgraded, so read it at startup and
  // leave it alone. The bar is built per monitor, so this runs once per widget.
  // The exotic rulesets cover layouts like trans (IPA) that ship in the same xkb
  // package and set just as well, so load them or those labels lose their code.
  Process {
    id: briefsProc
    command: ["xkbcli", "list", "--load-exotic"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.layoutBriefs = KeyboardLayoutModel.layoutBriefs(text)
    }
  }

  // Last assignment across the mango config files wins, matching how mango
  // resolves it. A reload can add a layout, so re-read when the files change.
  Process {
    id: layoutsProc
    command: ["bash", "-c",
      "grep -hE '^[[:space:]]*xkb_rules_layout[[:space:]]*=' \"$HOME\"/.config/mango/*.conf 2>/dev/null | tail -n 1"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.multipleLayouts = String(text || "").indexOf(",") !== -1
    }
  }

  FileView {
    path: Quickshell.env("HOME") + "/.config/mango/keyboard.conf"
    watchChanges: true
    printErrors: false
    onFileChanged: if (!layoutsProc.running) layoutsProc.running = true
  }

  visible: layoutLabel !== "" && multipleLayouts
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.layoutLabel
    fontSize: Style.font.caption
    horizontalMargin: 6
    tooltipText: root.layoutFull
    onPressed: function() { root.cycleLayout() }
  }
}
