#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Power" "$1" 2>/dev/null || true
}

if ! command -v fuzzel >/dev/null 2>&1; then
  notify "fuzzel not installed"
  exit 1
fi

cur=$(powerprofilesctl get 2>/dev/null | tr 'A-Z' 'a-z' || true)
if [ -z "${cur:-}" ]; then
  cur=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null | tr 'A-Z' 'a-z' | sed 's/powersave/power-saver/; s/schedutil/balanced/' || true)
fi

bat=""
for d in /sys/class/power_supply/BAT*; do
  [ -r "$d/capacity" ] && [ -r "$d/status" ] && { bat="$d"; break; }
done
bcap=$(cat "$bat/capacity" 2>/dev/null | tr -d ' \n' || true)
bstate=$(cat "$bat/status" 2>/dev/null | tr 'A-Z' 'a-z' | tr -d ' \n' || true)
[ -n "${bcap:-}" ] || bcap="?"
[ -n "${bstate:-}" ] || bstate="unknown"
TIP="not charging"
[ "${bstate:-}" = "charging" ] && TIP="charging"

MENU="battery $bcap% ($TIP)
"
for p in power-saver balanced performance; do
  if [ -n "${cur:-}" ] && [ "$p" = "$cur" ]; then MENU="${MENU}▶ $p
"
  else MENU="${MENU}  $p
"
  fi
done

CHOICE=$(printf '%s' "$MENU" | fuzzel --dmenu --hide-prompt --lines=4) || exit 0
CHOICE=$(printf '%s' "${CHOICE:-}" | sed 's/^▶ *//; s/^ *//' | tr 'A-Z' 'a-z')
[ -n "$CHOICE" ] || exit 0

case "$CHOICE" in
  power-saver|balanced|performance) ;;
  *) exit 0 ;;
esac

if powerprofilesctl set "$CHOICE" >/dev/null 2>&1; then
  notify "$CHOICE"
elif pkexec powerprofilesctl set "$CHOICE" >/dev/null 2>&1; then
  notify "$CHOICE"
else
  notify "could not set $CHOICE"
fi
