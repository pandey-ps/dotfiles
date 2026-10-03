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
for item in "auto (all on, best res)" "laptop only" "external only" "arrange (gui)"; do
  key=$(echo "$item" | cut -d'(' -f1 | xargs | tr 'A-Z' 'a-z')
  if [ -n "$cur_layout" ] && [ "$key" = "$cur_layout" ]; then MENU="${MENU}▶ $item
"
  else MENU="${MENU}  $item
"
  fi
done
CHOICE=$(printf '%s' "$MENU" | fuzzel --dmenu --hide-prompt --lines=4) || exit 0
[ -z "${CHOICE:-}" ] && exit 0
CHOICE=$(echo "$CHOICE" | tr 'A-Z' 'a-z' | sed 's/^▶ *//; s/^ *//')
if ! command -v hyprctl >/dev/null 2>&1; then
  notify "hyprctl not found"
  exit 1
fi
MONS=$(hyprctl monitors all 2>/dev/null | awk '/^Monitor /{print $2}')
if [ -z "${MONS:-}" ]; then
  notify "no monitors reported by hyprctl"
  exit 1
fi
INTERNAL_RE="eDP|LVDS|DSI"
INTERNAL=$(echo "$MONS" | grep -E "$INTERNAL_RE" | head -1 || true)
EXTERNALS=$(echo "$MONS" | grep -v -E "^eDP|^LVDS|^DSI" || true)
EXT1=$(echo "$EXTERNALS" | head -1)
active_ws_on() {
  hyprctl monitors all 2>/dev/null | awk -v m="Monitor $1" 'index($0,m)==1{f=1;next} /^Monitor /{f=0} f && /active workspace:/{print $3; exit}'
}
ws_has_windows() {
  hyprctl workspaces 2>/dev/null | awk -v w="$1" '$1=="workspace" && $3==w{f=1;next} /^workspace /{f=0} f && $1=="windows:"{print ($2+0>0)?1:0; exit}'
}
mon_disabled() {
  hyprctl monitors all 2>/dev/null | awk -v m="Monitor $1" 'index($0,m)==1{f=1;next} /^Monitor /{f=0} f && /disabled:/{print ($2=="true")?1:0; exit}'
}
CARRY=""
FOCUS_MON=""
apply_mon() {
  out=$1; shift
  hyprctl eval "hl.monitor({output=\"$out\", $*})" >/dev/null 2>&1 || notify "failed to configure $out"
}
enable_mon() {
  [ "$(mon_disabled "$1")" = "1" ] || return 0
  apply_mon "$1" "mode=\"preferred\", position=\"${2:-auto}\", scale=1, disabled=false"
}
disable_mon() {
  hyprctl eval "hl.monitor({output=\"$1\", disabled=true})" >/dev/null 2>&1 || notify "failed to disable $1"
}
CHOICE1=$(echo "$CHOICE" | cut -d' ' -f1)
case "$CHOICE1" in
  auto)
    for out in $MONS; do enable_mon "$out"; done
    ;;
  laptop)
    CARRY=$(active_ws_on "$EXT1")
    FOCUS_MON="$INTERNAL"
    for out in $EXTERNALS; do disable_mon "$out"; done
    enable_mon "$INTERNAL"
    ;;
  external)
    if [ -z "${EXT1:-}" ]; then
      notify "no external monitor found"
    else
      CARRY=$(active_ws_on "$INTERNAL")
      FOCUS_MON="$EXT1"
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
sleep 1
echo "$CHOICE1" > "$LAYOUT_FILE" 2>/dev/null || true
pkill -x waybar 2>/dev/null || true
i=0
while [ "$i" -lt 3 ]; do
  nohup waybar >/dev/null 2>&1 &
  sleep 1
  pgrep -x waybar >/dev/null 2>&1 && break
  i=$((i + 1))
done
pkill -x hyprpaper 2>/dev/null || true
sleep 1
nohup hyprpaper >/dev/null 2>&1 &
case "$CARRY" in ''|*[!0-9]*) CARRY="" ;; esac
[ -z "$CARRY" ] || [ "$(ws_has_windows "$CARRY")" = "1" ] || CARRY=""
[ -n "$FOCUS_MON" ] && hyprctl dispatch "hl.dsp.focus({monitor=\"$FOCUS_MON\"})" >/dev/null 2>&1 || true
if [ -z "$CARRY" ]; then
  ACT=$(hyprctl activeworkspace 2>/dev/null | awk '/workspace ID/{print $3; exit}')
  case "$ACT" in ''|*[!0-9]*) ACT="" ;; esac
  [ "$(ws_has_windows "$ACT")" = "1" ] || CARRY=$(hyprctl workspaces 2>/dev/null | awk '/^workspace /{id=$3} $1=="windows:" && $2+0>0{print id; exit}')
fi
[ -n "$CARRY" ] && hyprctl dispatch "hl.dsp.focus({workspace=$CARRY})" >/dev/null 2>&1 || true
