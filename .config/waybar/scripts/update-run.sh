#!/bin/sh
set -u

if [ -z "${UPDATE_INHIBITED:-}" ] && command -v systemd-inhibit >/dev/null 2>&1; then
  UPDATE_INHIBITED=1 exec systemd-inhibit --what=idle:sleep --why="system update" "$0" "$@"
fi

notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send "Update" "$1" 2>/dev/null || true
}

if command -v paccache >/dev/null 2>&1; then
  echo "pruning package cache (keep 2 versions)..."
  sudo paccache -rk2 || true
  echo
fi

yay -Syu --noconfirm
rc=$?

echo
NEW=$(find /etc -name '*.pacnew' 2>/dev/null || true)
if [ -n "${NEW:-}" ]; then
  echo "!! new config files left (.pacnew) - merge them with pacdiff:"
  printf '%s\n' "$NEW"
  notify "new .pacnew files need merging"
  echo
fi

ORPH=$(pacman -Qtdq 2>/dev/null || true)
if [ -n "${ORPH:-}" ]; then
  echo "orphan packages:"
  printf '%s\n' "$ORPH"
  printf 'remove them? [y/N] '
  read -r ans
  case "${ans:-}" in
    y|Y) sudo pacman -Rns --noconfirm $ORPH || true ;;
    *) echo "orphans kept" ;;
  esac
  echo
fi

kill -RTMIN+9 $(pgrep -x waybar) 2>/dev/null || true

if [ "$rc" -eq 0 ]; then
  notify "system updated"
else
  notify "update failed - check the terminal"
fi

printf 'done - press enter '
read -r _
