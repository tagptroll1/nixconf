import QtQuick
import qs.Commons
import qs.Ui

// Local addition, no upstream counterpart. Deliberately spotify-only: mopidy runs
// as a permanent MPRIS player here, so the generic omarchy.media widget would show
// and control it instead.
BarIndicator {
  id: root

  readonly property var mediaService: bar?.shell?.firstPartyServiceFor("omarchy.media")
  readonly property var spotifyPlayer: findSpotify()
  readonly property bool playing: spotifyPlayer ? !!spotifyPlayer.isPlaying : false
  readonly property string track: {
    if (!spotifyPlayer) return ""
    var title = String(spotifyPlayer.trackTitle || "")
    var artist = String(spotifyPlayer.trackArtist || "")
    if (title === "") return ""
    return artist === "" ? title : artist + " - " + title
  }

  active: spotifyPlayer !== null
  activeText: ""
  inactiveText: ""
  activeTooltipText: track !== "" ? track : "Spotify"
  inactiveTooltipText: "Launch Spotify"

  // Reading mediaService.players here keeps the binding reactive: the players list
  // is a property, so the enclosing binding re-evaluates when it changes.
  function findSpotify() {
    var list = mediaService ? mediaService.players : []
    for (var i = 0; i < list.length; i++) {
      var p = list[i]
      if (!p) continue
      if (String(p.desktopEntry || "").toLowerCase() === "spotify") return p
      var bus = String(p.dbusName || "")
      if (bus.slice(-8) === ".spotify") return p
      if (String(p.identity || "") === "Spotify") return p
    }
    return null
  }

  function act(action) {
    if (!root.mediaService || !root.spotifyPlayer) return
    root.mediaService.runAction(action, false, root.mediaService.playerKey(root.spotifyPlayer))
  }

  onPressed: function() {
    if (root.spotifyPlayer) root.act("playPause")
    // The mango windowrule appid:Spotify,isnamedscratchpad:1 catches the window, so
    // this starts spotify hidden — SUPER+s reveals it.
    else Util.execArgv(["spotify"])
  }

  onWheelMoved: function(delta) {
    if (delta > 0) root.act("previous")
    else if (delta < 0) root.act("next")
  }
}
