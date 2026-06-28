#!/usr/bin/env bash
# Linux Desktop: Click — click on screen elements by method
# Usage: bash scripts/desktop_click.sh <x> <y>       # Click coordinates
#        bash scripts/desktop_click.sh --text <text>  # Find text + click
#        bash scripts/desktop_click.sh --template <img.png>  # Find icon + click
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ "${1:-}" = "--text" ]; then
    TEXT="${2:-}"
    [ -z "$TEXT" ] && echo "Usage: $0 --text <text>" && exit 1
    python3 "$SCRIPT_DIR/lib/linux_desktop.py" find "$TEXT"
elif [ "${1:-}" = "--template" ]; then
    TEMPLATE="${2:-}"
    [ -z "$TEMPLATE" ] && echo "Usage: $0 --template <image.png>" && exit 1
    python3 -c "
import json, sys
sys.path.insert(0, '$SCRIPT_DIR/lib')
from linux_desktop import LinuxDesktop
dt = LinuxDesktop()
el = dt.find_template('$TEMPLATE')
if el:
    dt.click_element(el)
    print(json.dumps({'success': True, 'x': el.center_x, 'y': el.center_y, 'confidence': el.confidence}))
else:
    print(json.dumps({'success': False, 'error': 'Template not found'}))
"
elif [ $# -ge 2 ]; then
    python3 "$SCRIPT_DIR/lib/linux_desktop.py" click "$1" "$2"
else
    echo "Usage: $0 <x> <y> | --text <text> | --template <img.png>"
    exit 1
fi
