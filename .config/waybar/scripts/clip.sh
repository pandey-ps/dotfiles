#!/bin/sh
case "$1" in
  copy) key=C ;;
  paste) key=V ;;
  *) echo "usage: $0 copy|paste" >&2; exit 1 ;;
esac
HYPRCTL=/usr/bin/hyprctl
class=$($HYPRCTL activewindow 2>/dev/null | awk -F': ' '/^class:/{print $2; exit}' | tr '[:upper:]' '[:lower:]')
case "$class" in
  *terminal*|kitty|foot|wezterm|alacritty|*ghostty*|konsole|xfce4-terminal|xterm|st|st-256color|org.gnome.console)
    mods="CTRL SHIFT" ;;
  *) mods="CTRL" ;;
esac
$HYPRCTL eval "hl.dispatch(hl.dsp.send_shortcut({mods=\"$mods\", key=\"$key\"}))" >/dev/null 2>&1
