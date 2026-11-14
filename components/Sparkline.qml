import QtQuick
import qs.Commons

// A compact history graph made of one thin bar per sample. Cheap enough to
// redraw every second, and readable at panel-card size without axes.
//
// Bars are positioned by hand instead of through a layout: every bar has to
// share one baseline, and a RowLayout centering short bars is a surprisingly
// easy thing to get wrong.
Item {
  id: root

  property var values: []
  // Fixed scale for percentages (100) or temperatures; a value <= 0 turns on
  // auto-scaling from the largest sample in the list.
  property real maxValue: -1
  property color tone: Color.accent
  property int gap: 1
  property real minBarHeight: 1

  implicitHeight: Style.space(16)

  readonly property int count: values ? values.length : 0

  readonly property real peak: {
    var fixed = Number(maxValue)
    if (isFinite(fixed) && fixed > 0) return fixed

    var top = 0
    for (var i = 0; i < count; i++)
      top = Math.max(top, Number(values[i]) || 0)
    return top > 0 ? top : 1
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: Util.alpha(root.tone, 0.16)
  }

  Repeater {
    model: root.values

    Rectangle {
      required property var modelData
      required property int index

      readonly property real barWidth: Math.max(1, (root.width - root.gap * Math.max(0, root.count - 1)) / Math.max(1, root.count))

      x: index * (barWidth + root.gap)
      width: barWidth
      height: Math.max(root.minBarHeight, Math.round(root.height * Math.max(0, Math.min(1, (Number(modelData) || 0) / root.peak))))
      y: root.height - height

      radius: Math.min(1, width / 2)
      color: root.tone
      opacity: root.count <= 1 ? 1 : 0.35 + 0.65 * (index / (root.count - 1))
    }
  }
}
