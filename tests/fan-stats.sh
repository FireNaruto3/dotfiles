#!/usr/bin/env bash

set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script=$repo_root/quickshell/.config/quickshell/scripts/fan-stats.sh
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

sysfs_root=$test_root/sys
mock_bin=$test_root/bin
nvidia_log=$test_root/nvidia-smi.log
mkdir -p "$mock_bin"

cat > "$mock_bin/nvidia-smi" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "${NVIDIA_LOG:?}"
printf '%s\n' "${NVIDIA_TEMP:-71}"
[[ ${NVIDIA_FAIL:-false} != true ]]
EOF
chmod +x "$mock_bin/nvidia-smi"

reset_fixture() {
    rm -rf "$sysfs_root"
    rm -f "$nvidia_log"
    mkdir -p "$sysfs_root/class/hwmon/hwmon17" "$sysfs_root/class/hwmon/hwmon3"
    printf 'k10temp\n' > "$sysfs_root/class/hwmon/hwmon17/name"
    printf 'Tctl\n' > "$sysfs_root/class/hwmon/hwmon17/temp1_label"
    printf '48000\n' > "$sysfs_root/class/hwmon/hwmon17/temp1_input"
    printf 'asus\n' > "$sysfs_root/class/hwmon/hwmon3/name"
    printf 'cpu_fan\n' > "$sysfs_root/class/hwmon/hwmon3/fan1_label"
    printf '2600\n' > "$sysfs_root/class/hwmon/hwmon3/fan1_input"
    printf 'gpu-fan\n' > "$sysfs_root/class/hwmon/hwmon3/fan2_label"
    printf '0\n' > "$sysfs_root/class/hwmon/hwmon3/fan2_input"
    printf 'mid fan\n' > "$sysfs_root/class/hwmon/hwmon3/fan3_label"
    printf '900\n' > "$sysfs_root/class/hwmon/hwmon3/fan3_input"
}

add_nvidia() {
    local runtime_state=$1
    local device=$sysfs_root/bus/pci/devices/0000:01:00.0
    mkdir -p "$device/power"
    printf '0x10de\n' > "$device/vendor"
    printf '0x030000\n' > "$device/class"
    printf '%s\n' "$runtime_state" > "$device/power/runtime_status"
}

add_second_nvidia() {
    local device=$sysfs_root/bus/pci/devices/0000:02:00.0
    mkdir -p "$device/power"
    printf '0x10de\n' > "$device/vendor"
    printf '0x030200\n' > "$device/class"
    printf 'active\n' > "$device/power/runtime_status"
}

add_nvidia_hwmon() {
    local device=$sysfs_root/bus/pci/devices/0000:01:00.0
    mkdir -p "$device/hwmon/hwmon42"
    printf 'nvidia\n' > "$device/hwmon/hwmon42/name"
    printf 'edge\n' > "$device/hwmon/hwmon42/temp1_label"
    printf '69000\n' > "$device/hwmon/hwmon42/temp1_input"
    printf 'hotspot\n' > "$device/hwmon/hwmon42/temp2_label"
    printf '85000\n' > "$device/hwmon/hwmon42/temp2_input"
}

collect() {
    SYSFS_ROOT=$sysfs_root \
    NVIDIA_SMI_COMMAND=$mock_bin/nvidia-smi \
    NVIDIA_LOG=$nvidia_log \
    NVIDIA_FAIL=${NVIDIA_FAIL:-false} \
    COMMAND_TIMEOUT=1 \
        bash "$script" "$1"
}

assert_jq() {
    local json=$1
    local expression=$2
    jq -e "$expression" <<< "$json" >/dev/null || {
        printf 'Assertion failed: %s\nJSON: %s\n' "$expression" "$json" >&2
        exit 1
    }
}

reset_fixture
result=$(collect Integrated)
assert_jq "$result" '.gpu_mode == "Integrated" and .gpu_temp_state == "disabled"'
assert_jq "$result" '.cpu_temp == 48 and .cpu_temp_available'
assert_jq "$result" '.cpu_fan == 2600 and .cpu_fan_available'
assert_jq "$result" '.gpu_fan == 0 and .gpu_fan_available'
assert_jq "$result" '.mid_fan == 900 and .mid_fan_available'
[[ ! -e $nvidia_log ]]

reset_fixture
add_nvidia suspended
add_nvidia_hwmon
result=$(collect Hybrid)
assert_jq "$result" '.gpu_temp_state == "suspended" and (.gpu_temp_available | not)'
[[ ! -e $nvidia_log ]]

printf 'active\n' > "$sysfs_root/bus/pci/devices/0000:01:00.0/power/runtime_status"
result=$(collect Hybrid)
assert_jq "$result" '.gpu_temp_state == "active" and (.gpu_temp_available | not)'
[[ ! -e $nvidia_log ]]

reset_fixture
add_nvidia active
add_nvidia_hwmon
result=$(collect Ultimate)
assert_jq "$result" '.gpu_temp == 69 and .gpu_temp_available and .gpu_temp_state == "active"'
assert_jq "$result" '.gpu_pci_address == "0000:01:00.0"'
[[ ! -e $nvidia_log ]]

rm -rf "$sysfs_root/bus/pci/devices/0000:01:00.0/hwmon"
result=$(collect Ultimate)
assert_jq "$result" '.gpu_temp == 71 and .gpu_temp_available and .gpu_temp_state == "active"'
grep -Fq -- '--id=0000:01:00.0' "$nvidia_log"

rm -f "$nvidia_log"
NVIDIA_FAIL=true result=$(collect Ultimate)
assert_jq "$result" '(.gpu_temp_available | not) and .gpu_temp_state == "unavailable"'
unset NVIDIA_FAIL

reset_fixture
add_nvidia active
add_second_nvidia
result=$(collect Ultimate)
assert_jq "$result" '.gpu_temp_state == "ambiguous" and (.gpu_temp_available | not)'
[[ ! -e $nvidia_log ]]

reset_fixture
mkdir -p "$sysfs_root/class/hwmon/hwmon99"
printf 'asus\n' > "$sysfs_root/class/hwmon/hwmon99/name"
printf 'CPU Fan\n' > "$sysfs_root/class/hwmon/hwmon99/fan1_label"
printf '3100\n' > "$sysfs_root/class/hwmon/hwmon99/fan1_input"
result=$(collect Integrated)
assert_jq "$result" '.cpu_fan_state == "ambiguous" and (.cpu_fan_available | not)'
assert_jq "$result" '.gpu_fan_available and .mid_fan_available'

printf 'not-a-number\n' > "$sysfs_root/class/hwmon/hwmon99/fan1_input"
result=$(collect Integrated)
assert_jq "$result" '.cpu_fan_state == "ambiguous" and (.cpu_fan_available | not)'

reset_fixture
mkdir -p "$sysfs_root/class/hwmon/hwmon2"
printf 'k10temp\n' > "$sysfs_root/class/hwmon/hwmon2/name"
printf 'Tctl\n' > "$sysfs_root/class/hwmon/hwmon2/temp1_label"
printf '51000\n' > "$sysfs_root/class/hwmon/hwmon2/temp1_input"
result=$(collect Integrated)
assert_jq "$result" '.cpu_temp_state == "ambiguous" and (.cpu_temp_available | not)'

printf 'fan-stats tests passed\n'
