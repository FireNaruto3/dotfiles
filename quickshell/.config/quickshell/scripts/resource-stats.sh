#!/usr/bin/env bash

set -u

read_cpu() {
  read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat
  idle_total=$((idle + iowait))
  total=$((user + nice + system + idle + iowait + irq + softirq + steal))
  printf '%s %s\n' "$idle_total" "$total"
}

read -r idle_before total_before < <(read_cpu)
sleep 0.15
read -r idle_after total_after < <(read_cpu)
total_delta=$((total_after - total_before))
idle_delta=$((idle_after - idle_before))
if (( total_delta > 0 )); then
  cpu=$((100 * (total_delta - idle_delta) / total_delta))
else
  cpu=0
fi

read -r load_1 load_5 load_15 _ < /proc/loadavg

gpu=$(cat /sys/class/drm/card1/device/gpu_busy_percent 2>/dev/null || printf '0')
gpu=${gpu:-0}
gpu_clock=$(awk '/\*/ {gsub(/Mhz/, " MHz", $2); print $2; exit}' \
  /sys/class/drm/card1/device/pp_dpm_sclk 2>/dev/null)
gpu_max_clock=$(awk 'END {gsub(/Mhz/, " MHz", $2); print $2}' \
  /sys/class/drm/card1/device/pp_dpm_sclk 2>/dev/null)
gpu_clock=${gpu_clock:--}
gpu_max_clock=${gpu_max_clock:--}

read -r memory_total memory_used memory_percent memory_cache < <(
  free -b | awk '/Mem:/ {printf "%.2f %.2f %.0f %.2f\n", $2/1073741824, $3/1073741824, $3/$2*100, $6/1073741824}'
)
memory_total=${memory_total:-0}
memory_used=${memory_used:-0}
memory_percent=${memory_percent:-0}
memory_cache=${memory_cache:-0}
read -r swap_total swap_used < <(
  free -b | awk '/Swap:/ {printf "%.2f %.2f\n", $2/1073741824, $3/1073741824}'
)
swap_total=${swap_total:-0}
swap_used=${swap_used:-0}

cpu_temp=$(sensors 2>/dev/null | awk '/Tctl:/ {gsub(/[+°C]/, "", $2); printf "%.0f", $2; exit}')
gpu_temp=$(sensors 2>/dev/null | awk '/^edge:/ {gsub(/[+°C]/, "", $2); printf "%.0f", $2; exit}')
cpu_temp=${cpu_temp:-0}
gpu_temp=${gpu_temp:-0}

jq -cn \
  --argjson cpu "$cpu" \
  --arg load_1 "$load_1" \
  --arg load_5 "$load_5" \
  --arg load_15 "$load_15" \
  --argjson gpu "$gpu" \
  --arg gpu_clock "$gpu_clock" \
  --arg gpu_max_clock "$gpu_max_clock" \
  --argjson memory_used "$memory_used" \
  --argjson memory_total "$memory_total" \
  --argjson memory_percent "$memory_percent" \
  --argjson memory_cache "$memory_cache" \
  --argjson swap_used "$swap_used" \
  --argjson swap_total "$swap_total" \
  --argjson cpu_temp "$cpu_temp" \
  --argjson gpu_temp "$gpu_temp" \
  '{cpu: $cpu, load_1: $load_1, load_5: $load_5, load_15: $load_15,
    gpu: $gpu, gpu_clock: $gpu_clock, gpu_max_clock: $gpu_max_clock,
    memory_used: $memory_used, memory_total: $memory_total,
    memory_percent: $memory_percent, memory_cache: $memory_cache,
    swap_used: $swap_used, swap_total: $swap_total,
    cpu_temp: $cpu_temp, gpu_temp: $gpu_temp}'
