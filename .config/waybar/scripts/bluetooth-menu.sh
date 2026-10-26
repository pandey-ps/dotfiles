#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Bluetooth" "$1" 2>/dev/null || true
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
if ! command -v bluetoothctl >/dev/null 2>&1; then
  notify "bluetoothctl not found"
  exit 0
fi
if ! bluetoothctl list 2>/dev/null | grep -q .; then
  info_panel "  no bluetooth adapter on this machine"
fi

if ! bluetoothctl show 2>/dev/null | grep -q "Powered: yes"; then
  MENU="  turn bluetooth on"
  CHOICE=$(printf '%s\n' "$MENU" | fuzzel --dmenu --hide-prompt --lines=1) || exit 0
  [ -z "${CHOICE:-}" ] && exit 0
  if bluetoothctl power on >/dev/null 2>&1; then
    sleep 1
    exec "$0"
  else
    notify "could not turn bluetooth on"
  fi
  exit 0
fi

bluetoothctl --timeout 10 scan on >/dev/null 2>&1 &

DEVICES=$(bluetoothctl devices 2>/dev/null || true)

display_of() {
  mac=$(printf '%s' "$1" | awk '{print $2}')
  name=$(printf '%s' "$1" | cut -d' ' -f3-)
  [ -n "${name:-}" ] || name="$mac"
  if bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
    printf '%s (connected)' "$name"
  else
    printf '%s' "$name"
  fi
}

MENU=""
if [ -n "${DEVICES:-}" ]; then
  MENU=$(printf '%s\n' "$DEVICES" | while IFS= read -r entry; do
    [ -n "${entry:-}" ] || continue
    display_of "$entry"
    printf '\n'
  done)
fi

ACTIONS="turn bluetooth off"

if [ -n "${MENU:-}" ]; then
  MENU="$MENU
$ACTIONS"
else
  MENU="$ACTIONS"
fi

COUNT=$(printf '%s\n' "$MENU" | wc -l)
[ "$COUNT" -gt 12 ] && COUNT=12
[ "$COUNT" -lt 2 ] && COUNT=2

CHOICE=$(printf '%s\n' "$MENU" | fuzzel --dmenu --hide-prompt --lines="$COUNT") || exit 0
[ -z "${CHOICE:-}" ] && exit 0
CLEAN=$(printf '%s' "$CHOICE" | sed 's/^ *//')

case "$CLEAN" in
  turn\ bluetooth\ off)
    if bluetoothctl power off >/dev/null 2>&1; then
      notify "bluetooth off"
    else
      notify "could not turn bluetooth off"
    fi
    exit 0
    ;;
esac

MAC=""
NAME=""
if [ -n "${DEVICES:-}" ]; then
  MATCH=$(printf '%s\n' "$DEVICES" | while IFS= read -r entry; do
    [ -n "${entry:-}" ] || continue
    if [ "$(display_of "$entry")" = "$CHOICE" ]; then printf '%s' "$entry"; break; fi
  done)
  if [ -n "${MATCH:-}" ]; then
    MAC=$(printf '%s' "$MATCH" | awk '{print $2}')
    NAME=$(printf '%s' "$MATCH" | cut -d' ' -f3-)
  fi
fi
if [ -z "${MAC:-}" ]; then
  notify "device not found"
  exit 0
fi
[ -n "${NAME:-}" ] || NAME="$MAC"

INFO=$(bluetoothctl info "$MAC" 2>/dev/null || true)
if printf '%s' "$INFO" | grep -q "Connected: yes"; then
  ACT_MENU="disconnect"
else
  ACT_MENU="connect"
fi
if printf '%s' "$INFO" | grep -q "Paired: yes"; then
  ACT_MENU="$ACT_MENU
remove"
fi

ACT_COUNT=$(printf '%s\n' "$ACT_MENU" | wc -l)
[ "$ACT_COUNT" -lt 2 ] && ACT_COUNT=2
ACTION=$(printf '%s\n' "$ACT_MENU" | fuzzel --dmenu --prompt="$NAME" --lines="$ACT_COUNT") || exit 0
ACTION=$(printf '%s' "${ACTION:-}" | sed 's/^ *//')
[ -n "$ACTION" ] || exit 0

case "$ACTION" in
  disconnect)
    if bluetoothctl disconnect "$MAC" >/dev/null 2>&1; then
      notify "disconnected from $NAME"
    else
      notify "disconnect failed"
    fi
    exit 0
    ;;
  remove)
    if bluetoothctl remove "$MAC" >/dev/null 2>&1; then
      notify "removed $NAME"
    else
      notify "remove failed"
    fi
    exit 0
    ;;
  connect) ;;
  *) exit 0 ;;
esac

if ! printf '%s' "$INFO" | grep -q "Paired: yes"; then
  bluetoothctl scan off >/dev/null 2>&1 || true
  OUT=$(timeout 25 bluetoothctl pair "$MAC" 2>&1)
  if [ $? -ne 0 ]; then notify "pair failed: $OUT"; exit 0; fi
  bluetoothctl trust "$MAC" >/dev/null 2>&1 || true
fi
bluetoothctl scan off >/dev/null 2>&1 || true
OUT=$(timeout 25 bluetoothctl connect "$MAC" 2>&1)
if [ $? -eq 0 ]; then notify "connected to $NAME"; else notify "connect failed: $OUT"; fi
