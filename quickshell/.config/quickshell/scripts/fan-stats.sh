#!/usr/bin/env bash

set -u

numeric_or_zero() {
    [[ ${1:-} =~ ^[0-9]+$ ]] && printf '%s' "$1" || printf '0'
}

cpu_temp=$(sensors 2>/dev/null | awk '/Tctl:/ {gsub(/[+°C]/, "", $2); printf "%.0f", $2; exit}')
cpu_temp=${cpu_temp:-0}
gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader,nounits 2>/dev/null \
    | awk 'NR == 1 {printf "%.0f", $1}')
gpu_temp=${gpu_temp:-0}
fan_curves=$(asusctl fan-curve --get-enabled 2>/dev/null || true)
cpu_fan_curve=$(sed -n 's/^CPU: //p' <<< "$fan_curves")
gpu_fan_curve=$(sed -n 's/^GPU: //p' <<< "$fan_curves")
mid_fan_curve=$(sed -n 's/^MID: //p' <<< "$fan_curves")
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

cpu_temp=$(numeric_or_zero "$cpu_temp")
gpu_temp=$(numeric_or_zero "$gpu_temp")
cpu_fan=$(numeric_or_zero "$cpu_fan")
gpu_fan=$(numeric_or_zero "$gpu_fan")
mid_fan=$(numeric_or_zero "$mid_fan")

jq -cn \
    --argjson cpu_temp "$cpu_temp" \
    --argjson gpu_temp "$gpu_temp" \
    --argjson cpu_fan "$cpu_fan" \
    --argjson gpu_fan "$gpu_fan" \
    --argjson mid_fan "$mid_fan" \
    --arg cpu_fan_curve "$cpu_fan_curve" \
    --arg gpu_fan_curve "$gpu_fan_curve" \
    --arg mid_fan_curve "$mid_fan_curve" \
    '{
        cpu_temp: $cpu_temp,
        gpu_temp: $gpu_temp,
        cpu_fan: $cpu_fan,
        gpu_fan: $gpu_fan,
        mid_fan: $mid_fan,
        cpu_fan_curve_enabled: ($cpu_fan_curve | startswith("enabled: true,")),
        gpu_fan_curve_enabled: ($gpu_fan_curve | startswith("enabled: true,")),
        mid_fan_curve_enabled: ($mid_fan_curve | startswith("enabled: true,")),
        cpu_fan_curve: [
            $cpu_fan_curve
            | scan("([0-9]+)c:([0-9]+)%")
            | {temperature: (.[0] | tonumber), percent: (.[1] | tonumber)}
        ],
        gpu_fan_curve: [
            $gpu_fan_curve
            | scan("([0-9]+)c:([0-9]+)%")
            | {temperature: (.[0] | tonumber), percent: (.[1] | tonumber)}
        ],
        mid_fan_curve: [
            $mid_fan_curve
            | scan("([0-9]+)c:([0-9]+)%")
            | {temperature: (.[0] | tonumber), percent: (.[1] | tonumber)}
        ]
    }'
