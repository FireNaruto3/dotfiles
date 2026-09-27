#!/bin/sh

for brightness in /sys/class/leds/*::capslock/brightness; do
    [ -r "$brightness" ] || continue
    IFS= read -r value < "$brightness"
    if [ "$value" = 1 ]; then
        printf 'true\n'
        exit 0
    fi
done

printf 'false\n'
