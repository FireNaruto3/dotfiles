#!/usr/bin/env bash

set -u

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
if [[ -r /sys/class/power_supply/BAT1/charge_full_design ]]; then
  battery_health=$(awk 'NR==FNR {full=$1; next} {printf "%.0f", full/$1*100}' \
    /sys/class/power_supply/BAT1/charge_full \
    /sys/class/power_supply/BAT1/charge_full_design)
else
  battery_health=0
fi

uptime_seconds=$(awk '{printf "%.0f", $1}' /proc/uptime)
uptime_days=$((uptime_seconds / 86400))
uptime_hours=$(((uptime_seconds % 86400) / 3600))
uptime_minutes=$(((uptime_seconds % 3600) / 60))
if (( uptime_days > 0 )); then
  uptime="${uptime_days}d ${uptime_hours}h ${uptime_minutes}m"
else
  uptime="${uptime_hours}h ${uptime_minutes}m"
fi

if makoctl mode 2>/dev/null | grep -qx 'do-not-disturb'; then
  dnd=true
else
  dnd=false
fi

jq -cn \
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
  --argjson battery_health "$battery_health" \
  --arg uptime "$uptime" \
  --argjson dnd "$dnd" \
  '{bluetooth: $bluetooth, bluetooth_device: $bluetooth_device,
    network: $network, ssid: $ssid, signal: $signal,
    volume: $volume, muted: $muted, brightness: $brightness,
    battery: $battery, battery_state: $battery_state,
    battery_power: $battery_power, battery_time: $battery_time,
    battery_health: $battery_health, uptime: $uptime, dnd: $dnd}'
