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

DISP='function disp(preview,  tmp,n,a,res,size) {
  if (preview ~ /^\[\[ binary data /) {
    tmp=preview; sub(/^\[\[ binary data /, "", tmp); sub(/ \]\]$/, "", tmp)
    n=split(tmp, a, " ")
    res=""; if (n >= 1 && a[n] ~ /^[0-9]+x[0-9]+$/) { res=a[n]; n-- }
    size=""; if (n >= 2) size=a[1]" "a[2]; else if (n == 1) size=a[1]
    if (res != "" && size != "") return "[image] ("res", "size")"
    if (res != "") return "[image] ("res")"
    if (size != "") return "[image] ("size")"
    return "[image]"
  }
  return preview
}'

CHOICE=$(printf '%s\n' "$LIST" | awk "$DISP"' { line=$0; sub(/^[^\t]*\t/, "", line); print disp(line) }' | fuzzel --dmenu --prompt="clipboard: " --match-mode=exact --lines=12) || exit 0
[ -n "${CHOICE:-}" ] || exit 0
ID=$(printf '%s\n' "$LIST" | SEL="$CHOICE" awk -F'\t' "$DISP"' { line=$0; sub(/^[^\t]*\t/, "", line); if (disp(line) == ENVIRON["SEL"]) { print $1; exit } }' || true)
[ -n "${ID:-}" ] || exit 0
printf '%s' "$ID" | cliphist decode 2>/dev/null | wl-copy 2>/dev/null || notify "restore failed"
