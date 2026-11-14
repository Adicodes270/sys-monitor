import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "components"
import "Model.js" as Model

// Sys Analytics - the detail panel behind the bar HUD.
//
// Everything here reads live properties from BarWidget.qml (the `hostWidget`
// injection) instead of sampling on its own, so the bar and the panel always
// agree and there is only one process per tick.
Panel {
  id: root
  moduleName: "aditya27003.sys-analytics"
  ipcTarget: "aditya27003.sys-analytics"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  // The bar tracks the widget mounted in its slot, not this nested panel.
  readonly property var barIdentity: hostWidget || root
  readonly property var hw: hostWidget

  // ---- theme --------------------------------------------------------------
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color urgentColor: bar ? bar.urgent : Color.urgent
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property color accentMain: hw ? hw.accentMain : Color.accent
  readonly property color accentAlt: hw ? hw.accentAlt : Color.accent
  readonly property color warnColor: hw ? hw.warnColor : Color.urgent
  readonly property color dimColor: Util.alpha(root.foreground, 0.55)
  readonly property color faintColor: Util.alpha(root.foreground, 0.12)

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  // ---- view state ---------------------------------------------------------
  property bool showSettings: false
  property int settingCursor: 0
  onShowSettingsChanged: if (showSettings) settingCursor = 0

  // ---- live values, with fallbacks so the panel can render before the
  //      first sample lands or before the host is injected ---------------
  readonly property int cpuPct: hw && hw.cpuPct >= 0 ? hw.cpuPct : -1
  readonly property bool cpuReady: root.cpuPct >= 0
  readonly property real cpuFreqGhz: hw ? hw.cpuFreqGhz : 0
  readonly property int coreCount: hw ? hw.coreCount : 0
  readonly property var corePcts: hw ? hw.corePcts : []
  readonly property var cpuHistory: hw ? hw.cpuHistory : []

  readonly property int memPct: hw && hw.memPct >= 0 ? hw.memPct : -1
  readonly property real memUsedBytes: hw ? hw.memUsedBytes : 0
  readonly property real memTotalBytes: hw ? hw.memTotalBytes : 0
  readonly property int swapPct: hw ? hw.swapPct : 0
  readonly property real swapUsedBytes: hw ? hw.swapUsedBytes : 0
  readonly property real swapTotalBytes: hw ? hw.swapTotalBytes : 0
  readonly property var memHistory: hw ? hw.memHistory : []

  readonly property real tempC: hw ? hw.tempC : NaN
  readonly property real fanRpm: hw ? hw.fanRpm : -1
  readonly property real loadAvg: hw ? hw.loadAvg : 0
  readonly property real uptimeSeconds: hw ? hw.uptimeSeconds : 0
  readonly property var tempHistory: hw ? hw.tempHistory : []

  readonly property real netDownBps: hw ? hw.netDownBps : 0
  readonly property real netUpBps: hw ? hw.netUpBps : 0
  readonly property real netDownTotal: hw ? hw.netDownTotal : 0
  readonly property real netUpTotal: hw ? hw.netUpTotal : 0
  readonly property string netIface: hw ? (hw.netIface || "") : ""
  readonly property var netDownHistory: hw ? hw.netDownHistory : []
  readonly property var netUpHistory: hw ? hw.netUpHistory : []

  readonly property int diskPct: hw && hw.diskPct >= 0 ? hw.diskPct : -1
  readonly property real diskUsedBytes: hw ? hw.diskUsedBytes : 0
  readonly property real diskTotalBytes: hw ? hw.diskTotalBytes : 0
  readonly property real diskFreeBytes: hw ? hw.diskFreeBytes : 0

  readonly property var procs: hw ? hw.topProcs : []

  readonly property int intervalMs: hw ? hw.intervalMs : 1000
  readonly property bool neonOn: hw ? hw.neon === true : false

  // ---- formatting ---------------------------------------------------------
  function pctText(value, fallback) {
    if (!(value >= 0)) return fallback !== undefined ? fallback : "--"
    return I18n.formatNumber(value, 0) + "%"
  }

  function bytesText(bytes) {
    var p = Model.bytesParts(bytes)
    return I18n.formatNumber(p.value, p.decimals) + " " + p.unit
  }

  function rateText(bytesPerSecond) {
    var p = Model.rateParts(bytesPerSecond)
    return I18n.formatNumber(p.value, p.decimals) + " " + p.unit
  }

  function tempText() {
    if (!(root.tempC >= 0)) return strings.t("common.na")
    return I18n.formatNumber(Math.round(root.tempC), 0) + "°C"
  }

  function freqText() {
    return root.cpuFreqGhz > 0 ? I18n.formatNumber(root.cpuFreqGhz, 1) + " GHz" : "--"
  }

  function loadText() {
    return I18n.formatNumber(root.loadAvg, 2)
  }

  function fanText() {
    return root.fanRpm > 0 ? I18n.formatNumber(Math.round(root.fanRpm), 0) + " RPM" : "--"
  }

  function uptimeText() {
    return Model.formatUptime(root.uptimeSeconds)
  }

  function toneFor(value, warnAt, urgentAt, normal) {
    if (!(value >= 0)) return root.dimColor
    if (value >= urgentAt) return root.urgentColor
    if (value >= warnAt) return root.warnColor
    return normal
  }

  function cpuTone() { return root.toneFor(root.cpuPct, 60, 85, root.accentMain) }
  function memTone() { return root.toneFor(root.memPct, 70, 90, root.accentAlt) }
  function diskTone() { return root.toneFor(root.diskPct, 75, 90, root.accentMain) }
  function tempTone() { return root.toneFor(root.tempC, 70, 85, root.accentMain) }

  // ---- settings -----------------------------------------------------------
  function settingFlag(key) {
    return root.hw ? root.hw[key] === true : false
  }

  function setSetting(key, value) {
    if (root.hw && typeof root.hw.setSetting === "function") root.hw.setSetting(key, value)
  }

  function toggleSetting(key) {
    root.setSetting(key, !root.settingFlag(key))
  }

  function resetSettings() {
    if (root.hw && typeof root.hw.resetSettings === "function") root.hw.resetSettings()
  }

  function refresh() {
    if (root.hw && typeof root.hw.refresh === "function") root.hw.refresh()
  }

  function launchBtop() {
    if (root.bar && typeof root.bar.run === "function") root.bar.run("omarchy launch or focus tui btop")
    root.close()
  }

  function cycleInterval() {
    var values = [500, 1000, 2000]
    var index = values.indexOf(root.intervalMs)
    root.setSetting("intervalMs", values[(index + 1) % values.length])
  }

  function scrollBy(dy) {
    flick.contentY = Math.max(0, Math.min(flick.contentHeight - flick.height, flick.contentY + dy))
  }

  function moveSettingCursor(delta) {
    var count = root.toggleRows.length
    if (count <= 0) return
    root.settingCursor = Math.max(0, Math.min(count - 1, root.settingCursor + delta))
  }

  function activateSettingCursor() {
    var row = root.toggleRows[root.settingCursor]
    if (row) root.toggleSetting(row.key)
  }

  // The settings rows, built once so the keyboard and the layout share the
  // same order.
  readonly property var toggleRows: [
    { key: "showCpu", label: strings.t("settings.showCpu"), description: strings.t("settings.showCpu.desc") },
    { key: "showMem", label: strings.t("settings.showMem"), description: strings.t("settings.showMem.desc") },
    { key: "showTemp", label: strings.t("settings.showTemp"), description: strings.t("settings.showTemp.desc") },
    { key: "showNet", label: strings.t("settings.showNet"), description: strings.t("settings.showNet.desc") },
    { key: "showDisk", label: strings.t("settings.showDisk"), description: strings.t("settings.showDisk.desc") },
    { key: "showUptime", label: strings.t("settings.showUptime"), description: strings.t("settings.showUptime.desc") },
    { key: "neon", label: strings.t("settings.neon"), description: strings.t("settings.neon.desc") }
  ]

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      implicitHeight: body.implicitHeight
      onCloseRequested: root.close()
      onMoveRequested: function(dx, dy) {
        if (root.showSettings) root.moveSettingCursor(dy)
        else root.scrollBy(dy * Style.space(48))
      }
      onTabRequested: function(direction) {
        if (root.showSettings) root.moveSettingCursor(direction)
      }
      onActivateRequested: {
        if (root.showSettings) root.activateSettingCursor()
      }
      onTextKey: function(t) {
        if (t === "s" || t === "S") root.showSettings = !root.showSettings
        else if (t === "r" || t === "R") root.refresh()
        else if (t === "b" || t === "B") root.launchBtop()
      }

      Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        ColumnLayout {
          id: body
          width: flick.width
          spacing: Style.space(12)

          // ---- header -----------------------------------------------------
          RowLayout {
            Layout.fillWidth: true
            spacing: Style.space(8)

            Rectangle {
              width: Style.space(6)
              height: Style.space(6)
              radius: width / 2
              color: root.accentMain
              Layout.alignment: Qt.AlignVCenter

              SequentialAnimation on opacity {
                running: !Style.reduceMotion
                loops: Animation.Infinite
                NumberAnimation { to: 0.25; duration: Style.duration(900); easing.type: Easing.InOutQuad }
                NumberAnimation { to: 1.0; duration: Style.duration(900); easing.type: Easing.InOutQuad }
              }
            }

            Text {
              textFormat: Text.PlainText
              text: strings.t("panel.live")
              color: root.accentMain
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.4
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              textFormat: Text.PlainText
              text: "·"
              visible: true
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              Layout.alignment: Qt.AlignVCenter
            }

            Text {
              textFormat: Text.PlainText
              text: strings.t("panel.uptime") + " " + root.uptimeText()
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              Layout.fillWidth: true
              elide: Text.ElideRight
              Layout.alignment: Qt.AlignVCenter
            }

            PanelActionButton {
              iconText: root.showSettings ? "󰁍" : "󰒓"
              tooltipText: root.showSettings ? strings.t("panel.back") : strings.t("panel.settings")
              foreground: root.foreground
              fontFamily: root.fontFamily
              onClicked: root.showSettings = !root.showSettings
            }
          }

          // ---- title ------------------------------------------------------
          Text {
            textFormat: Text.PlainText
            Layout.fillWidth: true
            Layout.topMargin: -Style.space(4)
            text: root.showSettings ? strings.t("settings.title") : strings.t("panel.title")
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            elide: Text.ElideRight
          }

          // ---- detail view ------------------------------------------------
          ColumnLayout {
            Layout.fillWidth: true
            visible: !root.showSettings
            spacing: Style.space(12)

            // CPU hero
            Rectangle {
              Layout.fillWidth: true
              implicitHeight: hero.implicitHeight + Style.space(24)
              radius: Style.cornerRadius
              color: Util.alpha(root.foreground, 0.04)
              border.width: 1
              border.color: Util.alpha(root.cpuTone(), 0.32)

              CornerTicks {
                anchors.fill: parent
                anchors.margins: 1
                tickColor: Util.alpha(root.cpuTone(), 0.55)
                length: Style.space(9)
              }

              RowLayout {
                id: hero
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(16)

                ColumnLayout {
                  spacing: 0
                  Layout.alignment: Qt.AlignVCenter

                  Text {
                    textFormat: Text.PlainText
                    text: root.cpuReady ? I18n.formatNumber(root.cpuPct, 0) : "--"
                    color: root.cpuTone()
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.displayLarge
                    font.bold: true
                  }

                  Text {
                    textFormat: Text.PlainText
                    text: "% " + strings.t("panel.cpuLoad")
                    color: root.dimColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    font.letterSpacing: 1
                  }
                }

                ColumnLayout {
                  Layout.fillWidth: true
                  Layout.alignment: Qt.AlignVCenter
                  spacing: Style.space(6)

                  Sparkline {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Style.space(40)
                    values: root.cpuHistory
                    maxValue: 100
                    tone: root.cpuTone()
                    gap: 2
                  }

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(6)

                    Repeater {
                      model: [
                        { label: strings.t("panel.load"), value: root.loadText(), tone: root.foreground },
                        { label: strings.t("panel.freq"), value: root.freqText(), tone: root.foreground },
                        { label: strings.t("panel.temp"), value: root.tempText(), tone: root.tempTone() },
                        { label: strings.t("panel.fan"), value: root.fanText(), tone: root.foreground, visible: root.fanRpm > 0 }
                      ]

                      Rectangle {
                        required property var modelData

                        visible: modelData.visible !== false
                        Layout.fillWidth: true
                        implicitHeight: chip.implicitHeight + Style.space(8)
                        radius: Style.cornerRadius
                        color: Util.alpha(root.foreground, 0.04)
                        border.width: 1
                        border.color: Util.alpha(root.foreground, 0.10)

                        ColumnLayout {
                          id: chip
                          anchors.fill: parent
                          anchors.margins: Style.space(4)
                          spacing: 0

                          Text {
                            textFormat: Text.PlainText
                            text: modelData.label
                            color: root.dimColor
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.caption
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                          }

                          Text {
                            textFormat: Text.PlainText
                            text: modelData.value
                            color: modelData.tone
                            font.family: root.fontFamily
                            font.pixelSize: Style.font.body
                            font.bold: true
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                          }
                        }
                      }
                    }
                  }
                }
              }
            }

            // 2 x 2 metric cards
            GridLayout {
              Layout.fillWidth: true
              columns: 2
              columnSpacing: Style.space(10)
              rowSpacing: Style.space(10)

              MetricCard {
                Layout.fillWidth: true
                label: strings.t("panel.memory")
                value: root.bytesText(root.memUsedBytes) + " / " + root.bytesText(root.memTotalBytes)
                detail: root.pctText(root.memPct)
                meta: root.swapTotalBytes > 0
                  ? strings.t("panel.swap") + " " + root.bytesText(root.swapUsedBytes) + " / " + root.bytesText(root.swapTotalBytes)
                  : strings.t("panel.noSwap")
                fraction: root.memPct / 100
                values: root.memHistory
                maxValue: 100
                tone: root.memTone()
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              MetricCard {
                Layout.fillWidth: true
                label: strings.t("panel.disk")
                value: root.diskPct >= 0
                  ? root.bytesText(root.diskUsedBytes) + " / " + root.bytesText(root.diskTotalBytes)
                  : "--"
                detail: root.pctText(root.diskPct)
                meta: strings.t("panel.free") + " " + root.bytesText(root.diskFreeBytes)
                fraction: root.diskPct / 100
                values: []
                tone: root.diskTone()
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              MetricCard {
                Layout.fillWidth: true
                label: strings.t("panel.download")
                value: root.rateText(root.netDownBps)
                detail: "↓"
                meta: strings.t("panel.total") + " " + root.bytesText(root.netDownTotal) + (root.netIface ? "  ·  " + root.netIface : "")
                values: root.netDownHistory
                maxValue: -1
                tone: root.accentMain
                foreground: root.foreground
                fontFamily: root.fontFamily
              }

              MetricCard {
                Layout.fillWidth: true
                label: strings.t("panel.upload")
                value: root.rateText(root.netUpBps)
                detail: "↑"
                meta: strings.t("panel.total") + " " + root.bytesText(root.netUpTotal) + (root.netIface ? "  ·  " + root.netIface : "")
                values: root.netUpHistory
                maxValue: -1
                tone: root.accentAlt
                foreground: root.foreground
                fontFamily: root.fontFamily
              }
            }

            // Swap, shown only when the machine has a swap device
            ColumnLayout {
              Layout.fillWidth: true
              visible: root.swapTotalBytes > 0
              spacing: Style.space(4)

              RowLayout {
                Layout.fillWidth: true

                Text {
                  textFormat: Text.PlainText
                  text: strings.t("panel.swap")
                  color: root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                Item { Layout.fillWidth: true }

                Text {
                  textFormat: Text.PlainText
                  text: root.bytesText(root.swapUsedBytes) + " / " + root.bytesText(root.swapTotalBytes) + "  " + root.pctText(root.swapPct)
                  color: root.foreground
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              LevelBar {
                Layout.fillWidth: true
                implicitHeight: Style.space(6)
                fraction: root.swapPct / 100
                tone: root.toneFor(root.swapPct, 50, 80, root.accentAlt)
              }
            }

            // Per-core strip
            ColumnLayout {
              Layout.fillWidth: true
              visible: root.corePcts.length > 0
              spacing: Style.space(6)

              RowLayout {
                Layout.fillWidth: true

                Text {
                  textFormat: Text.PlainText
                  text: strings.t("panel.cores")
                  color: root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                Item { Layout.fillWidth: true }

                Text {
                  textFormat: Text.PlainText
                  text: root.coreCount + " ×"
                  color: root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              GridLayout {
                Layout.fillWidth: true
                columns: 6
                columnSpacing: Style.space(8)
                rowSpacing: Style.space(5)

                Repeater {
                  model: root.corePcts

                  ColumnLayout {
                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: Style.space(2)

                    RowLayout {
                      Layout.fillWidth: true
                      spacing: Style.space(3)

                      Text {
                        textFormat: Text.PlainText
                        text: "C" + index
                        color: root.dimColor
                        font.family: root.fontFamily
                        font.pixelSize: Math.max(7, Style.font.caption - 2)
                        font.bold: true
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: I18n.formatNumber(Number(modelData) || 0, 0)
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Math.max(7, Style.font.caption - 2)
                        font.bold: true
                      }
                    }

                    LevelBar {
                      Layout.fillWidth: true
                      implicitHeight: Style.space(3)
                      fraction: (Number(modelData) || 0) / 100
                      tone: root.toneFor(Number(modelData) || 0, 60, 85, root.accentMain)
                    }
                  }
                }
              }
            }

            // Top processes
            ColumnLayout {
              Layout.fillWidth: true
              spacing: Style.space(4)

              RowLayout {
                Layout.fillWidth: true

                Text {
                  textFormat: Text.PlainText
                  text: strings.t("panel.processes")
                  color: root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  font.letterSpacing: 1
                }

                Item { Layout.fillWidth: true }

                Text {
                  textFormat: Text.PlainText
                  text: strings.t("panel.processesHint")
                  color: root.dimColor
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Rectangle {
                Layout.fillWidth: true
                implicitHeight: procTable.implicitHeight + Style.space(14)
                radius: Style.cornerRadius
                color: Util.alpha(root.foreground, 0.025)
                border.width: 1
                border.color: Util.alpha(root.foreground, 0.10)

                ColumnLayout {
                  id: procTable
                  anchors.fill: parent
                  anchors.margins: Style.space(7)
                  spacing: Style.space(2)

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.space(6)

                    Text {
                      textFormat: Text.PlainText
                      text: strings.t("panel.pid")
                      color: root.dimColor
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      Layout.preferredWidth: Style.space(42)
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: strings.t("panel.name")
                      color: root.dimColor
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      Layout.fillWidth: true
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: strings.t("panel.cpuShort")
                      color: root.dimColor
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      horizontalAlignment: Text.AlignRight
                      Layout.preferredWidth: Style.space(44)
                    }

                    Text {
                      textFormat: Text.PlainText
                      text: strings.t("panel.memShort")
                      color: root.dimColor
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      horizontalAlignment: Text.AlignRight
                      Layout.preferredWidth: Style.space(44)
                    }
                  }

                  Repeater {
                    model: root.procs

                    RowLayout {
                      required property var modelData

                      Layout.fillWidth: true
                      spacing: Style.space(6)

                      Text {
                        textFormat: Text.PlainText
                        text: modelData.pid
                        color: root.dimColor
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                        Layout.preferredWidth: Style.space(42)
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: modelData.name
                        color: root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: I18n.formatNumber(modelData.cpu, 1) + "%"
                        color: modelData.cpu >= 50 ? root.urgentColor : root.foreground
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        font.bold: modelData.cpu >= 25
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: Style.space(44)
                      }

                      Text {
                        textFormat: Text.PlainText
                        text: I18n.formatNumber(modelData.mem, 1) + "%"
                        color: root.dimColor
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.bodySmall
                        horizontalAlignment: Text.AlignRight
                        Layout.preferredWidth: Style.space(44)
                      }
                    }
                  }

                  Text {
                    textFormat: Text.PlainText
                    visible: root.procs.length === 0
                    text: strings.t("panel.noProcesses")
                    color: root.dimColor
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.bodySmall
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                  }
                }
              }
            }

            // Footer actions
            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(6)

              Button {
                text: strings.t("panel.refresh")
                iconText: "󰑓"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.refresh()
              }

              Button {
                text: strings.t("panel.btop")
                iconText: "󰆍"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.launchBtop()
              }

              Item { Layout.fillWidth: true }

              Text {
                textFormat: Text.PlainText
                text: strings.t("panel.hint")
                color: root.dimColor
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
                Layout.maximumWidth: Style.space(150)
              }
            }
          }

          // ---- settings view ---------------------------------------------
          ColumnLayout {
            Layout.fillWidth: true
            visible: root.showSettings
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              Layout.fillWidth: true
              text: strings.t("settings.intro")
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
              wrapMode: Text.WordWrap
            }

            Repeater {
              model: root.toggleRows

              Toggle {
                required property var modelData
                required property int index

                Layout.fillWidth: true
                label: modelData.label
                description: modelData.description
                checked: root.settingFlag(modelData.key)
                hasCursor: root.settingCursor === index
                foreground: root.foreground
                accent: root.accentMain
                fontFamily: root.fontFamily
                onClicked: root.toggleSetting(modelData.key)
                onHovered: function(isHovered) {
                  if (isHovered) root.settingCursor = index
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              Layout.fillWidth: true
              Layout.topMargin: Style.space(4)
              text: strings.t("settings.interval")
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Style.space(6)

              Repeater {
                model: [
                  { value: 500, label: strings.t("settings.intervalFast") },
                  { value: 1000, label: strings.t("settings.intervalNormal") },
                  { value: 2000, label: strings.t("settings.intervalSlow") }
                ]

                Button {
                  required property var modelData

                  Layout.fillWidth: true
                  text: modelData.label
                  bordered: true
                  selected: root.intervalMs === modelData.value
                  foreground: root.foreground
                  accent: root.accentMain
                  fontFamily: root.fontFamily
                  onClicked: root.setSetting("intervalMs", modelData.value)
                }
              }
            }

            Text {
              textFormat: Text.PlainText
              Layout.fillWidth: true
              Layout.topMargin: Style.space(2)
              text: strings.t("settings.intervalHint")
              color: root.dimColor
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              wrapMode: Text.WordWrap
            }

            RowLayout {
              Layout.fillWidth: true
              Layout.topMargin: Style.space(8)
              spacing: Style.space(6)

              Button {
                text: strings.t("settings.reset")
                iconText: "󰜺"
                bordered: true
                foreground: root.urgentColor
                accent: root.urgentColor
                fontFamily: root.fontFamily
                onClicked: root.resetSettings()
              }

              Item { Layout.fillWidth: true }

              Button {
                text: strings.t("panel.back")
                iconText: "󰁍"
                bordered: true
                foreground: root.foreground
                fontFamily: root.fontFamily
                onClicked: root.showSettings = false
              }
            }
          }
        }
      }
    }
  }
}
