#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DISPLAY="${DISPLAY:-:99}"
BROWSER="${BROWSER:-surf}"
DATA_DIR="${DATA_DIR:-/tmp/browsing-skill}"
SESSION_FILE="$DATA_DIR/session"

usage() {
    echo "Usage: browser.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  open <url>       Navigate to URL (reuses existing browser tab)"
    echo "  new-tab <url>    Open URL in a new tab"
    echo "  refresh          Reload current page"
    echo "  back             Go back in history"
    echo "  forward          Go forward in history"
    echo "  close-tab        Close current tab"
    echo "  status           Check browser state"
    echo "  focus            Bring browser window to front"
    echo ""
    echo "The browser is persistent - never killed or reopened."
    echo "Use 'open' to navigate, 'new-tab' for additional tabs."
    exit 1
}

find_window() {
    DISPLAY="$DISPLAY" xdotool search --name ".+" 2>/dev/null | head -1 || true
}

ensure_window() {
    local win
    win=$(find_window)
    if [ -z "$win" ]; then
        echo "[browser] No window found. Is the browser running?"
        echo "[browser] Run: bash setup/start.sh"
        exit 1
    fi
    echo "$win"
}

case "${1:-}" in
    open)
        URL="${2:-}"
        if [ -z "$URL" ]; then
            echo "Usage: browser.sh open <url>"
            exit 1
        fi
        echo "[browser] Navigating to: $URL"
        WIN=$(ensure_window)
        DISPLAY="$DISPLAY" xdotool windowactivate "$WIN" 2>/dev/null || true
        sleep 0.3
        # Focus URL bar (Ctrl+L works in surf, qutebrowser, firefox, chromium)
        DISPLAY="$DISPLAY" xdotool key "ctrl+l" 2>/dev/null || true
        sleep 0.3
        DISPLAY="$DISPLAY" xdotool type --delay 8 "$URL" 2>/dev/null || true
        sleep 0.3
        DISPLAY="$DISPLAY" xdotool key Return 2>/dev/null || true
        echo "[browser] Done"
        ;;

    new-tab)
        URL="${2:-https://www.google.com}"
        echo "[browser] Opening new tab: $URL"
        WIN=$(ensure_window)
        DISPLAY="$DISPLAY" xdotool windowactivate "$WIN" 2>/dev/null || true
        sleep 0.2
        # Ctrl+T opens new tab (works in most browsers)
        DISPLAY="$DISPLAY" xdotool key "ctrl+t" 2>/dev/null || true
        sleep 0.5
        DISPLAY="$DISPLAY" xdotool type --delay 8 "$URL" 2>/dev/null || true
        sleep 0.3
        DISPLAY="$DISPLAY" xdotool key Return 2>/dev/null || true
        echo "[browser] New tab opened"
        ;;

    refresh|reload)
        WIN=$(ensure_window)
        DISPLAY="$DISPLAY" xdotool windowactivate "$WIN" 2>/dev/null || true
        DISPLAY="$DISPLAY" xdotool key "ctrl+r" 2>/dev/null || true
        echo "[browser] Page refreshed"
        ;;

    back)
        WIN=$(ensure_window)
        DISPLAY="$DISPLAY" xdotool windowactivate "$WIN" 2>/dev/null || true
        DISPLAY="$DISPLAY" xdotool key "alt+Left" 2>/dev/null || true
        echo "[browser] Navigated back"
        ;;

    forward)
        WIN=$(ensure_window)
        DISPLAY="$DISPLAY" xdotool windowactivate "$WIN" 2>/dev/null || true
        DISPLAY="$DISPLAY" xdotool key "alt+Right" 2>/dev/null || true
        echo "[browser] Navigated forward"
        ;;

    close-tab)
        WIN=$(ensure_window)
        DISPLAY="$DISPLAY" xdotool windowactivate "$WIN" 2>/dev/null || true
        DISPLAY="$DISPLAY" xdotool key "ctrl+w" 2>/dev/null || true
        echo "[browser] Tab closed"
        ;;

    focus)
        WIN=$(ensure_window)
        DISPLAY="$DISPLAY" xdotool windowactivate "$WIN" 2>/dev/null || true
        echo "[browser] Window focused"
        ;;

    status)
        WIN=$(find_window)
        if [ -n "$WIN" ]; then
            NAME=$(DISPLAY="$DISPLAY" xdotool getwindowname "$WIN" 2>/dev/null || echo "(no title)")
            echo "[browser] Running: $NAME"
            echo "[browser] Window ID: $WIN"
            DISPLAY="$DISPLAY" xdotool getwindowgeometry "$WIN" 2>/dev/null | tail -2
        else
            echo "[browser] No browser window"
            echo "[browser] Check environment: bash setup/start.sh"
            exit 1
        fi
        ;;

    *)
        usage
        ;;
esac
