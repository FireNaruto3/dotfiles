#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

notify_osd() {
    qs ipc call osd "$@" >/dev/null 2>&1 || true
}

case ${1:-} in
    volume)
        case ${2:-} in
            raise) wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0 ;;
            lower) wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05- ;;
            mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
            *) printf 'Invalid volume action: %s\n' "${2:-}" >&2; exit 2 ;;
        esac
        volume_line=$(wpctl get-volume @DEFAULT_AUDIO_SINK@)
        volume=$(awk '{printf "%.0f", $2 * 100}' <<< "$volume_line")
        muted=false
        [[ $volume_line == *"[MUTED]"* ]] && muted=true
        notify_osd showVolume "$volume" "$muted"
        ;;
    microphone)
        [[ ${2:-} == mute ]] || {
            printf 'Invalid microphone action: %s\n' "${2:-}" >&2
            exit 2
        }
        wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle
        notify_osd showMicrophone
        ;;
    brightness)
        device=$(bash "$script_dir/display-control.sh" backlight) || exit 1
        case ${2:-} in
            raise)
                brightnessctl -q -d "$device" set +5%
                ;;
            lower)
                maximum=$(<"/sys/class/backlight/$device/max_brightness")
                brightnessctl -q -d "$device" --min-value="$((maximum * 5 / 100))" set 5%-
                ;;
            *) printf 'Invalid brightness action: %s\n' "${2:-}" >&2; exit 2 ;;
        esac
        brightness_line=$(brightnessctl -d "$device" -m)
        IFS=, read -r _ _ _ brightness _ <<< "$brightness_line"
        notify_osd showBrightness "${brightness%%%}"
        ;;
    keyboard)
        case ${2:-} in
            raise|lower)
                keyboard_line=$(brightnessctl -d 'asus::kbd_backlight' -m 2>/dev/null) || exit 1
                IFS=, read -r _ _ current _ maximum <<< "$keyboard_line"
                levels=(off low med high)
                if [[ ${2:-} == raise ]]; then
                    target=$((current < maximum ? current + 1 : maximum))
                else
                    target=$((current > 0 ? current - 1 : 0))
                fi
                asusctl leds set "${levels[target]}"
                notify_osd showKeyboard
                ;;
            effect-next)
                asusctl aura effect --next-mode
                mode=
                while IFS= read -r path; do
                    [[ $path == /xyz/ljones/aura/* ]] || continue
                    mode_line=$(busctl get-property xyz.ljones.Asusd "$path" xyz.ljones.Aura LedMode 2>/dev/null) || continue
                    mode=${mode_line#u }
                    break
                done < <(busctl tree xyz.ljones.Asusd --list --no-pager 2>/dev/null || true)
                case $mode in
                    0) mode_label="Static" ;;
                    1) mode_label="Breathe" ;;
                    2) mode_label="Rainbow Cycle" ;;
                    3) mode_label="Rainbow Wave" ;;
                    10) mode_label="Pulse" ;;
                    *) mode_label="Changed" ;;
                esac
                notify_osd showKeyboardEffect "$mode_label"
                ;;
            *) printf 'Invalid keyboard action: %s\n' "${2:-}" >&2; exit 2 ;;
        esac
        ;;
    power-profile)
        [[ ${2:-} == next ]] || {
            printf 'Invalid power-profile action: %s\n' "${2:-}" >&2
            exit 2
        }
        current_profile=$(powerprofilesctl get)
        case $current_profile in
            power-saver) target_profile=balanced ;;
            balanced) target_profile=performance ;;
            performance) target_profile=power-saver ;;
            *) target_profile=balanced ;;
        esac
        powerprofilesctl set "$target_profile"
        active_profile=$(powerprofilesctl get)
        case $active_profile in
            power-saver) profile_label="Power Saver" ;;
            balanced) profile_label="Balanced" ;;
            performance) profile_label="Performance" ;;
            *) profile_label="$active_profile" ;;
        esac
        notify_osd showPowerProfile "$profile_label"
        ;;
    touchpad)
        [[ ${2:-} == toggle ]] || {
            printf 'Invalid touchpad action: %s\n' "${2:-}" >&2
            exit 2
        }
        state_dir="$HOME/.cache/niri"
        state_file="$state_dir/touchpad-disabled.kdl"
        if [[ -e $state_file ]]; then
            rm -f -- "$state_file"
            if ! niri validate -c "$HOME/.config/niri/config.kdl" >/dev/null 2>&1 \
                || ! niri msg action load-config-file >/dev/null; then
                mkdir -p -- "$state_dir"
                printf 'input {\n    touchpad {\n        off\n    }\n}\n' > "$state_file"
                niri msg action load-config-file >/dev/null 2>&1 || true
                printf 'Unable to enable the touchpad\n' >&2
                exit 1
            fi
            touchpad_state="On"
        else
            mkdir -p -- "$state_dir"
            temporary="$state_file.$$"
            trap 'rm -f -- "$temporary"' EXIT HUP INT TERM
            printf 'input {\n    touchpad {\n        off\n    }\n}\n' > "$temporary"
            mv -f -- "$temporary" "$state_file"
            if ! niri validate -c "$HOME/.config/niri/config.kdl" >/dev/null 2>&1 \
                || ! niri msg action load-config-file >/dev/null; then
                rm -f -- "$state_file"
                niri msg action load-config-file >/dev/null 2>&1 || true
                printf 'Unable to disable the touchpad\n' >&2
                exit 1
            fi
            touchpad_state="Off"
        fi
        notify_osd showTouchpad "$touchpad_state"
        ;;
    media)
        case ${2:-} in
            play-pause|play|pause|stop|previous|next) playerctl "${2:-}" ;;
            *) printf 'Invalid media action: %s\n' "${2:-}" >&2; exit 2 ;;
        esac
        case ${2:-} in
            play-pause) notify_osd showPlayPause ;;
            play) notify_osd showPlay ;;
            pause) notify_osd showPause ;;
            stop) notify_osd showStop ;;
            previous) notify_osd showPrevious ;;
            next) notify_osd showNext ;;
        esac
        ;;
    *)
        printf 'Usage: %s {volume raise|lower|mute|microphone mute|brightness raise|lower|keyboard raise|lower|effect-next|power-profile next|touchpad toggle|media play-pause|play|pause|stop|previous|next}\n' "$0" >&2
        exit 2
        ;;
esac
