#!/usr/bin/env bash

set -euo pipefail

target=${1:-}
case $target in
    Integrated|Hybrid|AsusMuxDgpu) ;;
    *)
        printf 'Unsupported GPU mode: %s\n' "${target:-missing}" >&2
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
if ! flock -n 9; then
    printf 'Another GPU mode request is already running\n' >&2
    exit 1
fi

state=$(bash "$script_dir/power-state.sh")

if [[ $(jq -r '.gpu_switch_ready' <<< "$state") != true ]]; then
    jq -r '.gpu_switch_error' <<< "$state" >&2
    exit 1
fi

current_mode=$(jq -r '.gpu_mode' <<< "$state")
if [[ $target == "$current_mode" ]]; then
    printf '%s is already the active GPU mode\n' "$target" >&2
    exit 1
fi

boot_id=$(cat /proc/sys/kernel/random/boot_id)
write_marker() {
    local action=$1
    local phase=$2
    local tmp

    tmp=$(mktemp "$state_dir/.gpu-mode-transition.XXXXXX")
    jq -cn \
        --arg boot_id "$boot_id" \
        --arg source_mode "$current_mode" \
        --arg mode "$target" \
        --arg action "$action" \
        --arg phase "$phase" \
        '{boot_id: $boot_id, source_mode: $source_mode, mode: $mode,
          action: $action, phase: $phase}' > "$tmp"
    mv "$tmp" "$state_file"
}

if [[ $target != AsusMuxDgpu && $current_mode != AsusMuxDgpu ]]; then
    write_marker logout prepared
    printf '%s selected. Logout required to apply the GPU mode change\n' "$target"
    exit 0
fi

write_marker reboot requesting
if ! output=$(supergfxctl --mode "$target" 2>&1); then
    rm -f "$state_file"
    printf '%s\n' "$output" >&2
    exit 1
fi

output_lower=${output,,}
if [[ $output_lower == *reboot* ]]; then
    write_marker reboot staged
elif [[ $output_lower == *logout* ]]; then
    write_marker logout staged
else
    rm -f "$state_file"
fi

printf '%s\n' "$output"
