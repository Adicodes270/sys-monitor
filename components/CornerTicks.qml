import QtQuick
import qs.Commons

// Corner brackets, the cheapest way to make a card read as a HUD frame.
// Eight hairlines, no shaders, no blur.
Item {
  id: root

  property color tickColor: Color.foreground
  property real length: Style.space(6)
  property real thickness: 1

  Rectangle { x: 0; y: 0; width: root.length; height: root.thickness; color: root.tickColor }
  Rectangle { x: 0; y: 0; width: root.thickness; height: root.length; color: root.tickColor }

  Rectangle { x: root.width - root.length; y: 0; width: root.length; height: root.thickness; color: root.tickColor }
  Rectangle { x: root.width - root.thickness; y: 0; width: root.thickness; height: root.length; color: root.tickColor }

  Rectangle { x: 0; y: root.height - root.thickness; width: root.length; height: root.thickness; color: root.tickColor }
  Rectangle { x: 0; y: root.height - root.length; width: root.thickness; height: root.length; color: root.tickColor }

  Rectangle { x: root.width - root.length; y: root.height - root.thickness; width: root.length; height: root.thickness; color: root.tickColor }
  Rectangle { x: root.width - root.thickness; y: root.height - root.length; width: root.thickness; height: root.length; color: root.tickColor }
}
