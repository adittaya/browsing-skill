#!/usr/bin/env bash
set -euo pipefail

DISPLAY="${DISPLAY:-:99}"
OUTPUT="${1:-/tmp/screen.png}"
ANALYZE="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# Capture screenshot
DISPLAY="$DISPLAY" import -window root "$OUTPUT" 2>&1
echo "Screenshot saved to $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"

# Analyze if requested
if [ "${ANALYZE}" = "--analyze" ] || [ "${ANALYZE}" = "-a" ]; then
    python3 "$REPO_DIR/lib/screen_analyzer.py" "$OUTPUT"
fi

# Output as JSON if requested
if [ "${ANALYZE}" = "--json" ] || [ "${ANALYZE}" = "-j" ]; then
    python3 "$REPO_DIR/lib/screen_analyzer.py" "$OUTPUT" --json
fi
