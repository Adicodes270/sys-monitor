#!/usr/bin/env bash
# Sys Analytics - one-pass metrics sampler.
#
# Prints labelled sections once and exits. Model.js parses them, and the
# widget keeps the previous sample so CPU and network get real deltas.
# No external dependencies: everything comes from /proc, /sys, and df.

section() {
  printf '\n===%s===\n' "$1"
}

section CPU
cat /proc/stat 2>/dev/null || true

section MEM
cat /proc/meminfo 2>/dev/null || true

section NETIF
# Lowest-metric default route (destination and mask both zero). Reading this
# lets the widget measure the link that actually carries traffic instead of
# summing interfaces that mirror the same packets.
awk 'NR > 1 && $2 == "00000000" && $8 == "00000000" {
  if (best == "" || $7 + 0 < metric + 0) { best = $1; metric = $7 }
}
END { if (best != "") print best }' /proc/net/route 2>/dev/null || true

section NET
cat /proc/net/dev 2>/dev/null || true

section NET_TIME
# Timestamp the counter read itself. EPOCHREALTIME is a bash builtin, so this
# costs no extra process; the comma-to-dot swap makes it locale-independent.
printf '%s\n' "${EPOCHREALTIME/,/.}"

section DISK
df -B1 --output=size,used,avail,pcent / 2>/dev/null | tail -n 1 || true

section HWMON
for dir in /sys/class/hwmon/hwmon*; do
  [ -d "$dir" ] || continue
  name=$(cat "$dir/name" 2>/dev/null || true)
  [ -n "$name" ] || continue
  temp=$(cat "$dir/temp1_input" 2>/dev/null || true)
  fan=$(cat "$dir/fan1_input" 2>/dev/null || true)
  printf '%s|%s|%s\n' "$name" "$temp" "$fan"
done

section THERMAL
for zone in /sys/class/thermal/thermal_zone*; do
  [ -d "$zone" ] || continue
  type=$(cat "$zone/type" 2>/dev/null || true)
  temp=$(cat "$zone/temp" 2>/dev/null || true)
  [ -n "$type" ] && printf '%s|%s\n' "$type" "$temp"
done

section FREQ
for file in \
  /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq \
  /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq \
  /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_avg_freq; do
  if [ -r "$file" ]; then
    cat "$file" 2>/dev/null
    break
  fi
done

section UPTIME
awk '{print $1}' /proc/uptime 2>/dev/null || true

section LOAD
awk '{print $1}' /proc/loadavg 2>/dev/null || true

section PROC
ps -eo pid=,comm=,%cpu=,%mem= --sort=-%cpu 2>/dev/null | head -n 8 | awk '
  {
    pid = $1
    mem = $NF
    cpu = $(NF - 1)
    $1 = ""
    $(NF - 1) = ""
    $NF = ""
    sub(/^[ \t]+/, "", $0)
    gsub(/\|/, "/", $0)
    gsub(/[<>&]/, "", $0)
    print pid "|" $0 "|" cpu "|" mem
  }'
