#!/usr/bin/env bash
# ============================================================================
# Clipboard — read, write, and clear the system clipboard
# ============================================================================
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/../lib/config.sh"

usage() {
    echo "Usage: clipboard.sh <command>"
    echo ""
    echo "Commands:"
    echo "  copy <text>     Copy text to clipboard"
    echo "  paste           Paste clipboard content (Ctrl+V)"
    echo "  read            Print clipboard content"
    echo "  clear           Clear the clipboard"
    echo "  file <path>     Copy file contents to clipboard"
    exit 1
}

CMD="${1:-}"
shift || true

case "$CMD" in
    copy)
        TEXT="$*"
        if [ -z "$TEXT" ]; then
            # Read from stdin
            TEXT=$(cat)
        fi
        if command -v xclip >/dev/null 2>&1; then
            DISPLAY="$DISPLAY" xclip -selection clipboard <<< "$TEXT"
            echo "Copied ${#TEXT} chars to clipboard"
        elif command -v xsel >/dev/null 2>&1; then
            DISPLAY="$DISPLAY" xsel -ib <<< "$TEXT"
            echo "Copied ${#TEXT} chars to clipboard"
        elif [ -n "${TERMUX_VERSION:-}" ] && command -v termux-clipboard-set >/dev/null 2>&1; then
            termux-clipboard-set "$TEXT"
            echo "Copied ${#TEXT} chars (Termux clipboard)"
        else
            echo "$TEXT" | DISPLAY="$DISPLAY" xdotool type --delay 5 --file -
            echo "Typed ${#TEXT} chars (fallback: xdotool type)"
        fi
        ;;

    read|get)
        if command -v xclip >/dev/null 2>&1; then
            DISPLAY="$DISPLAY" xclip -selection clipboard -o 2>/dev/null || echo ""
        elif command -v xsel >/dev/null 2>&1; then
            DISPLAY="$DISPLAY" xsel -ib 2>/dev/null || echo ""
        elif [ -n "${TERMUX_VERSION:-}" ] && command -v termux-clipboard-get >/dev/null 2>&1; then
            termux-clipboard-get
        else
            echo "(clipboard read not available)"
        fi
        ;;

    paste)
        WIN=$(DISPLAY="$DISPLAY" xdotool getactivewindow 2>/dev/null || true)
        if [ -n "$WIN" ]; then
            DISPLAY="$DISPLAY" xdotool key "ctrl+v" 2>/dev/null || \
            DISPLAY="$DISPLAY" xdotool key "Shift+Insert" 2>/dev/null || true
            echo "Pasted clipboard"
        else
            warn "No active window to paste into"
        fi
        ;;

    clear)
        if command -v xclip >/dev/null 2>&1; then
            DISPLAY="$DISPLAY" xclip -selection clipboard -i /dev/null
            echo "Clipboard cleared"
        elif command -v xsel >/dev/null 2>&1; then
            DISPLAY="$DISPLAY" xsel -cb
            echo "Clipboard cleared"
        else
            DISPLAY="$DISPLAY" xdotool key "ctrl+c" 2>/dev/null || true
            echo "Clipboard cleared (via Ctrl+C on empty selection)"
        fi
        ;;

    file)
        FILE="${1:-}"
        if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
            err "File not found: $FILE"
            exit 1
        fi
        if command -v xclip >/dev/null 2>&1; then
            DISPLAY="$DISPLAY" xclip -selection clipboard "$FILE"
        else
            DISPLAY="$DISPLAY" xdotool type --delay 5 --file "$FILE"
        fi
        echo "Copied file $FILE to clipboard"
        ;;

    *)
        usage
        ;;
esac
