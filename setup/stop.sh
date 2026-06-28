#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
source "$REPO_DIR/lib/config.sh"

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   Stopping Desktop Environment                  ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""

# Stop watchdog
if [ -f "$REPO_DIR/setup/watchdog.sh" ]; then
    bash "$REPO_DIR/setup/watchdog.sh" stop 2>/dev/null || true
fi

# Stop recording
if [ -f "$REPO_DIR/scripts/record.sh" ]; then
    bash "$REPO_DIR/scripts/record.sh" stop 2>/dev/null || true
fi

# Check if anything is running
if ! pgrep -f "Xvfb :" >/dev/null 2>&1 && ! pgrep -f "x11vnc" >/dev/null 2>&1 && \
   ! pgrep -f "ffmpeg.*x11grab" >/dev/null 2>&1; then
    echo "[stop] No running environment found"
    rm -f "$SESSION_FILE" 2>/dev/null || true
    exit 0
fi

echo "[stop] Killing browser..."
for p in surf qutebrowser links2 firefox chromium chromium-browser; do
    pkill -f "$p " 2>/dev/null || true
done
sleep 1

echo "[stop] Killing x11vnc..."
pkill -f "x11vnc" 2>/dev/null || true
sleep 1

echo "[stop] Killing window manager..."
pkill -f "fluxbox" 2>/dev/null || true
pkill -f "openbox" 2>/dev/null || true
sleep 1

echo "[stop] Killing Xvfb..."
pkill -f "Xvfb :" 2>/dev/null || true
sleep 1

echo "[stop] Killing recording..."
pkill -f "ffmpeg.*x11grab" 2>/dev/null || true
sleep 1

# SIGKILL if anything remains
for proc_pattern in "Xvfb :" "x11vnc" "fluxbox" "ffmpeg.*x11grab"; do
    if pgrep -f "$proc_pattern" >/dev/null 2>&1; then
        pkill -9 -f "$proc_pattern" 2>/dev/null || true
    fi
done

rm -f "$SESSION_FILE" "$DATA_DIR/watchdog.pid" "$DATA_DIR/recording.pid" 2>/dev/null || true

echo ""
echo "[stop] All processes stopped"
echo "══════════════════════════════════════════════════════"
echo ""
