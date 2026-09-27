#!/bin/sh

config="$HOME/.config/quickshell/LockShell.qml"
runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
lock_pid=

cleanup() {
    if [ -n "$lock_pid" ] && kill -0 "$lock_pid" 2>/dev/null; then
        kill "$lock_pid" 2>/dev/null || :
        wait "$lock_pid" 2>/dev/null || :
    fi
}

trap 'cleanup; exit 1' HUP INT TERM

exec 9>"$runtime_dir/quickshell-lock.lock" || exit 1
flock 9 || exit 1

if [ "$(qs ipc -p "$config" call lock isSecure 2>/dev/null)" = "true" ]; then
    exit 0
fi

qs -n -p "$config" >/dev/null 2>&1 &
lock_pid=$!

attempt=0
while [ "$attempt" -lt 100 ]; do
    if [ "$(qs ipc -p "$config" call lock isSecure 2>/dev/null)" = "true" ]; then
        lock_pid=
        exit 0
    fi

    if ! kill -0 "$lock_pid" 2>/dev/null; then
        wait "$lock_pid" 2>/dev/null || :
        lock_pid=
        exit 1
    fi

    attempt=$((attempt + 1))
    sleep 0.1
done

cleanup
exit 1
