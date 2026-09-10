#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Clipboard" "$1" 2>/dev/null || true
}

if ! command -v fuzzel >/dev/null 2>&1; then
  notify "fuzzel not installed"
  exit 1
fi
if ! command -v cliphist >/dev/null 2>&1; then
  notify "cliphist not installed"
  exit 1
fi
if ! command -v wl-copy >/dev/null 2>&1; then
  notify "wl-clipboard not installed"
  exit 1
fi

LIST=$(cliphist list 2>/dev/null || true)

CHOICE=$(printf '%s\n' "$LIST" | cut -f2- | fuzzel --dmenu --prompt="clipboard: " --match-mode=exact --lines=12) || exit 0
[ -n "${CHOICE:-}" ] || exit 0
ID=$(printf '%s\n' "$LIST" | SEL="$CHOICE" awk -F'\t' '{line=$0; sub(/^[^\t]*\t/, "", line); if (line == ENVIRON["SEL"]) { print $1; exit } }' || true)
[ -n "${ID:-}" ] || exit 0
printf '%s\t%s\n' "$ID" "$CHOICE" | cliphist decode 2>/dev/null | wl-copy 2>/dev/null || notify "restore failed"
