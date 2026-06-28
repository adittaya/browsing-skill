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
    echo "Examples:"
    echo "  click.sh 640 480           Click at coordinates"
    echo "  click.sh --text continue   Find and click 'Continue' button"
    echo "  click.sh --element modal   Find and click modal dismiss button"
    echo "  click.sh --analyze         Analyze screen and show clickable areas"
    echo ""
    echo "Button: 1=left, 2=middle, 3=right (default: 1)"
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

    --json)
        shift
        if [ $# -ge 2 ]; then
            python3 "$REPO_DIR/lib/element_locator.py" --click "$1" "$2" --json
        else
            python3 "$REPO_DIR/lib/element_locator.py" --find "${1:-continue}" --json
        fi
        ;;

    *)
        X="${1:-}"
        Y="${2:-}"
        BTN="${3:-1}"
        if [ -z "$X" ] || [ -z "$Y" ]; then
            usage
        fi
        DISPLAY="$DISPLAY" xdotool mousemove "$X" "$Y" click "$BTN"
        echo "Clicked ($X, $Y) with button $BTN"
        ;;
esac
