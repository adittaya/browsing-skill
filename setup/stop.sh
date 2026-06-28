#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="${DATA_DIR:-/tmp/browsing-skill}"
SESSION_FILE="$DATA_DIR/session"

echo ""
echo "═══════════════════════════════════════════════"
echo "  Stopping Browser Environment"
echo "═══════════════════════════════════════════════"
echo ""

# Check if environment is actually running
if ! pgrep -f "Xvfb :" >/dev/null 2>&1 && ! pgrep -f "x11vnc" >/dev/null 2>&1; then
    echo "[stop] No running browser environment found"
    echo "[stop] Nothing to stop"
    rm -f "$SESSION_FILE" "$DATA_DIR"/*.pid 2>/dev/null || true
    exit 0
fi

echo "[stop] Killing browser..."
pkill -f "surf " 2>/dev/null || true
pkill -f "qutebrowser" 2>/dev/null || true
pkill -f "links2" 2>/dev/null || true
pkill -f "firefox" 2>/dev/null || true
pkill -f "chromium" 2>/dev/null || true
sleep 1

echo "[stop] Killing x11vnc..."
pkill -f "x11vnc" 2>/dev/null || true
sleep 1

echo "[stop] Killing fluxbox..."
pkill -f "fluxbox" 2>/dev/null || true
sleep 1

echo "[stop] Killing Xvfb..."
pkill -f "Xvfb :" 2>/dev/null || true
sleep 1

# Verify nothing left
if pgrep -f "Xvfb :" >/dev/null 2>&1 || pgrep -f "x11vnc" >/dev/null 2>&1; then
    echo "[stop] Some processes still running, sending SIGKILL..."
    pkill -9 -f "Xvfb :" 2>/dev/null || true
    pkill -9 -f "x11vnc" 2>/dev/null || true
    pkill -9 -f "fluxbox" 2>/dev/null || true
    pkill -9 -f "surf|qutebrowser|links2|firefox|chromium" 2>/dev/null || true
fi

rm -f "$SESSION_FILE" "$DATA_DIR"/*.pid 2>/dev/null || true

echo ""
echo "[stop] All processes stopped"
echo "═══════════════════════════════════════════════"
echo ""
