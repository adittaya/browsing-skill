#!/usr/bin/env bash
set -euo pipefail

DISPLAY_VAL="${DISPLAY:-:99}"
VNC_PORT="${VNC_PORT:-5900}"
SESSION_FILE="${DATA_DIR:-/tmp/desktop-skill}/session"

# Load session if available
if [ -f "$SESSION_FILE" ]; then
    source "$SESSION_FILE" 2>/dev/null || true
fi

echo ""
echo "  Desktop Environment — Status"
echo ""

# Runtime detection (same logic as start.sh)
detect_runtime() {
    if [ -n "${TERMUX_VERSION:-}" ] || command -v termux-setup-storage >/dev/null 2>&1; then
        echo "termux"; return
    fi
    if [ -n "${DISPLAY:-}" ]; then
        if command -v xdpyinfo >/dev/null 2>&1 && xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
            echo "existing-desktop"; return
        fi
    fi
    if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -e "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-0}" 2>/dev/null ]; then
        echo "existing-desktop"; return
    fi
    echo "terminal"
}

# Environment info
echo "  Platform:    $(uname -s) $(uname -m)"
echo "  Distro:      $( (cat /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || echo 'unknown')"
echo "  Runtime:     $(detect_runtime)"
if [ -n "${TERMUX_VERSION:-}" ]; then
    echo "  Termux:      v$TERMUX_VERSION"
fi
echo "  Hostname:    $(hostname 2>/dev/null || echo 'unknown')"
echo "  User:        $(whoami)"
echo ""

# DISPLAY info
echo "  DISPLAY:     ${DISPLAY_VAL}"
if command -v xdpyinfo >/dev/null 2>&1; then
    xdpyinfo -display "$DISPLAY_VAL" 2>/dev/null | grep -E "dimensions|depths" | head -2 | sed 's/^/  /' || echo "  (no X display connection)"
elif [ -n "${TERMUX_VERSION:-}" ]; then
    echo "  (Termux:X11 display may be available)"
else
    echo "  (xdpyinfo not available)"
fi
echo ""

# VNC
echo "  VNC port:    ${VNC_PORT:-5900}"
if command -v lsof >/dev/null 2>&1; then
    lsof -i ":${VNC_PORT:-5900}" 2>/dev/null | grep -q LISTEN && echo "  VNC status:  RUNNING" || echo "  VNC status:  STOPPED"
elif command -v ss >/dev/null 2>&1; then
    ss -tlnp 2>/dev/null | grep -q ":${VNC_PORT:-5900}" && echo "  VNC status:  RUNNING" || echo "  VNC status:  STOPPED"
elif command -v netstat >/dev/null 2>&1; then
    netstat -tlnp 2>/dev/null | grep -q ":${VNC_PORT:-5900}" && echo "  VNC status:  RUNNING" || echo "  VNC status:  STOPPED"
else
    echo "  VNC status:  (cannot check)"
fi
echo ""

# Processes
echo "  Processes:"
for proc_pattern in "Xvfb" "x11vnc" "fluxbox" "openbox" "surf" "qutebrowser" "links2" "firefox" "chromium" "termux-x11"; do
    pids=$(pgrep -f "$proc_pattern" 2>/dev/null || true)
    if [ -n "$pids" ]; then
        for pid in $pids; do
            cmd=$(ps -p "$pid" -o comm= 2>/dev/null || echo "$proc_pattern")
            echo "    [RUNNING] $cmd (PID $pid)"
        done
    fi
done
echo ""

# Browser window
WIN=$(DISPLAY="$DISPLAY_VAL" xdotool search --name ".+" 2>/dev/null | head -1 || true)
if [ -n "$WIN" ]; then
    NAME=$(DISPLAY="$DISPLAY_VAL" xdotool getwindowname "$WIN" 2>/dev/null || echo "unknown")
    GEO=$(DISPLAY="$DISPLAY_VAL" xdotool getwindowgeometry "$WIN" 2>/dev/null | tail -1 || echo "")
    echo "  Browser:     $NAME"
    echo "  Geometry:   $GEO"
fi
echo ""
