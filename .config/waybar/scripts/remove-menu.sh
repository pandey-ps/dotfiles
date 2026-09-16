#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Remove" "$1" 2>/dev/null || true
}

if ! command -v fuzzel >/dev/null 2>&1; then
  notify "fuzzel not installed"
  exit 1
fi

LIST=$(pacman -Qeq 2>/dev/null || true)
if [ -z "${LIST:-}" ]; then
  notify "no installed packages found"
  exit 0
fi

PKG=$(printf '%s\n' "$LIST" | fuzzel --dmenu --prompt="remove: " --match-mode=fzf --lines=12) || exit 0
PKG=$(printf '%s' "${PKG:-}" | sed 's/^ *//;s/ *$//')
[ -n "$PKG" ] || exit 0

if ! pacman -Qq "$PKG" >/dev/null 2>&1; then
  notify "not installed: $PKG"
  exit 0
fi

CONFIRM=$(printf 'no\nyes\n' | fuzzel --dmenu --prompt="remove $PKG? " --lines=2) || exit 0
[ "$CONFIRM" = "yes" ] || exit 0

if ! command -v alacritty >/dev/null 2>&1; then
  notify "alacritty not installed"
  exit 1
fi
alacritty --title "remove $PKG" -e sh -c "sudo pacman -Rns $PKG; echo; printf 'done - press enter '; read -r _" >/dev/null 2>&1 &
