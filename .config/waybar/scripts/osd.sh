#!/bin/sh
popup() {
  idf="${XDG_RUNTIME_DIR:-/tmp}/osd-$1.id"
  prev=$(cat "$idf" 2>/dev/null) || prev=0
  case "$prev" in ''|*[!0-9]*) prev=0 ;; esac
  nid=$(notify-send -p -t 1500 -r "$prev" -h int:value:"$4" "$2" "$3" 2>/dev/null) || nid=""
  [ -n "$nid" ] && printf '%s' "$nid" > "$idf"
}

case "$1" in
  vol-up) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+ 2>/dev/null ;;
  vol-down) wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%- 2>/dev/null ;;
  mute) wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle 2>/dev/null ;;
  bri-up) brightnessctl s 10%+ >/dev/null 2>&1 ;;
  bri-down)
    brightnessctl s 10%- >/dev/null 2>&1
    pct=$(brightnessctl -m 2>/dev/null | head -1 | cut -d, -f4 | tr -d '%') || pct=0
    case "$pct" in ''|*[!0-9]*) pct=0 ;; esac
    [ "$pct" -lt 5 ] && brightnessctl s 5% >/dev/null 2>&1 || true
    ;;
  *) echo "usage: $0 vol-up|vol-down|mute|bri-up|bri-down" >&2; exit 1 ;;
esac

case "$1" in
  vol-up|vol-down|mute)
    out=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null) || out=""
    pct=$(printf '%s' "$out" | awk '{printf "%d", $2*100}') || pct=0
    [ -n "$pct" ] || pct=0
    if printf '%s' "$out" | grep -q MUTED; then
      popup vol "Volume muted" "" "$pct"
    else
      popup vol "Volume $pct%" "" "$pct"
    fi
    ;;
  bri-up|bri-down)
    pct=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d '%') || pct=0
    [ -n "$pct" ] || pct=0
    popup bri "Brightness $pct%" "" "$pct"
    ;;
esac
