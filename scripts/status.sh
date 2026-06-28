#!/usr/bin/env bash
set -euo pipefail

DISPLAY="${DISPLAY:-:99}"
VNC_PORT="${VNC_PORT:-5900}"

echo "============================================"
echo "  Browsing Environment Status"
echo "============================================"
echo ""

echo "Processes:"
for PROC in "Xvfb:$DISPLAY" "x11vnc.*$DISPLAY" "fluxbox" "surf" "qutebrowser" "links2"; do
    if pgrep -f "$PROC" >/dev/null 2>&1; then
        echo "  [RUNNING] $PROC"
    else
        echo "  [STOPPED] $PROC"
    fi
done

echo ""

# Check VNC port
if command -v lsof &>/dev/null; then
    if lsof -i ":$VNC_PORT" >/dev/null 2>&1; then
        echo "VNC:     RUNNING on port $VNC_PORT"
    else
        echo "VNC:     NOT RUNNING on port $VNC_PORT"
    fi
elif command -v ss &>/dev/null; then
    if ss -tlnp | grep -q ":$VNC_PORT"; then
        echo "VNC:     RUNNING on port $VNC_PORT"
    else
        echo "VNC:     NOT RUNNING on port $VNC_PORT"
    fi
else
    python3 -c "import socket; s=socket.socket(); s.settimeout(2); r=s.connect_ex(('localhost',$VNC_PORT)); print('VNC:','OPEN' if r==0 else 'CLOSED'); s.close()" 2>/dev/null || echo "VNC:     UNKNOWN"
fi

echo ""

# Display info
echo "DISPLAY:  $DISPLAY"
echo "Screen:   $(DISPLAY="$DISPLAY" xdpyinfo 2>/dev/null | grep dimensions || echo 'unknown')"

# Browser info
WIN=$(DISPLAY="$DISPLAY" xdotool search --name ".+" 2>/dev/null | head -1 || true)
if [ -n "$WIN" ]; then
    NAME=$(DISPLAY="$DISPLAY" xdotool getwindowname "$WIN" 2>/dev/null || echo "unknown")
    echo "Window:   $NAME"
    DISPLAY="$DISPLAY" xdotool getwindowgeometry "$WIN" 2>/dev/null | head -2 | sed 's/^/          /'
fi

echo ""
echo "============================================"
