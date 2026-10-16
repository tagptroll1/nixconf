import QtQuick
import Quickshell.Io
import qs.Ui
import qs.Commons

// mangowm/mango releases that tagptroll1/mango main does not contain yet.
Panel {
  id: root
  moduleName: "omarchy.mango-fork"

  readonly property string api: "https://api.github.com/repos/mangowm/mango"
  readonly property string base: "tagptroll1:main"

  // Newest first: { tag, name, published, body, url, commits (newest first) }.
  property var releases: []
  property bool failed: false
  // Expanded releases and commit sublists, keyed by tag.
  property var openReleases: ({})
  property var openCommits: ({})
  // CursorSurface wants hover state at the root, not read off each MouseArea.
  property string hoveredKey: ""

  function toggled(map, key) {
    var copy = Object.assign({}, map)
    copy[key] = !copy[key]
    return copy
  }

  // A release is new when its tag commit is among the upstream commits the
  // fork lacks; it owns the commits since the previous new release.
  function newReleases(compare, list, tags) {
    var tagSha = {}
    tags.forEach(function(t) { tagSha[t.name] = t.commit.sha })
    var at = {}
    compare.commits.forEach(function(c, i) { at[c.sha] = i })

    var found = list
      .filter(function(r) { return !r.draft && at[tagSha[r.tag_name]] !== undefined })
      .sort(function(a, b) { return at[tagSha[a.tag_name]] - at[tagSha[b.tag_name]] })

    var out = []
    var start = 0
    found.forEach(function(r) {
      var end = at[tagSha[r.tag_name]] + 1
      out.push({
        tag: r.tag_name,
        name: r.name || r.tag_name,
        published: String(r.published_at || "").slice(0, 10),
        body: r.body || "",
        url: r.html_url,
        commits: compare.commits.slice(start, end).reverse()
      })
      start = end
    })
    return out.reverse()
  }

  // Unauthenticated GitHub API allows 60 requests an hour, shared by both monitors.
  Timer {
    interval: 30 * 60 * 1000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: if (!fetchProc.running) fetchProc.running = true
  }

  Process {
    id: fetchProc
    command: ["bash", "-c",
      'c=$(curl -fsS --max-time 10 "$1/compare/$2...main") &&'
      + ' r=$(curl -fsS --max-time 10 "$1/releases?per_page=100") &&'
      + ' t=$(curl -fsS --max-time 10 "$1/tags?per_page=100") &&'
      + ' printf "[%s,%s,%s]" "$c" "$r" "$t"',
      "bash", root.api, root.base]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          root.releases = root.newReleases(data[0], data[1], data[2])
          root.failed = false
        } catch (e) {
          root.failed = true
        }
      }
    }
    onExited: function(code) { if (code !== 0) root.failed = true }
  }

  visible: failed || releases.length > 0
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰑓"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(520))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Text {
          width: parent.width
          text: root.failed ? "Could not reach GitHub"
            : "Personal fork is " + root.releases.length
              + (root.releases.length === 1 ? " release" : " releases") + " behind mangowm/mango"
          color: root.bar.foreground
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.title
        }

        ListView {
          visible: root.releases.length > 0
          width: parent.width
          height: Math.min(contentHeight, Style.space(440))
          interactive: contentHeight > height
          clip: true
          spacing: Style.space(2)
          boundsBehavior: Flickable.StopAtBounds
          model: root.releases

          delegate: Column {
            id: release
            required property var modelData
            readonly property bool expanded: root.openReleases[modelData.tag] === true
            readonly property bool commitsExpanded: root.openCommits[modelData.tag] === true
            width: ListView.view.width
            spacing: Style.space(2)

            RowButton {
              key: "release:" + release.modelData.tag
              label: (release.expanded ? "󰅀 " : "󰅂 ") + release.modelData.name
                + "  " + release.modelData.published
              trailing: goButton.width + Style.space(6)
              onActivated: root.openReleases = root.toggled(root.openReleases, release.modelData.tag)

              PanelActionButton {
                id: goButton
                anchors.right: parent.right
                anchors.rightMargin: Style.space(4)
                anchors.verticalCenter: parent.verticalCenter
                iconText: "󰏌"
                tooltipText: "Go to release"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                onClicked: {
                  root.close()
                  Util.execArgv(["xdg-open", release.modelData.url])
                }
              }
            }

            Text {
              visible: release.expanded && release.modelData.body !== ""
              x: Style.space(24)
              width: parent.width - x - Style.space(6)
              topPadding: Style.space(4)
              bottomPadding: Style.space(4)
              text: release.modelData.body
              textFormat: Text.MarkdownText
              wrapMode: Text.Wrap
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.body
            }

            RowButton {
              visible: release.expanded
              indent: Style.space(18)
              key: "commits:" + release.modelData.tag
              label: (release.commitsExpanded ? "󰅀 " : "󰅂 ") + release.modelData.commits.length
                + (release.modelData.commits.length === 1 ? " commit" : " commits")
              onActivated: root.openCommits = root.toggled(root.openCommits, release.modelData.tag)
            }

            Repeater {
              model: release.expanded && release.commitsExpanded ? release.modelData.commits : []

              delegate: RowButton {
                required property var modelData
                indent: Style.space(36)
                key: modelData.sha
                label: modelData.sha.slice(0, 7) + "  " + modelData.commit.message.split("\n")[0]
                onActivated: {
                  root.close()
                  Util.execArgv(["xdg-open", modelData.html_url])
                }
              }
            }
          }
        }
      }
    }
  }

  component RowButton: CursorSurface {
    id: row
    property string key
    property string label
    property real indent: 0
    // Room kept free on the right for a button placed inside the row.
    property real trailing: 0
    signal activated()

    width: parent ? parent.width : 0
    implicitHeight: rowText.implicitHeight + Style.space(8)
    hasCursor: root.hoveredKey === key
    foreground: root.bar.foreground

    Text {
      id: rowText
      anchors.fill: parent
      anchors.leftMargin: Style.space(6) + row.indent
      anchors.rightMargin: Style.space(6) + row.trailing
      verticalAlignment: Text.AlignVCenter
      text: row.label
      color: root.bar.foreground
      font.family: root.bar.fontFamily
      font.pixelSize: Style.font.body
      elide: Text.ElideRight
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onContainsMouseChanged: {
        if (containsMouse) root.hoveredKey = row.key
        else if (root.hoveredKey === row.key) root.hoveredKey = ""
      }
      onClicked: row.activated()
    }
  }
}
