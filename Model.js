// Pure parsing and formatting helpers for Sys Analytics.
//
// Everything here takes raw text from /proc, /sys, df, or ps and returns
// plain objects. Keeping it out of the QML makes the sampling logic easy to
// read and test on its own.

// One combined sample is split on "===NAME===" markers, so a single bash
// spawn can gather every metric in one read. Names may contain underscores
// (NETIF, NET_TIME).
function parseSections(text) {
  var parts = String(text || "").split(/===([A-Z0-9_]+)===\r?\n?/)
  var sections = {}
  for (var i = 1; i < parts.length; i += 2) sections[parts[i]] = parts[i + 1] || ""
  return sections
}

// The aggregate "cpu ..." line and every per-core "cpu0 ..." line. Per-core
// lines have no space before the digit, which is what keeps them separate.
function parseCpu(text) {
  var lines = String(text || "").split("\n")
  var total = null
  var cores = []

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].replace(/^\s+|\s+$/g, "")
    var match = /^cpu(\d*)\s+(.+)$/.exec(line)
    if (!match) continue

    var values = match[2].split(/\s+/).map(Number)
    var idle = (values[3] || 0) + (values[4] || 0)
    var sum = 0
    for (var j = 0; j < Math.min(values.length, 8); j++) sum += values[j] || 0

    var sample = { total: sum, idle: idle }
    if (match[1] === "") total = sample
    else cores.push(sample)
  }

  return { total: total, cores: cores }
}

// Percentage busy between two /proc/stat samples. Null until there is a
// second sample, since one reading has no delta to measure from.
function cpuPercent(prev, curr) {
  if (!prev || !curr) return null
  var totalDelta = curr.total - prev.total
  var idleDelta = curr.idle - prev.idle
  if (totalDelta <= 0 || idleDelta < 0) return null
  return Math.max(0, Math.min(100, Math.round(100 * (1 - idleDelta / totalDelta))))
}

function parseMem(text) {
  var lines = String(text || "").split("\n")
  var values = {}

  for (var i = 0; i < lines.length; i++) {
    var match = /^([^:]+):\s+(\d+)/.exec(lines[i])
    if (match) values[match[1]] = parseInt(match[2], 10)
  }

  var totalBytes = (values.MemTotal || 0) * 1024
  var availBytes = (values.MemAvailable || values.MemFree || 0) * 1024
  var swapTotalBytes = (values.SwapTotal || 0) * 1024
  var swapFreeBytes = (values.SwapFree || 0) * 1024

  return {
    totalBytes: totalBytes,
    availBytes: availBytes,
    usedBytes: Math.max(0, totalBytes - availBytes),
    swapTotalBytes: swapTotalBytes,
    swapFreeBytes: swapFreeBytes,
    swapUsedBytes: Math.max(0, swapTotalBytes - swapFreeBytes)
  }
}

// Sum rx/tx bytes for one interface. Each /proc/net/dev row is
// "iface: rxBytes rxPackets ... (8 receive columns) txBytes ...", so the tx
// byte count is the first field after the receive block.
//
// Summing every interface double counts: bridges count both the bridge and its
// slaves, and virtual devices (docker, veth, VPNs) repeat traffic that already
// passed through a physical NIC. Prefer the default-route interface, which is
// the one carrying the traffic users actually care about. With no default
// route, sum physical interfaces; only fall back to everything when the host
// has no physical interface at all.
var VIRTUAL_IFACE = /^(lo$|docker|veth|br-|virbr|vmnet|vboxnet|tun|tap|utun|wg|tailscale|zt|lxc|cni|flannel|kube|vnet|dummy)/

function parseNet(text, preferredIface) {
  var raw = String(text || "")
  var re = /^\s*([^:\s]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/gm
  var interfaces = []
  var byName = {}
  var match

  while ((match = re.exec(raw)) !== null) {
    var entry = {
      name: match[1],
      rxBytes: parseInt(match[2], 10),
      txBytes: parseInt(match[3], 10)
    }
    interfaces.push(entry)
    byName[entry.name] = entry
  }

  var wanted = String(preferredIface || "").replace(/\s+/g, "")
  if (wanted !== "" && byName[wanted]) return netTotals(byName[wanted])

  var physical = interfaces.filter(function(iface) {
    return iface.name !== "lo" && !VIRTUAL_IFACE.test(iface.name)
  })
  if (physical.length === 0) {
    physical = interfaces.filter(function(iface) { return iface.name !== "lo" })
  }

  if (physical.length === 1) return netTotals(physical[0])

  var rxBytes = 0
  var txBytes = 0
  for (var i = 0; i < physical.length; i++) {
    rxBytes += physical[i].rxBytes
    txBytes += physical[i].txBytes
  }

  return { iface: "sum", rxBytes: rxBytes, txBytes: txBytes }
}

function netTotals(iface) {
  return { iface: iface.name, rxBytes: iface.rxBytes, txBytes: iface.txBytes }
}

// Bytes/sec between two /proc/net/dev samples. Null on the first sample, a
// non-positive interval, a changed interface, or a counter that went backwards
// (interface reset). Tracking one interface at a time also means a switch from
// Wi-Fi to Ethernet resets the baseline instead of producing a bogus spike.
function netRate(prev, curr, dtSeconds) {
  if (!prev || !curr || !(dtSeconds > 0)) return null
  if (prev.iface !== curr.iface) return null
  var rxDelta = curr.rxBytes - prev.rxBytes
  var txDelta = curr.txBytes - prev.txBytes
  if (rxDelta < 0 || txDelta < 0) return null
  return { rxBps: rxDelta / dtSeconds, txBps: txDelta / dtSeconds }
}

// Sampler timestamps are seconds since the epoch (EPOCHREALTIME), so rates use
// the moment the counters were read rather than the moment the shell finished
// parsing the output. Returns null when the section is missing or malformed.
function parseSeconds(text) {
  var value = parseFloat(String(text || "").replace(/\s+/g, "").replace(",", "."))
  return isFinite(value) && value > 0 ? value : null
}

// Last row of `df -B1 --output=size,used,avail,pcent /`.
function parseDisk(text) {
  var lines = String(text || "").replace(/^\s+|\s+$/g, "").split("\n")
  if (lines.length === 0 || lines[0] === "") return null

  var cols = lines[lines.length - 1].replace(/^\s+|\s+$/g, "").split(/\s+/)
  if (cols.length < 4) return null

  var totalBytes = parseInt(cols[0], 10)
  var usedBytes = parseInt(cols[1], 10)
  var freeBytes = parseInt(cols[2], 10)
  var usedPct = parseInt(cols[3], 10)

  if (!isFinite(totalBytes) || !isFinite(usedPct)) return null

  return {
    totalBytes: totalBytes,
    usedBytes: usedBytes,
    freeBytes: freeBytes,
    usedPct: Math.max(0, Math.min(100, usedPct))
  }
}

// hwmon lines are "name|temp1_input|fan1_input"; thermal lines are
// "type|temp". Prefer the CPU package driver over the generic ACPI zone.
function parseTemps(hwmonText, thermalText) {
  var preferred = ["coretemp", "k10temp", "zenpower"]
  var tempC = null
  var fanRpm = -1

  var lines = String(hwmonText || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var cols = lines[i].split("|")
    if (cols.length < 2) continue

    var name = String(cols[0] || "").replace(/^\s+|\s+$/g, "")
    var temp = parseFloat(cols[1])
    var fan = parseFloat(cols[2])

    if (isFinite(fan) && fan > fanRpm) fanRpm = fan

    if (tempC === null && preferred.indexOf(name) !== -1 && isFinite(temp) && temp > 0) {
      tempC = temp / 1000
    }
  }

  if (tempC === null) {
    var thermal = String(thermalText || "").split("\n")
    var fallback = null

    for (var t = 0; t < thermal.length; t++) {
      var zone = thermal[t].split("|")
      if (zone.length < 2) continue

      var type = String(zone[0] || "").replace(/^\s+|\s+$/g, "")
      var ztemp = parseFloat(zone[1])
      if (!isFinite(ztemp) || ztemp <= 0) continue

      if (type === "x86_pkg_temp" || type === "cpu-thermal") {
        tempC = ztemp / 1000
        break
      }
      if (fallback === null && type !== "")
        fallback = ztemp / 1000
    }

    if (tempC === null) tempC = fallback
  }

  return { tempC: tempC, fanRpm: fanRpm }
}

// One ps row is "pid|name|cpu|mem". The name may contain spaces, so only the
// first and last two fields are fixed. Process names are untrusted text:
// strip control characters and markup delimiters before display.
function parseProcs(text) {
  var lines = String(text || "").split("\n")
  var procs = []

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (line === "") continue

    var parts = line.split("|")
    if (parts.length < 4) continue

    var pid = parseInt(parts[0], 10)
    var name = sanitizeName(parts.slice(1, parts.length - 2).join("|"))
    var cpu = parseFloat(parts[parts.length - 2])
    var mem = parseFloat(parts[parts.length - 1])

    if (!isFinite(pid) || name === "") continue

    procs.push({
      pid: pid,
      name: name,
      cpu: isFinite(cpu) ? Math.max(0, cpu) : 0,
      mem: isFinite(mem) ? Math.max(0, mem) : 0
    })
  }

  return procs
}

function sanitizeName(value) {
  var name = String(value || "")
    .replace(/[\u0000-\u001f\u007f]/g, "")
    .replace(/[<>]/g, "")
    .replace(/\s+/g, " ")
    .replace(/^\s+|\s+$/g, "")
  if (name.length > 28) name = name.slice(0, 27) + "…"
  return name
}

// Histories are plain arrays copied on append, so QML bindings notice the
// new value instead of mutating in place.
function appendHistory(values, value, limit) {
  var out = Array.isArray(values) ? values.slice() : []
  var number = Number(value)
  if (!isFinite(number)) return out

  out.push(number)
  var cap = Math.max(1, Number(limit) || 40)
  if (out.length > cap) out = out.slice(out.length - cap)
  return out
}

function uptimeParts(seconds) {
  var total = Math.max(0, Math.floor(Number(seconds) || 0))
  return {
    days: Math.floor(total / 86400),
    hours: Math.floor((total % 86400) / 3600),
    minutes: Math.floor((total % 3600) / 60)
  }
}

function pad2(value) {
  return value < 10 ? "0" + value : String(value)
}

function formatUptime(seconds) {
  var p = uptimeParts(seconds)
  if (p.days > 0) return p.days + "d " + pad2(p.hours) + "h " + pad2(p.minutes) + "m"
  if (p.hours > 0) return p.hours + "h " + pad2(p.minutes) + "m"
  return p.minutes + "m"
}

function formatUptimeCompact(seconds) {
  var p = uptimeParts(seconds)
  if (p.days > 0) return p.days + "d" + pad2(p.hours) + "h"
  if (p.hours > 0) return p.hours + "h" + pad2(p.minutes) + "m"
  return p.minutes + "m"
}

function formatUptimeShort(seconds) {
  var p = uptimeParts(seconds)
  if (p.days > 0) return p.days + "d"
  if (p.hours > 0) return p.hours + "h"
  return p.minutes + "m"
}

// Split a byte count into a localizable number and its unit. QML calls
// I18n.formatNumber on the value so decimal separators follow the language.
function scaleParts(value, units) {
  var v = Math.max(0, Number(value) || 0)
  var i = 0

  while (v >= 1024 && i < units.length - 1) {
    v /= 1024
    i++
  }

  var decimals = i === 0 ? 0 : (v < 10 ? 1 : 0)
  return { value: v, unit: units[i], decimals: decimals }
}

function bytesParts(bytes) {
  return scaleParts(bytes, ["B", "KB", "MB", "GB", "TB"])
}

function rateParts(bytesPerSecond) {
  return scaleParts(bytesPerSecond, ["B/s", "KB/s", "MB/s", "GB/s", "TB/s"])
}

function compactRateParts(bytesPerSecond) {
  return scaleParts(bytesPerSecond, ["B/s", "K/s", "M/s", "G/s", "T/s"])
}

function shortRateParts(bytesPerSecond) {
  return scaleParts(bytesPerSecond, ["B", "K", "M", "G", "T"])
}

// Plain-string fallbacks for tooltips and tests; the QML formats the parts
// through I18n so it can localize the decimal separator.
function formatBytes(bytes) {
  var p = bytesParts(bytes)
  return p.value.toFixed(p.decimals) + " " + p.unit
}

function formatRate(bytesPerSecond) {
  var p = rateParts(bytesPerSecond)
  return p.value.toFixed(p.decimals) + " " + p.unit
}

if (typeof module !== "undefined") {
  module.exports = {
    parseSections: parseSections,
    parseCpu: parseCpu,
    cpuPercent: cpuPercent,
    parseMem: parseMem,
    parseNet: parseNet,
    netRate: netRate,
    parseSeconds: parseSeconds,
    parseDisk: parseDisk,
    parseTemps: parseTemps,
    parseProcs: parseProcs,
    sanitizeName: sanitizeName,
    appendHistory: appendHistory,
    formatUptime: formatUptime,
    formatUptimeCompact: formatUptimeCompact,
    formatUptimeShort: formatUptimeShort,
    bytesParts: bytesParts,
    rateParts: rateParts,
    compactRateParts: compactRateParts,
    shortRateParts: shortRateParts,
    formatBytes: formatBytes,
    formatRate: formatRate
  }
}
