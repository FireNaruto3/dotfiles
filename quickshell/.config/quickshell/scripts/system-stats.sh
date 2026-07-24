#!/usr/bin/env bash

set -u

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

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

brightness=$(bash "$script_dir/display-control.sh" brightness 2>/dev/null || printf '0')
brightness=${brightness:-0}

battery_info=$(upower -i /org/freedesktop/UPower/devices/DisplayDevice 2>/dev/null || true)
battery=$(awk -F': *' '/percentage:/ {gsub(/%/, "", $2); print $2; exit}' <<< "$battery_info")
battery_state=$(awk -F': *' '/state:/ {print $2; exit}' <<< "$battery_info")
case $battery_state in
  charging) battery_state=Charging ;;
  discharging) battery_state=Discharging ;;
  fully-charged) battery_state=Full ;;
  pending-charge) battery_state='Pending charge' ;;
  pending-discharge) battery_state='Pending discharge' ;;
  *) battery_state=Unknown ;;
esac
battery_power=$(awk -F': *' '/energy-rate:/ {print $2 + 0; exit}' <<< "$battery_info")
battery_time=$(awk -F': *' '/time to empty:|time to full:/ {print $2; exit}' <<< "$battery_info")
battery=${battery:-0}
battery_power=${battery_power:-0}
battery_time=${battery_time:-}

battery_path=
for supply in /sys/class/power_supply/*; do
  [[ -r $supply/type ]] || continue
  read -r supply_type < "$supply/type"
  [[ $supply_type == Battery ]] || continue
  if [[ -r $supply/present ]]; then
    read -r supply_present < "$supply/present"
    [[ $supply_present == 1 ]] || continue
  fi
  if [[ -r $supply/scope ]]; then
    read -r supply_scope < "$supply/scope"
    [[ $supply_scope == System ]] || continue
  fi
  battery_path=$supply
  break
done

if [[ -n $battery_path && -r $battery_path/power_now ]]; then
  battery_power=$(awk '{printf "%.1f", $1/1000000}' "$battery_path/power_now")
elif [[ -n $battery_path && -r $battery_path/voltage_now && -r $battery_path/current_now ]]; then
  battery_power=$(awk 'NR==FNR {voltage=$1; next} {printf "%.1f", voltage*$1/1000000000000}' \
    "$battery_path/voltage_now" \
    "$battery_path/current_now")
fi
if [[ -n $battery_path && -r $battery_path/charge_full_design && -r $battery_path/charge_full ]]; then
  battery_health=$(awk 'NR==FNR {full=$1; next} {printf "%.0f", full/$1*100}' \
    "$battery_path/charge_full" \
    "$battery_path/charge_full_design")
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
