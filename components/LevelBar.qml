import QtQuick
import qs.Commons

// A thin HUD level meter: a dim track with a neon fill and a soft halo.
// Every width change animates, so a metric climbing between polls reads as
// movement rather than a jump.
Item {
  id: root

  property real fraction: 0
  property color tone: Color.accent
  property color trackColor: Util.alpha(tone, 0.14)

  implicitHeight: Style.space(5)
  implicitWidth: Style.space(80)

  readonly property real clamped: Math.max(0, Math.min(1, Number(fraction) || 0))

  // Soft light around the fill. Drawn first so the solid bar sits on top.
  Rectangle {
    visible: fill.width > 0
    width: fill.width
    height: root.height + Style.space(2)
    y: -Style.space(1)
    radius: height / 2
    color: Util.alpha(root.tone, 0.18)
  }

  Rectangle {
    anchors.fill: parent
    radius: height / 2
    color: root.trackColor
  }

  Rectangle {
    id: fill
    width: root.clamped * root.width
    height: root.height
    radius: height / 2
    color: root.tone

    Behavior on width {
      NumberAnimation {
        duration: Style.duration(180)
        easing.type: Easing.OutCubic
      }
    }
  }
}
