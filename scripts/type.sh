#!/usr/bin/env bash
set -euo pipefail

DISPLAY="${DISPLAY:-:99}"

usage() {
    echo "Usage: type.sh <text>"
    echo "       type.sh --input <text>"
    echo "       type.sh --key <key-combo>"
    echo ""
    echo "Examples:"
    echo "  type.sh \"Hello World\"       Type text"
    echo '  type.sh --key "ctrl+a"       Press Ctrl+A'
    echo '  type.sh --key "Return"       Press Enter'
    echo "  type.sh --input \"user@example.com\"  Type into focused field"
    exit 1
}

if [ $# -eq 0 ]; then
    usage
fi

case "${1:-}" in
    --input|--text)
        shift
        TEXT="$*"
        DISPLAY="$DISPLAY" xdotool type --delay 15 "$TEXT"
        echo "Typed: ${TEXT:0:50}${TEXT:50+}"
        ;;

    --key)
        shift
        KEYS="$*"
        DISPLAY="$DISPLAY" xdotool key "$KEYS"
        echo "Pressed: $KEYS"
        ;;

    *)
        DISPLAY="$DISPLAY" xdotool type --delay 15 "$*"
        echo "Typed: ${*:0:50}${*:50+}"
        ;;
esac
