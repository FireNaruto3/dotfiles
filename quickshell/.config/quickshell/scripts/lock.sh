#!/bin/sh

config="$HOME/.config/quickshell/LockShell.qml"

qs -d -n -p "$config" || exit 1

attempt=0
while [ "$attempt" -lt 100 ]; do
    if [ "$(qs ipc -p "$config" call lock isSecure 2>/dev/null)" = "true" ]; then
        exit 0
    fi

    attempt=$((attempt + 1))
    sleep 0.1
done

# Keep a proven locker available if Quickshell cannot acquire the protocol.
if command -v gtklock >/dev/null 2>&1; then
    exec gtklock -d \
        -s "$HOME/.config/gtklock/style.css" \
        -x "$HOME/.config/gtklock/layout.xml" \
        -b "$HOME/dotfiles/wallpapers/Karina5.jpg"
fi

exit 1
