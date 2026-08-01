#!/usr/bin/env bash

set -u -o pipefail

readonly sink='@DEFAULT_SINK@'
readonly step=5
readonly lock_file="${XDG_RUNTIME_DIR:-/tmp}/quickshell-audio-control.lock"

command -v pactl >/dev/null 2>&1 || {
    printf 'pactl is required for audio control\n' >&2
    exit 1
}

exec 9>"$lock_file"
flock -x 9

volume_percent() {
    pactl get-sink-volume "$sink" 2>/dev/null | awk -F/ '
        NR == 1 {
            value = $2
            gsub(/[^0-9]/, "", value)
            if (value != "") {
                print value
                exit
            }
        }
    '
}

current=$(volume_percent)
[[ $current =~ ^[0-9]+$ ]] || {
    printf 'Unable to read the default sink volume\n' >&2
    exit 1
}

case ${1:-} in
    raise)
        target=$((current + step))
        (( target > 100 )) && target=100
        pactl set-sink-volume "$sink" "${target}%"
        ;;
    lower)
        target=$((current - step))
        (( target < 0 )) && target=0
        pactl set-sink-volume "$sink" "${target}%"
        ;;
    mute)
        pactl set-sink-mute "$sink" toggle
        ;;
    *)
        printf 'Usage: %s {raise|lower|mute}\n' "$0" >&2
        exit 2
        ;;
esac

volume=$(volume_percent)
[[ $volume =~ ^[0-9]+$ ]] || exit 1

if pactl get-sink-mute "$sink" 2>/dev/null | grep -q '^Mute: yes$'; then
    muted=true
    icon='sink-volume-muted-symbolic'
elif (( volume < 34 )); then
    muted=false
    icon='sink-volume-low-symbolic'
elif (( volume < 67 )); then
    muted=false
    icon='sink-volume-medium-symbolic'
else
    muted=false
    icon='sink-volume-high-symbolic'
fi

progress=$(awk -v volume="$volume" 'BEGIN { printf "%.2f", volume / 100 }')

# Keep the bar immediate while the normal collector remains the source of truth.
qs ipc call panels updateAudio "$volume" "$muted" >/dev/null 2>&1 || true
swayosd-client \
    --custom-icon "$icon" \
    --custom-progress-text "${volume}%" \
    --custom-progress "$progress"
