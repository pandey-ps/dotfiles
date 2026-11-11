#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Update" "$1" 2>/dev/null || true
}

info_panel() {
  COUNT=$(printf '%s\n' "$1" | wc -l)
  [ "$COUNT" -gt 6 ] && COUNT=6
  [ "$COUNT" -lt 2 ] && COUNT=2
  printf '%s\n' "$1" | fuzzel --dmenu --hide-prompt --lines="$COUNT" >/dev/null 2>&1 || true
  exit 0
}

if ! command -v fuzzel >/dev/null 2>&1; then
  notify "fuzzel not installed"
  exit 1
fi
if ! command -v yay >/dev/null 2>&1; then
  info_panel "  yay not installed (AUR helper needed)"
fi

UPD=$(yay -Qu 2>/dev/null | wc -l)
[ -n "${UPD:-}" ] || UPD=0

if [ "$UPD" -eq 0 ]; then
  info_panel "  system up to date"
fi

CHOICE=$(printf 'update system (%s packages)\n' "$UPD" | fuzzel --dmenu --hide-prompt --lines=2) || exit 0
[ -n "${CHOICE:-}" ] || exit 0
case "$CHOICE" in
  update\ system*) ;;
  *) exit 0 ;;
esac

if ! command -v alacritty >/dev/null 2>&1; then
  notify "alacritty not installed"
  exit 0
fi

alacritty --title "system update" -e "$HOME/.config/waybar/scripts/update-run.sh" >/dev/null 2>&1 &
