#!/usr/bin/env bash

set -u -o pipefail

json_array_from_lines() {
    jq -sc '.'
}

wifi_state() {
    local line in_use ssid remainder signal security saved_uuid saved_connections active_uuid
    local saved_line saved_remainder saved_name saved_type

    saved_connections=$(nmcli -t -f NAME,UUID,TYPE connection show 2>/dev/null)
    active_uuid=$(nmcli -t -f UUID,TYPE connection show --active 2>/dev/null \
        | awk -F: '$2 == "802-11-wireless" {print $1; exit}')

    while IFS= read -r line; do
        [[ -n $line ]] || continue
        in_use=${line%%:*}
        remainder=${line#*:}
        security=${remainder##*:}
        remainder=${remainder%:*}
        signal=${remainder##*:}
        ssid=${remainder%:*}
        ssid=${ssid//\\:/:}
        ssid=${ssid//\\\\/\\}
        [[ -n $ssid ]] || continue

        saved_uuid=
        while IFS= read -r saved_line; do
            saved_type=${saved_line##*:}
            saved_remainder=${saved_line%:*}
            saved_uuid=${saved_remainder##*:}
            saved_name=${saved_remainder%:*}
            saved_name=${saved_name//\\:/:}
            saved_name=${saved_name//\\\\/\\}
            if [[ $saved_type == 802-11-wireless && $saved_name == "$ssid" ]]; then
                break
            fi
            saved_uuid=
        done <<< "$saved_connections"
        [[ $in_use == '*' && -n $active_uuid ]] && saved_uuid=$active_uuid
        jq -cn \
            --arg name "$ssid" \
            --arg uuid "$saved_uuid" \
            --argjson signal "${signal:-0}" \
            --arg security "$security" \
            --argjson active "$([[ $in_use == '*' ]] && printf true || printf false)" \
            '{name: $name, uuid: $uuid, signal: $signal, security: $security,
              secured: ($security != "" and $security != "--"), active: $active}'
    done < <(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan auto 2>/dev/null) \
        | jq -sc '
            group_by(.name)
            | map(sort_by(-.signal) as $entries
                | $entries[0] + {
                    active: any($entries[]; .active),
                    uuid: ([ $entries[].uuid | select(length > 0) ][0] // "")
                  })
            | sort_by(-.signal)
            | .[:10]
        '
}

bluetooth_devices() {
    local address name connected

    while read -r _ address name; do
        [[ -n ${address:-} ]] || continue
        if bluetoothctl info "$address" 2>/dev/null | grep -q 'Connected: yes'; then
            connected=true
        else
            connected=false
        fi
        jq -cn --arg address "$address" --arg name "$name" --argjson connected "$connected" \
            '{address: $address, name: $name, connected: $connected}'
    done < <(bluetoothctl devices Paired 2>/dev/null) | json_array_from_lines
}

audio_nodes() {
    local target=$1

    wpctl status 2>/dev/null | awk -v target="$target" '
        index($0, target ":") {inside=1; next}
        inside && /Devices:|Sinks:|Sources:|Filters:|Streams:|Video:/ {exit}
        inside && match($0, /[0-9]+[.]/) {
            line=$0
            active=(line ~ /[*]/ ? "true" : "false")
            id=substr(line, RSTART, RLENGTH - 1)
            sub(/^.*[0-9]+[.] /, "", line)
            sub(/ \[vol:.*$/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            printf "%s\t%s\t%s\n", id, active, line
        }
    ' | while IFS=$'\t' read -r id active name; do
        jq -cn --arg id "$id" --arg name "$name" --argjson active "$active" \
            '{id: $id, name: $name, active: $active}'
    done | json_array_from_lines
}

display_state() {
    niri msg -j outputs 2>/dev/null | jq -c '
        [to_entries[]
            | .value as $output
            | ($output.current_mode // -1) as $current
            | ($output.modes[$current] // null) as $active_mode
            | {
                name: .key,
                label: (($output.make + " " + ($output.model | gsub("[[:space:]]+$"; "")))
                    | gsub("^[[:space:]]+|[[:space:]]+$"; "")),
                enabled: ($current >= 0),
                current_mode: (if $active_mode then
                    "\($active_mode.width)x\($active_mode.height)@\(($active_mode.refresh_rate / 1000) * 1000 | round / 1000)"
                    else "" end),
                modes: ([$output.modes[]
                    | select($active_mode == null or (.width == $active_mode.width and .height == $active_mode.height))
                    | {
                        label: "\(.refresh_rate / 1000 | round) Hz",
                        value: "\(.width)x\(.height)@\((.refresh_rate / 1000) * 1000 | round / 1000)",
                        active: ($active_mode != null and .width == $active_mode.width
                            and .height == $active_mode.height
                            and .refresh_rate == $active_mode.refresh_rate)
                      }
                  ] | unique_by(.label))
              }]
    ' 2>/dev/null || printf '[]\n'
}

vpn_state() {
    local line remainder name uuid type active active_uuids

    active_uuids=$(nmcli -t -f UUID connection show --active 2>/dev/null)

    while IFS= read -r line; do
        type=${line##*:}
        remainder=${line%:*}
        uuid=${remainder##*:}
        name=${remainder%:*}
        name=${name//\\:/:}
        name=${name//\\\\/\\}
        [[ $type == vpn || $type == wireguard ]] || continue
        if grep -Fqx -- "$uuid" <<< "$active_uuids"; then
            active=true
        else
            active=false
        fi
        jq -cn --arg name "$name" --arg uuid "$uuid" --arg type "$type" --argjson active "$active" \
            '{name: $name, uuid: $uuid, type: $type, active: $active}'
    done < <(nmcli -t -f NAME,UUID,TYPE connection show 2>/dev/null) | json_array_from_lines
}

state() {
    local wifi_enabled wifi_networks bluetooth_powered sinks sources displays vpns

    wifi_enabled=$([[ $(nmcli radio wifi 2>/dev/null) == enabled ]] && printf true || printf false)
    wifi_networks=$(wifi_state)
    bluetooth_powered=$([[ $(bluetoothctl show 2>/dev/null) == *'Powered: yes'* ]] && printf true || printf false)
    sinks=$(audio_nodes Sinks)
    sources=$(audio_nodes Sources)
    displays=$(display_state)
    vpns=$(vpn_state)

    jq -cn \
        --argjson wifi_enabled "$wifi_enabled" \
        --argjson wifi_networks "$wifi_networks" \
        --argjson bluetooth_powered "$bluetooth_powered" \
        --argjson bluetooth_devices "$(bluetooth_devices)" \
        --argjson sinks "$sinks" \
        --argjson sources "$sources" \
        --argjson displays "$displays" \
        --argjson vpns "$vpns" \
        '{wifi_enabled: $wifi_enabled, wifi_networks: $wifi_networks,
          bluetooth_powered: $bluetooth_powered, bluetooth_devices: $bluetooth_devices,
          sinks: $sinks, sources: $sources, displays: $displays, vpns: $vpns}'
}

action=${1:-state}
shift || true

case $action in
    state) state ;;
    wifi-power) nmcli radio wifi "${1:?Missing Wi-Fi state}" ;;
    wifi-connect)
        if [[ -n ${2:-} ]]; then
            nmcli connection up uuid "$2"
        else
            nmcli device wifi connect "${1:?Missing SSID}"
        fi
        ;;
    wifi-connect-password)
        nmcli device wifi connect "${1:?Missing SSID}" password "${2:?Missing password}"
        ;;
    wifi-disconnect) nmcli connection down uuid "${1:?Missing connection UUID}" ;;
    bluetooth-power) bluetoothctl power "${1:?Missing Bluetooth state}" ;;
    bluetooth-connect) bluetoothctl connect "${1:?Missing Bluetooth address}" ;;
    bluetooth-disconnect) bluetoothctl disconnect "${1:?Missing Bluetooth address}" ;;
    audio-default) wpctl set-default "${1:?Missing audio node ID}" ;;
    audio-mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
    microphone-mute) wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
    display-power)
        if [[ ${2:-} == off ]]; then
            enabled_outputs=$(niri msg -j outputs 2>/dev/null \
                | jq '[.[] | select(.current_mode != null)] | length')
            if ((enabled_outputs <= 1)); then
                printf 'The only active display cannot be disabled\n' >&2
                exit 1
            fi
        fi
        niri msg output "${1:?Missing output}" "${2:?Missing display state}"
        ;;
    display-mode) niri msg output "${1:?Missing output}" mode "${2:?Missing display mode}" ;;
    vpn-up) nmcli connection up uuid "${1:?Missing VPN UUID}" ;;
    vpn-down) nmcli connection down uuid "${1:?Missing VPN UUID}" ;;
    *)
        printf 'Unknown quick-settings action: %s\n' "$action" >&2
        exit 2
        ;;
esac
