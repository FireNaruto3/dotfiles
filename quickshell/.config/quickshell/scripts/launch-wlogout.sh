#!/bin/sh

set -eu

style="$HOME/.cache/matugen/wlogout.css"
if [ -s "$style" ]; then
    exec wlogout --css "$style" --buttons-per-row 2
fi

exec wlogout --buttons-per-row 2
