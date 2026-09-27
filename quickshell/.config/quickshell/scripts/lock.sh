#!/bin/sh

config="$HOME/.config/quickshell/LockShell.qml"
runtime_dir=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
lock_unit=quickshell-lock-shell.service
lock_pid=
started_unit=

is_secure() {
    result=$(timeout --foreground --signal=TERM --kill-after=0.1s 0.25s \
        qs ipc "$@" call lock isSecure 2>/dev/null) || return 1
    [ "$result" = "true" ]
}

cleanup() {
    [ -n "$started_unit" ] || return
    systemctl --user stop "$lock_unit" >/dev/null 2>&1 || :
}

trap 'cleanup; exit 1' HUP INT TERM

exec 9>"$runtime_dir/quickshell-lock.lock" || exit 1

if is_secure -p "$config"; then
    exit 0
fi

if ! flock -w 2 9; then
    is_secure -p "$config"
    exit $?
fi

if is_secure -p "$config"; then
    exit 0
fi

systemctl --user reset-failed "$lock_unit" >/dev/null 2>&1 || :
systemctl --user start "$lock_unit" || exit 1
started_unit=true

lock_pid=$(systemctl --user show "$lock_unit" -p MainPID --value 2>/dev/null)
case "$lock_pid" in
    ''|0|*[!0-9]*)
        cleanup
        exit 1
        ;;
esac

attempt=0
while [ "$attempt" -lt 25 ]; do
    if is_secure --pid "$lock_pid"; then
        started_unit=
        exit 0
    fi

    if ! kill -0 "$lock_pid" 2>/dev/null; then
        started_unit=
        exit 1
    fi

    attempt=$((attempt + 1))
    sleep 0.1
done

cleanup
exit 1
