#!/usr/bin/env bash

set -euo pipefail

session=${1:-}
leader=${2:-}
target=${3:-}
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

# Stay outside the graphical session and wait for its compositor to fully exit.
for _ in {1..300}; do
    if ! kill -0 "$leader" 2>/dev/null \
        && ! loginctl show-session "$session" >/dev/null 2>&1; then
        break
    fi
    sleep 0.1
done
if kill -0 "$leader" 2>/dev/null || loginctl show-session "$session" >/dev/null 2>&1; then
    fail_transition "Timed out waiting for the old graphical session to exit"
fi

# Process exit closes its DRM and NVIDIA file descriptors synchronously. Leave a
# short scheduling grace period without consuming logind's user-manager delay.
sleep 0.2

state=$(bash "$script_dir/power-state.sh")
if [[ $(jq -r '.gpu_transition_pending' <<< "$state") != true \
    || $(jq -r '.gpu_action_ready' <<< "$state") != true \
    || $(jq -r '.gpu_requested_mode' <<< "$state") != "$target" ]]; then
    error=$(jq -r '.gpu_switch_error // ""' <<< "$state")
    fail_transition "${error:-GPU transition changed while the session was exiting}"
fi

write_phase applying

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
