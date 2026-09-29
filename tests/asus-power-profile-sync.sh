#!/usr/bin/env bash

set -euo pipefail

test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

mock_bin=$test_root/bin
state_dir=$test_root/state
power_supply_path=$test_root/power_supply
mkdir -p "$mock_bin" "$state_dir" "$power_supply_path"

cat > "$mock_bin/asusctl" <<'EOF'
#!/bin/sh

set -eu

case ${1:-}': '${2:-} in
    'profile: set')
        profile=$3
        case ${4:-} in
            --ac)
                printf '%s\n' "$profile" > "$ASUSCTL_STATE_DIR/ac"
                ;;
            --battery)
                printf '%s\n' "$profile" > "$ASUSCTL_STATE_DIR/battery"
                ;;
        esac
        if [ "${ASUSCTL_IGNORE_ACTIVE:-0}" != 1 ]; then
            printf '%s\n' "$profile" > "$ASUSCTL_STATE_DIR/active"
        fi
        ;;
    'profile: get')
        printf 'Active profile: %s\n' "$(cat "$ASUSCTL_STATE_DIR/active")"
        printf 'AC profile %s\n' "$(cat "$ASUSCTL_STATE_DIR/ac")"
        printf 'Battery profile %s\n' "$(cat "$ASUSCTL_STATE_DIR/battery")"
        ;;
    *)
        exit 2
        ;;
esac
EOF
chmod +x "$mock_bin/asusctl"

helper=system/usr/libexec/asus-power-profile-sync

reset_state() {
    printf 'Performance\n' > "$state_dir/active"
    printf 'Performance\n' > "$state_dir/ac"
    printf 'Performance\n' > "$state_dir/battery"
    rm -rf "$power_supply_path"
    mkdir -p "$power_supply_path/AC" "$power_supply_path/BAT"
    printf 'Mains\n' > "$power_supply_path/AC/type"
    printf '%s\n' "$1" > "$power_supply_path/AC/online"
    printf 'Battery\n' > "$power_supply_path/BAT/type"
}

run_helper() {
    ASUSCTL_COMMAND=$mock_bin/asusctl \
        ASUSCTL_STATE_DIR=$state_dir \
        POWER_SUPPLY_PATH=$power_supply_path \
        "$helper" "$@"
}

reset_state 1
run_helper configure >/dev/null
[[ $(< "$state_dir/ac") == Balanced ]]
[[ $(< "$state_dir/battery") == Quiet ]]
[[ $(< "$state_dir/active") == Balanced ]]

reset_state 0
run_helper configure >/dev/null
[[ $(< "$state_dir/ac") == Balanced ]]
[[ $(< "$state_dir/battery") == Quiet ]]
[[ $(< "$state_dir/active") == Quiet ]]

printf 'Balanced\n' > "$state_dir/ac"
printf 'Quiet\n' > "$state_dir/battery"
printf 'Performance\n' > "$state_dir/active"
run_helper apply >/dev/null
[[ $(< "$state_dir/active") == Quiet ]]

printf 'Performance\n' > "$state_dir/active"
if ASUSCTL_IGNORE_ACTIVE=1 run_helper apply >/dev/null 2>&1; then
    printf 'Expected profile verification failure\n' >&2
    exit 1
fi

printf 'asus-power-profile-sync tests passed\n'
