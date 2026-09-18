#!/usr/bin/env bash

set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script=$repo_root/scripts/.local/bin/gpu-mode
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

mock_bin=$test_root/bin
state_dir=$test_root/state
mkdir -p "$mock_bin" "$state_dir"

cat > "$mock_bin/asusctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state_dir=${GPU_MODE_TEST_STATE:?}
if [[ $1 == armoury && $2 == get ]]; then
    value=$(<"$state_dir/current-$3")
    printf '%s:\n  current: [%s,(%s)]\n' "$3" "$((1 - value))" "$value"
elif [[ $1 == armoury && $2 == set ]]; then
    printf '%s' "$4" > "$state_dir/queued-$3"
else
    exit 2
fi
EOF

cat > "$mock_bin/busctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state_dir=${GPU_MODE_TEST_STATE:?}
property=${3##*/}
if [[ -r $state_dir/queued-$property ]]; then
    value=$(<"$state_dir/queued-$property")
else
    value=-1
fi
printf 'i %s\n' "$value"
EOF

cat > "$mock_bin/systemctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
state_dir=${GPU_MODE_TEST_STATE:?}
if [[ $1 == is-active ]]; then
    [[ ${@: -1} != supergfxd.service ]] || exit 3
    [[ ${2:-} == --quiet ]] || printf 'active\n'
elif [[ $1 == reboot ]]; then
    [[ ! -e $state_dir/fail-reboot ]] || exit 1
    : > "$state_dir/rebooted"
else
    exit 2
fi
EOF

chmod +x "$mock_bin/asusctl" "$mock_bin/busctl" "$mock_bin/systemctl"
export PATH="$mock_bin:$PATH"
export GPU_MODE_TEST_STATE=$state_dir
export XDG_RUNTIME_DIR=$test_root

assert_eq() {
    local expected=$1
    local actual=$2
    [[ $actual == "$expected" ]] || {
        printf 'Expected %q, got %q\n' "$expected" "$actual" >&2
        exit 1
    }
}

set_current() {
    printf '%s' "$1" > "$state_dir/current-dgpu_disable"
    printf '%s' "$2" > "$state_dir/current-gpu_mux_mode"
    rm -f "$state_dir"/queued-* "$state_dir/rebooted"
}

set_current 0 1
assert_eq Hybrid "$("$script" --get)"

status=$("$script" status)
[[ $status == *'Configured mode: Hybrid'* ]]
[[ $status == *'dGPU runtime power:'* ]]
[[ $status == *'Queued mode: None'* ]]
[[ $status == *'Services: asusd=active, asus-shutdown=active, supergfxd=inactive'* ]]

"$script" --yes integrated >/dev/null
assert_eq 1 "$(<"$state_dir/queued-dgpu_disable")"
assert_eq 1 "$(<"$state_dir/queued-gpu_mux_mode")"
[[ -e $state_dir/rebooted ]]

set_current 0 0
assert_eq Ultimate "$("$script" --get)"
assert_eq 'Ultimate is already active.' "$("$script" ultimate)"

set_current 1 1
printf '0' > "$state_dir/queued-dgpu_disable"
if "$script" --yes hybrid >"$test_root/conflict.out" 2>"$test_root/conflict.err"; then
    printf 'Expected a partial queue to be rejected\n' >&2
    exit 1
fi
[[ $(<"$test_root/conflict.err") == *'queued GPU mode (Partial)'* ]]

set_current 0 1
: > "$state_dir/fail-reboot"
if "$script" --yes ultimate >"$test_root/reboot.out" 2>"$test_root/reboot.err"; then
    printf 'Expected a failed reboot request to be rejected\n' >&2
    exit 1
fi
assert_eq 0 "$(<"$state_dir/queued-dgpu_disable")"
assert_eq 1 "$(<"$state_dir/queued-gpu_mux_mode")"
[[ $(<"$test_root/reboot.err") == *'pending change was neutralized'* ]]

printf 'gpu-mode tests passed\n'
