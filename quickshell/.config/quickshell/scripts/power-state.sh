#!/usr/bin/env bash

set -u

numeric_or_zero() {
    [[ ${1:-} =~ ^[0-9]+$ ]] && printf '%s' "$1" || printf '0'
}

power_profile=$(powerprofilesctl get 2>/dev/null || printf 'unknown')
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
display_state=$(bash "$script_dir/display-control.sh" state 2>/dev/null || printf '{"refresh":0,"available_refresh":[]}')
display_refresh=$(jq -r '.refresh // 0' <<< "$display_state")
display_refresh_rates=$(jq -c '.available_refresh // []' <<< "$display_state")
keyboard_line=$(brightnessctl -d 'asus::kbd_backlight' -m 2>/dev/null || true)
IFS=, read -r _ _ keyboard_brightness _ keyboard_max <<< "$keyboard_line"
keyboard_brightness=${keyboard_brightness:-0}
keyboard_max=${keyboard_max:-0}
charge_limit=0
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
    if [[ -r $supply/charge_control_end_threshold ]]; then
        read -r charge_limit < "$supply/charge_control_end_threshold"
    fi
    break
done

keyboard_brightness=$(numeric_or_zero "$keyboard_brightness")
keyboard_max=$(numeric_or_zero "$keyboard_max")
charge_limit=$(numeric_or_zero "$charge_limit")
display_refresh=$(numeric_or_zero "$display_refresh")

jq -cn \
    --arg power_profile "$power_profile" \
    --argjson keyboard_brightness "$keyboard_brightness" \
    --argjson keyboard_max "$keyboard_max" \
    --argjson charge_limit "$charge_limit" \
    --argjson display_refresh "$display_refresh" \
    --argjson display_refresh_rates "$display_refresh_rates" \
    '{
        power_profile: $power_profile,
        keyboard_brightness: $keyboard_brightness,
        keyboard_max: $keyboard_max,
        charge_limit: $charge_limit,
        display_refresh: $display_refresh,
        display_refresh_rates: $display_refresh_rates
    }'
