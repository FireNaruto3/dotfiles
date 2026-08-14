#!/usr/bin/env bash

set -u

numeric_or_zero() {
    [[ ${1:-} =~ ^[0-9]+$ ]] && printf '%s' "$1" || printf '0'
}

cpu_temp=0
cpu_temp_available=false
for hwmon in /sys/class/hwmon/hwmon*; do
    [[ -r $hwmon/name ]] || continue
    read -r hwmon_name < "$hwmon/name"
    [[ $hwmon_name == k10temp ]] || continue
    for label_path in "$hwmon"/temp*_label; do
        [[ -r $label_path ]] || continue
        read -r temp_label < "$label_path"
        [[ $temp_label == Tctl ]] || continue
        input_path=${label_path%_label}_input
        [[ -r $input_path ]] || continue
        cpu_temp=$(awk '{printf "%.0f", $1 / 1000}' "$input_path")
        [[ $cpu_temp =~ ^[0-9]+$ ]] && cpu_temp_available=true
        break 2
    done
done

gpu_temp=0
gpu_temp_available=false
gpu_temp_state=unavailable
gpu_mode=$(supergfxctl --get 2>/dev/null || printf 'Unknown')
nvidia_device=

for device in /sys/bus/pci/devices/*; do
    [[ -r $device/vendor && -r $device/class ]] || continue
    read -r vendor < "$device/vendor"
    read -r device_class < "$device/class"
    if [[ $vendor == 0x10de && $device_class == 0x03* ]]; then
        nvidia_device=$device
        break
    fi
done

if [[ $gpu_mode == Integrated ]]; then
    gpu_temp_state=disabled
elif [[ -n $nvidia_device ]]; then
    runtime_status=unknown
    if [[ -r $nvidia_device/power/runtime_status ]]; then
        read -r runtime_status < "$nvidia_device/power/runtime_status"
    fi

    if [[ $runtime_status == suspended ]]; then
        gpu_temp_state=suspended
    elif [[ $runtime_status == active || $gpu_mode == AsusMuxDgpu ]]; then
        for hwmon in "$nvidia_device"/hwmon/hwmon*; do
            [[ -d $hwmon ]] || continue
            for input_path in "$hwmon"/temp*_input; do
                [[ -r $input_path ]] || continue
                read -r temp_value < "$input_path"
                [[ $temp_value =~ ^[0-9]+$ ]] || continue
                gpu_temp=$(awk -v value="$temp_value" 'BEGIN {printf "%.0f", value / 1000}')
                gpu_temp_available=true
                gpu_temp_state=active
                break 2
            done
        done

        # Hybrid telemetry must not keep a temporarily active dGPU awake.
        if [[ $gpu_temp_available != true && $gpu_mode == AsusMuxDgpu \
            && -r $nvidia_device/power/runtime_status ]]; then
            read -r runtime_status < "$nvidia_device/power/runtime_status"
            if [[ $runtime_status == active ]]; then
                gpu_temp=$(nvidia-smi --query-gpu=temperature.gpu \
                    --format=csv,noheader,nounits 2>/dev/null | awk 'NR == 1 {print $1}')
                if [[ $gpu_temp =~ ^[0-9]+$ ]]; then
                    gpu_temp_available=true
                    gpu_temp_state=active
                fi
            fi
        fi
    fi
fi

fan_profile=Unknown
fan_curves=
for _ in 1 2 3; do
    profiles_before=$(asusctl profile get 2>/dev/null || true)
    profile_before=$(sed -n 's/^Active profile: //p' <<< "$profiles_before")
    [[ -n $profile_before ]] || break

    fan_curves=$(asusctl fan-curve --get-enabled 2>/dev/null || true)
    profiles_after=$(asusctl profile get 2>/dev/null || true)
    profile_after=$(sed -n 's/^Active profile: //p' <<< "$profiles_after")
    if [[ $profile_before == "$profile_after" ]]; then
        fan_profile=$profile_before
        break
    fi
    fan_curves=
    sleep 0.05
done

cpu_fan_curve=$(sed -n 's/^CPU: //p' <<< "$fan_curves")
gpu_fan_curve=$(sed -n 's/^GPU: //p' <<< "$fan_curves")
[[ -n $cpu_fan_curve ]] && cpu_fan_curve_available=true || cpu_fan_curve_available=false
[[ -n $gpu_fan_curve ]] && gpu_fan_curve_available=true || gpu_fan_curve_available=false

cpu_fan=0
gpu_fan=0
mid_fan=0
cpu_fan_available=false
gpu_fan_available=false
mid_fan_available=false
max_fan_rpm=20000
for hwmon in /sys/class/hwmon/hwmon*; do
    [[ -r $hwmon/name ]] || continue
    read -r hwmon_name < "$hwmon/name"
    [[ $hwmon_name == asus ]] || continue

    for label_path in "$hwmon"/fan*_label; do
        [[ -r $label_path ]] || continue
        read -r fan_label < "$label_path"
        fan_label=${fan_label,,}
        fan_label=${fan_label// /_}
        fan_label=${fan_label//-/_}
        case "$fan_label" in
            cpu_fan|gpu_fan|mid_fan) ;;
            *) continue ;;
        esac

        input_path=${label_path%_label}_input
        [[ -r $input_path ]] || continue
        read -r fan_value < "$input_path"
        [[ $fan_value =~ ^[0-9]+$ ]] || continue
        (( fan_value <= max_fan_rpm )) || continue

        case "$fan_label" in
            cpu_fan)
                cpu_fan=$fan_value
                cpu_fan_available=true
                ;;
            gpu_fan)
                gpu_fan=$fan_value
                gpu_fan_available=true
                ;;
            mid_fan)
                mid_fan=$fan_value
                mid_fan_available=true
                ;;
        esac
    done
done

cpu_temp=$(numeric_or_zero "$cpu_temp")
gpu_temp=$(numeric_or_zero "$gpu_temp")
cpu_fan=$(numeric_or_zero "$cpu_fan")
gpu_fan=$(numeric_or_zero "$gpu_fan")
mid_fan=$(numeric_or_zero "$mid_fan")

jq -cn \
    --arg fan_profile "$fan_profile" \
    --argjson cpu_temp "$cpu_temp" \
    --argjson cpu_temp_available "$cpu_temp_available" \
    --argjson gpu_temp "$gpu_temp" \
    --argjson gpu_temp_available "$gpu_temp_available" \
    --arg gpu_temp_state "$gpu_temp_state" \
    --argjson cpu_fan "$cpu_fan" \
    --argjson cpu_fan_available "$cpu_fan_available" \
    --argjson gpu_fan "$gpu_fan" \
    --argjson gpu_fan_available "$gpu_fan_available" \
    --argjson mid_fan "$mid_fan" \
    --argjson mid_fan_available "$mid_fan_available" \
    --arg cpu_fan_curve "$cpu_fan_curve" \
    --argjson cpu_fan_curve_available "$cpu_fan_curve_available" \
    --arg gpu_fan_curve "$gpu_fan_curve" \
    --argjson gpu_fan_curve_available "$gpu_fan_curve_available" \
    '{
        fan_profile: $fan_profile,
        cpu_temp: $cpu_temp,
        cpu_temp_available: $cpu_temp_available,
        gpu_temp: $gpu_temp,
        gpu_temp_available: $gpu_temp_available,
        gpu_temp_state: $gpu_temp_state,
        cpu_fan: $cpu_fan,
        cpu_fan_available: $cpu_fan_available,
        gpu_fan: $gpu_fan,
        gpu_fan_available: $gpu_fan_available,
        mid_fan: $mid_fan,
        mid_fan_available: $mid_fan_available,
        cpu_fan_curve_available: $cpu_fan_curve_available,
        gpu_fan_curve_available: $gpu_fan_curve_available,
        cpu_fan_curve_enabled: ($cpu_fan_curve | startswith("enabled: true,")),
        gpu_fan_curve_enabled: ($gpu_fan_curve | startswith("enabled: true,")),
        cpu_fan_curve: [
            $cpu_fan_curve
            | scan("([0-9]+)c:([0-9]+)%")
            | {temperature: (.[0] | tonumber), percent: (.[1] | tonumber)}
        ],
        gpu_fan_curve: [
            $gpu_fan_curve
            | scan("([0-9]+)c:([0-9]+)%")
            | {temperature: (.[0] | tonumber), percent: (.[1] | tonumber)}
        ]
    }'
