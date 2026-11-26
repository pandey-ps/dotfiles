#!/bin/sh
set -u

DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
FILE="$DIR/bar-bg.css"
mkdir -p "$DIR" 2>/dev/null || true

if grep -q '^window#waybar' "$FILE" 2>/dev/null; then
  printf '/* transparent bar */\n' > "$FILE"
else
  printf 'window#waybar { background-color: #000000; }\n' > "$FILE"
fi

kill -USR2 $(pgrep -x waybar) 2>/dev/null || true
