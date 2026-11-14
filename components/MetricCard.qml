import QtQuick
import QtQuick.Layouts
import qs.Commons

// One telemetry card: a dim uppercase label, a big value, an optional meta
// line, and either a history graph or a level meter. Every card shares the
// same implicit height so the grid stays even.
Rectangle {
  id: root

  property string label: ""
  property string value: ""
  property string detail: ""
  property string meta: ""

  property real fraction: -1
  property var values: []
  property real maxValue: -1
  property bool showGraph: true

  property color tone: Color.accent
  property color foreground: Color.foreground
  property string fontFamily: Style.font.family

  radius: Style.cornerRadius
  color: Util.alpha(foreground, 0.035)
  border.color: Util.alpha(foreground, 0.12)
  border.width: 1
  implicitHeight: Style.space(92)

  readonly property bool graphVisible: root.showGraph && root.values.length > 0

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(3)

    RowLayout {
      Layout.fillWidth: true
      spacing: Style.space(6)

      Text {
        textFormat: Text.PlainText
        text: root.label.toUpperCase()
        color: Util.alpha(root.foreground, 0.55)
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
        font.letterSpacing: 1.1
        elide: Text.ElideRight
        Layout.fillWidth: true
      }

      Text {
        textFormat: Text.PlainText
        text: root.detail
        visible: text !== ""
        color: root.tone
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        font.bold: true
      }
    }

    Text {
      textFormat: Text.PlainText
      text: root.value
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.subtitle
      font.bold: true
      elide: Text.ElideRight
      Layout.fillWidth: true
    }

    Text {
      textFormat: Text.PlainText
      text: root.meta
      visible: text !== ""
      color: Util.alpha(root.foreground, 0.45)
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      elide: Text.ElideRight
      Layout.fillWidth: true
    }

    Item {
      Layout.fillHeight: true
    }

    Sparkline {
      visible: root.graphVisible
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(14)
      values: root.values
      maxValue: root.maxValue
      tone: root.tone
      gap: 1
    }

    LevelBar {
      visible: !root.graphVisible && root.fraction >= 0
      Layout.fillWidth: true
      Layout.preferredHeight: Style.space(5)
      fraction: Math.max(0, Math.min(1, root.fraction))
      tone: root.tone
    }
  }
}
