#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Wallpaper" "$1" 2>/dev/null || true
}

if ! command -v fuzzel >/dev/null 2>&1; then
  notify "fuzzel not installed"
  exit 1
fi

DIR="$HOME/dotfiles/wallpapers"
if [ ! -d "$DIR" ]; then
  notify "no wallpapers directory found"
  exit 1
fi

LIST=$(find "$DIR" -maxdepth 1 -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) -printf "%f\n" 2>/dev/null | sort || true)
if [ -z "${LIST:-}" ]; then
  notify "no wallpapers in $DIR"
  exit 0
fi

COUNT=$(printf '%s\n' "$LIST" | wc -l)
[ "$COUNT" -gt 12 ] && COUNT=12
[ "$COUNT" -lt 2 ] && COUNT=2

CHOICE=$(printf '%s\n' "$LIST" | fuzzel --dmenu --prompt="wallpaper: " --match-mode=exact --lines="$COUNT") || exit 0
CHOICE=$(printf '%s' "${CHOICE:-}" | sed 's/^ *//;s/ *$//')
[ -n "$CHOICE" ] || exit 0

FILE="$DIR/$CHOICE"
[ -f "$FILE" ] || { notify "not found: $CHOICE"; exit 0; }

if command -v hyprctl >/dev/null 2>&1; then
  hyprctl hyprpaper wallpaper ",$FILE,cover" >/dev/null 2>&1 || true
fi
for conf in "$HOME/.config/hypr/hyprpaper.conf" "$HOME/dotfiles/.config/hypr/hyprpaper.conf" "$HOME/.config/hypr/hyprlock.conf" "$HOME/dotfiles/.config/hypr/hyprlock.conf"; do
  [ -f "$conf" ] || continue
  sed -i "s|^[[:space:]]*path = .*|    path = $FILE|" "$conf" 2>/dev/null || true
done
notify "$CHOICE"
