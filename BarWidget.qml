import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Commons as Commons
import qs.Ui
import "Model.js" as Model

// Sys Analytics - bar entry point.
//
// The bar shows a single compact HUD row (CPU / RAM / temp / network / disk,
// plus uptime when enabled). Clicking it opens Panel.qml, which reads the same
// live properties from this widget, so there is one sampler and one source of
// truth.
BarWidget {
  id: root
  moduleName: "aditya27003.sys-analytics"

  // ---- settings -----------------------------------------------------------
  readonly property bool showCpu: root.boolSetting("showCpu", true)
  readonly property bool showMem: root.boolSetting("showMem", true)
  readonly property bool showTemp: root.boolSetting("showTemp", true)
  readonly property bool showNet: root.boolSetting("showNet", true)
  readonly property bool showDisk: root.boolSetting("showDisk", true)
  readonly property bool showUptime: root.boolSetting("showUptime", false)
  readonly property bool neon: root.boolSetting("neon", true)
  readonly property int intervalMs: Math.max(500, Math.min(5000, Math.round(Number(root.setting("intervalMs", 1000)) || 1000)))

  readonly property int historyLimit: 40

  // ---- live metrics -------------------------------------------------------
  property bool ready: false

  property int cpuPct: -1
  property real cpuFreqGhz: 0
  property var corePcts: []
  property int coreCount: 0

  property int memPct: -1
  property real memUsedBytes: 0
  property real memTotalBytes: 0
  property int swapPct: 0
  property real swapUsedBytes: 0
  property real swapTotalBytes: 0

  property real tempC: NaN
  property real fanRpm: -1

  property real loadAvg: 0
  property real uptimeSeconds: 0

  property real netDownBps: 0
  property real netUpBps: 0
  property real netDownTotal: 0
  property real netUpTotal: 0
  property real netPeak: 1
  property string netIface: ""

  property int diskPct: -1
  property real diskUsedBytes: 0
  property real diskTotalBytes: 0
  property real diskFreeBytes: 0

  property var topProcs: []

  // ---- history ------------------------------------------------------------
  property var cpuHistory: []
  property var memHistory: []
  property var netDownHistory: []
  property var netUpHistory: []
  property var tempHistory: []

  // ---- previous samples ---------------------------------------------------
  property var prevCpu: null
  property var prevCores: []
  property var prevNet: null
  property real prevNetTime: 0

  // ---- theme --------------------------------------------------------------
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property color urgentColor: bar ? bar.urgent : Color.urgent
  readonly property color accentMain: neon ? "#22d3ee" : Color.accent
  readonly property color accentAlt: neon ? "#c084fc" : Color.accent
  readonly property color warnColor: neon ? "#fbbf24" : Util.alpha(foreground, 0.8)
  readonly property color dimColor: Util.alpha(foreground, 0.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property int hudFontSize: Math.max(8, Math.min(10, Math.round(root.barSize / 2.7)))
  readonly property int verticalFontSize: Math.max(7, Math.min(9, Math.round(root.barSize / 3.5)))

  Commons.Translations {
    id: strings
    directory: Qt.resolvedUrl("i18n")
  }

  // ---- formatting ---------------------------------------------------------
  function fmtBytes(bytes) {
    var p = Model.bytesParts(bytes)
    return I18n.formatNumber(p.value, p.decimals) + " " + p.unit
  }

  function fmtRate(bytesPerSecond) {
    var p = Model.rateParts(bytesPerSecond)
    return I18n.formatNumber(p.value, p.decimals) + " " + p.unit
  }

  function compactRate(bytesPerSecond) {
    var p = Model.compactRateParts(bytesPerSecond)
    return I18n.formatNumber(p.value, p.decimals) + p.unit
  }

  function shortRate(bytesPerSecond) {
    var p = Model.shortRateParts(bytesPerSecond)
    return I18n.formatNumber(Math.round(p.value), 0) + p.unit
  }

  function tempText() {
    return isNaN(root.tempC) ? strings.t("common.na") : I18n.formatNumber(Math.round(root.tempC), 0) + "°C"
  }

  function tempShort() {
    return isNaN(root.tempC) ? "--" : I18n.formatNumber(Math.round(root.tempC), 0) + "°"
  }

  function freqText() {
    return root.cpuFreqGhz > 0 ? I18n.formatNumber(root.cpuFreqGhz, 1) + " GHz" : "--"
  }

  function loadText() {
    return I18n.formatNumber(root.loadAvg, 2)
  }

  function memText() {
    return root.fmtBytes(root.memUsedBytes) + " / " + root.fmtBytes(root.memTotalBytes) + " (" + root.memPct + "%)"
  }

  function diskText() {
    return root.fmtBytes(root.diskUsedBytes) + " / " + root.fmtBytes(root.diskTotalBytes) + " (" + root.diskPct + "%)"
  }

  function netText() {
    return "↓ " + root.fmtRate(root.netDownBps) + "  ↑ " + root.fmtRate(root.netUpBps)
  }

  function uptimeText() {
    return Model.formatUptime(root.uptimeSeconds)
  }

  function boolSetting(name, fallback) {
    var value = root.setting(name, fallback)
    if (typeof value === "boolean") return value
    if (typeof value === "string") return value.toLowerCase() === "true" || value === "1"
    return !!value
  }

  function persistSetting(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
  }

  function setSetting(key, value) {
    root.persistSetting(key, value)
  }

  function resetSettings() {
    var entry = { id: root.moduleName }
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function")
      root.bar.shell.updateEntryInline(root.moduleName, entry)
    root.refresh()
  }

  // ---- tooltip ------------------------------------------------------------
  function tooltipText() {
    var lines = [strings.t("tooltip.title")]

    if (root.showCpu)
      lines.push(strings.t("tooltip.cpu") + "  " + (root.cpuPct >= 0 ? root.cpuPct + "%" : "--") + (root.cpuFreqGhz > 0 ? "  ·  " + root.freqText() : ""))
    if (root.showMem)
      lines.push(strings.t("tooltip.ram") + "  " + root.memText())
    if (root.showTemp)
      lines.push(strings.t("tooltip.temp") + "  " + root.tempText() + (isNaN(root.tempC) ? "" : "  ·  " + strings.t("panel.load") + " " + root.loadText()))
    if (root.showNet)
      lines.push(strings.t("tooltip.net") + "  " + root.netText() + (root.netIface ? "  ·  " + root.netIface : ""))
    if (root.showDisk)
      lines.push(strings.t("tooltip.disk") + "  " + root.diskText() + "  ·  " + root.fmtBytes(root.diskFreeBytes) + " " + strings.t("common.free"))
    if (root.showUptime)
      lines.push(strings.t("tooltip.uptime") + "  " + root.uptimeText())

    lines.push(strings.t("tooltip.hint"))
    return lines.join("\n")
  }

  // ---- bar cell models ----------------------------------------------------
  function toneFor(value, warnAt, urgentAt, normal) {
    if (value >= urgentAt) return root.urgentColor
    if (value >= warnAt) return root.warnColor
    return normal
  }

  function valueColor(value, urgentAt) {
    return value >= urgentAt ? root.urgentColor : root.foreground
  }

  readonly property var hudModel: root.hudCells()
  readonly property var verticalModel: root.verticalCells()

  // Every visible metric lives in one row. Widths come from TextMetrics so a
  // value changing from "9%" to "100%" never makes the bar jitter.
  function hudCells() {
    var cells = []

    if (root.showCpu) cells.push({
      key: "cpu",
      glyph: "",
      text: root.cpuPct >= 0 ? root.cpuPct + "%" : "--",
      width: pctMetrics.width,
      tone: root.toneFor(root.cpuPct, 60, 85, root.accentMain),
      textColor: root.valueColor(root.cpuPct, 85)
    })

    if (root.showMem) cells.push({
      key: "mem",
      glyph: "",
      text: root.memPct >= 0 ? root.memPct + "%" : "--",
      width: pctMetrics.width,
      tone: root.toneFor(root.memPct, 70, 90, root.accentAlt),
      textColor: root.valueColor(root.memPct, 90)
    })

    if (root.showTemp) cells.push({
      key: "temp",
      glyph: "",
      text: root.tempShort(),
      width: tempMetrics.width,
      tone: root.toneFor(root.tempC, 70, 85, root.accentMain),
      textColor: root.tempC >= 85 ? root.urgentColor : root.foreground
    })

    if (root.showNet) cells.push({
      key: "net",
      glyph: "⇣",
      text: root.compactRate(root.netDownBps),
      width: netMetrics.width,
      tone: root.accentAlt,
      textColor: root.foreground
    })

    if (root.showDisk) cells.push({
      key: "disk",
      glyph: "",
      text: root.diskPct >= 0 ? root.diskPct + "%" : "--",
      width: pctMetrics.width,
      tone: root.toneFor(root.diskPct, 75, 90, root.accentMain),
      textColor: root.valueColor(root.diskPct, 90)
    })

    if (root.showUptime) cells.push({
      key: "uptime",
      glyph: "",
      text: Model.formatUptimeCompact(root.uptimeSeconds),
      width: uptimeMetrics.width,
      tone: root.dimColor,
      textColor: root.foreground
    })

    return cells
  }

  function verticalCells() {
    var cells = []

    if (root.showCpu) cells.push({
      glyph: "",
      text: root.cpuPct >= 0 ? root.cpuPct + "%" : "--",
      tone: root.toneFor(root.cpuPct, 60, 85, root.accentMain),
      textColor: root.valueColor(root.cpuPct, 85)
    })
    if (root.showMem) cells.push({
      glyph: "",
      text: root.memPct >= 0 ? root.memPct + "%" : "--",
      tone: root.toneFor(root.memPct, 70, 90, root.accentAlt),
      textColor: root.valueColor(root.memPct, 90)
    })
    if (root.showTemp) cells.push({
      glyph: "",
      text: root.tempShort(),
      tone: root.toneFor(root.tempC, 70, 85, root.accentMain),
      textColor: root.tempC >= 85 ? root.urgentColor : root.foreground
    })
    if (root.showNet) cells.push({
      glyph: "⇣",
      text: root.shortRate(root.netDownBps),
      tone: root.accentAlt,
      textColor: root.foreground
    })
    if (root.showDisk) cells.push({
      glyph: "",
      text: root.diskPct >= 0 ? root.diskPct + "%" : "--",
      tone: root.toneFor(root.diskPct, 75, 90, root.accentMain),
      textColor: root.valueColor(root.diskPct, 90)
    })
    if (root.showUptime) cells.push({
      glyph: "",
      text: Model.formatUptimeShort(root.uptimeSeconds),
      tone: root.dimColor,
      textColor: root.foreground
    })

    return cells
  }

  TextMetrics {
    id: pctMetrics
    font.family: root.fontFamily
    font.pixelSize: root.hudFontSize
    font.bold: true
    text: "100%"
  }

  TextMetrics {
    id: tempMetrics
    font.family: root.fontFamily
    font.pixelSize: root.hudFontSize
    font.bold: true
    text: "999°"
  }

  TextMetrics {
    id: netMetrics
    font.family: root.fontFamily
    font.pixelSize: root.hudFontSize
    font.bold: true
    text: "1000K/s"
  }

  TextMetrics {
    id: uptimeMetrics
    font.family: root.fontFamily
    font.pixelSize: root.hudFontSize
    font.bold: true
    text: "999d23h"
  }

  // ---- sampling -----------------------------------------------------------
  readonly property string samplerPath: decodeURIComponent(String(Qt.resolvedUrl("scripts/sample.sh")).replace(/^file:\/\//, ""))

  function refresh() {
    if (!sampleProc.running) sampleProc.running = true
  }

  function applySample(text) {
    var now = Date.now()
    var sections = Model.parseSections(text)

    // CPU
    var cpu = Model.parseCpu(sections.CPU || "")
    if (cpu.total) {
      var pct = Model.cpuPercent(root.prevCpu, cpu.total)
      if (pct !== null) {
        root.cpuPct = pct
        root.cpuHistory = Model.appendHistory(root.cpuHistory, pct, root.historyLimit)
      }

      if (root.prevCores.length === cpu.cores.length && cpu.cores.length > 0) {
        var cores = []
        for (var i = 0; i < cpu.cores.length; i++) {
          var corePct = Model.cpuPercent(root.prevCores[i], cpu.cores[i])
          cores.push(corePct === null ? 0 : corePct)
        }
        root.corePcts = cores
      }

      root.prevCpu = cpu.total
      root.prevCores = cpu.cores
      root.coreCount = cpu.cores.length
    }

    // Memory and swap
    var mem = Model.parseMem(sections.MEM || "")
    if (mem.totalBytes > 0) {
      root.memTotalBytes = mem.totalBytes
      root.memUsedBytes = mem.usedBytes
      root.memPct = Math.round(100 * mem.usedBytes / mem.totalBytes)
      root.memHistory = Model.appendHistory(root.memHistory, root.memPct, root.historyLimit)

      root.swapTotalBytes = mem.swapTotalBytes
      root.swapUsedBytes = mem.swapUsedBytes
      root.swapPct = mem.swapTotalBytes > 0 ? Math.round(100 * mem.swapUsedBytes / mem.swapTotalBytes) : 0
    }

    // Network. The sampler records the moment it read /proc/net/dev, so the
    // rate uses the real interval between counter reads rather than process
    // spawn/parse latency. A sub-200 ms gap (for example an immediate refresh
    // right after changing the interval) is ignored so it cannot invent a
    // spike; the next sample then spans the full window.
    var net = Model.parseNet(sections.NET || "", sections.NETIF || "")
    var netTime = Model.parseSeconds(sections.NET_TIME || "")
    if (netTime === null) netTime = now / 1000

    if (root.prevNet && root.prevNetTime > 0) {
      if (root.prevNet.iface !== net.iface) {
        root.netDownBps = 0
        root.netUpBps = 0
        root.prevNet = net
        root.prevNetTime = netTime
      } else {
        var dt = netTime - root.prevNetTime
        if (dt >= 0.2) {
          var rate = Model.netRate(root.prevNet, net, dt)
          if (rate) {
            root.netDownBps = rate.rxBps
            root.netUpBps = rate.txBps
            root.netPeak = Math.max(1, rate.rxBps, rate.txBps, root.netPeak * 0.995)
            root.netDownHistory = Model.appendHistory(root.netDownHistory, rate.rxBps, root.historyLimit)
            root.netUpHistory = Model.appendHistory(root.netUpHistory, rate.txBps, root.historyLimit)
          } else {
            root.netDownBps = 0
            root.netUpBps = 0
          }
          root.prevNet = net
          root.prevNetTime = netTime
        }
      }
    } else {
      root.prevNet = net
      root.prevNetTime = netTime
    }

    root.netIface = net.iface === "sum" ? "" : net.iface
    root.netDownTotal = net.rxBytes
    root.netUpTotal = net.txBytes

    // Disk
    var disk = Model.parseDisk(sections.DISK || "")
    if (disk) {
      root.diskTotalBytes = disk.totalBytes
      root.diskUsedBytes = disk.usedBytes
      root.diskFreeBytes = disk.freeBytes
      root.diskPct = disk.usedPct
    }

    // Temperature and fan
    var temps = Model.parseTemps(sections.HWMON || "", sections.THERMAL || "")
    root.tempC = temps.tempC === null ? NaN : temps.tempC
    root.fanRpm = temps.fanRpm
    if (!isNaN(root.tempC))
      root.tempHistory = Model.appendHistory(root.tempHistory, root.tempC, root.historyLimit)

    // Frequency
    var freqKhz = parseFloat(String(sections.FREQ || "").replace(/^\s+|\s+$/g, ""))
    if (isFinite(freqKhz) && freqKhz > 0) root.cpuFreqGhz = freqKhz / 1000000

    // Uptime and load
    var up = parseFloat(String(sections.UPTIME || "").replace(/^\s+|\s+$/g, ""))
    if (isFinite(up)) root.uptimeSeconds = up

    var load = parseFloat(String(sections.LOAD || "").replace(/^\s+|\s+$/g, ""))
    if (isFinite(load)) root.loadAvg = load

    // Processes
    root.topProcs = Model.parseProcs(sections.PROC || "")
    root.ready = true
  }

  Process {
    id: sampleProc
    command: ["bash", root.samplerPath]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applySample(text)
    }

    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").replace(/^\s+|\s+$/g, "")
        if (message.length > 0) console.warn("sys-analytics sampler: " + message)
      }
    }
  }

  Timer {
    id: pollTimer
    interval: root.intervalMs
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  onIntervalMsChanged: root.refresh()

  // ---- bar button ---------------------------------------------------------
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    labelVisible: false
    hasVisualContent: true
    verticalPadding: 0
    fixedWidth: root.vertical
      ? Math.max(root.barSize, verticalHud.implicitWidth + Style.space(4))
      : Math.max(12, hud.implicitWidth + Style.space(8))
    fixedHeight: root.vertical
      ? Math.max(root.barSize, verticalHud.implicitHeight + Style.space(4))
      : Math.max(12, root.barSize - Style.space(2))
    tooltipText: root.tooltipText()
    pressFeedbackButtons: Qt.LeftButton | Qt.MiddleButton

    onPressed: function(button) {
      if (button === Qt.RightButton) {
        if (root.bar) root.bar.run("omarchy launch or focus tui btop")
      } else if (button === Qt.MiddleButton) {
        root.refresh()
      } else {
        root.togglePanel()
      }
    }

    // Capsule frame. Subtle on idle, accent-tinted on hover and while open.
    Rectangle {
      anchors.fill: parent
      radius: Style.cornerRadius > 0 ? height / 2 : 0
      color: Util.alpha(root.foreground, button.tooltipHovered ? 0.10 : (root.opened ? 0.08 : 0.035))
      border.width: 1
      border.color: Util.alpha(
        root.opened || button.tooltipHovered ? root.accentMain : root.foreground,
        button.tooltipHovered ? 0.45 : (root.opened ? 0.50 : 0.14)
      )

      Behavior on color {
        ColorAnimation { duration: Style.duration(160) }
      }
      Behavior on border.color {
        ColorAnimation { duration: Style.duration(160) }
      }
    }

    // Horizontal single-row HUD.
    Item {
      id: hud
      anchors.centerIn: parent
      visible: !root.vertical
      implicitWidth: hudRow.implicitWidth
      implicitHeight: hudRow.implicitHeight

      RowLayout {
        id: hudRow
        anchors.centerIn: parent
        spacing: 0

        Repeater {
          model: root.hudModel

          delegate: HudCell {
            fontFamily: root.fontFamily
            fontSize: root.hudFontSize
            separatorColor: Util.alpha(root.foreground, 0.16)
          }
        }
      }
    }

    // Vertical bar layout: one compact row per metric.
    Column {
      id: verticalHud
      anchors.centerIn: parent
      visible: root.vertical
      spacing: Style.space(1)

      Repeater {
        model: root.verticalModel

        Row {
          required property var modelData
          spacing: Style.space(2)

          Text {
            textFormat: Text.PlainText
            text: parent.modelData.glyph
            color: parent.modelData.tone
            font.family: root.fontFamily
            font.pixelSize: root.verticalFontSize
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            textFormat: Text.PlainText
            text: parent.modelData.text
            color: parent.modelData.textColor
            font.family: root.fontFamily
            font.pixelSize: root.verticalFontSize
            font.bold: true
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }

  // Cell used by the horizontal HUD. Inline so every metric shares exactly one
  // separator/value recipe and the row stays visually even.
  component HudCell: RowLayout {
    id: cell

    required property var modelData
    required property int index

    property string fontFamily: Style.font.family
    property real fontSize: Style.font.caption
    property color separatorColor: Color.foreground

    spacing: Style.space(2)
    Layout.alignment: Qt.AlignVCenter

    Rectangle {
      visible: cell.index > 0
      Layout.preferredWidth: 1
      Layout.preferredHeight: Math.round(cell.fontSize * 1.15)
      Layout.alignment: Qt.AlignVCenter
      color: cell.separatorColor
    }

    Text {
      textFormat: Text.PlainText
      text: cell.modelData.glyph
      color: cell.modelData.tone
      font.family: cell.fontFamily
      font.pixelSize: cell.fontSize
      Layout.alignment: Qt.AlignVCenter
    }

    Text {
      textFormat: Text.PlainText
      text: cell.modelData.text
      color: cell.modelData.textColor
      font.family: cell.fontFamily
      font.pixelSize: cell.fontSize
      font.bold: true
      horizontalAlignment: Text.AlignLeft
      Layout.preferredWidth: cell.modelData.width
      Layout.alignment: Qt.AlignVCenter
    }
  }

  // ---- panel lifecycle ----------------------------------------------------
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  readonly property real openPanelIndicatorWidth: button.width
  readonly property real openPanelIndicatorHeight: Math.max(Style.space(10), Math.round(Style.bar.iconSlot * 0.55))

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    root.togglePanel()
  }

  function togglePanel() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  onBarChanged: root.injectPanel()
  onSettingsChanged: root.injectPanel()

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }

    
  }

  
}

