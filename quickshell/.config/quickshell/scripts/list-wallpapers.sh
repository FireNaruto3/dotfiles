#!/usr/bin/env bash

set -u
shopt -s nullglob nocaseglob

directory="/home/jonathan/dotfiles/wallpapers"
files=(
    "$directory"/*.jpg
    "$directory"/*.jpeg
    "$directory"/*.png
    "$directory"/*.webp
    "$directory"/*.avif
)

printf '%s\0' "${files[@]}" \
    | sort -z \
    | jq -Rs '
        split("\u0000")
        | map(select(length > 0))
        | map({
            source: ("file://" + .),
            name: (split("/")[-1] | sub("\\.[^.]+$"; ""))
        })
    '
