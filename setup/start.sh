#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

DISPLAY_NUM="${DISPLAY_NUM:-99}"
DISPLAY=":$DISPLAY_NUM"
VNC_PORT="${VNC_PORT:-5900}"
SCREEN_SIZE="${SCREEN_SIZE:-1280x720x24}"
BROWSER="${BROWSER:-surf}"
DATA_DIR="${DATA_DIR:-/tmp/browsing-skill}"

mkdir -p "$DATA_DIR"

cleanup() {
    echo "[start] Cleaning up existing processes..."
    pkill -f "Xvfb $DISPLAY" 2>/dev/null || true
    pkill -f "x11vnc.*$DISPLAY" 2>/dev/null || true
    pkill -f "fluxbox" 2>/dev/null || true
    sleep 1
}

start_xvfb() {
    if pgrep -f "Xvfb $DISPLAY" >/dev/null; then
        echo "[start] Xvfb already running on $DISPLAY"
        return 0
    fi
    echo "[start] Starting Xvfb on $DISPLAY (${SCREEN_SIZE})..."
    Xvfb "$DISPLAY" -screen 0 "$SCREEN_SIZE" &>"$DATA_DIR/xvfb.log" &
    local pid=$!
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        echo "[start] Xvfb PID: $pid"
    else
        echo "[start] Xvfb failed to start"
        cat "$DATA_DIR/xvfb.log"
        return 1
    fi
}

start_fluxbox() {
    if pgrep -f "fluxbox.*$DISPLAY" >/dev/null; then
        echo "[start] Fluxbox already running"
        return 0
    fi
    echo "[start] Starting fluxbox window manager..."
    DISPLAY="$DISPLAY" fluxbox &>"$DATA_DIR/fluxbox.log" &
    local pid=$!
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
        echo "[start] Fluxbox PID: $pid"
    else
        echo "[start] Fluxbox failed to start"
        return 1
    fi
}

start_x11vnc() {
    if pgrep -f "x11vnc.*$DISPLAY" >/dev/null; then
        echo "[start] x11vnc already running"
        return 0
    fi
    echo "[start] Starting x11vnc on port $VNC_PORT..."
    x11vnc -display "$DISPLAY" -forever -nopw -rfbport "$VNC_PORT" -bg \
        -o "$DATA_DIR/x11vnc.log" 2>&1
    sleep 1
    if lsof -i ":$VNC_PORT" 2>/dev/null || grep -q "Listening for VNC" "$DATA_DIR/x11vnc.log" 2>/dev/null; then
        echo "[start] x11vnc listening on port $VNC_PORT"
    else
        echo "[start] x11vnc may not be listening - check log"
        tail -3 "$DATA_DIR/x11vnc.log"
    fi
}

start_browser() {
    if [ $# -gt 0 ]; then
        local url="$1"
    else
        local url="about:blank"
    fi

    echo "[start] Starting browser: $BROWSER with URL: $url"

    case "$BROWSER" in
        surf)
            DISPLAY="$DISPLAY" LIBGL_ALWAYS_SOFTWARE=1 surf "$url" &>"$DATA_DIR/browser.log" &
            ;;
        qutebrowser)
            DISPLAY="$DISPLAY" qutebrowser "$url" &>"$DATA_DIR/browser.log" &
            ;;
        links2)
            DISPLAY="$DISPLAY" links2 -g "$url" &>"$DATA_DIR/browser.log" &
            ;;
        firefox)
            DISPLAY="$DISPLAY" firefox --new-instance "$url" &>"$DATA_DIR/browser.log" &
            ;;
        chromium)
            DISPLAY="$DISPLAY" chromium-browser --no-sandbox "$url" &>"$DATA_DIR/browser.log" &
            ;;
        *)
            echo "[start] Unknown browser: $BROWSER, trying surf"
            DISPLAY="$DISPLAY" LIBGL_ALWAYS_SOFTWARE=1 surf "$url" &>"$DATA_DIR/browser.log" &
            ;;
    esac

    local pid=$!
    echo "[start] Browser PID: $pid"

    # Wait for browser window
    for i in $(seq 1 10); do
        local win
        win=$(DISPLAY="$DISPLAY" xdotool search --name ".+" 2>/dev/null | head -3 | tail -1 || true)
        if [ -n "$win" ] && [ "$win" != "0" ]; then
            echo "[start] Browser window detected: $win"
            DISPLAY="$DISPLAY" xdotool windowsize "$win" 1280 720 2>/dev/null || true
            DISPLAY="$DISPLAY" xdotool windowmove "$win" 0 0 2>/dev/null || true
            DISPLAY="$DISPLAY" xdotool windowactivate "$win" 2>/dev/null || true
            break
        fi
        sleep 1
    done
}

show_status() {
    echo ""
    echo "========================================"
    echo "  Browsing Environment Active"
    echo "  DISPLAY:     $DISPLAY"
    echo "  VNC:         localhost:$VNC_PORT"
    echo "  Browser:     $BROWSER"
    echo "  Screen:      $SCREEN_SIZE"
    echo "  Data Dir:    $DATA_DIR"
    echo "========================================"
    echo ""
    echo "Processes:"
    pgrep -a -f "Xvfb|x11vnc|fluxbox" 2>/dev/null | grep -v grep || echo "  (check failed)"
}

cleanup
start_xvfb
start_fluxbox
start_x11vnc
start_browser "$@"
show_status
