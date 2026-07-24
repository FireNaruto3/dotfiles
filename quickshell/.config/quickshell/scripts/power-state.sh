#!/usr/bin/env bash

set -u

numeric_or_zero() {
    [[ ${1:-} =~ ^[0-9]+$ ]] && printf '%s' "$1" || printf '0'
}

numeric_or_minus_two() {
    [[ ${1:-} =~ ^-?[0-9]+$ ]] && printf '%s' "$1" || printf '%s' '-2'
}

queued_gpu_value() {
    local property_path=$1
    local value

    value=$(busctl get-property \
        xyz.ljones.Asusd \
        "$property_path" \
        xyz.ljones.AsusArmoury \
        QueuedGpuValue 2>/dev/null | awk '{print $2}')
    numeric_or_minus_two "$value"
}

power_profile=$(powerprofilesctl get 2>/dev/null || printf 'unknown')
asus_profiles=$(asusctl profile get 2>/dev/null || true)
asus_profile=$(sed -n 's/^Active profile: //p' <<< "$asus_profiles")
ac_profile=$(sed -n 's/^AC profile //p' <<< "$asus_profiles")
battery_profile=$(sed -n 's/^Battery profile //p' <<< "$asus_profiles")
gpu_mode=$(supergfxctl --get 2>/dev/null || printf 'Unknown')
pending_action=$(supergfxctl --pend-action 2>/dev/null || printf 'Unknown')
pending_mode=$(supergfxctl --pend-mode 2>/dev/null || printf 'Unknown')
pending_action_lower=${pending_action,,}
if [[ $pending_action != "No action required" || $pending_mode != "Unknown" ]]; then
    # Supergfx holds its GPU lock while waiting for logout, so Power would block.
    gpu_status=transitioning
else
    gpu_status=$(supergfxctl --status 2>/dev/null || printf 'unknown')
fi
gpu_always_reboot=$(busctl call \
    org.supergfxctl.Daemon \
    /org/supergfxctl/Gfx \
    org.supergfxctl.Daemon \
    Config 2>/dev/null | awk '{print $5}')
gpu_config_available=true
if [[ $gpu_always_reboot != true && $gpu_always_reboot != false ]]; then
    gpu_config_available=false
    gpu_always_reboot=false
fi
gpu_dgpu_disable=$(cat /sys/devices/platform/asus-nb-wmi/dgpu_disable 2>/dev/null || printf '%s' '-2')
gpu_mux_mode=$(cat /sys/devices/platform/asus-nb-wmi/gpu_mux_mode 2>/dev/null || printf '%s' '-2')
queued_dgpu_disable=$(queued_gpu_value /xyz/ljones/asus_armoury/dgpu_disable)
queued_gpu_mux=$(queued_gpu_value /xyz/ljones/asus_armoury/gpu_mux_mode)
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
gpu_dgpu_disable=$(numeric_or_minus_two "$gpu_dgpu_disable")
gpu_mux_mode=$(numeric_or_minus_two "$gpu_mux_mode")

gpu_transition_pending=false
gpu_action_ready=false
gpu_action_required=
gpu_requested_mode=Unknown
gpu_transition_error=
gpu_state_home=${XDG_STATE_HOME:-$HOME/.local/state}
gpu_transition_file=$gpu_state_home/quickshell/gpu-mode-transition.json

mode_matches_firmware() {
    case $1 in
        Integrated) (( gpu_dgpu_disable == 1 && gpu_mux_mode == 1 )) ;;
        Hybrid) (( gpu_dgpu_disable == 0 && gpu_mux_mode == 1 )) ;;
        AsusMuxDgpu) (( gpu_dgpu_disable == 0 && gpu_mux_mode == 0 )) ;;
        *) return 1 ;;
    esac
}

if [[ -r $gpu_transition_file ]]; then
    current_boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || true)
    marker_boot_id=$(jq -r '.boot_id // ""' "$gpu_transition_file" 2>/dev/null || true)
    gpu_source_mode=$(jq -r '.source_mode // "Unknown"' "$gpu_transition_file" 2>/dev/null || printf 'Unknown')
    gpu_requested_mode=$(jq -r '.mode // "Unknown"' "$gpu_transition_file" 2>/dev/null || printf 'Unknown')
    gpu_action_required=$(jq -r '.action // "unknown"' "$gpu_transition_file" 2>/dev/null || printf 'unknown')
    gpu_transition_phase=$(jq -r '.phase // "staged"' "$gpu_transition_file" 2>/dev/null || printf 'staged')
    marker_error=$(jq -r '.error // ""' "$gpu_transition_file" 2>/dev/null || true)

    if (( queued_dgpu_disable == -2 || queued_gpu_mux == -2 )); then
        gpu_transition_error="Unable to verify queued ASUS GPU settings"
    elif (( queued_dgpu_disable != -1 || queued_gpu_mux != -1 )); then
        gpu_transition_error="ROG/ASUSD queued a conflicting GPU mode change"
    elif [[ $gpu_transition_phase == prepared ]]; then
        if [[ -z $current_boot_id || $marker_boot_id != "$current_boot_id" ]]; then
            gpu_transition_error="Prepared GPU mode switch expired after reboot"
        elif [[ $gpu_mode == "$gpu_source_mode" ]] && mode_matches_firmware "$gpu_source_mode" \
            && [[ $pending_action == "No action required" && $pending_mode == "Unknown" ]]; then
            gpu_transition_pending=true
            gpu_action_ready=true
        else
            gpu_transition_error="GPU state changed before logout could apply $gpu_requested_mode"
        fi
    elif [[ $gpu_transition_phase == applying ]]; then
        if [[ $gpu_mode == "$gpu_requested_mode" ]] && mode_matches_firmware "$gpu_requested_mode" \
            && [[ $pending_action == "No action required" && $pending_mode == "Unknown" ]]; then
            rm -f "$gpu_transition_file"
            gpu_action_required=
            gpu_requested_mode=Unknown
        elif [[ $gpu_mode == "$gpu_source_mode" ]] && mode_matches_firmware "$gpu_source_mode" \
            && [[ $pending_action == "No action required" && $pending_mode == "Unknown" ]] \
            && ! systemctl --user is-active --quiet quickshell-gpu-transition.service; then
            failed_mode=$gpu_requested_mode
            rm -f "$gpu_transition_file"
            gpu_action_required=
            gpu_requested_mode=Unknown
            gpu_transition_error="GPU mode switch to $failed_mode did not complete after logout"
        else
            gpu_transition_pending=true
        fi
    elif [[ $gpu_transition_phase == failed ]]; then
        rm -f "$gpu_transition_file"
        gpu_action_required=
        gpu_requested_mode=Unknown
        gpu_transition_error=${marker_error:-GPU mode switch failed after logout}
    elif [[ $gpu_transition_phase == requesting ]]; then
        gpu_transition_pending=true
    elif [[ $gpu_action_required == reboot && -n $current_boot_id \
        && $marker_boot_id == "$current_boot_id" ]]; then
        gpu_transition_pending=true
        if [[ $pending_action_lower == *reboot* ]]; then
            gpu_action_ready=true
        elif [[ $pending_action == "No action required" && $pending_mode == "Unknown" ]]; then
            if [[ $gpu_mode == "$gpu_requested_mode" ]] && mode_matches_firmware "$gpu_requested_mode"; then
                gpu_action_ready=true
            elif [[ $gpu_mode == "$gpu_source_mode" ]] && mode_matches_firmware "$gpu_source_mode"; then
                failed_mode=$gpu_requested_mode
                rm -f "$gpu_transition_file"
                gpu_action_required=
                gpu_requested_mode=Unknown
                gpu_transition_error="GPU mode switch to $failed_mode failed while staging"
            else
                gpu_transition_error="GPU mode switch to $gpu_requested_mode failed while staging"
            fi
        fi
    elif [[ $gpu_mode == "$gpu_requested_mode" ]] && mode_matches_firmware "$gpu_requested_mode" \
        && [[ $pending_action == "No action required" && $pending_mode == "Unknown" ]]; then
        rm -f "$gpu_transition_file"
        gpu_action_required=
        gpu_requested_mode=Unknown
    elif [[ -z $current_boot_id || $marker_boot_id != "$current_boot_id" ]]; then
        gpu_transition_error="Requested GPU mode $gpu_requested_mode did not become active"
    elif [[ $gpu_action_required == reboot || $gpu_action_required == logout ]]; then
        if [[ $gpu_action_required == logout \
            && $pending_action == "No action required" && $pending_mode == "Unknown" ]]; then
            if [[ $gpu_mode == "$gpu_source_mode" ]] && mode_matches_firmware "$gpu_source_mode"; then
                failed_mode=$gpu_requested_mode
                rm -f "$gpu_transition_file"
                gpu_action_required=
                gpu_requested_mode=Unknown
                gpu_transition_error="GPU mode switch to $failed_mode timed out before logout"
            else
                gpu_transition_error="GPU mode switch to $gpu_requested_mode failed before logout"
            fi
        else
            gpu_transition_pending=true
            if [[ $gpu_action_required == logout && $pending_action_lower == *logout* ]]; then
                gpu_action_ready=true
            fi
        fi
    else
        gpu_transition_error="Unknown GPU transition state"
    fi
fi

gpu_switch_ready=true
gpu_switch_error=
if ! systemctl is-active --quiet supergfxd.service; then
    gpu_switch_ready=false
    gpu_switch_error="supergfxd is not running"
elif [[ $gpu_config_available != true ]]; then
    gpu_switch_ready=false
    gpu_switch_error="Unable to read the live Supergfx configuration"
elif [[ $gpu_always_reboot == true ]]; then
    gpu_switch_ready=false
    gpu_switch_error="Install the safe Supergfx config with always_reboot disabled"
elif [[ -n $gpu_transition_error ]]; then
    gpu_switch_ready=false
    gpu_switch_error=$gpu_transition_error
elif [[ $gpu_transition_pending == true ]]; then
    gpu_switch_ready=false
    gpu_switch_error="${gpu_action_required^} required to finish switching to $gpu_requested_mode"
elif [[ $pending_action != "No action required" || $pending_mode != "Unknown" ]]; then
    gpu_switch_ready=false
    gpu_switch_error="Supergfx already has a pending mode change"
elif (( queued_dgpu_disable == -2 || queued_gpu_mux == -2 )); then
    gpu_switch_ready=false
    gpu_switch_error="Unable to verify queued ASUS GPU settings"
elif (( queued_dgpu_disable != -1 || queued_gpu_mux != -1 )); then
    gpu_switch_ready=false
    gpu_switch_error="ROG/ASUSD has a queued GPU mode change"
else
    if ! mode_matches_firmware "$gpu_mode"; then
        gpu_switch_ready=false
        case $gpu_mode in
            Integrated|Hybrid|AsusMuxDgpu)
                gpu_switch_error="Supergfx mode does not match ASUS firmware state"
                ;;
            *)
                gpu_switch_error="Unknown Supergfx mode: $gpu_mode"
                ;;
        esac
    fi
fi

jq -cn \
    --arg power_profile "$power_profile" \
    --arg asus_profile "${asus_profile:-Unknown}" \
    --arg ac_profile "${ac_profile:-Unknown}" \
    --arg battery_profile "${battery_profile:-Unknown}" \
    --arg gpu_mode "$gpu_mode" \
    --arg gpu_status "$gpu_status" \
    --arg pending_action "$pending_action" \
    --arg pending_mode "$pending_mode" \
    --argjson gpu_always_reboot "$gpu_always_reboot" \
    --argjson gpu_config_available "$gpu_config_available" \
    --argjson gpu_switch_ready "$gpu_switch_ready" \
    --arg gpu_switch_error "$gpu_switch_error" \
    --argjson gpu_transition_pending "$gpu_transition_pending" \
    --argjson gpu_action_ready "$gpu_action_ready" \
    --arg gpu_action_required "$gpu_action_required" \
    --arg gpu_requested_mode "$gpu_requested_mode" \
    --argjson gpu_dgpu_disable "$gpu_dgpu_disable" \
    --argjson gpu_mux_mode "$gpu_mux_mode" \
    --argjson queued_dgpu_disable "$queued_dgpu_disable" \
    --argjson queued_gpu_mux "$queued_gpu_mux" \
    --argjson keyboard_brightness "$keyboard_brightness" \
    --argjson keyboard_max "$keyboard_max" \
    --argjson charge_limit "$charge_limit" \
    --argjson display_refresh "$display_refresh" \
    --argjson display_refresh_rates "$display_refresh_rates" \
    '{
        power_profile: $power_profile,
        asus_profile: $asus_profile,
        ac_profile: $ac_profile,
        battery_profile: $battery_profile,
        gpu_mode: $gpu_mode,
        gpu_status: $gpu_status,
        pending_action: $pending_action,
        pending_mode: $pending_mode,
        gpu_always_reboot: $gpu_always_reboot,
        gpu_config_available: $gpu_config_available,
        gpu_switch_ready: $gpu_switch_ready,
        gpu_switch_error: $gpu_switch_error,
        gpu_transition_pending: $gpu_transition_pending,
        gpu_action_ready: $gpu_action_ready,
        gpu_action_required: $gpu_action_required,
        gpu_requested_mode: $gpu_requested_mode,
        gpu_dgpu_disable: $gpu_dgpu_disable,
        gpu_mux_mode: $gpu_mux_mode,
        queued_dgpu_disable: $queued_dgpu_disable,
        queued_gpu_mux: $queued_gpu_mux,
        keyboard_brightness: $keyboard_brightness,
        keyboard_max: $keyboard_max,
        charge_limit: $charge_limit,
        display_refresh: $display_refresh,
        display_refresh_rates: $display_refresh_rates
    }'
