#!/usr/bin/env bash
set -euo pipefail

DISPLAY="${DISPLAY:-:99}"

usage() {
    echo "Usage: scroll.sh <direction> [amount]"
    echo ""
    echo "Directions:"
    echo "  down         Scroll down (default)"
    echo "  up           Scroll up"
    echo "  top          Scroll to top"
    echo "  bottom       Scroll to bottom"
    echo "  page-down    Page down"
    echo "  page-up      Page up"
    echo ""
    echo "Amount: number of scroll steps (default: 3, ignored for page/top/bottom)"
    exit 1
}

DIR="${1:-down}"
AMOUNT="${2:-3}"

case "$DIR" in
    down)
        for i in $(seq 1 "$AMOUNT"); do
            DISPLAY="$DISPLAY" xdotool click 5
            sleep 0.3
        done
        echo "Scrolled down $AMOUNT steps"
        ;;

    up)
        for i in $(seq 1 "$AMOUNT"); do
            DISPLAY="$DISPLAY" xdotool click 4
            sleep 0.3
        done
        echo "Scrolled up $AMOUNT steps"
        ;;

    top|home)
        DISPLAY="$DISPLAY" xdotool key "ctrl+Home"
        echo "Scrolled to top"
        ;;

    bottom|end)
        DISPLAY="$DISPLAY" xdotool key "ctrl+End"
        echo "Scrolled to bottom"
        ;;

    page-down|pagedown)
        DISPLAY="$DISPLAY" xdotool key "Page_Down"
        echo "Page down"
        ;;

    page-up|pageup)
        DISPLAY="$DISPLAY" xdotool key "Page_Up"
        echo "Page up"
        ;;

    *)
        usage
        ;;
esac
