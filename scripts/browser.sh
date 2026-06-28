#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DISPLAY="${DISPLAY:-:99}"

usage() {
    echo "Usage: browser.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  open <url>         Open URL in browser"
    echo "  refresh            Refresh current page"
    echo "  back               Go back"
    echo "  forward            Go forward"
    echo "  close              Close browser"
    echo "  status             Check browser status"
    echo ""
    echo "Environment:"
    echo "  DISPLAY            X display (default: :99)"
    echo "  BROWSER            Browser to use (default: surf)"
    exit 1
}

find_browser_window() {
    local name="${1:-}"
    local win
    if [ -n "$name" ]; then
        win=$(DISPLAY="$DISPLAY" xdotool search --name "$name" 2>/dev/null | head -1 || true)
    else
        # Try common browser window names
        for n in "surf" "qutebrowser" "Links" "Mozilla Firefox" "Chromium" "Navigator"; do
            win=$(DISPLAY="$DISPLAY" xdotool search --name "$n" 2>/dev/null | head -1 || true)
            [ -n "$win" ] && break
        done
    fi
    echo "$win"
}

ensure_window() {
    local win
    win=$(find_browser_window)
    if [ -z "$win" ]; then
        echo "No browser window found. Start browser first."
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
        # Open in existing browser or start new one
        WIN=$(find_browser_window)
        if [ -n "$WIN" ]; then
            DISPLAY="$DISPLAY" xdotool windowactivate "$WIN"
            sleep 0.5
            # Use Ctrl+L to focus URL bar, then type URL
            DISPLAY="$DISPLAY" xdotool key "ctrl+l"
            sleep 0.3
            DISPLAY="$DISPLAY" xdotool type --delay 10 "$URL"
            sleep 0.3
            DISPLAY="$DISPLAY" xdotool key Return
            echo "Opened $URL in existing browser"
        else
            # Start new browser
            BROWSER="${BROWSER:-surf}"
            case "$BROWSER" in
                surf) DISPLAY="$DISPLAY" LIBGL_ALWAYS_SOFTWARE=1 surf "$URL" &>/tmp/browser.log & ;;
                qutebrowser) DISPLAY="$DISPLAY" qutebrowser "$URL" &>/tmp/browser.log & ;;
                links2) DISPLAY="$DISPLAY" links2 -g "$URL" &>/tmp/browser.log & ;;
                *)
                    echo "Unknown browser: $BROWSER"
                    exit 1
                    ;;
            esac
            echo "Started $BROWSER with $URL (PID: $!)"
        fi
        ;;

    refresh)
        WIN=$(ensure_window)
        DISPLAY="$DISPLAY" xdotool windowactivate "$WIN"
        DISPLAY="$DISPLAY" xdotool key "ctrl+r"
        echo "Page refreshed"
        ;;

    back)
        WIN=$(ensure_window)
        DISPLAY="$DISPLAY" xdotool windowactivate "$WIN"
        DISPLAY="$DISPLAY" xdotool key "alt+Left"
        echo "Navigated back"
        ;;

    forward)
        WIN=$(ensure_window)
        DISPLAY="$DISPLAY" xdotool windowactivate "$WIN"
        DISPLAY="$DISPLAY" xdotool key "alt+Right"
        echo "Navigated forward"
        ;;

    close)
        pkill -f "surf.*$DISPLAY" 2>/dev/null || true
        pkill -f "qutebrowser.*$DISPLAY" 2>/dev/null || true
        pkill -f "links2.*$DISPLAY" 2>/dev/null || true
        echo "Browser closed"
        ;;

    status)
        WIN=$(find_browser_window)
        if [ -n "$WIN" ]; then
            NAME=$(DISPLAY="$DISPLAY" xdotool getwindowname "$WIN" 2>/dev/null || echo "unknown")
            echo "Browser running: $NAME (window: $WIN)"
            DISPLAY="$DISPLAY" xdotool getwindowgeometry "$WIN" 2>/dev/null | head -2
        else
            echo "No browser window detected"
            exit 1
        fi
        ;;

    *)
        usage
        ;;
esac
