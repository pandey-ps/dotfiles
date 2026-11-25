#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Display" "$1" 2>/dev/null || true
}

MONS=$(hyprctl monitors all 2>/dev/null | awk '/^Monitor /{print $2}')
INT=$(printf '%s\n' "$MONS" | grep -E '^eDP|^LVDS|^DSI' | head -1 || true)
if [ -z "${INT:-}" ]; then
  notify "no internal display found"
  exit 0
fi

hyprctl dispatch "hl.dsp.dpms({action=\"off\", monitor=\"$INT\"})" >/dev/null 2>&1 || true
sleep 1
hyprctl dispatch "hl.dsp.dpms({action=\"on\", monitor=\"$INT\"})" >/dev/null 2>&1 || true
sleep 1

STATUS=$(hyprctl monitors 2>/dev/null | awk -v m="Monitor $INT" 'index($0,m)==1{f=1;next} /^Monitor /{f=0} f && /dpmsStatus:/{print $2; exit}')
if [ "$STATUS" = "0" ]; then
  sleep 1
  hyprctl dispatch "hl.dsp.dpms({action=\"on\", monitor=\"$INT\"})" >/dev/null 2>&1 || notify "could not wake $INT"
fi
