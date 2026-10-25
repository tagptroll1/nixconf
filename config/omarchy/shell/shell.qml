import QtQuick
import Quickshell
import Quickshell.Io

import qs.Commons

import "plugins/bar"
import "services"
import "plugins/background" as BackgroundPlugin
import "plugins/notifications" as NotificationsPlugin
import "plugins/polkit" as PolkitPlugin
import "plugins/lock" as LockPlugin
import "plugins/services/media" as MediaPlugin
import "plugins/services/discord" as DiscordPlugin
import "plugins/services/nightlight" as NightlightPlugin
import "plugins/menu" as MenuPlugin
import "plugins/clipboard" as ClipboardPlugin
import "plugins/emojis" as EmojisPlugin
import "plugins/calculator" as CalculatorPlugin
import "plugins/imagepicker" as ImagePickerPlugin
import "plugins/osd" as OsdPlugin
import "plugins/stagedock" as StageDockPlugin
import "plugins/panels/speedtest" as SpeedTestPanel
import "plugins/panels/keybindings" as KeybindingsPanel
import "plugins/devgallery" as DevGallery

// The whole desktop, wired by hand. Every service, overlay, panel and the bar
// itself is named here: there is no manifest scan, no shell.json, and nothing
// to enable or place at runtime. Adding something means adding it below.
ShellRoot {
  id: root

  property string home: Quickshell.env("HOME")
  // Set by the mango session (config-qs.conf). Themes, templates and the
  // helper scripts all resolve against it.
  property string omarchyPath: Quickshell.env("OMARCHY_PATH")

  // ----------------------------------------------------------- services
  //
  // Shared state, handed to consumers by property injection. Relative-path
  // imports do not share singleton state, so a plugin that imported these
  // itself would get its own empty copy.

  property AppLibrary appLibrary: AppLibrary { }

  BackgroundPlugin.Background { id: backgroundService }

  NotificationsPlugin.Service {
    id: notificationService
    shell: root
    omarchyPath: root.omarchyPath
  }

  PolkitPlugin.PolkitAgent { id: polkitService }

  LockPlugin.Service {
    id: lockService
    shell: root
    omarchyPath: root.omarchyPath
  }

  MediaPlugin.Service {
    id: mediaService
    shell: root
  }

  DiscordPlugin.Service {
    id: discordService
    shell: root
  }

  NightlightPlugin.Service {
    id: nightlightService
    shell: root
  }

  Item {
    id: idleService

    property bool stayAwake: false
    // A Discord call keeps the machine up even when nothing is typed for the
    // whole hibernate timeout.
    property bool inCall: false
    readonly property bool inhibit: stayAwake || inCall

    function setIdleEnabled(enabled) {
      stayAwake = !enabled
      return enabled ? "enabled" : "disabled"
    }

    Timer {
      interval: 30000
      running: true
      repeat: true
      triggeredOnStart: true
      onTriggered: callProbe.running = true
    }

    Process {
      id: callProbe
      command: ["vesktop-in-call"]
      onExited: function(exitCode) { idleService.inCall = exitCode === 0 }
    }
  }

  // Indicators and panels ask for a service by id rather than reaching for a
  // specific object, so one lookup keeps those call sites unchanged.
  readonly property var services: ({
    "omarchy.background": backgroundService,
    "omarchy.notifications": notificationService,
    "omarchy.polkit": polkitService,
    "omarchy.lock": lockService,
    "omarchy.media": mediaService,
    "omarchy.discord": discordService,
    "omarchy.nightlight": nightlightService,
    "omarchy.idle": idleService
  })

  function serviceFor(id) {
    return services[String(id)] || null
  }

  function firstPartyServiceFor(id) {
    return serviceFor(id)
  }

  // --------------------------------------------------------------- bar

  property Bar bar: Bar {
    shell: root
  }

  // Edge tabs for windows docked by mango's stage layout.
  StageDockPlugin.StageDock {
    shell: root
  }

  // ---------------------------------------------------------- overlays
  //
  // Always mounted: each owns state that has to outlive being closed (the
  // clipboard's capture watchers, the menu's app list and guard results, the
  // calculator's history).

  MenuPlugin.Menu {
    id: menuOverlay
    shell: root
    omarchyPath: root.omarchyPath
  }

  ClipboardPlugin.Clipboard {
    id: clipboardOverlay
  }

  EmojisPlugin.Emojis {
    id: emojisOverlay
    shell: root
    omarchyPath: root.omarchyPath
  }

  CalculatorPlugin.Calculator {
    id: calculatorOverlay
    shell: root
  }

  ImagePickerPlugin.ImagePicker {
    id: imagePickerOverlay
    omarchyPath: root.omarchyPath
  }

  OsdPlugin.Osd { id: osdOverlay }

  // ----------------------------------------------------- on-demand panels
  //
  // Built on first summon and torn down on hide: none of them has state worth
  // keeping while closed, and two of them hold a running speed test.

  component OnDemandPanel: Loader {
    id: panelLoader

    // Marks this as a panel that lives behind a Loader, so callPanel knows to
    // reach through to `item`. Sniffing for `item` instead would be wrong: an
    // always-mounted panel can have a member of that name (the menu has an
    // item(id) lookup), and it is not the panel.
    readonly property bool onDemand: true

    // Payload for the open() that cannot happen until the component exists.
    property string pendingPayload: ""

    readonly property bool opened: active && item
      ? (item.opened === undefined ? true : item.opened === true)
      : false

    active: false
    asynchronous: true

    function open(payloadJson) {
      pendingPayload = payloadJson || "{}"
      if (active && item) deliver()
      else active = true
    }

    function close() {
      if (item && typeof item.close === "function") item.close()
      active = false
    }

    function deliver() {
      if (item && typeof item.open === "function") {
        try { item.open(pendingPayload) } catch (e) {
          console.warn("panel open() threw:", e)
        }
      }
      pendingPayload = ""
    }

    onLoaded: deliver()
    onStatusChanged: if (status === Loader.Error) {
      console.warn("panel failed to load:", errorString())
      active = false
    }
  }

  OnDemandPanel {
    id: speedTestPanel
    sourceComponent: Component {
      SpeedTestPanel.Panel { shell: root }
    }
  }

  OnDemandPanel {
    id: keybindingsPanel
    sourceComponent: Component {
      KeybindingsPanel.Panel { shell: root }
    }
  }

  OnDemandPanel {
    id: devGalleryPanel
    sourceComponent: Component {
      DevGallery.GalleryPanel { shell: root }
    }
  }

  // ------------------------------------------------------------ routing
  //
  // Keybinds and scripts name a panel by id (`shell toggle omarchy.menu`), so
  // the id stays the address however the panel is built.
  readonly property var panels: ({
    "omarchy.menu": menuOverlay,
    "omarchy.clipboard": clipboardOverlay,
    "omarchy.emojis": emojisOverlay,
    "omarchy.calculator": calculatorOverlay,
    "omarchy.image-picker": imagePickerOverlay,
    "omarchy.osd": osdOverlay,
    "omarchy.speedtest": speedTestPanel,
    "omarchy.keybindings": keybindingsPanel,
    "omarchy.dev-gallery": devGalleryPanel
  })

  function panelFor(id) {
    return panels[String(id || "")] || null
  }

  // Audio, bluetooth, network, power, monitor, clock and weather live inside
  // the bar, once per monitor. Routing through the live bar opens the copy on
  // the focused output; a fixed target would only ever reach one of them.
  function summon(id, payloadJson) {
    var panel = panelFor(id)
    if (panel) {
      panel.open(payloadJson)
      return true
    }
    if (bar && bar.summonBarWidget(id)) return true
    console.warn("summon: nothing answers to", id)
    return false
  }

  function hide(id) {
    var panel = panelFor(id)
    if (panel) {
      panel.close()
      return true
    }
    if (bar && bar.hideBarWidget(id)) return true
    return false
  }

  function isPluginOpen(id) {
    var panel = panelFor(id)
    if (panel) return panel.opened === true
    return bar ? bar.isBarWidgetOpen(id) : false
  }

  function toggle(id, payloadJson) {
    return isPluginOpen(id) ? hide(id) : summon(id, payloadJson)
  }

  // Call a method on a mounted panel. Used by helper scripts that want more
  // than open/close (the menu's refresh, the image picker's ping).
  function callPanel(id, method, arg) {
    var panel = panelFor(id)
    if (!panel) return "unknown"
    var target = panel.onDemand === true ? panel.item : panel
    if (!target || typeof target[method] !== "function") return "unknown"
    try {
      var result = target[method](arg)
      return result === undefined || result === null ? "ok" : String(result)
    } catch (e) {
      console.warn("panel " + id + " " + method + "() threw:", e)
      return "error"
    }
  }

  Component.onCompleted: console.log("omarchy-shell started",
    "omarchyPath=" + root.omarchyPath,
    "shellDir=" + Quickshell.shellDir)

  // --------------------------------------------------- image selector IPC
  //
  // omarchy-menu-images drives this: it writes the chosen row to a file the
  // caller is waiting on, so the handshake (open/preload/cancel/ping plus the
  // selection and done files) is a contract with that script.
  IpcHandler {
    target: "image-selector"

    function open(imageDirs: string,
                  imageRowsB64: string,
                  selectedImage: string,
                  selectionFile: string,
                  doneFile: string,
                  showLabels: string,
                  filterable: string): string {
      return root.summon("omarchy.image-picker", JSON.stringify({
        imageDirs: imageDirs,
        imageRows: Util.decodeBase64(imageRowsB64),
        selectedImage: selectedImage,
        selectionFile: selectionFile,
        doneFile: doneFile,
        showLabels: showLabels,
        filterable: filterable
      })) ? "ok" : "unknown"
    }

    function preload(imageRowsB64: string,
                     selectedImage: string,
                     showLabels: string,
                     filterable: string): string {
      imagePickerOverlay.preloadRows(Util.decodeBase64(imageRowsB64), selectedImage,
                                     showLabels, filterable)
      return "ok"
    }

    function cancel(doneFile: string): string {
      imagePickerOverlay.closeSelector(doneFile || "")
      return "ok"
    }

    function ping(): string {
      return "ok"
    }
  }

  // ---------------------------------------------------------- shell IPC

  IpcHandler {
    target: "shell"

    function ping(): string {
      return "ok"
    }

    // omarchy-theme-set hands over the new palette as base64 so the running
    // shell repaints without a restart.
    function applyTheme(colorsB64: string, shellB64: string): string {
      var colorsRaw = ""
      var shellRaw = ""
      try { colorsRaw = Qt.atob(String(colorsB64 || "")) } catch (e) { colorsRaw = "" }
      try { shellRaw = Qt.atob(String(shellB64 || "")) } catch (e2) { shellRaw = "" }
      Colors.loadColors(colorsRaw)
      Colors.loadShell(shellRaw)
      Style.scheduleRefresh()
      return "ok"
    }

    function summon(id: string, payloadJson: string): string {
      return root.summon(id, payloadJson) ? "ok" : "unknown"
    }

    function hide(id: string): void {
      root.hide(id)
    }

    function toggle(id: string, payloadJson: string): void {
      root.toggle(id, payloadJson)
    }

    function call(id: string, method: string, arg: string): string {
      return root.callPanel(id, method, arg)
    }

    // A bar section's panels answer to their position as well as their id, so a
    // hotkey can mean "the third panel in the right section". Returns the id it
    // acted on, or "unknown" when the section holds no panel there.
    function togglePanelAt(section: string, index: string): string {
      var id = root.bar ? root.bar.panelWidgetIdAt(section, index) : ""
      if (!id) return "unknown"
      root.toggle(id, "{}")
      return id
    }

    function debugBarGeometry(): string {
      return JSON.stringify(root.bar ? root.bar.debugBarGeometry() : [])
    }
  }
}
