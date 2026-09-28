#!/usr/bin/env bash

set -euo pipefail

repo_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
script=$repo_root/quickshell/.config/quickshell/scripts/fan-curves.sh
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT

cat > "$test_root/gpu-mode" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-} == --get ]]
printf 'Hybrid\n'
EOF

cat > "$test_root/asusctl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == profile && $2 == get ]]; then
    printf 'Active profile: Balanced\n'
elif [[ $1 == fan-curve && $2 == --get-enabled ]]; then
    printf 'CPU: enabled: true, 40c:0%%,60c:20%%\n'
    printf 'GPU: enabled: false, 45c:0%%,65c:30%%\n'
else
    exit 2
fi
EOF
chmod +x "$test_root/gpu-mode" "$test_root/asusctl"

result=$(ASUSCTL_COMMAND=$test_root/asusctl \
    GPU_MODE_COMMAND=$test_root/gpu-mode \
    COMMAND_TIMEOUT=1 \
    bash "$script")

jq -e '
    .gpu_mode == "Hybrid"
    and .fan_profile == "Balanced"
    and .cpu_fan_curve_enabled
    and (.gpu_fan_curve_enabled | not)
    and .cpu_fan_curve == [
        {temperature: 40, percent: 0},
        {temperature: 60, percent: 20}
    ]
' <<< "$result" >/dev/null

printf 'fan-curves tests passed\n'
