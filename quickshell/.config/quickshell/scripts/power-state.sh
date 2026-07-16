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
fan_curves=$(asusctl fan-curve --get-enabled 2>/dev/null || true)
cpu_fan_curve=$(sed -n 's/^CPU: //p' <<< "$fan_curves")
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
cpu_fan=0
gpu_fan=0
mid_fan=0
for hwmon in /sys/class/hwmon/hwmon*; do
    if read -r hwmon_name < "$hwmon/name" && [[ $hwmon_name == asus ]]; then
        for label_path in "$hwmon"/fan*_label; do
            [[ -r $label_path ]] || continue
            read -r fan_label < "$label_path"
            input_path=${label_path%_label}_input
            [[ -r $input_path ]] || continue
            read -r fan_value < "$input_path"
            case "$fan_label" in
                cpu_fan) cpu_fan=$fan_value ;;
                gpu_fan) gpu_fan=$fan_value ;;
                mid_fan) mid_fan=$fan_value ;;
            esac
        done
        break
    fi
done

keyboard_brightness=$(numeric_or_zero "$keyboard_brightness")
keyboard_max=$(numeric_or_zero "$keyboard_max")
display_refresh=$(numeric_or_zero "$display_refresh")
cpu_fan=$(numeric_or_zero "$cpu_fan")
gpu_fan=$(numeric_or_zero "$gpu_fan")
mid_fan=$(numeric_or_zero "$mid_fan")

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
    --arg cpu_fan_curve "$cpu_fan_curve" \
    --argjson keyboard_brightness "$keyboard_brightness" \
    --argjson keyboard_max "$keyboard_max" \
    --argjson display_refresh "$display_refresh" \
    --argjson cpu_fan "$cpu_fan" \
    --argjson gpu_fan "$gpu_fan" \
    --argjson mid_fan "$mid_fan" \
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
        cpu_fan_curve_enabled: ($cpu_fan_curve | startswith("enabled: true,")),
        cpu_fan_curve: [
            $cpu_fan_curve
            | scan("([0-9]+)c:([0-9]+)%")
            | {temperature: (.[0] | tonumber), percent: (.[1] | tonumber)}
        ],
        keyboard_brightness: $keyboard_brightness,
        keyboard_max: $keyboard_max,
        display_refresh: $display_refresh,
        cpu_fan: $cpu_fan,
        gpu_fan: $gpu_fan,
        mid_fan: $mid_fan
    }'
