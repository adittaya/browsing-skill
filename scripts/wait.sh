#!/usr/bin/env bash
# ============================================================================
# Adaptive Wait — wait for screen conditions before proceeding
# Polls until a condition is met or timeout expires.
# ============================================================================
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/../lib/config.sh"

usage() {
    echo "Usage: wait.sh <condition> [args]"
    echo ""
    echo "Conditions:"
    echo "  stable [secs]       Wait until screen stops changing (default 2s stability)"
    echo "  text <string>       Wait for text to appear on screen (via OCR)"
    echo "  button <hint>       Wait for a button with hint to appear"
    echo "  modal <dismiss>     Wait for modal to appear then dismiss"
    echo "  loaded [secs]       Wait for page to load (screen stops changing)"
    echo "  seconds <n>         Just sleep N seconds (simple delay)"
    echo "  window <name>       Wait for window with title to appear"
    echo "  pixel <x> <y> <hex> Wait for pixel to match color"
    echo ""
    echo "Examples:"
    echo "  wait.sh stable              Wait for page to finish loading"
    echo "  wait.sh text 'Continue'     Wait for text to appear (up to 15s)"
    echo "  wait.sh button continue     Wait for Continue button"
    echo "  wait.sh seconds 5           Plain sleep"
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
TIMEOUT="${WAIT_TIMEOUT:-15}"
INTERVAL=0.5

COND="${1:-}"
shift || true

case "$COND" in
    stable|loaded)
        MIN_STABLE="${1:-2}"
        echo "Waiting for screen to stabilize (timeout: ${TIMEOUT}s)..."
        LAST_HASH=""
        STABLE_FOR=0
        ELAPSED=0
        while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
            CAPTURE=$(DISPLAY="$DISPLAY" import -window root /tmp/_wait_stable.png 2>/dev/null || true)
            HASH=$(md5sum /tmp/_wait_stable.png 2>/dev/null | cut -d' ' -f1 || echo "")
            if [ "$HASH" = "$LAST_HASH" ] && [ -n "$HASH" ]; then
                STABLE_FOR=$(echo "$STABLE_FOR + $INTERVAL" | bc 2>/dev/null || echo "0")
                if [ "$(echo "$STABLE_FOR >= $MIN_STABLE" | bc 2>/dev/null)" = "1" ]; then
                    echo "Screen stable for ${MIN_STABLE}s after ${ELAPSED}s total"
                    rm -f /tmp/_wait_stable.png
                    exit 0
                fi
            else
                STABLE_FOR=0
            fi
            LAST_HASH="$HASH"
            sleep "$INTERVAL"
            ELAPSED=$(echo "$ELAPSED + $INTERVAL" | bc 2>/dev/null || echo "0")
        done
        echo "Timeout: screen did not stabilize in ${TIMEOUT}s"
        rm -f /tmp/_wait_stable.png
        exit 1
        ;;

    text)
        TEXT="${1:-}"
        if [ -z "$TEXT" ]; then
            usage
        fi
        echo "Waiting for text '$TEXT' (timeout: ${TIMEOUT}s)..."
        ELAPSED=0
        while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
            RESULT=$(python3 "$REPO_DIR/lib/ocr.py" --capture --find "$TEXT" 2>/dev/null || true)
            if echo "$RESULT" | grep -qi "found"; then
                echo "$RESULT"
                echo "Text appeared after ${ELAPSED}s"
                exit 0
            fi
            sleep "$INTERVAL"
            ELAPSED=$(echo "$ELAPSED + $INTERVAL" | bc 2>/dev/null || echo "0")
        done
        echo "Timeout: '$TEXT' not found in ${TIMEOUT}s"
        exit 1
        ;;

    button)
        HINT="${1:-continue}"
        echo "Waiting for '$HINT' button (timeout: ${TIMEOUT}s)..."
        ELAPSED=0
        while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
            RESULT=$(python3 "$REPO_DIR/lib/screen_analyzer.py" --capture --json 2>/dev/null || true)
            if echo "$RESULT" | grep -qi "button"; then
                echo "Button detected after ${ELAPSED}s"
                exit 0
            fi
            sleep "$INTERVAL"
            ELAPSED=$(echo "$ELAPSED + $INTERVAL" | bc 2>/dev/null || echo "0")
        done
        echo "Timeout: button not found in ${TIMEOUT}s"
        exit 1
        ;;

    modal)
        echo "Waiting for modal (timeout: ${TIMEOUT}s)..."
        ELAPSED=0
        while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
            RESULT=$(python3 "$REPO_DIR/lib/screen_analyzer.py" --capture --json 2>/dev/null || true)
            if echo "$RESULT" | grep -qi "modal"; then
                echo "Modal detected after ${ELAPSED}s, dismissing..."
                bash "$REPO_DIR/scripts/click.sh" --element modal 2>/dev/null || true
                exit 0
            fi
            sleep "$INTERVAL"
            ELAPSED=$(echo "$ELAPSED + $INTERVAL" | bc 2>/dev/null || echo "0")
        done
        echo "Timeout: no modal appeared in ${TIMEOUT}s"
        exit 1
        ;;

    seconds)
        COUNT="${1:-3}"
        echo "Waiting ${COUNT}s..."
        sleep "$COUNT"
        echo "Done"
        ;;

    window)
        NAME="${1:-}"
        if [ -z "$NAME" ]; then
            usage
        fi
        echo "Waiting for window '$NAME' (timeout: ${TIMEOUT}s)..."
        ELAPSED=0
        while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
            WIN=$(DISPLAY="$DISPLAY" xdotool search --name "$NAME" 2>/dev/null | head -1 || true)
            if [ -n "$WIN" ]; then
                echo "Window '$NAME' found after ${ELAPSED}s"
                exit 0
            fi
            sleep "$INTERVAL"
            ELAPSED=$(echo "$ELAPSED + $INTERVAL" | bc 2>/dev/null || echo "0")
        done
        echo "Timeout: window '$NAME' not found in ${TIMEOUT}s"
        exit 1
        ;;

    pixel)
        X="${1:-}"
        Y="${2:-}"
        HEX="${3:-}"
        if [ -z "$X" ] || [ -z "$Y" ]; then
            usage
        fi
        echo "Waiting for pixel ($X, $Y) to match $HEX (timeout: ${TIMEOUT}s)..."
        ELAPSED=0
        while [ "$ELAPSED" -lt "$TIMEOUT" ]; do
            COLOR=$(DISPLAY="$DISPLAY" xdotool getpixel "$X" "$Y" 2>/dev/null || echo "")
            if [ "$COLOR" = "$HEX" ]; then
                echo "Pixel matched after ${ELAPSED}s"
                exit 0
            fi
            sleep "$INTERVAL"
            ELAPSED=$(echo "$ELAPSED + $INTERVAL" | bc 2>/dev/null || echo "0")
        done
        echo "Timeout: pixel did not match in ${TIMEOUT}s"
        exit 1
        ;;

    *)
        usage
        ;;
esac
