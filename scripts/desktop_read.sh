#!/usr/bin/env bash
# Linux Desktop: Read — read screen using accessibility tree + OCR
# Uses pyatspi, mss, pytesseract to convert screen into structured text.
# Usage: bash scripts/desktop_read.sh
#        bash scripts/desktop_read.sh --json
#        bash scripts/desktop_read.sh --ocr-only
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

case "${1:-}" in
    --ocr-only)
        python3 -c "
import json, sys
sys.path.insert(0, '$SCRIPT_DIR/lib')
from linux_desktop import LinuxDesktop
dt = LinuxDesktop()
elements = dt.ocr_screen()
if isinstance(elements, list):
    for e in elements:
        print(f'  \"{e.text}\" @({e.center_x},{e.center_y}) [{e.width}x{e.height}]')
else:
    print(elements.get('error', 'Unknown error'))
"
        ;;
    --accessibility-only)
        python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR/lib')
from linux_desktop import LinuxDesktop
dt = LinuxDesktop()
tree = dt.get_accessibility_tree()
if isinstance(tree, list):
    print(dt.accessibility_to_text(tree))
else:
    print(tree.get('error', 'Unknown error'))
"
        ;;
    *)
        python3 "$SCRIPT_DIR/lib/linux_desktop.py" read
        ;;
esac
