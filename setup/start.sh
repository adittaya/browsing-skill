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
SESSION_FILE="$DATA_DIR/session"

mkdir -p "$DATA_DIR"

# ─── Session helpers ──────────────────────────────────────────

session_save() {
    echo "DISPLAY_NUM=$DISPLAY_NUM" > "$SESSION_FILE"
    echo "VNC_PORT=$VNC_PORT" >> "$SESSION_FILE"
    echo "BROWSER=$BROWSER" >> "$SESSION_FILE"
    echo "SCREEN_SIZE=$SCREEN_SIZE" >> "$SESSION_FILE"
    echo "XVFB_PID=$(pgrep -f "Xvfb $DISPLAY" 2>/dev/null | head -1)" >> "$SESSION_FILE"
    echo "X11VNC_PID=$(pgrep -f "x11vnc.*$DISPLAY" 2>/dev/null | head -1)" >> "$SESSION_FILE"
    echo "FLUXBOX_PID=$(pgrep -f "fluxbox.*$DISPLAY" 2>/dev/null | head -1)" >> "$SESSION_FILE"
    echo "BROWSER_PID=$(pgrep -f "$BROWSER.*$DISPLAY" 2>/dev/null | head -1)" >> "$SESSION_FILE"
    echo "BROWSER_WINDOW=$(DISPLAY="$DISPLAY" xdotool search --name ".+" 2>/dev/null | head -1)" >> "$SESSION_FILE"
}

session_load() {
    if [ -f "$SESSION_FILE" ]; then
        source "$SESSION_FILE" 2>/dev/null || true
    fi
}

is_running() {
    pgrep -f "Xvfb $DISPLAY" >/dev/null 2>&1 && \
    pgrep -f "x11vnc.*$DISPLAY" >/dev/null 2>&1 && \
    pgrep -f "fluxbox.*$DISPLAY" >/dev/null 2>&1
}

# ─── Core services (start once, never restart) ───────────────

ensure_xvfb() {
    if pgrep -f "Xvfb $DISPLAY" >/dev/null 2>&1; then
        echo "[env] Xvfb already running on $DISPLAY"
        return 0
    fi
    echo "[env] Starting Xvfb on $DISPLAY (${SCREEN_SIZE})..."
    Xvfb "$DISPLAY" -screen 0 "$SCREEN_SIZE" &>"$DATA_DIR/xvfb.log" &
    local pid=$!
    for i in $(seq 1 5); do
        if kill -0 "$pid" 2>/dev/null; then
            echo "[env] Xvfb PID: $pid"
            return 0
        fi
        sleep 1
    done
    echo "[env] Xvfb failed to start"
    cat "$DATA_DIR/xvfb.log"
    return 1
}

ensure_fluxbox() {
    if pgrep -f "fluxbox.*$DISPLAY" >/dev/null 2>&1; then
        echo "[env] Fluxbox already running"
        return 0
    fi
    echo "[env] Starting fluxbox..."
    DISPLAY="$DISPLAY" fluxbox &>"$DATA_DIR/fluxbox.log" &
    local pid=$!
    sleep 2
    if kill -0 "$pid" 2>/dev/null; then
        echo "[env] Fluxbox PID: $pid"
        return 0
    fi
    echo "[env] Fluxbox failed to start"
    return 1
}

ensure_x11vnc() {
    if pgrep -f "x11vnc.*$DISPLAY" >/dev/null 2>&1; then
        echo "[env] x11vnc already running on port $VNC_PORT"
        return 0
    fi
    echo "[env] Starting x11vnc on port $VNC_PORT..."
    x11vnc -display "$DISPLAY" -forever -nopw -rfbport "$VNC_PORT" -bg \
        -o "$DATA_DIR/x11vnc.log" 2>&1
    sleep 2
    if grep -q "Listening for VNC" "$DATA_DIR/x11vnc.log" 2>/dev/null; then
        echo "[env] x11vnc listening on port $VNC_PORT"
        return 0
    fi
    echo "[env] x11vnc may not be listening - check $DATA_DIR/x11vnc.log"
    tail -3 "$DATA_DIR/x11vnc.log"
    return 1
}

# ─── Browser (start once, reuse forever) ─────────────────────

ensure_browser() {
    local url="${1:-}"

    # Check if browser already running
    local existing_pid
    existing_pid=$(pgrep -f "$BROWSER.*$DISPLAY" 2>/dev/null | head -1 || true)

    if [ -n "$existing_pid" ] && [ "$existing_pid" != "0" ]; then
        echo "[browser] $BROWSER already running (PID: $existing_pid)"
        # If URL provided, navigate existing browser there
        if [ -n "$url" ]; then
            echo "[browser] Navigating to: $url"
            local win
            win=$(DISPLAY="$DISPLAY" xdotool search --name ".+" 2>/dev/null | head -1 || true)
            if [ -n "$win" ]; then
                DISPLAY="$DISPLAY" xdotool windowactivate "$win" 2>/dev/null || true
                sleep 0.5
                DISPLAY="$DISPLAY" xdotool key "ctrl+l" 2>/dev/null || true
                sleep 0.3
                DISPLAY="$DISPLAY" xdotool type --delay 10 "$url" 2>/dev/null || true
                sleep 0.3
                DISPLAY="$DISPLAY" xdotool key Return 2>/dev/null || true
                echo "[browser] Navigation sent"
            fi
        fi
        return 0
    fi

    # No browser running - start one
    if [ -z "$url" ]; then
        url="https://www.google.com"
    fi

    echo "[browser] Starting $BROWSER with homepage: $url"

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
            echo "[browser] Unknown browser: $BROWSER, trying surf"
            DISPLAY="$DISPLAY" LIBGL_ALWAYS_SOFTWARE=1 surf "$url" &>"$DATA_DIR/browser.log" &
            ;;
    esac

    local pid=$!
    echo "[browser] Started PID: $pid"

    # Wait for window to appear
    for i in $(seq 1 15); do
        local win
        win=$(DISPLAY="$DISPLAY" xdotool search --name ".+" 2>/dev/null | head -1 || true)
        if [ -n "$win" ] && [ "$win" != "0" ]; then
            echo "[browser] Window detected: $win"
            DISPLAY="$DISPLAY" xdotool windowsize "$win" 1280 720 2>/dev/null || true
            DISPLAY="$DISPLAY" xdotool windowmove "$win" 0 0 2>/dev/null || true
            DISPLAY="$DISPLAY" xdotool windowactivate "$win" 2>/dev/null || true
            return 0
        fi
        sleep 1
    done
    echo "[browser] Browser started but window not yet detected"
    return 0
}

# ─── Main ────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════"
echo "  Browser Environment"
echo "═══════════════════════════════════════════════"

# Load previous session
session_load

# Start core services (no-op if already running)
ensure_xvfb
ensure_fluxbox
ensure_x11vnc

# Start or reuse browser (default: Google homepage)
if [ $# -ge 1 ]; then
    ensure_browser "$1"
else
    ensure_browser "https://www.google.com"
fi

session_save

echo ""
echo "  STATUS: Ready"
echo "  DISPLAY: $DISPLAY"
echo "  VNC:     localhost:$VNC_PORT"
echo "  Browser: $BROWSER (persistent session)"
echo ""
echo "  Commands:"
echo "    bash scripts/browser.sh open <url>"
echo "    bash scripts/screenshot.sh --analyze"
echo "    bash scripts/click.sh --text <hint>"
echo "    bash scripts/scroll.sh down 5"
echo "    bash scripts/type.sh --key 'ctrl+l'"
echo "═══════════════════════════════════════════════"
echo ""
