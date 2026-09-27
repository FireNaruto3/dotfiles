#!/bin/sh

set -eu

clear_entry='[Clear clipboard history]'
history=$(cliphist list 2>/dev/null) || history=

# Keep the picker and existing database bounded even if the watcher used
# cliphist's larger default.
overflow=$(printf '%s\n' "$history" | tail -n +201)
if [ -n "$overflow" ]; then
    printf '%s\n' "$overflow" | cliphist delete
    history=$(printf '%s\n' "$history" | head -n 200)
fi

selection=$(
    { printf '%s\n' "$clear_entry"; [ -z "$history" ] || printf '%s\n' "$history"; } \
        | rofi -dmenu -i -p "Clipboard"
) || exit 0
[ -n "$selection" ] || exit 0

if [ "$selection" = "$clear_entry" ]; then
    confirmation=$(printf 'Cancel\nClear history\n' | rofi -dmenu -i -no-custom -p "Clear clipboard history?") || exit 0
    [ "$confirmation" = 'Clear history' ] || exit 0
    cliphist wipe
    wl-copy --clear
    exit 0
fi

printf '%s\n' "$selection" | cliphist decode | wl-copy
