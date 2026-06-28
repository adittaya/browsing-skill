#!/usr/bin/env bash
set -euo pipefail

DISPLAY_NUM="${DISPLAY_NUM:-99}"
DISPLAY=":$DISPLAY_NUM"

echo "[stop] Stopping browsing environment..."

pkill -f "surf.*$DISPLAY" 2>/dev/null || true
pkill -f "qutebrowser.*$DISPLAY" 2>/dev/null || true
pkill -f "links2.*$DISPLAY" 2>/dev/null || true
pkill -f "firefox.*$DISPLAY" 2>/dev/null || true
pkill -f "chromium.*$DISPLAY" 2>/dev/null || true
sleep 1

pkill -f "x11vnc.*$DISPLAY" 2>/dev/null || true
pkill -f "fluxbox.*$DISPLAY" 2>/dev/null || true
pkill "Xvfb" 2>/dev/null || true
sleep 1

echo "[stop] Processes remaining:"
pgrep -a -f "Xvfb|x11vnc|fluxbox|surf|qutebrowser|links2" 2>/dev/null || echo "  (none)"
echo "[stop] Done"
