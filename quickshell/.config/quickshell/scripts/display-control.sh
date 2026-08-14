#!/usr/bin/env bash

set -u -o pipefail

panel_make='Samsung Display Corp.'
panel_model='ATNA40CU05-0'

display_entry() {
    local outputs matches

    outputs=$(niri msg -j outputs 2>/dev/null) || {
        printf 'Unable to query Niri outputs\n' >&2
        return 1
    }
    matches=$(jq -c --arg make "$panel_make" --arg model "$panel_model" '
        [to_entries[]
            | select(.value.make == $make)
            | select((.value.model | gsub("[[:space:]]+$"; "")) == $model)]
    ' <<< "$outputs") || return 1

    if [[ $(jq 'length' <<< "$matches") != 1 ]]; then
        printf 'Unable to identify the internal display unambiguously\n' >&2
        return 1
    fi

    jq -c '.[0]' <<< "$matches"
}

display_state() {
    local entry

    entry=$(display_entry) || return 1
    jq -c '
        . as $entry
        | ($entry.value.current_mode // -1) as $current
        | {
            output: $entry.key,
            refresh: (if $current < 0 then 0
                      else (($entry.value.modes[$current].refresh_rate / 1000) | round)
                      end),
            available_refresh: [
                $entry.value.modes[]
                | select(.width == 2880 and .height == 1800)
                | ((.refresh_rate / 1000) | round)
            ] | unique
        }
    ' <<< "$entry"
}

mode_for_refresh() {
    local target=$1
    local entry mode

    [[ $target =~ ^[0-9]+$ ]] || {
        printf 'Invalid refresh rate: %s\n' "$target" >&2
        return 1
    }
    entry=$(display_entry) || return 1
    mode=$(jq -r --argjson target "$target" '
        [.value.modes[]
            | select(.width == 2880 and .height == 1800)
            | select((((.refresh_rate / 1000) | round) - $target) | fabs < 1)]
        | if length == 1 then
            .[0] | "\(.width)x\(.height)@\((.refresh_rate / 1000) * 1000 | round / 1000)"
          else empty
          end
    ' <<< "$entry") || return 1

    if [[ -z $mode ]]; then
        printf 'The internal display does not advertise %s Hz\n' "$target" >&2
        return 1
    fi

    # Niri requires exactly three decimal places for refresh rates.
    awk -F@ '{printf "%s@%.3f\n", $1, $2}' <<< "$mode"
}

internal_connector() {
    local connector status
    local -a connected=()

    shopt -s nullglob
    for connector in /sys/class/drm/card*-eDP-*; do
        read -r status < "$connector/status" || continue
        [[ $status == connected ]] && connected+=("$connector")
    done
    shopt -u nullglob

    if (( ${#connected[@]} != 1 )); then
        printf 'Unable to identify the connected internal display connector\n' >&2
        return 1
    fi

    printf '%s\n' "${connected[0]}"
}

backlight_device() {
    local connector connector_path card card_device driver backlight backlight_path
    local -a direct=() gpu=() all=()

    connector=$(internal_connector) || return 1
    connector_path=$(readlink -f "$connector") || return 1
    card=${connector##*/}
    card=${card%%-*}
    card_device=$(readlink -f "/sys/class/drm/$card/device") || return 1
    driver=$(basename "$(readlink -f "/sys/class/drm/$card/device/driver")")

    shopt -s nullglob
    for backlight in /sys/class/backlight/*; do
        all+=("${backlight##*/}")
        backlight_path=$(readlink -f "$backlight") || continue
        [[ $backlight_path == "$connector_path"/* ]] && direct+=("${backlight##*/}")
        [[ $backlight_path == "$card_device"/* ]] && gpu+=("${backlight##*/}")
    done
    shopt -u nullglob

    if (( ${#direct[@]} == 1 )); then
        printf '%s\n' "${direct[0]}"
    elif [[ $driver == nvidia && -d /sys/class/backlight/nvidia_wmi_ec_backlight ]]; then
        printf '%s\n' nvidia_wmi_ec_backlight
    elif (( ${#gpu[@]} == 1 )); then
        printf '%s\n' "${gpu[0]}"
    elif (( ${#all[@]} == 1 )); then
        printf '%s\n' "${all[0]}"
    else
        printf 'Unable to identify the internal display backlight unambiguously\n' >&2
        return 1
    fi
}

brightness_percent() {
    local device value

    device=$(backlight_device) || return 1
    value=$(brightnessctl -d "$device" -m 2>/dev/null | awk -F, 'NR == 1 {gsub(/%/, "", $4); print $4}')
    [[ $value =~ ^[0-9]+$ ]] || return 1
    printf '%s\n' "$value"
}

case ${1:-} in
    state)
        display_state
        ;;
    output)
        display_entry | jq -r '.key'
        ;;
    set-refresh)
        entry=$(display_entry) || exit 1
        output=$(jq -r '.key' <<< "$entry")
        mode=$(mode_for_refresh "${2:-}") || exit 1
        niri msg output "$output" mode "$mode"
        ;;
    backlight)
        backlight_device
        ;;
    brightness)
        brightness_percent
        ;;
    set-brightness)
        device=$(backlight_device) || exit 1
        [[ -n ${2:-} ]] || { printf 'Missing brightness value\n' >&2; exit 1; }
        brightnessctl -d "$device" set "$2"
        ;;
    save-brightness)
        device=$(backlight_device) || exit 1
        brightnessctl -d "$device" -s
        ;;
    restore-brightness)
        device=$(backlight_device) || exit 1
        brightnessctl -d "$device" -r
        ;;
    *)
        printf 'Usage: %s {state|output|set-refresh HZ|backlight|brightness|set-brightness VALUE|save-brightness|restore-brightness}\n' "$0" >&2
        exit 2
        ;;
esac
