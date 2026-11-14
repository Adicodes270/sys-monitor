#!/usr/bin/env bash
# Cyber System Monitor - Metrics Provider
set -euo pipefail

# 1. CPU ticks
read -r _ u n s i io irq sirq st _ < /proc/stat
total=$((u + n + s + i + io + irq + sirq + st))
idle=$((i + io))

# 2. RAM & Swap info (in kB)
mem_total=0; mem_avail=0; swap_total=0; swap_free=0
while read -r key val _; do
  case "$key" in
    MemTotal:) mem_total="$val" ;;
    MemAvailable:) mem_avail="$val" ;;
    SwapTotal:) swap_total="$val" ;;
    SwapFree:) swap_free="$val" ;;
  esac
done < /proc/meminfo
mem_used=$((mem_total - mem_avail))
swap_used=$((swap_total - swap_free))

# 3. Load average & Temperature
load=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0.0")
temp="N/A"
if [[ -f /sys/class/thermal/thermal_zone0/temp ]]; then
  temp_raw=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "")
  if [[ -n "$temp_raw" && "$temp_raw" =~ ^[0-9]+$ ]]; then
    temp="$((temp_raw / 1000))"
  fi
fi

# 4. Uptime formatted
uptime_str="N/A"
if [[ -f /proc/uptime ]]; then
  up_secs=$(awk '{printf "%.0f", $1}' /proc/uptime 2>/dev/null || echo 0)
  up_h=$((up_secs / 3600))
  up_m=$(((up_secs % 3600) / 60))
  uptime_str="${up_h}h ${up_m}m"
fi

# 5. Top 3 CPU processes (sanitized, alphanumeric process names)
top_procs="[]"
if command -v ps >/dev/null 2>&1; then
  procs_json=$(ps -eo comm,%cpu,%mem --sort=-%cpu --no-headers 2>/dev/null | head -n 3 | awk '{
    # Escape quotes and backslashes in process names
    gsub(/"/, "", $1);
    gsub(/\\/, "", $1);
    printf "{\"name\":\"%s\",\"cpu\":\"%s\",\"mem\":\"%s\"},", $1, $2, $3
  }' | sed 's/,$//')
  top_procs="[${procs_json}]"
fi

# 6. Single-line JSON output
cat <<EOF
{"total":$total,"idle":$idle,"memTotal":$mem_total,"memUsed":$mem_used,"swapTotal":$swap_total,"swapUsed":$swap_used,"load":"$load","temp":"$temp","uptime":"$uptime_str","topProcs":$top_procs}
EOF
