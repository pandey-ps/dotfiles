#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Display" "$1" 2>/dev/null || true
}

if ! command -v fuzzel >/dev/null 2>&1; then
  notify "fuzzel not installed"
  exit 1
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/display-menu"
mkdir -p "$CACHE_DIR" 2>/dev/null || true
LAYOUT_FILE="$CACHE_DIR/layout"
cur_layout=$(cat "$LAYOUT_FILE" 2>/dev/null || echo "")
MENU=""
for item in "auto (all on, best res)" "mirror (same image on all)" "extend right" "extend left" "laptop only" "external only" "arrange (gui)"; do
  key=$(echo "$item" | cut -d'(' -f1 | xargs | tr 'A-Z' 'a-z')
  if [ -n "$cur_layout" ] && [ "$key" = "$cur_layout" ]; then MENU="${MENU}▶ $item
"
  else MENU="${MENU}  $item
"
  fi
done
CHOICE=$(printf '%s' "$MENU" | fuzzel --dmenu --lines=7) || exit 0
[ -z "${CHOICE:-}" ] && exit 0
CHOICE=$(echo "$CHOICE" | tr 'A-Z' 'a-z' | sed 's/^▶ *//; s/^ *//')
if ! command -v hyprctl >/dev/null 2>&1; then
  notify "hyprctl not found"
  exit 1
fi
MONS=$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}')
if [ -z "${MONS:-}" ]; then
  notify "no monitors reported by hyprctl"
  exit 1
fi
INTERNAL_RE="eDP|LVDS|DSI"
INTERNAL=$(echo "$MONS" | grep -E "$INTERNAL_RE" | head -1 || true)
EXTERNALS=$(echo "$MONS" | grep -v -E "^eDP|^LVDS|^DSI" || true)
EXT1=$(echo "$EXTERNALS" | head -1)
[ -z "$INTERNAL" ] && INTERNAL=$(echo "$MONS" | head -1)
apply_mon() {
  out=$1; shift
  hyprctl eval "hl.monitor({output=\"$out\", $*})" >/dev/null 2>&1 || notify "failed to configure $out"
}
enable_mon() {
  apply_mon "$1" "mode=\"preferred\", position=\"${2:-auto}\", scale=1"
}
disable_mon() {
  hyprctl eval "hl.monitor({output=\"$1\", disabled=true})" >/dev/null 2>&1 || notify "failed to disable $1"
}
CHOICE1=$(echo "$CHOICE" | cut -d' ' -f1)
case "$CHOICE1" in
  auto)
    for out in $MONS; do enable_mon "$out"; done
    ;;
  mirror)
    if [ -z "${EXTERNALS:-}" ]; then
      notify "only one monitor: nothing to mirror"
    else
      for out in $EXTERNALS; do apply_mon "$out" "mode=\"preferred\", position=\"auto\", scale=1, mirror=\"$INTERNAL\""; done
    fi
    ;;
  extend)
    enable_mon "$INTERNAL" "0x0"
    if echo "$CHOICE" | grep -q "left"; then
      [ -n "${EXT1:-}" ] && enable_mon "$EXT1" "auto-left"
    else
      [ -n "${EXT1:-}" ] && enable_mon "$EXT1" "auto-right"
    fi
    [ -z "${EXT1:-}" ] && notify "only one monitor: nothing to extend to"
    ;;
  laptop)
    for out in $EXTERNALS; do disable_mon "$out"; done
    enable_mon "$INTERNAL"
    ;;
  external)
    if [ -z "${EXT1:-}" ]; then
      notify "no external monitor found"
    else
      enable_mon "$EXT1"
      for out in $EXTERNALS; do [ "$out" != "$EXT1" ] && enable_mon "$out" "auto-right"; done
      disable_mon "$INTERNAL"
    fi
    ;;
  arrange)
    if command -v wdisplays >/dev/null 2>&1; then
      hyprctl dispatch 'hl.dsp.exec_cmd("wdisplays")' >/dev/null 2>&1 || wdisplays >/dev/null 2>&1 &
    else
      notify "wdisplays not installed"
    fi
    exit 0
    ;;
  *) exit 0 ;;
esac
echo "$CHOICE1" > "$LAYOUT_FILE" 2>/dev/null || true
