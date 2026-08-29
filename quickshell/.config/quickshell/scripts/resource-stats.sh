#!/usr/bin/env bash

set -u

read -r cpu_idle cpu_total < <(
  awk '
    /^cpu[0-9]+ / {
      idle += $5 + $6
      for (field = 2; field <= 11; field++)
        total += $field
    }
    END { printf "%.0f %.0f\n", idle, total }
  ' /proc/stat
)

read -r memory_total_kib memory_available_kib < <(
  awk '
    /^MemTotal:/ { total = $2 }
    /^MemAvailable:/ { available = $2 }
    END { print total + 0, available + 0 }
  ' /proc/meminfo
)
memory_used_kib=$((memory_total_kib - memory_available_kib))
if ((memory_total_kib > 0)); then
  memory_percent=$(((memory_used_kib * 100 + memory_total_kib / 2) / memory_total_kib))
else
  memory_percent=0
fi
memory_used=$(awk -v value="$memory_used_kib" 'BEGIN { printf "%.1f", value * 1024 / 1000000000 }')
memory_total=$(awk -v value="$memory_total_kib" 'BEGIN { printf "%.1f", value * 1024 / 1000000000 }')

jq -cn \
  --argjson cpu_idle "$cpu_idle" \
  --argjson cpu_total "$cpu_total" \
  --argjson memory_percent "$memory_percent" \
  --argjson memory_used "$memory_used" \
  --argjson memory_total "$memory_total" \
  '{cpu_idle: $cpu_idle, cpu_total: $cpu_total,
    memory_percent: $memory_percent,
    memory_used: $memory_used, memory_total: $memory_total}'
