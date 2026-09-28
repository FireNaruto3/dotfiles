#!/usr/bin/env bash

set -u

asusctl_command=${ASUSCTL_COMMAND:-asusctl}
gpu_mode_command=${GPU_MODE_COMMAND:-$HOME/.local/bin/gpu-mode}
command_timeout=${COMMAND_TIMEOUT:-3}
gpu_mode=$(timeout "$command_timeout" "$gpu_mode_command" --get 2>/dev/null || printf 'Unknown')
fan_profile=Unknown
fan_curves=
for _ in 1 2 3; do
    profiles_before=$(timeout "$command_timeout" "$asusctl_command" profile get 2>/dev/null || true)
    profile_before=$(sed -n 's/^Active profile: //p' <<< "$profiles_before")
    [[ -n $profile_before ]] || break

    fan_curves=$(timeout "$command_timeout" "$asusctl_command" fan-curve --get-enabled 2>/dev/null || true)
    profiles_after=$(timeout "$command_timeout" "$asusctl_command" profile get 2>/dev/null || true)
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

jq -cn \
    --arg gpu_mode "$gpu_mode" \
    --arg fan_profile "$fan_profile" \
    --arg cpu_fan_curve "$cpu_fan_curve" \
    --argjson cpu_fan_curve_available "$cpu_fan_curve_available" \
    --arg gpu_fan_curve "$gpu_fan_curve" \
    --argjson gpu_fan_curve_available "$gpu_fan_curve_available" \
    '{
        gpu_mode: $gpu_mode,
        fan_profile: $fan_profile,
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
