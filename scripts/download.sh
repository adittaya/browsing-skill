#!/usr/bin/env bash
# ============================================================================
# Download Manager — track, list, and retrieve downloaded files
# ============================================================================
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/../lib/config.sh"

usage() {
    echo "Usage: download.sh <command> [args]"
    echo ""
    echo "Commands:"
    echo "  list                List downloaded files"
    echo "  recent [n]          Show N most recent downloads (default: 5)"
    echo "  latest              Show path to the most recent download"
    echo "  watch [seconds]     Watch for new downloads (poll every N sec, default 2)"
    echo "  open <file>         Open a downloaded file in the browser"
    echo "  cleanup <days>      Delete downloads older than N days"
    echo "  monitor <ext>       Start monitoring for downloads of type (pdf,zip,etc)"
    exit 1
}

CMD="${1:-}"
shift || true

mkdir -p "$DOWNLOAD_DIR"

case "$CMD" in
    list)
        echo "Downloads in $DOWNLOAD_DIR:"
        echo ""
        if [ -d "$DOWNLOAD_DIR" ] && [ "$(find "$DOWNLOAD_DIR" -mindepth 1 2>/dev/null | wc -l)" -gt 0 ]; then
            ls -lhS "$DOWNLOAD_DIR" | head -40
        else
            echo "  (empty)"
        fi
        ;;

    recent)
        COUNT="${1:-5}"
        echo "${COUNT} most recent downloads:"
        echo ""
        find "$DOWNLOAD_DIR" -type f -printf '%T@ %p\n' 2>/dev/null | \
            sort -rn | head -n "$COUNT" | \
            while IFS= read -r line; do
                TS=$(echo "$line" | cut -d' ' -f1)
                FILE=$(echo "$line" | cut -d' ' -f2-)
                SIZE=$(du -h "$FILE" 2>/dev/null | cut -f1)
                DATE=$(date -d "@$TS" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo "?")
                echo "  $DATE  ${SIZE}  $(basename "$FILE")"
            done
        ;;

    latest)
        LATEST=$(find "$DOWNLOAD_DIR" -type f -printf '%T@ %p\n' 2>/dev/null | \
            sort -rn | head -1 | cut -d' ' -f2-)
        if [ -n "$LATEST" ] && [ -f "$LATEST" ]; then
            echo "$LATEST ($(du -h "$LATEST" | cut -f1))"
        else
            echo "No downloads yet"
            exit 1
        fi
        ;;

    watch)
        INTERVAL="${1:-2}"
        echo "Watching $DOWNLOAD_DIR for new files (poll every ${INTERVAL}s)..."
        echo "Press Ctrl+C to stop"
        echo ""
        BEFORE=$(find "$DOWNLOAD_DIR" -type f 2>/dev/null | wc -l)
        while true; do
            sleep "$INTERVAL"
            AFTER=$(find "$DOWNLOAD_DIR" -type f 2>/dev/null | wc -l)
            if [ "$AFTER" -gt "$BEFORE" ]; then
                NEW_FILES=$(find "$DOWNLOAD_DIR" -type f -newer "$DOWNLOAD_DIR/.watch" 2>/dev/null || echo "")
                if [ -n "$NEW_FILES" ]; then
                    echo "[$(date '+%H:%M:%S')] New download detected:"
                    find "$DOWNLOAD_DIR" -type f -newer "$DOWNLOAD_DIR/.watch" -exec ls -lh {} \; 2>/dev/null | sed 's/^/  /'
                fi
                BEFORE="$AFTER"
            fi
            touch "$DOWNLOAD_DIR/.watch" 2>/dev/null || true
        done
        ;;

    open)
        FILE="${1:-}"
        if [ -z "$FILE" ]; then
            # Open the latest download
            FILE=$(find "$DOWNLOAD_DIR" -type f -printf '%T@ %p\n' 2>/dev/null | \
                sort -rn | head -1 | cut -d' ' -f2-)
        fi
        if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
            echo "File not found: $FILE"
            exit 1
        fi
        echo "Opening: $FILE"
        # Try to open in browser via file:// URL
        bash "$(dirname "$0")/browser.sh" open "file://$(realpath "$FILE")" 2>/dev/null || \
        xdg-open "$FILE" 2>/dev/null || \
        echo "Could not open file — it's at: $FILE"
        ;;

    cleanup)
        DAYS="${1:-30}"
        echo "Cleaning up downloads older than ${DAYS} days from $DOWNLOAD_DIR..."
        COUNT=$(find "$DOWNLOAD_DIR" -type f -mtime "+${DAYS}" -delete -print 2>/dev/null | wc -l)
        echo "Removed $COUNT files"
        ;;

    monitor)
        EXT="${1:-}"
        echo "Monitoring for $EXT downloads..."
        echo "Downloads go to: $DOWNLOAD_DIR"
        echo "Use 'download.sh list' to see files"
        # Just set download dir for the specified type
        mkdir -p "$DOWNLOAD_DIR/$EXT" 2>/dev/null || true
        ;;

    *)
        usage
        ;;
esac
