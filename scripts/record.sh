#!/usr/bin/env bash
# ============================================================================
# Session Recording — record the screen with ffmpeg
# ============================================================================
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/../lib/config.sh"

usage() {
    echo "Usage: record.sh <command>"
    echo ""
    echo "Commands:"
    echo "  start [name]        Start recording (default name: session-<timestamp>)"
    echo "  stop                Stop recording and save video"
    echo "  status              Check if recording is active"
    echo "  list                List saved recordings"
    echo "  cleanup <days>      Delete recordings older than N days"
    exit 1
}

PID_FILE="$DATA_DIR/recording.pid"

CMD="${1:-}"
shift || true

case "$CMD" in
    start)
        NAME="${1:-session-$(date +%Y%m%d-%H%M%S)}"
        OUTPUT="$RECORD_DIR/$NAME.mp4"

        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            echo "Recording already active (PID: $(cat "$PID_FILE"))"
            echo "Output: $(cat "$DATA_DIR/recording_output.txt" 2>/dev/null || echo unknown)"
            exit 1
        fi

        mkdir -p "$RECORD_DIR"

        # Check display availability
        if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
            echo "Display $DISPLAY not available — recording may fail"
        fi

        # Check ffmpeg
        if ! command -v ffmpeg >/dev/null 2>&1; then
            echo "ffmpeg not installed. Install it and try again."
            exit 1
        fi

        # Get screen size
        read -r WIDTH HEIGHT <<< "$(xdpyinfo -display "$DISPLAY" 2>/dev/null | grep dimensions | grep -oP '\d+x\d+' | tr 'x' ' ' || echo '1280 720')"

        echo "Starting recording: $OUTPUT"
        echo "  Resolution: ${WIDTH}x${HEIGHT}"
        echo "  Display:    $DISPLAY"

        DISPLAY="$DISPLAY" ffmpeg -y -video_size "${WIDTH}x${HEIGHT}" -framerate 10 \
            -f x11grab -i "$DISPLAY.0+0,0" \
            -c:v libx264 -preset ultrafast -crf 28 \
            -pix_fmt yuv420p \
            "$OUTPUT" &>"$RECORD_DIR/ffmpeg.log" &
        PID=$!
        echo "$PID" > "$PID_FILE"
        echo "$OUTPUT" > "$DATA_DIR/recording_output.txt"

        # Verify it started
        sleep 2
        if kill -0 "$PID" 2>/dev/null; then
            echo "Recording started (PID: $PID)"
        else
            echo "Recording failed to start — check ffmpeg.log"
            tail -5 "$RECORD_DIR/ffmpeg.log"
            rm -f "$PID_FILE"
            exit 1
        fi
        ;;

    stop)
        if [ ! -f "$PID_FILE" ]; then
            # Try to find any lingering ffmpeg
            PID=$(pgrep -f "ffmpeg.*x11grab" 2>/dev/null | head -1 || true)
            if [ -n "$PID" ]; then
                echo "Found orphaned ffmpeg (PID: $PID)"
                kill "$PID" 2>/dev/null || true
                sleep 1
                echo "Recording stopped"
            else
                echo "No active recording"
                exit 0
            fi
        else
            PID=$(cat "$PID_FILE")
            if kill -0 "$PID" 2>/dev/null; then
                kill "$PID" 2>/dev/null || true
                sleep 1
                echo "Recording stopped"
            else
                echo "Recording process not running"
            fi
            rm -f "$PID_FILE"
        fi

        OUTPUT=$(cat "$DATA_DIR/recording_output.txt" 2>/dev/null || echo "")
        if [ -n "$OUTPUT" ] && [ -f "$OUTPUT" ]; then
            SIZE=$(du -h "$OUTPUT" | cut -f1)
            DURATION=$(ffprobe -v quiet -show_entries format=duration -of csv=p=0 "$OUTPUT" 2>/dev/null | xargs printf "%.0f" 2>/dev/null || echo "?")
            echo "  Saved: $OUTPUT (${SIZE}, ${DURATION}s)"
        fi
        rm -f "$DATA_DIR/recording_output.txt"
        ;;

    status)
        if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            OUTPUT=$(cat "$DATA_DIR/recording_output.txt" 2>/dev/null || echo unknown)
            SIZE=$( [ -f "$OUTPUT" ] && du -h "$OUTPUT" | cut -f1 || echo "N/A")
            echo "Recording: ACTIVE"
            echo "  PID:    $(cat "$PID_FILE")"
            echo "  Output: $OUTPUT"
            echo "  Size:   $SIZE"
        else
            PID=$(pgrep -f "ffmpeg.*x11grab" 2>/dev/null | head -1 || true)
            if [ -n "$PID" ]; then
                echo "Recording: ACTIVE (orphaned, PID: $PID)"
            else
                echo "Recording: INACTIVE"
            fi
        fi
        ;;

    list)
        echo "Saved recordings in $RECORD_DIR:"
        echo ""
        if [ -d "$RECORD_DIR" ]; then
            find "$RECORD_DIR" -name "*.mp4" -exec ls -lh {} \; 2>/dev/null | \
                awk '{printf "  %s %s %s\n", $6, $5, $NF}' || echo "  (none)"
        else
            echo "  (none)"
        fi
        ;;

    cleanup)
        DAYS="${1:-7}"
        echo "Cleaning up recordings older than ${DAYS} days..."
        find "$RECORD_DIR" -name "*.mp4" -mtime "+${DAYS}" -delete 2>/dev/null || true
        echo "Done"
        ;;

    *)
        usage
        ;;
esac
