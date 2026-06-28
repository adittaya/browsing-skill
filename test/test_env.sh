#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DISPLAY="${DISPLAY:-:99}"

echo "========================================="
echo "  Environment Test Suite"
echo "========================================="
echo ""

FAILED=0
PASSED=0

check() {
    local name="$1"
    shift
    if "$@" &>/dev/null; then
        echo "  [PASS] $name"
        PASSED=$((PASSED + 1))
    else
        echo "  [FAIL] $name"
        FAILED=$((FAILED + 1))
    fi
}

echo "--- Dependency Checks ---"
check "Xvfb available" command -v Xvfb
check "x11vnc available" command -v x11vnc
check "fluxbox available" command -v fluxbox
check "xdotool available" command -v xdotool
check "python3 available" command -v python3
check "ImageMagick import available" command -v import
check "Pillow available" python3 -c "from PIL import Image; print('ok')"

echo ""
echo "--- Python Library Checks ---"
check "screen_analyzer imports" python3 -c "import sys; sys.path.insert(0,'$REPO_DIR/lib'); from screen_analyzer import ScreenAnalyzer"
check "element_locator imports" python3 -c "import sys; sys.path.insert(0,'$REPO_DIR/lib'); from element_locator import ElementLocator"

echo ""
echo "--- Environment Checks ---"
check "Xvfb running" pgrep -f "Xvfb $DISPLAY"
check "x11vnc running" pgrep -f "x11vnc.*$DISPLAY"
check "fluxbox running" pgrep -f "fluxbox.*$DISPLAY"

echo ""
echo "--- Screen Checks ---"
check "Screen capture works" DISPLAY="$DISPLAY" import -window root /tmp/test_screen.png
check "Screenshot has content" python3 -c "
from PIL import Image; img = Image.open('/tmp/test_screen.png')
assert img.size == (1280, 720), f'Bad size: {img.size}'
print(f'OK: {img.size}')
"

echo ""
echo "--- Analysis Checks ---"
check "Screen analysis runs" python3 "$REPO_DIR/lib/screen_analyzer.py" /tmp/test_screen.png
check "Element locator runs" python3 "$REPO_DIR/lib/element_locator.py" --analyze

echo ""
echo "========================================="
echo "  Results: $PASSED passed, $FAILED failed"
echo "========================================="

exit $FAILED
