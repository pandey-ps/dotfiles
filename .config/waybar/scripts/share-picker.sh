#!/bin/sh
# xdph custom share picker (see ~/.config/hypr/xdph.conf).
# Lists monitors + windows in fuzzel and prints the [SELECTION]
# protocol xdph expects. Any args from xdph (--allow-token etc.)
# are accepted and ignored. Cancel/empty -> silent exit 1.
set -u

MAP=""
MENU=""
MONS=$(hyprctl monitors 2>/dev/null | awk '/^Monitor /{print $2}' || true)
for m in $MONS; do
  MENU="${MENU}screen: $m
"
done

if [ -n "${XDPH_WINDOW_SHARING_LIST:-}" ]; then
  ROWS=$(printf '%s' "$XDPH_WINDOW_SHARING_LIST" | awk '
    BEGIN { RS="\\[HA>]" }
    {
      s=$0
      i=index(s,"[HC>]"); if (!i) next; handle=substr(s,1,i-1); s=substr(s,i+5)
      i=index(s,"[HT>]"); if (!i) next; class=substr(s,1,i-1); s=substr(s,i+5)
      i=index(s,"[HE>]"); if (i) title=substr(s,1,i-1); else title=s
      if (title == "" && class == "") next
      printf "window: %s (%s)\t%s\n", title, class, handle
    }' || true)
  if [ -n "${ROWS:-}" ]; then
    MENU="$MENU$(printf '%s\n' "$ROWS" | cut -f1)
"
    MAP=$(printf '%s\n' "$ROWS")
  fi
fi

if [ -z "$(printf '%s' "${MENU:-}" | tr -d ' \n')" ]; then
  exit 1
fi

CHOICE=$(printf '%s' "$MENU" | fuzzel --dmenu --prompt="share: " --match-mode=exact --lines=12) || exit 1
CHOICE=$(printf '%s' "${CHOICE:-}" | sed 's/^ *//;s/ *$//')
[ -n "$CHOICE" ] || exit 1

case "$CHOICE" in
  "screen: "*)
    printf '[SELECTION]/screen:%s\n' "${CHOICE#screen: }"
    exit 0
    ;;
  "window: "*)
    HANDLE=$(printf '%s\n' "$MAP" | SEL="$CHOICE" awk -F'\t' '$1 == ENVIRON["SEL"] { print $2; exit }' || true)
    [ -n "${HANDLE:-}" ] || exit 1
    printf '[SELECTION]/window:%s\n' "$HANDLE"
    exit 0
    ;;
  *) exit 1 ;;
esac
