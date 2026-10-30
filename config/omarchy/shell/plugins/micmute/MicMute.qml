import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import qs.Commons
import qs.Ui

// Mic-muted badge for the Caps Lock toggle (mango keybinds.conf). Overlay layer
// is the one mango stacks above fullscreen windows, so it shows over games.
Item {
  id: root

  readonly property var source: Pipewire.defaultAudioSource
  readonly property bool muted: !!(source && source.audio && source.audio.muted)

  // Qt reports no output serial here, so mango's serial can't be matched; the
  // main monitor is the ultrawide, and the widest screen also covers it alone.
  readonly property var mainScreen: {
    var best = null
    var screens = Quickshell.screens || []
    for (var i = 0; i < screens.length; i++)
      if (!best || screens[i].width > best.width) best = screens[i]
    return best
  }

  readonly property int pad: Style.space(10)

  PwObjectTracker { objects: [root.source] }

  PanelWindow {
    visible: root.muted && root.mainScreen !== null
    screen: root.mainScreen
    anchors { top: true; left: true }
    margins { top: Style.space(16); left: Style.space(16) }
    implicitWidth: card.width
    implicitHeight: card.height
    color: "transparent"
    WlrLayershell.namespace: "omarchy-micmute"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    // Click-through, so the badge never eats input meant for the game.
    mask: Region {}

    BorderSurface {
      id: card
      width: card.borderLeft + root.pad + glyph.implicitWidth + root.pad + card.borderRight
      height: card.borderTop + root.pad + glyph.implicitHeight + root.pad + card.borderBottom
      color: Util.alpha(Colors.background, 0.9)
      borderSpec: Border.surfaceSpec("popups", "border", Colors.popups.border, Math.max(1, Style.space(2)))
      radius: Style.cornerRadius

      Text {
        id: glyph
        x: card.borderLeft + root.pad
        y: card.borderTop + root.pad
        text: "󰍭"
        font.family: Style.font.family
        font.pixelSize: Style.font.title
        color: Colors.urgent
      }
    }
  }
}
