#!/usr/bin/env bash
# Quick emerge progress monitor — not part of CI pipeline
set -euo pipefail

BUILD_ROOT="${GENTOOVM_BUILD_ROOT:-/home/jalsarraf/gentoo}/build"
EMERGE_LOG="$BUILD_ROOT/var/log/emerge.log"

completed=$(sudo grep -c "::: completed" "$EMERGE_LOG" 2>/dev/null || echo 0)
total=$(sudo grep -m1 ">>> emerge (1 of" "$EMERGE_LOG" 2>/dev/null | grep -oP 'of \K\d+' || echo "?")
current=$(sudo grep ">>> emerge" "$EMERGE_LOG" 2>/dev/null | tail -1 | grep -oP '\(\K[^)]+' || echo "?")

echo "Progress: $current | Completed: $completed of $total"
echo "Currently: $(pgrep -a sandbox 2>/dev/null | sed 's/.*\[/[/;s/\] .*/]/' | tr '\n' ' ')"
