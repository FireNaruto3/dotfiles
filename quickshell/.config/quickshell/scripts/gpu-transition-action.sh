#!/usr/bin/env bash

set -euo pipefail

action=${1:-}
case $action in
    logout|reboot) ;;
    *)
        printf 'Unsupported GPU transition action: %s\n' "${action:-missing}" >&2
        exit 2
        ;;
esac

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
state_home=${XDG_STATE_HOME:-$HOME/.local/state}
state_dir=$state_home/quickshell
mkdir -p "$state_dir"

exec 9>"$state_dir/gpu-mode-switch.lock"
if ! flock -n 9; then
    printf 'Another GPU mode action is already running\n' >&2
    exit 1
fi

state=$(bash "$script_dir/power-state.sh")
if [[ $(jq -r '.gpu_transition_pending' <<< "$state") != true \
    || $(jq -r '.gpu_action_ready' <<< "$state") != true \
    || $(jq -r '.gpu_action_required' <<< "$state") != "$action" ]]; then
    error=$(jq -r '.gpu_switch_error // ""' <<< "$state")
    printf '%s\n' "${error:-GPU transition is not ready for $action}" >&2
    exit 1
fi

queued_value() {
    busctl get-property \
        xyz.ljones.Asusd \
        "$1" \
        xyz.ljones.AsusArmoury \
        QueuedGpuValue 2>/dev/null | awk '{print $2}'
}

queued_dgpu=$(queued_value /xyz/ljones/asus_armoury/dgpu_disable)
queued_mux=$(queued_value /xyz/ljones/asus_armoury/gpu_mux_mode)
if [[ $queued_dgpu != -1 || $queued_mux != -1 ]]; then
    printf 'ROG/ASUSD queued a conflicting GPU mode change\n' >&2
    exit 1
fi

if [[ $action == reboot ]]; then
    systemctl reboot
else
    session=${XDG_SESSION_ID:-}
    if [[ -z $session ]]; then
        printf 'Unable to determine the current login session\n' >&2
        exit 1
    fi

    leader=$(loginctl show-session "$session" -p Leader --value)
    target=$(jq -r '.mode // "Unknown"' "$state_dir/gpu-mode-transition.json")
    if [[ ! $leader =~ ^[0-9]+$ || $target == Unknown ]]; then
        printf 'Unable to prepare the GPU transition worker\n' >&2
        exit 1
    fi

    systemctl --user reset-failed quickshell-gpu-transition.service 2>/dev/null || true
    systemd-run --user --collect \
        --unit=quickshell-gpu-transition \
        --service-type=exec \
        --setenv=XDG_STATE_HOME="$state_home" \
        /usr/bin/bash "$script_dir/gpu-mode-apply-after-logout.sh" \
        "$session" "$leader" "$target" >/dev/null
    loginctl terminate-session "$session"
fi
