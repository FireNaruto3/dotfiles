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

read -r memory_total memory_used < <(
  free -b | awk '/Mem:/ {printf "%.2f %.2f\n", $2/1073741824, $3/1073741824}'
)
memory_total=${memory_total:-0}
memory_used=${memory_used:-0}

cpu_temp=$(sensors 2>/dev/null | awk '/Tctl:/ {gsub(/[+°C]/, "", $2); printf "%.0f", $2; exit}')
gpu_temp=$(sensors 2>/dev/null | awk '/^edge:/ {gsub(/[+°C]/, "", $2); printf "%.0f", $2; exit}')
cpu_temp=${cpu_temp:-0}
gpu_temp=${gpu_temp:-0}

if bluetoothctl show 2>/dev/null | grep -q 'Powered: yes'; then
  bluetooth="on"
else
  bluetooth="off"
fi
bluetooth_device=$(bluetoothctl devices Connected 2>/dev/null | sed -n '1s/^Device [^ ]* //p')
if [[ -n "$bluetooth_device" ]]; then
  bluetooth="connected"
fi

network="disconnected"
ssid=""
signal=0
if nmcli -t -f TYPE,STATE device status 2>/dev/null | grep -q '^ethernet:connected'; then
  network="ethernet"
fi
wifi_line=$(nmcli -t -f IN-USE,SSID,SIGNAL device wifi list 2>/dev/null | awk -F: '$1 == "*" {print; exit}')
if [[ -n "$wifi_line" ]]; then
  network="wifi"
  signal=${wifi_line##*:}
  ssid=${wifi_line#*:}
  ssid=${ssid%:*}
fi

volume_line=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)
volume=$(awk '{printf "%.0f", $2 * 100}' <<< "$volume_line")
volume=${volume:-0}
if [[ "$volume_line" == *"[MUTED]"* ]]; then
  muted=true
else
  muted=false
fi

brightness=$(brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/, "", $4); print $4; exit}')
brightness=${brightness:-0}

battery=$(cat /sys/class/power_supply/BAT1/capacity 2>/dev/null || printf '0')
battery_state=$(cat /sys/class/power_supply/BAT1/status 2>/dev/null || printf 'Unknown')
if [[ -r /sys/class/power_supply/BAT1/power_now ]]; then
  battery_power=$(awk '{printf "%.1f", $1/1000000}' /sys/class/power_supply/BAT1/power_now)
elif [[ -r /sys/class/power_supply/BAT1/voltage_now && -r /sys/class/power_supply/BAT1/current_now ]]; then
  battery_power=$(awk 'NR==FNR {voltage=$1; next} {printf "%.1f", voltage*$1/1000000000000}' \
    /sys/class/power_supply/BAT1/voltage_now \
    /sys/class/power_supply/BAT1/current_now)
else
  battery_power=0
fi
battery_time=$(upower -i /org/freedesktop/UPower/devices/battery_BAT1 2>/dev/null \
  | awk -F': *' '/time to empty|time to full/ {print $2; exit}')

jq -cn \
  --argjson cpu "$cpu" \
  --argjson memory_used "$memory_used" \
  --argjson memory_total "$memory_total" \
  --argjson cpu_temp "$cpu_temp" \
  --argjson gpu_temp "$gpu_temp" \
  --arg bluetooth "$bluetooth" \
  --arg bluetooth_device "$bluetooth_device" \
  --arg network "$network" \
  --arg ssid "$ssid" \
  --argjson signal "${signal:-0}" \
  --argjson volume "$volume" \
  --argjson muted "$muted" \
  --argjson brightness "$brightness" \
  --argjson battery "$battery" \
  --arg battery_state "$battery_state" \
  --argjson battery_power "$battery_power" \
  --arg battery_time "$battery_time" \
  '{cpu: $cpu, memory_used: $memory_used, memory_total: $memory_total,
    cpu_temp: $cpu_temp, gpu_temp: $gpu_temp,
    bluetooth: $bluetooth, bluetooth_device: $bluetooth_device,
    network: $network, ssid: $ssid, signal: $signal,
    volume: $volume, muted: $muted, brightness: $brightness,
    battery: $battery, battery_state: $battery_state,
    battery_power: $battery_power, battery_time: $battery_time}'
