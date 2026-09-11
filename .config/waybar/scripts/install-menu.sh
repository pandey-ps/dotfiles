#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Install" "$1" 2>/dev/null || true
}

if ! command -v fuzzel >/dev/null 2>&1; then
  notify "fuzzel not installed"
  exit 1
fi

SRC=$(printf 'arch\naur\n' | fuzzel --dmenu --hide-prompt --lines=2) || exit 0
SRC=$(printf '%s' "${SRC:-}" | sed 's/^ *//')
[ -n "$SRC" ] || exit 0

case "$SRC" in
  arch)
    LIST=$(pacman -Slq 2>/dev/null || true)
    ;;
  aur)
    HELPER="yay"
    if ! command -v yay >/dev/null 2>&1; then notify "yay not installed"; exit 1; fi
    CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/install-menu"
    CACHE_FILE="$CACHE_DIR/aur-list"
    mkdir -p "$CACHE_DIR" 2>/dev/null || true
    if [ -s "$CACHE_FILE" ]; then
      LIST=$(cat "$CACHE_FILE")
      if [ -z "$(find "$CACHE_FILE" -mmin -60 2>/dev/null)" ]; then
        ($HELPER -Slq > "$CACHE_FILE.tmp" 2>/dev/null && mv "$CACHE_FILE.tmp" "$CACHE_FILE") &
      fi
    else
      LIST=$($HELPER -Slq 2>/dev/null || true)
      [ -n "${LIST:-}" ] && printf '%s\n' "$LIST" > "$CACHE_FILE" 2>/dev/null || true
    fi
    ;;
  *) exit 0 ;;
esac
if [ -z "${LIST:-}" ]; then
  notify "package list empty"
  exit 0
fi

PKG=$(printf '%s\n' "$LIST" | fuzzel --dmenu --prompt="search: " --match-mode=exact --lines=12) || exit 0
PKG=$(printf '%s' "${PKG:-}" | sed 's/^ *//;s/ *$//')
[ -n "$PKG" ] || exit 0

case "$SRC" in
  arch)
    REAL=$(pacman -Slq 2>/dev/null | grep -xF "$PKG" | head -1 || true)
    [ -n "${REAL:-}" ] || { notify "not an arch package: $PKG"; exit 0; }
    INSTALL_CMD="sudo pacman -S --needed $REAL"
    ;;
  aur)
    if ! $HELPER -Si "$PKG" >/dev/null 2>&1; then
      notify "not an aur package: $PKG"
      exit 0
    fi
    INSTALL_CMD="$HELPER -S --needed $PKG"
    ;;
esac

if ! command -v alacritty >/dev/null 2>&1; then
  notify "alacritty not installed"
  exit 1
fi
alacritty --title "install $PKG" -e sh -c "$INSTALL_CMD; echo; printf 'done - press enter '; read -r _" >/dev/null 2>&1 &
