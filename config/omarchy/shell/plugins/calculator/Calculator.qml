import Quickshell
import Quickshell.Wayland
import QtQuick
import qs.Commons
import qs.Ui
import "../../Commons/Calc.js" as Calc

// A plain calculator: digits, the four operators, parentheses, and the list of
// what was worked out before. No modes, no units, no unknowns - anything that
// wants those has the menu's "=" query and the same evaluator behind it.
//
// Earlier answers are readable as $0 (the last one) through $9, so a running
// total can be built out of the rows above instead of retyping them: 25*2+$0.
//
// Always mounted rather than built on summon, unlike the on-demand panels: the
// history is state worth keeping while the card is closed.
Item {
  id: root

  property var shell: null

  property bool opened: false

  // The expression being typed. Everything shown is derived from it.
  property string input: ""
  // True while the input holds an answer rather than something typed. A digit
  // then starts a new sum and an operator carries the answer forward, which is
  // what every pocket calculator does after "=".
  property bool resultShown: false

  // Null until the expression means something, so a half-typed "2+" shows no
  // answer rather than an error. A $n past the end of the history is one of
  // those nothings, so an answer never quietly stands in for a missing row.
  readonly property var live: Calc.evaluateExpression(root.input, root.historyValues)
  readonly property string liveText: live ? live.text : ""

  // The answers behind $0..$9, newest first. Reassigned rather than mutated:
  // that is what re-evaluates `live` when a row lands.
  property var historyValues: []

  property int historyLimit: 50
  // How far the $n labels go. Rows past this keep their answer and lose only
  // the shorthand.
  readonly property int referenceLimit: 10

  // Shares the [menu] surface tokens, so a theme that styles the menu styles
  // this too.
  property color background: Colors.menu.background
  property color foreground: Colors.menu.text
  property color border: Colors.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Colors.menu.scrim
  property color accent: Colors.menu.selectedText
  property color rowBackground: Colors.menu.selectedBackground
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md

  property int columns: 4
  property int rows: 5
  property int keySpacing: Style.spacing.sm
  property int cardWidth: Math.min(Style.space(360), panel.width - Style.gapsOut * 2)
  property int contentWidth: cardWidth - contentMargin * 2
  property int keyWidth: Math.floor((contentWidth - keySpacing * (columns - 1)) / columns)
  property int keyHeight: Math.max(Style.space(48), Style.font.heading * 2 + Style.spacing.md)
  property int keypadHeight: keyHeight * rows + keySpacing * (rows - 1)
  property int displayHeight: Style.font.display + Style.font.subtitle + Style.spacing.sm
  property int historyHeight: Style.space(110)
  property int cardHeight: Math.min(
    contentMargin * 2 + historyHeight + displayHeight + keypadHeight + contentSpacing * 2,
    panel.height - Style.gapsOut * 2)

  // kind decides what a press does; `value` is what lands in the input when it
  // differs from the label, so the pad can show ÷ and × and still feed the
  // parser / and *.
  readonly property var keys: [
    [{ label: "AC", kind: "clear" },
     { label: "(", kind: "insert", value: "(" },
     { label: ")", kind: "insert", value: ")" },
     { label: "÷", kind: "insert", value: "/" }],
    [{ label: "7", kind: "digit" }, { label: "8", kind: "digit" }, { label: "9", kind: "digit" },
     { label: "×", kind: "insert", value: "*" }],
    [{ label: "4", kind: "digit" }, { label: "5", kind: "digit" }, { label: "6", kind: "digit" },
     { label: "−", kind: "insert", value: "-" }],
    [{ label: "1", kind: "digit" }, { label: "2", kind: "digit" }, { label: "3", kind: "digit" },
     { label: "+", kind: "insert", value: "+" }],
    [{ label: "0", kind: "digit" }, { label: ".", kind: "digit" },
     { label: "⌫", kind: "back" }, { label: "=", kind: "equals" }]
  ]

  // What the keyboard may put into the expression directly. ^, % and $ are not
  // on the pad but the parser takes all three, so typing them works.
  readonly property string typedChars: "0123456789.+-*/%^()$"

  // Where a number may follow: everything a value can legally come after.
  readonly property string operatorChars: "+-*/%^("

  ListModel { id: historyModel }

  function open(payloadJson) {
    root.opened = true
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  function close() {
    root.opened = false
  }

  function dismiss() {
    root.opened = false
    if (root.shell && typeof root.shell.hide === "function")
      root.shell.hide("omarchy.calculator")
  }

  function toggle() {
    if (root.opened) root.dismiss()
    else root.open("{}")
  }

  function press(key) {
    if (key.kind === "clear") root.clearAll()
    else if (key.kind === "back") root.backspace()
    else if (key.kind === "equals") root.commit()
    else root.insert(key.value === undefined ? key.label : key.value, key.kind === "digit")
  }

  function insert(text, startsNumber) {
    if (root.resultShown) {
      if (startsNumber) root.input = ""
      root.resultShown = false
    }
    root.input += text
  }

  function clearAll() {
    root.input = ""
    root.resultShown = false
  }

  function backspace() {
    root.input = root.input.substring(0, root.input.length - 1)
    root.resultShown = false
  }

  function commit() {
    var answer = root.live
    if (!answer) return
    historyModel.insert(0, { expression: answer.expression, result: answer.text, value: answer.value })
    while (historyModel.count > root.historyLimit) historyModel.remove(historyModel.count - 1)
    root.rebuildValues()
    root.input = answer.text
    root.resultShown = true
  }

  function rebuildValues() {
    var values = []
    for (var i = 0; i < historyModel.count && i < root.referenceLimit; i++)
      values.push(historyModel.get(i).value)
    root.historyValues = values
  }

  // Clicking a history row puts its answer back in play. It can only be
  // appended where a number belongs - after an operator or into an empty
  // input. Anywhere else the digits would run into what is already typed and
  // "7*6" would silently become "7*621", so there the row replaces the input
  // instead, which is what recalling one means.
  function recall(text) {
    var last = root.input.substring(root.input.length - 1)
    var continues = root.input === "" || (!root.resultShown && root.operatorChars.indexOf(last) >= 0)
    if (!continues) root.clearAll()
    root.insert(String(text), true)
  }

  function copyResult() {
    var value = root.liveText || root.input
    if (!value) return
    Quickshell.execDetached(["bash", "-c", "printf %s " + Util.shellQuote(value) + " | wl-copy"])
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-calculator"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismiss()
    }

    BorderSurface {
      id: card
      width: root.cardWidth
      height: root.cardHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.input) root.clearAll()
            else root.dismiss()
            event.accepted = true
          } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.commit()
            event.accepted = true
          } else if (event.key === Qt.Key_Backspace) {
            root.backspace()
            event.accepted = true
          } else if (event.key === Qt.Key_Delete) {
            root.clearAll()
            event.accepted = true
          } else if (event.key === Qt.Key_C && (event.modifiers & Qt.ControlModifier)) {
            root.copyResult()
            event.accepted = true
          } else if (event.text === "=") {
            root.commit()
            event.accepted = true
          } else if (event.text.length === 1 && root.typedChars.indexOf(event.text) >= 0) {
            // "$" opens a value the same way a digit does, so it starts a new
            // sum rather than running onto the answer already shown.
            root.insert(event.text, event.text >= "0" && event.text <= "9"
                                    || event.text === "." || event.text === "$")
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.topMargin: card.contentTopInset
        anchors.rightMargin: card.contentRightInset
        anchors.bottomMargin: card.contentBottomInset
        anchors.leftMargin: card.contentLeftInset
        spacing: root.contentSpacing

        // ------------------------------------------------------- history
        Item {
          width: parent.width
          height: root.historyHeight

          ListView {
            id: historyView
            anchors.fill: parent
            model: historyModel
            clip: true
            // Newest at the top: it is the one worth reaching for, and a list
            // that grows downward would push it out of sight.
            boundsBehavior: Flickable.StopAtBounds
            spacing: Style.spacing.xs

            delegate: Item {
              id: historyRow
              required property int index
              required property string expression
              required property string result

              width: historyView.width
              height: Style.font.bodySmall + Style.spacing.controlPaddingY * 2

              Rectangle {
                anchors.fill: parent
                radius: root.cornerRadius
                color: hover.hovered ? root.rowBackground : "transparent"

                HoverHandler { id: hover }
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.recall(result)
                }

                // The name this row answers to in an expression. Rows past $9
                // keep the answer and lose the shorthand, so the column is
                // blank rather than lying about what can be typed.
                Text {
                  id: referenceText
                  anchors.left: parent.left
                  anchors.leftMargin: Style.spacing.rowPaddingX
                  anchors.verticalCenter: parent.verticalCenter
                  text: historyRow.index < root.referenceLimit ? "$" + historyRow.index : ""
                  color: root.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                Text {
                  anchors.left: referenceText.right
                  anchors.leftMargin: Style.spacing.sm
                  anchors.verticalCenter: parent.verticalCenter
                  width: parent.width * 0.45
                  text: expression
                  color: root.foreground
                  opacity: 0.5
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                  elide: Text.ElideLeft
                }

                Text {
                  anchors.right: parent.right
                  anchors.rightMargin: Style.spacing.rowPaddingX
                  anchors.verticalCenter: parent.verticalCenter
                  text: "= " + result
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }
              }
            }
          }

          Text {
            anchors.centerIn: parent
            visible: historyModel.count === 0
            text: "Answers land here as $0 to $9"
            color: root.foreground
            opacity: 0.4
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
          }
        }

        // ------------------------------------------------------- display
        Item {
          width: parent.width
          height: root.displayHeight

          Text {
            id: expressionText
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            horizontalAlignment: Text.AlignRight
            text: root.input || "0"
            color: root.foreground
            opacity: root.input ? 1 : 0.4
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            // Left, so the digits being typed stay on screen.
            elide: Text.ElideLeft
          }

          Text {
            anchors.top: expressionText.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            horizontalAlignment: Text.AlignRight
            // Hidden once the answer is the input, where it would only repeat
            // the line above.
            visible: root.liveText !== "" && root.liveText !== root.input
            text: "= " + root.liveText
            color: root.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.subtitle
            elide: Text.ElideLeft
          }
        }

        // -------------------------------------------------------- keypad
        Column {
          width: parent.width
          spacing: root.keySpacing

          Repeater {
            model: root.keys

            Row {
              id: keyRow
              required property var modelData

              spacing: root.keySpacing

              Repeater {
                model: keyRow.modelData

                Button {
                  required property var modelData

                  width: root.keyWidth
                  height: root.keyHeight
                  text: modelData.label
                  foreground: modelData.kind === "equals" ? root.accent : root.foreground
                  accent: root.accent
                  fontFamily: root.fontFamily
                  fontSize: Style.font.heading
                  bordered: true
                  onClicked: root.press(modelData)
                }
              }
            }
          }
        }
      }
    }
  }
}
