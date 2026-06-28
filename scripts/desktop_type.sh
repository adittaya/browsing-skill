#!/usr/bin/env bash
# Linux Desktop: Type — type text using PyAutoGUI (human-like) or xdotool fallback
# Usage: bash scripts/desktop_type.sh "Hello World"
#        bash scripts/desktop_type.sh --key enter
#        bash scripts/desktop_type.sh --slow "Important text"
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"

TEXT=""
KEY=""
INTERVAL=0.05

while [ $# -gt 0 ]; do
    case "$1" in
        --key) KEY="$2"; shift 2 ;;
        --slow) INTERVAL="$2"; shift 2 ;;
        *) TEXT="$1"; shift ;;
    esac
done

if [ -n "$KEY" ]; then
    python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR/lib')
from linux_desktop import LinuxDesktop
dt = LinuxDesktop()
print(dt.type_text('', key='$KEY'))
"
elif [ -n "$TEXT" ]; then
    python3 -c "
import sys
sys.path.insert(0, '$SCRIPT_DIR/lib')
from linux_desktop import LinuxDesktop
dt = LinuxDesktop()
print(dt.type_text('$TEXT', interval=$INTERVAL))
"
else
    echo "Usage: $0 <text> | --key <key> | --slow <text>"
    echo "Keys: enter, tab, escape, backspace, up, down, left, right, ctrl+c, alt+f4"
    exit 1
fi
