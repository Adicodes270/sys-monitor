import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "aditya27003.cyber-sysmon"

  property int cpuPercent: 0
  property int memPercent: 0
  property string memUsedGb: "0.0"
  property string memTotalGb: "0.0"
  property int swapPercent: 0
  property string swapUsedGb: "0.0"
  property string swapTotalGb: "0.0"
  property string loadAvg: "0.0"
  property string cpuTemp: "N/A"
  property string uptime: "--"
  property var topProcs: []

  property real prevTotal: 0
  property real prevIdle: 0

  property bool popupOpen: false

  function close() { popupOpen = false }
  function open() { popupOpen = true }
  function toggle() { popupOpen = !popupOpen }

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  function parseStats(jsonStr) {
    if (!jsonStr || jsonStr.trim() === "") return
    try {
      var data = JSON.parse(jsonStr)
      if (root.prevTotal > 0 && data.total > root.prevTotal) {
        var dTotal = data.total - root.prevTotal
        var dIdle = data.idle - root.prevIdle
        var pct = Math.max(0, Math.min(100, Math.round(((dTotal - dIdle) / dTotal) * 100)))
        root.cpuPercent = pct
      }
      root.prevTotal = data.total
      root.prevIdle = data.idle

      if (data.memTotal > 0) {
        root.memPercent = Math.max(0, Math.min(100, Math.round((data.memUsed / data.memTotal) * 100)))
        root.memUsedGb = (data.memUsed / (1024 * 1024)).toFixed(1)
        root.memTotalGb = (data.memTotal / (1024 * 1024)).toFixed(1)
      }
      if (data.swapTotal > 0) {
        root.swapPercent = Math.max(0, Math.min(100, Math.round((data.swapUsed / data.swapTotal) * 100)))
        root.swapUsedGb = (data.swapUsed / (1024 * 1024)).toFixed(1)
        root.swapTotalGb = (data.swapTotal / (1024 * 1024)).toFixed(1)
      }
      root.loadAvg = data.load ? String(data.load) : "0.0"
      root.cpuTemp = data.temp ? String(data.temp) : "N/A"
      root.uptime = data.uptime ? String(data.uptime) : "--"
      root.topProcs = data.topProcs || []
    } catch (err) {
      console.warn("cyber-sysmon json error: " + err)
    }
  }

  Process {
    id: statsProc
    command: ["bash", Qt.resolvedUrl("scripts/stats.sh").toString().replace("file://", "")]
    stdout: SplitParser {
      onRead: function(line) {
        root.parseStats(line)
      }
    }
  }

  Timer {
    id: pollTimer
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: {
      if (!statsProc.running) statsProc.running = true
    }
  }

  implicitWidth: pill.implicitWidth + Style.space(8)
  implicitHeight: barSize

  // The Cyber Status Bar Pill
  Rectangle {
    id: pill
    anchors.centerIn: parent
    height: Math.min(28, Math.round(barSize * 0.72))
    implicitWidth: row.implicitWidth + 16
    radius: height / 2
    color: mouseArea.containsMouse ? "#2606b6d4" : (root.popupOpen ? "#33a855f7" : "#1a0b1120")
    border.color: mouseArea.containsMouse ? "#00f5ff" : (root.popupOpen ? "#c084fc" : "#3338bdf8")
    border.width: 1

    Behavior on color { ColorAnimation { duration: Style.duration(160) } }
    Behavior on border.color { ColorAnimation { duration: Style.duration(160) } }

    Row {
      id: row
      anchors.centerIn: parent
      spacing: Style.space(6)

      // CPU Icon & Value
      Text {
        textFormat: Text.PlainText
        text: ""
        color: root.cpuPercent > 80 ? "#f43f5e" : (root.cpuPercent > 50 ? "#fbbf24" : "#00f5ff")
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: root.cpuPercent + "%"
        color: root.cpuPercent > 80 ? "#f43f5e" : "#e2e8f0"
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }

      // Divider
      Rectangle {
        width: 1
        height: 12
        color: "#334155"
        anchors.verticalCenter: parent.verticalCenter
      }

      // RAM Icon & Value
      Text {
        textFormat: Text.PlainText
        text: ""
        color: root.memPercent > 85 ? "#f43f5e" : (root.memPercent > 70 ? "#fbbf24" : "#c084fc")
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.body
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        textFormat: Text.PlainText
        text: root.memPercent + "%"
        color: root.memPercent > 85 ? "#f43f5e" : "#e2e8f0"
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

      onEntered: {
        if (root.bar) root.bar.showTooltip(root, strings.t("tooltip.hint"))
      }
      onExited: {
        if (root.bar) root.bar.hideTooltip(root)
      }
      onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
          root.toggle()
        } else if (mouse.button === Qt.RightButton) {
          if (root.bar) root.bar.run("omarchy launch or focus tui btop")
        } else if (mouse.button === Qt.MiddleButton) {
          if (!statsProc.running) statsProc.running = true
        }
      }
    }
  }

  // Telemetry Popup Card
  PopupCard {
    id: popup
    anchorItem: root
    bar: root.bar
    owner: root
    open: root.popupOpen
    contentWidth: popup.fittedContentWidth(Style.space(340))
    contentHeight: popup.fittedContentHeight(col.implicitHeight)

    Column {
      id: col
      width: parent ? parent.width : Style.space(340)
      spacing: Style.space(10)

      // Header
      Row {
        width: parent.width
        spacing: Style.space(8)

        Text {
          textFormat: Text.PlainText
          text: "󰻠"
          color: "#00f5ff"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          textFormat: Text.PlainText
          text: strings.t("panel.title")
          color: "#00f5ff"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1.2
          anchors.verticalCenter: parent.verticalCenter
        }

        // Live badge
        Rectangle {
          radius: 3
          height: 16
          width: liveText.implicitWidth + 8
          color: "#1a10b981"
          border.color: "#34d399"
          border.width: 1
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: liveText
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: "● " + strings.t("panel.online")
            color: "#34d399"
            font.pixelSize: 9
            font.bold: true
          }
        }

        Item { Layout.fillWidth: true; width: 1 }

        // Uptime
        Text {
          textFormat: Text.PlainText
          text: "⏱ " + root.uptime
          color: "#a855f7"
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
          anchors.verticalCenter: parent.verticalCenter
        }
      }

      // Neon Divider
      Rectangle {
        width: parent.width
        height: 1
        color: "#2638bdf8"
      }

      // CPU Section
      Column {
        width: parent.width
        spacing: Style.space(4)

        Row {
          width: parent.width
          Text {
            textFormat: Text.PlainText
            text: strings.t("panel.cpuUsage")
            color: "#94a3b8"
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true; width: 1 }
          Text {
            textFormat: Text.PlainText
            text: (root.cpuTemp !== "N/A" ? root.cpuTemp + "°C  ·  " : "") + strings.t("panel.load") + ": " + root.loadAvg + "  ·  " + root.cpuPercent + "%"
            color: root.cpuPercent > 80 ? "#f43f5e" : "#00f5ff"
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        // CPU Bar Track
        Rectangle {
          width: parent.width
          height: 6
          radius: 3
          color: "#1e293b"
          clip: true

          Rectangle {
            height: parent.height
            width: Math.max(4, Math.round((root.cpuPercent / 100) * parent.width))
            radius: 3
            color: root.cpuPercent > 80 ? "#f43f5e" : (root.cpuPercent > 50 ? "#fbbf24" : "#00f5ff")
            Behavior on width {
              NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic }
            }
          }
        }
      }

      // Memory Section
      Column {
        width: parent.width
        spacing: Style.space(4)

        Row {
          width: parent.width
          Text {
            textFormat: Text.PlainText
            text: strings.t("panel.memory")
            color: "#94a3b8"
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true; width: 1 }
          Text {
            textFormat: Text.PlainText
            text: root.memUsedGb + " / " + root.memTotalGb + " GB (" + root.memPercent + "%)"
            color: root.memPercent > 85 ? "#f43f5e" : "#c084fc"
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        // RAM Bar Track
        Rectangle {
          width: parent.width
          height: 6
          radius: 3
          color: "#1e293b"
          clip: true

          Rectangle {
            height: parent.height
            width: Math.max(4, Math.round((root.memPercent / 100) * parent.width))
            radius: 3
            color: root.memPercent > 85 ? "#f43f5e" : (root.memPercent > 70 ? "#fbbf24" : "#c084fc")
            Behavior on width {
              NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic }
            }
          }
        }
      }

      // Swap Section (if configured)
      Column {
        width: parent.width
        spacing: Style.space(4)
        visible: root.swapTotalGb !== "0.0"

        Row {
          width: parent.width
          Text {
            textFormat: Text.PlainText
            text: strings.t("panel.swap")
            color: "#94a3b8"
            font.pixelSize: Style.font.caption
          }
          Item { Layout.fillWidth: true; width: 1 }
          Text {
            textFormat: Text.PlainText
            text: root.swapUsedGb + " / " + root.swapTotalGb + " GB (" + root.swapPercent + "%)"
            color: "#818cf8"
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }

        Rectangle {
          width: parent.width
          height: 5
          radius: 2.5
          color: "#1e293b"
          clip: true

          Rectangle {
            height: parent.height
            width: Math.max(4, Math.round((root.swapPercent / 100) * parent.width))
            radius: 2.5
            color: "#818cf8"
            Behavior on width {
              NumberAnimation { duration: Style.duration(180); easing.type: Easing.OutCubic }
            }
          }
        }
      }

      // Top Processes Section
      Column {
        width: parent.width
        spacing: Style.space(4)

        Text {
          textFormat: Text.PlainText
          text: strings.t("panel.topProcs")
          color: "#64748b"
          font.pixelSize: 10
          font.bold: true
          font.letterSpacing: 0.8
        }

        Repeater {
          model: root.topProcs
          delegate: Row {
            width: col.width
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: modelData.name || "proc"
              color: "#cbd5e1"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 11
              width: Style.space(140)
              elide: Text.ElideRight
            }

            Item { Layout.fillWidth: true; width: 1 }

            Text {
              textFormat: Text.PlainText
              text: "CPU " + modelData.cpu + "%"
              color: "#00f5ff"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 10
            }

            Text {
              textFormat: Text.PlainText
              text: "RAM " + modelData.mem + "%"
              color: "#c084fc"
              font.family: "JetBrainsMono Nerd Font"
              font.pixelSize: 10
            }
          }
        }
      }

      // Divider
      Rectangle {
        width: parent.width
        height: 1
        color: "#2638bdf8"
      }

      // Action Footer
      Row {
        width: parent.width
        spacing: Style.space(8)

        // Launch Btop Button
        Rectangle {
          height: 28
          width: (parent.width - Style.space(8)) / 2
          radius: 6
          color: btopHover.containsMouse ? "#2600f5ff" : "#111827"
          border.color: btopHover.containsMouse ? "#00f5ff" : "#3338bdf8"
          border.width: 1

          Behavior on color { ColorAnimation { duration: Style.duration(120) } }
          Behavior on border.color { ColorAnimation { duration: Style.duration(120) } }

          Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
              textFormat: Text.PlainText
              text: "󰄛"
              color: "#00f5ff"
              font.pixelSize: Style.font.body
            }
            Text {
              textFormat: Text.PlainText
              text: strings.t("panel.launchBtop")
              color: "#f1f5f9"
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          MouseArea {
            id: btopHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              root.close()
              if (root.bar) root.bar.run("omarchy launch or focus tui btop")
            }
          }
        }

        // Refresh Button
        Rectangle {
          height: 28
          width: (parent.width - Style.space(8)) / 2
          radius: 6
          color: refHover.containsMouse ? "#26a855f7" : "#111827"
          border.color: refHover.containsMouse ? "#c084fc" : "#33a855f7"
          border.width: 1

          Behavior on color { ColorAnimation { duration: Style.duration(120) } }
          Behavior on border.color { ColorAnimation { duration: Style.duration(120) } }

          Row {
            anchors.centerIn: parent
            spacing: 6
            Text {
              textFormat: Text.PlainText
              text: "↺"
              color: "#c084fc"
              font.pixelSize: Style.font.body
            }
            Text {
              textFormat: Text.PlainText
              text: strings.t("panel.refresh")
              color: "#f1f5f9"
              font.pixelSize: Style.font.caption
              font.bold: true
            }
          }

          MouseArea {
            id: refHover
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (!statsProc.running) statsProc.running = true
            }
          }
        }
      }
    }
  }
}
