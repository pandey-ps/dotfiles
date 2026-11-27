#!/bin/sh
set -u

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "System" "$1" 2>/dev/null || true
}

if ! command -v efibootmgr >/dev/null 2>&1; then
  notify "efibootmgr not installed"
  exit 1
fi

ID=$(efibootmgr 2>/dev/null | awk -F'[* \t]+' '/Windows Boot Manager/{print $1; exit}')
[ -n "${ID:-}" ] || { notify "Windows boot entry not found"; exit 1; }
ID=${ID#Boot}

if sudo efibootmgr -n "$ID" >/dev/null 2>&1; then
  systemctl reboot
else
  notify "could not set Windows as next boot"
fi
