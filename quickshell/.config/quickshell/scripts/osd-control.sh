#!/usr/bin/env bash

set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

notify_osd() {
    qs ipc call osd "$1" >/dev/null 2>&1 || true
}

case ${1:-} in
    volume)
        case ${2:-} in
            raise) wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05+ -l 1.0 ;;
            lower) wpctl set-volume @DEFAULT_AUDIO_SINK@ 0.05- ;;
            mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
            *) printf 'Invalid volume action: %s\n' "${2:-}" >&2; exit 2 ;;
        esac
        notify_osd showVolume
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
        notify_osd showBrightness
        ;;
    keyboard)
        keyboard_line=$(brightnessctl -d 'asus::kbd_backlight' -m 2>/dev/null) || exit 1
        IFS=, read -r _ _ current _ maximum <<< "$keyboard_line"
        levels=(off low med high)
        case ${2:-} in
            raise) target=$((current < maximum ? current + 1 : maximum)) ;;
            lower) target=$((current > 0 ? current - 1 : 0)) ;;
            *) printf 'Invalid keyboard action: %s\n' "${2:-}" >&2; exit 2 ;;
        esac
        asusctl leds set "${levels[target]}"
        notify_osd showKeyboard
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
        printf 'Usage: %s {volume raise|lower|mute|microphone mute|brightness raise|lower|keyboard raise|lower|media play-pause|play|pause|stop|previous|next}\n' "$0" >&2
        exit 2
        ;;
esac
