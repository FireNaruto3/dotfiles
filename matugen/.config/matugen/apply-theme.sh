#!/usr/bin/env bash

set -euo pipefail

config_home=${XDG_CONFIG_HOME:-"$HOME/.config"}
cache_home=${XDG_CACHE_HOME:-"$HOME/.cache"}
cache_dir="$cache_home/matugen"
start_command=""

if [[ ${1:-} == --start ]]; then
    start_command=${2:-}
    shift 2
fi

wallpaper=${1:-}
if [[ -z $wallpaper ]]; then
    shopt -s extglob
    while IFS='=' read -r key value; do
        [[ ${key//[[:space:]]/} == wallpaper ]] || continue
        value=${value##+([[:space:]])}
        value=${value%%+([[:space:]])}
        wallpaper=${value/#\~/$HOME}
        break
    done < "$config_home/waypaper/config.ini"
fi

if [[ -z $wallpaper || ! -f $wallpaper ]]; then
    printf 'Unable to resolve wallpaper for dynamic theme: %s\n' "$wallpaper" >&2
    [[ -z $start_command ]] || exec "$start_command"
    exit 1
fi

matugen_bin=$(command -v matugen || true)
if [[ -z $matugen_bin ]]; then
    printf 'matugen is not installed; keeping the static theme\n' >&2
    [[ -z $start_command ]] || exec "$start_command"
    exit 1
fi

mkdir -p "$cache_dir" "$config_home/ghostty/themes"
exec 9>"$cache_dir/apply.lock"
flock 9

"$matugen_bin" image \
    --quiet \
    --type scheme-fidelity \
    --config "$config_home/matugen/config.toml" \
    "$wallpaper"

# Do not carry the exclusive lock into long-running startup processes.
flock -u 9
exec 9>&-

if [[ -n $start_command ]]; then
    if [[ $start_command == mako ]]; then
        exec mako --config "$cache_dir/mako"
    fi
    exec "$start_command"
fi

if pgrep -x mako >/dev/null; then
    makoctl reload || true
fi

if pgrep -x ghostty >/dev/null && command -v gapplication >/dev/null; then
    gapplication action com.mitchellh.ghostty reload-config || true
fi
