#!/usr/bin/env bash

set -euo pipefail

target=${1:-}
case $target in
    Integrated|Hybrid) ;;
    *)
        printf 'Unsupported post-logout GPU mode: %s\n' "${target:-missing}" >&2
        exit 2
        ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state_home=${XDG_STATE_HOME:-$HOME/.local/state}
state_dir=$state_home/quickshell
state_file=$state_dir/gpu-mode-transition.json
mkdir -p "$state_dir"
umask 077

exec 9>"$state_dir/gpu-mode-switch.lock"
flock -x 9

write_phase() {
    local phase=$1
    local error=${2:-}
    local tmp

    [[ -r $state_file ]] || return 1
    tmp=$(mktemp "$state_dir/.gpu-mode-transition.XXXXXX")
    jq --arg phase "$phase" --arg error "$error" \
        '.phase = $phase | if $error == "" then del(.error) else .error = $error end' \
        "$state_file" > "$tmp"
    mv "$tmp" "$state_file"
}

fail_transition() {
    local message=$1
    write_phase failed "$message" || true
    printf '%s\n' "$message" >&2
    exit 1
}

marker_target=$(jq -r '.mode // "Unknown"' "$state_file" 2>/dev/null || printf 'Unknown')
marker_phase=$(jq -r '.phase // "unknown"' "$state_file" 2>/dev/null || printf 'unknown')
if [[ $marker_target != "$target" || $marker_phase != prepared ]]; then
    fail_transition "GPU transition marker is no longer prepared for $target"
fi

state=$(bash "$script_dir/power-state.sh")
if [[ $(jq -r '.gpu_transition_pending' <<< "$state") != true \
    || $(jq -r '.gpu_action_ready' <<< "$state") != true \
    || $(jq -r '.gpu_requested_mode' <<< "$state") != "$target" ]]; then
    error=$(jq -r '.gpu_switch_error // ""' <<< "$state")
    fail_transition "${error:-GPU transition changed while the session was exiting}"
fi

write_phase applying

# Niri runs as a user service outside loginctl's session scope. Its detached
# helper scopes may exit while the session shuts down, so stop each one on a
# best-effort basis and let the NVIDIA holder check enforce safety.
if ! scope_state=$(systemctl --user list-units 'app-niri-*.scope' \
    --type=scope --state=running --output=json); then
    fail_transition "Unable to enumerate Niri helper scopes"
fi
mapfile -t niri_scopes < <(jq -r '.[].unit' <<< "$scope_state")
for niri_scope in "${niri_scopes[@]}"; do
    systemctl --user stop "$niri_scope" 2>/dev/null || true
done

if ! systemctl --user stop niri.service; then
    fail_transition "Unable to stop the Niri user service"
fi

if ! command -v lsof >/dev/null; then
    fail_transition "lsof is required to verify NVIDIA device users"
fi

shopt -s nullglob
nvidia_devices=()
for nvidia_device in /dev/nvidia*; do
    [[ -c $nvidia_device ]] && nvidia_devices+=("$nvidia_device")
done
for vendor_file in /sys/class/drm/*/device/vendor; do
    read -r vendor < "$vendor_file" || continue
    [[ ${vendor,,} == 0x10de ]] || continue
    drm_path=${vendor_file%/device/vendor}
    drm_name=${drm_path##*/}
    [[ -e /dev/dri/$drm_name ]] && nvidia_devices+=("/dev/dri/$drm_name")
done
shopt -u nullglob

holders=
if (( ${#nvidia_devices[@]} > 0 )); then
    for _ in {1..50}; do
        holders=$(lsof -t "${nvidia_devices[@]}" 2>/dev/null || true)
        [[ -z $holders ]] && break
        sleep 0.1
    done
fi
if [[ -n $holders ]]; then
    holders=${holders//$'\n'/, }
    fail_transition "NVIDIA devices are still in use by process IDs: $holders"
fi

if ! output=$(supergfxctl --mode "$target" 2>&1); then
    fail_transition "${output:-Unable to request GPU mode $target}"
fi

for _ in {1..900}; do
    pending_mode=$(supergfxctl --pend-mode 2>/dev/null || printf 'Unknown')
    pending_action=$(supergfxctl --pend-action 2>/dev/null || printf 'Unknown')
    mode=$(supergfxctl --get 2>/dev/null || printf 'Unknown')
    dgpu_disable=$(cat /sys/devices/platform/asus-nb-wmi/dgpu_disable 2>/dev/null || printf '%s' '-2')
    gpu_mux_mode=$(cat /sys/devices/platform/asus-nb-wmi/gpu_mux_mode 2>/dev/null || printf '%s' '-2')
    firmware_matches=false
    if [[ $target == Integrated && $dgpu_disable == 1 && $gpu_mux_mode == 1 ]] \
        || [[ $target == Hybrid && $dgpu_disable == 0 && $gpu_mux_mode == 1 ]]; then
        firmware_matches=true
    fi
    if [[ $pending_mode == Unknown && $pending_action == "No action required" \
        && $mode == "$target" && $firmware_matches == true ]]; then
        write_phase applied
        exit 0
    fi
    sleep 0.1
done

fail_transition "GPU mode switch to $target did not complete after logout"
