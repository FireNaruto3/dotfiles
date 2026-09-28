#!/usr/bin/env bash

set -u -o pipefail

sysfs_root=${SYSFS_ROOT:-/sys}
nvidia_smi_command=${NVIDIA_SMI_COMMAND:-nvidia-smi}
command_timeout=${COMMAND_TIMEOUT:-2}
gpu_mode=${1:-Unknown}
max_fan_rpm=20000

numeric_or_zero() {
    [[ ${1:-} =~ ^[0-9]+$ ]] && printf '%s' "$1" || printf '0'
}

normalise_label() {
    local label=${1,,}
    label=${label// /_}
    printf '%s' "${label//-/_}"
}

cpu_temp=0
cpu_temp_available=false
cpu_temp_state=missing
cpu_temp_count=0
cpu_temp_source_count=0
for hwmon in "$sysfs_root"/class/hwmon/hwmon*; do
    [[ -r $hwmon/name ]] || continue
    read -r hwmon_name < "$hwmon/name"
    [[ $hwmon_name == k10temp ]] || continue
    for label_path in "$hwmon"/temp*_label; do
        [[ -r $label_path ]] || continue
        read -r temp_label < "$label_path"
        [[ $temp_label == Tctl ]] || continue
        ((cpu_temp_source_count += 1))
        input_path=${label_path%_label}_input
        [[ -r $input_path ]] || {
            cpu_temp_state=invalid
            continue
        }
        read -r temp_value < "$input_path"
        [[ $temp_value =~ ^[0-9]+$ ]] || {
            cpu_temp_state=invalid
            continue
        }
        ((cpu_temp_count += 1))
        cpu_temp=$(awk -v value="$temp_value" 'BEGIN {printf "%.0f", value / 1000}')
    done
done
if ((cpu_temp_source_count > 1)); then
    cpu_temp=0
    cpu_temp_state=ambiguous
elif ((cpu_temp_count == 1)); then
    cpu_temp_available=true
    cpu_temp_state=active
fi

nvidia_device=
nvidia_device_count=0
for device in "$sysfs_root"/bus/pci/devices/*; do
    [[ -r $device/vendor && -r $device/class ]] || continue
    read -r vendor < "$device/vendor"
    read -r device_class < "$device/class"
    if [[ $vendor == 0x10de && $device_class == 0x03* ]]; then
        nvidia_device=$device
        ((nvidia_device_count += 1))
    fi
done
if ((nvidia_device_count != 1)); then
    nvidia_device=
fi

gpu_temp=0
gpu_temp_available=false
gpu_temp_state=unavailable
gpu_pci_address=
if [[ -n $nvidia_device ]]; then
    gpu_pci_address=${nvidia_device##*/}
fi

case $gpu_mode in
    Integrated)
        gpu_temp_state=disabled
        ;;
    Hybrid)
        if ((nvidia_device_count > 1)); then
            gpu_temp_state=ambiguous
        elif [[ -z $nvidia_device ]]; then
            gpu_temp_state=missing
        elif [[ -r $nvidia_device/power/runtime_status ]]; then
            read -r runtime_status < "$nvidia_device/power/runtime_status"
            case $runtime_status in
                active|suspended) gpu_temp_state=$runtime_status ;;
                *) gpu_temp_state=unavailable ;;
            esac
        fi
        ;;
    Ultimate)
        if ((nvidia_device_count > 1)); then
            gpu_temp_state=ambiguous
        elif [[ -z $nvidia_device ]]; then
            gpu_temp_state=missing
        else
            preferred_temp_count=0
            all_temp_count=0
            preferred_temp=
            sole_temp=
            for hwmon in "$nvidia_device"/hwmon/hwmon*; do
                [[ -r $hwmon/name ]] || continue
                read -r hwmon_name < "$hwmon/name"
                [[ $hwmon_name == nvidia ]] || continue
                for input_path in "$hwmon"/temp*_input; do
                    [[ -r $input_path ]] || continue
                    read -r temp_value < "$input_path"
                    [[ $temp_value =~ ^[0-9]+$ ]] || continue
                    ((all_temp_count += 1))
                    sole_temp=$temp_value
                    label_path=${input_path%_input}_label
                    temp_label=
                    [[ -r $label_path ]] && read -r temp_label < "$label_path"
                    temp_label=$(normalise_label "$temp_label")
                    if [[ $temp_label == gpu || $temp_label == edge || $temp_label == gpu_core ]]; then
                        ((preferred_temp_count += 1))
                        preferred_temp=$temp_value
                    fi
                done
            done

            selected_temp=
            if ((preferred_temp_count == 1)); then
                selected_temp=$preferred_temp
            elif ((preferred_temp_count == 0 && all_temp_count == 1)); then
                selected_temp=$sole_temp
            fi
            if [[ -n $selected_temp ]]; then
                gpu_temp=$(awk -v value="$selected_temp" 'BEGIN {printf "%.0f", value / 1000}')
                gpu_temp_available=true
                gpu_temp_state=active
            elif ((preferred_temp_count > 1 || (preferred_temp_count == 0 && all_temp_count > 1))); then
                gpu_temp_state=ambiguous
            fi

            if [[ $gpu_temp_available != true ]] && command -v "$nvidia_smi_command" >/dev/null 2>&1; then
                nvidia_output=
                if nvidia_output=$(timeout "$command_timeout" "$nvidia_smi_command" \
                    --id="$gpu_pci_address" \
                    --query-gpu=temperature.gpu \
                    --format=csv,noheader,nounits 2>/dev/null); then
                    gpu_temp=$(awk 'NR == 1 {print $1}' <<< "$nvidia_output")
                    if [[ $gpu_temp =~ ^[0-9]+$ ]]; then
                        gpu_temp_available=true
                        gpu_temp_state=active
                    else
                        gpu_temp=0
                    fi
                fi
            fi

            if [[ $gpu_temp_available != true && $gpu_temp_state != ambiguous \
                && -r $nvidia_device/power/runtime_status ]]; then
                read -r runtime_status < "$nvidia_device/power/runtime_status"
                [[ $runtime_status == suspended ]] && gpu_temp_state=suspended
            fi
        fi
        ;;
    *) gpu_temp_state=unknown_mode ;;
esac

declare -A fan_count=([cpu_fan]=0 [gpu_fan]=0 [mid_fan]=0)
declare -A fan_valid=([cpu_fan]=0 [gpu_fan]=0 [mid_fan]=0)
declare -A fan_value=([cpu_fan]=0 [gpu_fan]=0 [mid_fan]=0)
declare -A fan_invalid=([cpu_fan]=false [gpu_fan]=false [mid_fan]=false)
for hwmon in "$sysfs_root"/class/hwmon/hwmon*; do
    [[ -r $hwmon/name ]] || continue
    read -r hwmon_name < "$hwmon/name"
    [[ $hwmon_name == asus ]] || continue

    for label_path in "$hwmon"/fan*_label; do
        [[ -r $label_path ]] || continue
        read -r fan_label < "$label_path"
        fan_label=$(normalise_label "$fan_label")
        case $fan_label in
            cpu_fan|gpu_fan|mid_fan) ;;
            *) continue ;;
        esac
        ((fan_count[$fan_label] += 1))

        input_path=${label_path%_label}_input
        if [[ ! -r $input_path ]]; then
            fan_invalid[$fan_label]=true
            continue
        fi
        read -r current_fan_value < "$input_path"
        if [[ ! $current_fan_value =~ ^[0-9]+$ ]] || ((current_fan_value > max_fan_rpm)); then
            fan_invalid[$fan_label]=true
            continue
        fi
        ((fan_valid[$fan_label] += 1))
        fan_value[$fan_label]=$current_fan_value
    done
done

fan_result() {
    local label=$1
    local count=${fan_count[$label]}
    local valid=${fan_valid[$label]}
    if ((count > 1)); then
        printf '0 false ambiguous\n'
    elif ((count == 1 && valid == 1)); then
        printf '%s true available\n' "${fan_value[$label]}"
    elif [[ ${fan_invalid[$label]} == true ]]; then
        printf '0 false invalid\n'
    else
        printf '0 false missing\n'
    fi
}

read -r cpu_fan cpu_fan_available cpu_fan_state < <(fan_result cpu_fan)
read -r gpu_fan gpu_fan_available gpu_fan_state < <(fan_result gpu_fan)
read -r mid_fan mid_fan_available mid_fan_state < <(fan_result mid_fan)

cpu_temp=$(numeric_or_zero "$cpu_temp")
gpu_temp=$(numeric_or_zero "$gpu_temp")

jq -cn \
    --arg gpu_mode "$gpu_mode" \
    --arg gpu_pci_address "$gpu_pci_address" \
    --argjson cpu_temp "$cpu_temp" \
    --argjson cpu_temp_available "$cpu_temp_available" \
    --arg cpu_temp_state "$cpu_temp_state" \
    --argjson gpu_temp "$gpu_temp" \
    --argjson gpu_temp_available "$gpu_temp_available" \
    --arg gpu_temp_state "$gpu_temp_state" \
    --argjson cpu_fan "$cpu_fan" \
    --argjson cpu_fan_available "$cpu_fan_available" \
    --arg cpu_fan_state "$cpu_fan_state" \
    --argjson gpu_fan "$gpu_fan" \
    --argjson gpu_fan_available "$gpu_fan_available" \
    --arg gpu_fan_state "$gpu_fan_state" \
    --argjson mid_fan "$mid_fan" \
    --argjson mid_fan_available "$mid_fan_available" \
    --arg mid_fan_state "$mid_fan_state" \
    '{
        gpu_mode: $gpu_mode,
        gpu_pci_address: $gpu_pci_address,
        cpu_temp: $cpu_temp,
        cpu_temp_available: $cpu_temp_available,
        cpu_temp_state: $cpu_temp_state,
        gpu_temp: $gpu_temp,
        gpu_temp_available: $gpu_temp_available,
        gpu_temp_state: $gpu_temp_state,
        cpu_fan: $cpu_fan,
        cpu_fan_available: $cpu_fan_available,
        cpu_fan_state: $cpu_fan_state,
        gpu_fan: $gpu_fan,
        gpu_fan_available: $gpu_fan_available,
        gpu_fan_state: $gpu_fan_state,
        mid_fan: $mid_fan,
        mid_fan_available: $mid_fan_available,
        mid_fan_state: $mid_fan_state
    }'
