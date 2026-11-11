#!/bin/sh
set -u

n=$(yay -Qu 2>/dev/null | wc -l)
[ "${n:-0}" -gt 0 ] && printf 'update %s' "$n"
