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

microphone_line=$(wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null || true)
if [[ $microphone_line == *"[MUTED]"* ]]; then
  microphone_muted=true
else
  microphone_muted=false
fi

lock_state() {
  local path value

  shopt -s nullglob
  for path in /sys/class/leds/*::"$1"; do
    [[ -r $path/brightness ]] || continue
    read -r value < "$path/brightness"
    if [[ $value == 1 ]]; then
      shopt -u nullglob
      printf 'true\n'
      return
    fi
  done
  shopt -u nullglob
  printf 'false\n'
}

caps_lock=$(lock_state capslock)
num_lock=$(lock_state numlock)
scroll_lock=$(lock_state scrolllock)

brightness=$(bash "$script_dir/display-control.sh" brightness 2>/dev/null || printf '0')
brightness=${brightness:-0}
keyboard_line=$(brightnessctl -d 'asus::kbd_backlight' -m 2>/dev/null || true)
IFS=, read -r _ _ keyboard_brightness _ keyboard_max <<< "$keyboard_line"
keyboard_brightness=${keyboard_brightness:-0}
keyboard_max=${keyboard_max:-3}

battery_info=$(upower -i /org/freedesktop/UPower/devices/DisplayDevice 2>/dev/null || true)
battery=$(awk -F': *' '/percentage:/ {gsub(/%/, "", $2); if ($2 ~ /^[0-9]+([.][0-9]+)?$/) print $2; exit}' <<< "$battery_info")
battery_state=$(awk -F': *' '/state:/ {print $2; exit}' <<< "$battery_info")
case $battery_state in
  charging) battery_state=Charging ;;
  discharging) battery_state=Discharging ;;
  fully-charged) battery_state=Full ;;
  pending-charge) battery_state='Pending charge' ;;
  pending-discharge) battery_state='Pending discharge' ;;
  *) battery_state=Unknown ;;
esac
battery_power=$(awk -F': *' '/energy-rate:/ {if ($2 ~ /^[0-9]+([.][0-9]+)? W$/) print $2 + 0; exit}' <<< "$battery_info")
battery_time=$(awk -F': *' '/time to empty:|time to full:/ {print $2; exit}' <<< "$battery_info")
battery=${battery:-null}
battery_power=${battery_power:-null}
battery_time=${battery_time:-}

power_total=0
power_count=0
health_total=0
health_count=0
shopt -s nullglob
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
  supply_power=
  if [[ -r $supply/power_now ]]; then
    supply_power=$(awk '$1 >= 0 {printf "%.6f", $1 / 1000000}' "$supply/power_now")
  elif [[ -r $supply/voltage_now && -r $supply/current_now ]]; then
    supply_power=$(awk 'NR == FNR {voltage=$1; next} $1 >= 0 {printf "%.6f", voltage * $1 / 1000000000000}' \
      "$supply/voltage_now" "$supply/current_now")
  fi
  if [[ -n $supply_power ]]; then
    power_total=$(awk -v total="$power_total" -v value="$supply_power" 'BEGIN {printf "%.6f", total + value}')
    ((power_count += 1))
  fi

  full_path=
  design_path=
  if [[ -r $supply/energy_full && -r $supply/energy_full_design ]]; then
    full_path=$supply/energy_full
    design_path=$supply/energy_full_design
  elif [[ -r $supply/charge_full && -r $supply/charge_full_design ]]; then
    full_path=$supply/charge_full
    design_path=$supply/charge_full_design
  fi
  if [[ -n $full_path ]]; then
    supply_health=$(awk 'NR == FNR {full=$1; next} $1 > 0 {printf "%.6f", full / $1 * 100}' \
      "$full_path" "$design_path")
    if [[ -n $supply_health ]]; then
      health_total=$(awk -v total="$health_total" -v value="$supply_health" 'BEGIN {printf "%.6f", total + value}')
      ((health_count += 1))
    fi
  fi
done
shopt -u nullglob

if ((power_count > 0)); then
  battery_power=$(awk -v total="$power_total" 'BEGIN {printf "%.1f", total}')
fi
if ((health_count > 0)); then
  battery_health=$(awk -v total="$health_total" -v count="$health_count" 'BEGIN {printf "%.0f", total / count}')
else
  battery_health=null
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
  --argjson microphone_muted "$microphone_muted" \
  --argjson brightness "$brightness" \
  --argjson keyboard_brightness "$keyboard_brightness" \
  --argjson keyboard_max "$keyboard_max" \
  --argjson caps_lock "$caps_lock" \
  --argjson num_lock "$num_lock" \
  --argjson scroll_lock "$scroll_lock" \
  --argjson battery "$battery" \
  --arg battery_state "$battery_state" \
  --argjson battery_power "$battery_power" \
  --arg battery_time "$battery_time" \
  --argjson battery_health "$battery_health" \
  --arg uptime "$uptime" \
  --argjson dnd "$dnd" \
  '{bluetooth: $bluetooth, bluetooth_device: $bluetooth_device,
    network: $network, ssid: $ssid, signal: $signal,
    volume: $volume, muted: $muted, microphone_muted: $microphone_muted,
    brightness: $brightness, keyboard_brightness: $keyboard_brightness,
    keyboard_max: $keyboard_max, caps_lock: $caps_lock,
    num_lock: $num_lock, scroll_lock: $scroll_lock,
    battery: $battery, battery_state: $battery_state,
    battery_power: $battery_power, battery_time: $battery_time,
    battery_health: $battery_health, uptime: $uptime, dnd: $dnd}'
