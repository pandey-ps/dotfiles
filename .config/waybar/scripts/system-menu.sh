#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "System" "$1" 2>/dev/null || true
}

if ! command -v fuzzel >/dev/null 2>&1; then
  notify "fuzzel not installed"
  exit 1
fi

CHOICE=$(printf 'shutdown\nreboot\nreboot (win)\nsleep\n' | fuzzel --dmenu --hide-prompt --lines=4) || exit 0
[ -z "${CHOICE:-}" ] && exit 0
CHOICE=$(printf '%s' "$CHOICE" | tr 'A-Z' 'a-z' | sed 's/^ *//;s/ *$//')

case "$CHOICE" in
  shutdown) systemctl poweroff ;;
  reboot) systemctl reboot ;;
  "reboot (win)") alacritty --title "reboot windows" -e sh -c '~/.config/waybar/scripts/reboot-windows.sh; printf "\npress enter "; read -r _' >/dev/null 2>&1 & ;;
  sleep) systemctl suspend ;;
  *) exit 0 ;;
esac
