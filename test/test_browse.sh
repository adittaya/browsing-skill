#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
DISPLAY="${DISPLAY:-:99}"

echo "========================================="
echo "  Browsing Workflow Test"
echo "========================================="
echo ""

FAILED=0

run_test() {
    local name="$1"
    shift
    echo "--- Test: $name ---"
    if "$@" 2>&1; then
        echo "  [PASS] $name"
    else
        echo "  [FAIL] $name"
        FAILED=$((FAILED + 1))
    fi
    echo ""
}

# Make scripts executable
chmod +x "$REPO_DIR/setup/"*.sh "$REPO_DIR/scripts/"*.sh

# Test 1: Navigate to a page
run_test "Navigate to example.com" \
    bash "$REPO_DIR/scripts/browser.sh" open "https://example.com"

sleep 3

# Test 2: Take screenshot and analyze
run_test "Screenshot and analyze" \
    bash "$REPO_DIR/scripts/screenshot.sh" /tmp/test_browse.png --analyze

# Test 3: Scroll down
run_test "Scroll down" \
    bash "$REPO_DIR/scripts/scroll.sh" down 3

sleep 1

# Test 4: Scroll to top
run_test "Scroll to top" \
    bash "$REPO_DIR/scripts/scroll.sh" top

sleep 1

# Test 5: Take another screenshot
run_test "Second screenshot" \
    bash "$REPO_DIR/scripts/screenshot.sh" /tmp/test_browse2.png

# Test 6: Click in center (should do nothing harmful)
run_test "Click center" \
    bash "$REPO_DIR/scripts/click.sh" 640 360

sleep 1

# Test 7: Environment status
run_test "Status check" \
    bash "$REPO_DIR/scripts/status.sh"

echo "========================================="
if [ "$FAILED" -eq 0 ]; then
    echo "  All tests passed!"
else
    echo "  $FAILED test(s) failed"
fi
echo "========================================="

exit $FAILED
