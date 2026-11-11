#!/bin/sh
set -u

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/waybar/update-count"
n=$(yay -Qu 2>/dev/null | wc -l)
[ -n "${n:-}" ] || n=0
mkdir -p "$(dirname "$CACHE")" 2>/dev/null || true
printf '%s' "$n" > "$CACHE" 2>/dev/null || true
[ "$n" -gt 0 ] && printf '↻'
