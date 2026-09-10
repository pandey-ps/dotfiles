#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Audio" "$1" 2>/dev/null || true
}

if ! command -v fuzzel >/dev/null 2>&1; then
  notify "fuzzel not installed"
  exit 1
fi
if ! command -v pactl >/dev/null 2>&1; then
  notify "pactl not installed"
  exit 1
fi

get_sink() { pactl get-default-sink 2>/dev/null || pactl info 2>/dev/null | awk -F': ' '/Default Sink/{print $2}'; }
get_src()  { pactl get-default-source 2>/dev/null || pactl info 2>/dev/null | awk -F': ' '/Default Source/{print $2}'; }
CUR_SINK=$(get_sink || true)
CUR_SRC=$(get_src || true)

flat_list() {
  pactl list sinks 2>/dev/null | awk '
    /Name: /{n=$2}
    /Description: /{d=substr($0,index($0,$2)); printf "%s|%s\n", n, d}
  ' | while IFS='|' read -r name desc; do
    [ -n "${name:-}" ] || continue
    mark=" "; [ "${name:-}" = "${CUR_SINK:-}" ] && mark="▶"
    printf "%s output: %s\n" "$mark" "$(printf '%s' "$desc" | tr 'A-Z' 'a-z')"
  done
  pactl list sources 2>/dev/null | awk '
    /Name: /{n=$2}
    /Description: /{d=substr($0,index($0,$2)); if (n !~ /\.monitor$/) printf "%s|%s\n", n, d}
  ' | while IFS='|' read -r name desc; do
    [ -n "${name:-}" ] || continue
    mark=" "; [ "${name:-}" = "${CUR_SRC:-}" ] && mark="▶"
    printf "%s input: %s\n" "$mark" "$(printf '%s' "$desc" | tr 'A-Z' 'a-z')"
  done
  return 0
}

move_all() {
  pactl list sink-inputs short 2>/dev/null | awk '{print $1}' | while read -r i; do
    pactl move-sink-input "$i" "$1" 2>/dev/null || true
  done
}

MENU="$(flat_list || true)"
if [ -z "${MENU:-}" ]; then
  MENU="  no audio devices found"
  NO_DEVICES=1
fi
COUNT=$(printf '%s\n' "$MENU" | wc -l)
[ "$COUNT" -gt 8 ] && COUNT=8
[ "$COUNT" -lt 2 ] && COUNT=2

CHOICE=$(printf '%s\n' "$MENU" | fuzzel --dmenu --hide-prompt --lines="$COUNT") || exit 0
[ -z "${CHOICE:-}" ] && exit 0
[ "${NO_DEVICES:-0}" -eq 1 ] && exit 0

CLEAN=$(printf '%s' "$CHOICE" | sed 's/^▶ *//; s/^ *//')
DESC=$(printf '%s' "$CLEAN" | sed 's/^output: //; s/^input: //')

if printf '%s' "$CLEAN" | grep -q "^output:"; then
  NAME=$(pactl list sinks 2>/dev/null | awk -v d="$DESC" 'BEGIN{IGNORECASE=1} /Name: /{n=$2} /Description: /{desc=substr($0,index($0,$2)); if(tolower(desc)==tolower(d)) print n}' | head -1 || true)
  if [ -n "${NAME:-}" ]; then
    pactl set-default-sink "$NAME" 2>/dev/null && move_all "$NAME" || notify "could not switch sink"
  else
    notify "sink not found"
  fi
elif printf '%s' "$CLEAN" | grep -q "^input:"; then
  NAME=$(pactl list sources 2>/dev/null | awk -v d="$DESC" 'BEGIN{IGNORECASE=1} /Name: /{n=$2} /Description: /{desc=substr($0,index($0,$2)); if(n !~ /\.monitor$/ && tolower(desc)==tolower(d)) print n}' | head -1 || true)
  if [ -n "${NAME:-}" ]; then
    pactl set-default-source "$NAME" 2>/dev/null || notify "could not switch source"
  else
    notify "source not found"
  fi
fi
