#!/bin/sh
# clock display for waybar: shows day+time, click toggles date.
# usage: clock.sh [show|toggle]
set -u

F="${XDG_CACHE_HOME:-$HOME/.cache}/waybar-clock-mode"

case "${1:-show}" in
  toggle)
    if [ "$(cat "$F" 2>/dev/null)" = "date" ]; then printf 'time' > "$F"
    else printf 'date' > "$F"
    fi
    pkill -RTMIN+8 waybar 2>/dev/null || true
    ;;
  *)
    if [ "$(cat "$F" 2>/dev/null)" = "date" ]; then date +'%Y-%m-%d'
    else date +'%a, %H:%M' | tr 'A-Z' 'a-z'
    fi
    ;;
esac
