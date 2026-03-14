#!/usr/bin/env bash
BUILD_ROOT=/home/jalsarraf/gentoo/build
last=$(sudo tail -1 "$BUILD_ROOT/var/log/emerge.log" 2>/dev/null)
completed=$(sudo grep -c "::: completed" "$BUILD_ROOT/var/log/emerge.log" 2>/dev/null)
total=$(sudo grep ">>> emerge (1 of" "$BUILD_ROOT/var/log/emerge.log" 2>/dev/null | head -1 | grep -oP 'of \K\d+')
current=$(sudo grep ">>> emerge" "$BUILD_ROOT/var/log/emerge.log" 2>/dev/null | tail -1 | grep -oP '\(\K[^)]+')
echo "Progress: $current | Completed: $completed of ${total:-?}"
echo "Currently: $(ps aux | grep -E '\[.*\] sandbox' | grep -v grep | sed 's/.*\[/[/' | sed 's/\] .*/]/' | tr '\n' ' ')"
