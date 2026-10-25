import QtQuick
import QtQuick.Shapes
import qs.Commons

Item {
  id: root

  property real iconSize: Style.font.icon
  property color color: Colors.foreground
  property bool crossed: false
  property bool pulsing: false

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  // The Proton VPN mark (Simple Icons, 24×24), drawn as a Shape so it takes
  // the theme color. Split in two so the rear fold reads as depth.
  Item {
    id: mark
    width: 24
    height: 24
    scale: root.iconSize / 24
    transformOrigin: Item.TopLeft

    SequentialAnimation on opacity {
      running: root.pulsing
      loops: Animation.Infinite
      NumberAnimation { to: 0.35; duration: 520; easing.type: Easing.InOutQuad }
      NumberAnimation { to: 1.0; duration: 520; easing.type: Easing.InOutQuad }
      onRunningChanged: if (!running) mark.opacity = 1.0
    }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer

      ShapePath {
        strokeWidth: -1
        strokeColor: "transparent"
        fillColor: Qt.rgba(root.color.r, root.color.g, root.color.b, 0.5)
        PathSvg { path: "M23.586 7.14l-9.662 14.61c-1.036 1.567-3.38 1.478-4.293-.162l-.093-.168c.3-.01.594-.086.855-.235a1.85 1.85 0 0 0 .612-.57l.86-1.28 6.516-9.844c.46-.694.525-1.56.173-2.314a2.375 2.375 0 0 0-1.899-1.364L.493 3.956l-.476-.054C-.163 2.392 1.101.95 2.784 1.143l18.991 2.16c1.856.21 2.835 2.289 1.812 3.838z" }
      }

      ShapePath {
        strokeWidth: -1
        strokeColor: "transparent"
        fillColor: root.color
        PathSvg { path: "M10.176 20.058l.858-1.28 6.513-9.838c.57-.86.026-2.014-1.005-2.131L.378 4.95l8.373 15.055a.84.84 0 0 0 1.424.052h.001z" }
      }
    }
  }

  Rectangle {
    visible: root.crossed
    anchors.centerIn: parent
    width: parent.width * 1.22
    height: Math.max(2, parent.height * 0.14)
    radius: height / 2
    color: root.color
    rotation: -45
  }
}
