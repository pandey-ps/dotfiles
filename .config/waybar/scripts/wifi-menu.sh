#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Wi-Fi" "$1" 2>/dev/null || true
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
if ! command -v nmcli >/dev/null 2>&1; then
  info_panel "  nmcli not installed (install NetworkManager)"
fi
if ! nmcli general status >/dev/null 2>&1; then
  info_panel "  NetworkManager not running"
fi

IFACE=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="wifi"{print $1; exit}')
if [ -z "${IFACE:-}" ]; then
  ACTIVE=$(nmcli -t -f NAME con show --active 2>/dev/null | head -1 || true)
  INFO="  no wifi adapter on this machine"
  [ -n "${ACTIVE:-}" ] && INFO="$INFO
  active connection: $ACTIVE"
  info_panel "$INFO"
fi

display_of() {
  line=$(printf '%s' "$1" | sed 's/\\:/__COLON__/g')
  use=$(printf '%s' "$line" | cut -d: -f1)
  ssid=$(printf '%s' "$line" | cut -d: -f2 | sed 's/__COLON__/:/g')
  if [ "$use" = "*" ]; then
    sig=$(printf '%s' "$line" | cut -d: -f3)
    printf "%s (%s%%)" "$ssid" "$sig"
  else
    printf "%s" "$ssid"
  fi
}

if [ "$(nmcli -t -f WIFI radio 2>/dev/null)" != "enabled" ]; then
  MENU="  turn wifi on"
  CHOICE=$(printf '%s\n' "$MENU" | fuzzel --dmenu --hide-prompt --lines=1) || exit 0
  [ -z "${CHOICE:-}" ] && exit 0
  if nmcli radio wifi on >/dev/null 2>&1; then
    sleep 2
    exec "$0"
  else
    notify "could not turn wifi on"
  fi
  exit 0
fi

nmcli dev wifi rescan ifname "$IFACE" >/dev/null 2>&1 &
SCAN=$(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY dev wifi list ifname "$IFACE" --rescan no 2>/dev/null | grep -v '^::' | grep -v '^$' || true)

MENU=""
if [ -n "${SCAN:-}" ]; then
  MENU=$(printf '%s\n' "$SCAN" | sed 's/\\:/__COLON__/g' | sort -t: -k1,1r -k3,3nr | awk -F: '!seen[$2]++' | sed 's/__COLON__/\\:/g' | while IFS= read -r entry; do
    [ -n "${entry:-}" ] || continue
    display_of "$entry"
  done)
fi

CUR=$(printf '%s\n' "$SCAN" | grep '^\*:' | sed 's/\\:/__COLON__/g' | cut -d: -f2 | sed 's/__COLON__/:/g' | head -1 || true)

ACTIONS="join hidden network"

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
  join\ hidden*)
    SSID=$(fuzzel --dmenu --prompt-only="ssid: " </dev/null) || exit 0
    [ -n "${SSID:-}" ] || exit 0
    PASS=$(fuzzel --dmenu --prompt-only="password (empty = open): " --password </dev/null) || exit 0
    if [ -n "${PASS:-}" ]; then
      OUT=$(nmcli dev wifi connect "$SSID" password "$PASS" hidden yes 2>&1)
    else
      OUT=$(nmcli dev wifi connect "$SSID" hidden yes 2>&1)
    fi
    if [ $? -eq 0 ]; then notify "connected to $SSID"; else notify "connect failed: $OUT"; fi
    exit 0
    ;;
esac

SSID=""; SEC=""
if [ -n "${SCAN:-}" ]; then
  MATCH=$(printf '%s\n' "$SCAN" | while IFS= read -r entry; do
    [ -n "${entry:-}" ] || continue
    if [ "$(display_of "$entry")" = "$CHOICE" ]; then printf '%s' "$entry"; break; fi
  done)
  if [ -n "${MATCH:-}" ]; then
    tmp=$(printf '%s' "$MATCH" | sed 's/\\:/__COLON__/g')
    SSID=$(printf '%s' "$tmp" | cut -d: -f2 | sed 's/__COLON__/:/g')
    SEC=$(printf '%s' "$tmp" | cut -d: -f4 | awk '{print $1}')
  fi
fi
if [ -z "${SSID:-}" ]; then
  notify "network not found"
  exit 0
fi

if [ "${SSID:-}" = "${CUR:-}" ]; then
  if nmcli dev disconnect "$IFACE" >/dev/null 2>&1; then
    notify "disconnected from $SSID"
  else
    notify "disconnect failed"
  fi
  exit 0
fi

if nmcli -t -f NAME con show 2>/dev/null | grep -qxF -- "$SSID"; then
  OUT=$(nmcli con up id "$SSID" 2>&1)
  if [ $? -eq 0 ]; then notify "connected to $SSID"; else notify "connect failed: $OUT"; fi
  exit 0
fi

if [ -z "${SEC:-}" ] || [ "$SEC" = "--" ]; then
  OUT=$(nmcli dev wifi connect "$SSID" 2>&1)
  if [ $? -eq 0 ]; then notify "connected to $SSID"; else notify "connect failed: $OUT"; fi
  exit 0
fi

PASS=$(fuzzel --dmenu --prompt-only="password for $SSID: " --password </dev/null) || exit 0
[ -n "${PASS:-}" ] || exit 0
OUT=$(nmcli dev wifi connect "$SSID" password "$PASS" 2>&1)
if [ $? -eq 0 ]; then notify "connected to $SSID"; else notify "connect failed: $OUT"; fi
