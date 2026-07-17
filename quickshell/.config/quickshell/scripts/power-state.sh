#!/usr/bin/env bash

set -u

numeric_or_zero() {
    [[ ${1:-} =~ ^[0-9]+$ ]] && printf '%s' "$1" || printf '0'
}

power_profile=$(powerprofilesctl get 2>/dev/null || printf 'unknown')
asus_profiles=$(asusctl profile get 2>/dev/null || true)
asus_profile=$(sed -n 's/^Active profile: //p' <<< "$asus_profiles")
ac_profile=$(sed -n 's/^AC profile //p' <<< "$asus_profiles")
battery_profile=$(sed -n 's/^Battery profile //p' <<< "$asus_profiles")
gpu_mode=$(supergfxctl --get 2>/dev/null || printf 'Unknown')
gpu_status=$(supergfxctl --status 2>/dev/null || printf 'unknown')
pending_action=$(supergfxctl --pend-action 2>/dev/null || printf 'Unknown')
pending_mode=$(supergfxctl --pend-mode 2>/dev/null || printf 'Unknown')
supported_modes=$(supergfxctl --supported 2>/dev/null || printf '[]')
output_state=$(niri msg -j outputs 2>/dev/null || printf '{}')
display_refresh=$(jq -r '
    .["eDP-1"] as $output
    | if $output.current_mode == null then 0
      else (($output.modes[$output.current_mode].refresh_rate / 1000) | round)
      end
' <<< "$output_state" 2>/dev/null || printf '0')
keyboard_line=$(brightnessctl -d 'asus::kbd_backlight' -m 2>/dev/null || true)
IFS=, read -r _ _ keyboard_brightness _ keyboard_max <<< "$keyboard_line"
keyboard_brightness=${keyboard_brightness:-0}
keyboard_max=${keyboard_max:-0}

keyboard_brightness=$(numeric_or_zero "$keyboard_brightness")
keyboard_max=$(numeric_or_zero "$keyboard_max")
display_refresh=$(numeric_or_zero "$display_refresh")

jq -cn \
    --arg power_profile "$power_profile" \
    --arg asus_profile "${asus_profile:-Unknown}" \
    --arg ac_profile "${ac_profile:-Unknown}" \
    --arg battery_profile "${battery_profile:-Unknown}" \
    --arg gpu_mode "$gpu_mode" \
    --arg gpu_status "$gpu_status" \
    --arg pending_action "$pending_action" \
    --arg pending_mode "$pending_mode" \
    --arg supported_modes "$supported_modes" \
    --argjson keyboard_brightness "$keyboard_brightness" \
    --argjson keyboard_max "$keyboard_max" \
    --argjson display_refresh "$display_refresh" \
    '{
        power_profile: $power_profile,
        asus_profile: $asus_profile,
        ac_profile: $ac_profile,
        battery_profile: $battery_profile,
        gpu_mode: $gpu_mode,
        gpu_status: $gpu_status,
        pending_action: $pending_action,
        pending_mode: $pending_mode,
        supported_modes: $supported_modes,
        keyboard_brightness: $keyboard_brightness,
        keyboard_max: $keyboard_max,
        display_refresh: $display_refresh
    }'
