#!/usr/bin/env bash
set -euo pipefail

DISPLAY="${DISPLAY:-:99}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

usage() {
    echo "Usage: click.sh <x> <y> [button]"
    echo "       click.sh --text <text-hint>"
    echo "       click.sh --element <element-type>"
    echo "       click.sh --analyze"
    echo ""
    echo "Buttons: 1=left (default), 2=middle, 3=right"
    echo "         --double for double-click"
    echo ""
    echo "Examples:"
    echo "  click.sh 640 480            Left click at coordinates"
    echo "  click.sh 640 480 3          Right click"
    echo "  click.sh 640 480 1 --double Double-left click"
    echo "  click.sh --text continue    Find 'Continue' button and click"
    echo "  click.sh --element modal    Dismiss modal overlay"
    echo "  click.sh --analyze          Show what's clickable on screen"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

case "${1:-}" in
    --text|--find)
        shift
        HINT="${1:-continue}"
        python3 "$REPO_DIR/lib/element_locator.py" --find "$HINT"
        ;;

    --element)
        shift
        ELEM="${1:-continue}"
        python3 "$REPO_DIR/lib/element_locator.py" --find "$ELEM"
        ;;

    --analyze)
        python3 "$REPO_DIR/lib/screen_analyzer.py" --capture
        ;;

    *)
        X="${1:-}"
        Y="${2:-}"
        BTN="${3:-1}"
        DOUBLE="${4:-}"

        if [ -z "$X" ] || [ -z "$Y" ]; then
            usage
        fi

        DISPLAY="$DISPLAY" xdotool mousemove "$X" "$Y"

        if [ "$DOUBLE" = "--double" ] || [ "$DOUBLE" = "-d" ]; then
            DISPLAY="$DISPLAY" xdotool click --repeat 2 "$BTN"
            echo "Double-clicked ($X, $Y) button $BTN"
        else
            DISPLAY="$DISPLAY" xdotool click "$BTN"
            BTN_NAME="left"
            [ "$BTN" = "2" ] && BTN_NAME="middle"
            [ "$BTN" = "3" ] && BTN_NAME="right"
            echo "Clicked ($X, $Y) $BTN_NAME button"
        fi
        ;;
esac
