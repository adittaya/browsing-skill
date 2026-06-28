#!/usr/bin/env bash
# ============================================================================
# Dialog Handler — detect and interact with JavaScript dialogs
# (alert, confirm, prompt) and system popup windows.
# ============================================================================
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/../lib/config.sh"

usage() {
    echo "Usage: dialog.sh <command>"
    echo ""
    echo "Commands:"
    echo "  detect              Check if a dialog is open"
    echo "  accept              Press Enter / click OK"
    echo "  dismiss             Press Escape / click Cancel"
    echo "  type <text>         Type into a prompt dialog"
    echo "  screenshot          Capture just the dialog area"
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

CMD="${1:-}"
shift || true

case "$CMD" in
    detect)
        # Multiple detection strategies
        FOUND=false

        # 1. Check for dialog windows via xdotool
        WINS=$(DISPLAY="$DISPLAY" xdotool search --name "" 2>/dev/null | sort -u || true)
        for WIN in $WINS; do
            NAME=$(DISPLAY="$DISPLAY" xdotool getwindowname "$WIN" 2>/dev/null || true)
            case "$NAME" in
                *alert*|*Alert*|*confirm*|*Confirm*|*prompt*|*Prompt*)
                    echo "Dialog detected via window title: $NAME (ID: $WIN)"
                    FOUND=true
                    ;;
            esac
        done

        # 2. Check for modal windows (transient-for or above other windows)
        ACTIVE=$(DISPLAY="$DISPLAY" xdotool getactivewindow 2>/dev/null || true)
        ROOT=$(DISPLAY="$DISPLAY" xdotool getrootwindow 2>/dev/null || true)
        if [ -n "$ACTIVE" ] && [ -n "$ROOT" ] && [ "$ACTIVE" != "$ROOT" ]; then
            ACTIVE_NAME=$(DISPLAY="$DISPLAY" xdotool getwindowname "$ACTIVE" 2>/dev/null || true)
            if [ -n "$ACTIVE_NAME" ]; then
                echo "Active window: $ACTIVE_NAME (ID: $ACTIVE)"
                FOUND=true
            fi
        fi

        # 3. Use screen analyzer to look for dialog-like UI
        RESULT=$(python3 "$REPO_DIR/lib/screen_analyzer.py" --capture --json 2>/dev/null || true)
        if echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print('modal' if d.get('modal') else '')" 2>/dev/null | grep -q .; then
            echo "Dialog detected via screen analysis (modal overlay)"
            FOUND=true
        fi

        if [ "$FOUND" = false ]; then
            echo "No dialog detected"
            exit 1
        fi
        ;;

    accept|ok|confirm)
        echo "Accepting dialog..."

        # Strategy 1: Press Enter (works for most JS dialogs)
        DISPLAY="$DISPLAY" xdotool key --delay 100 Return
        sleep 0.5

        # Strategy 2: Click center of screen (for custom modal buttons)
        if python3 "$REPO_DIR/lib/screen_analyzer.py" --capture --json 2>/dev/null | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print('modal' if d.get('modal') else '')" 2>/dev/null | grep -q .; then
            # Click at the center of the screen where OK buttons usually are
            DISPLAY="$DISPLAY" xdotool mousemove 640 450 click 1
            sleep 0.3
            # Also try clicking a generic OK button area
            bash "$REPO_DIR/scripts/click.sh" --text OK 2>/dev/null || true
            bash "$REPO_DIR/scripts/click.sh" --text ok 2>/dev/null || true
            bash "$REPO_DIR/scripts/click.sh" --text Accept 2>/dev/null || true
        fi

        echo "Dialog accepted"
        ;;

    dismiss|cancel)
        echo "Dismissing dialog..."

        # Strategy 1: Press Escape
        DISPLAY="$DISPLAY" xdotool key Escape
        sleep 0.5

        # Strategy 2: Click outside / Cancel button
        if python3 "$REPO_DIR/lib/screen_analyzer.py" --capture --json 2>/dev/null | \
            python3 -c "import sys,json; d=json.load(sys.stdin); print('modal' if d.get('modal') else '')" 2>/dev/null | grep -q .; then
            bash "$REPO_DIR/scripts/click.sh" --text Cancel 2>/dev/null || true
            bash "$REPO_DIR/scripts/click.sh" --text cancel 2>/dev/null || true
            bash "$REPO_DIR/scripts/click.sh" --text Dismiss 2>/dev/null || true
            # Click top-right corner (close button area)
            DISPLAY="$DISPLAY" xdotool mousemove 1230 50 click 1
        fi

        echo "Dialog dismissed"
        ;;

    type)
        TEXT="$*"
        echo "Typing into prompt dialog: $TEXT"
        DISPLAY="$DISPLAY" xdotool type --delay 15 "$TEXT"
        sleep 0.3
        DISPLAY="$DISPLAY" xdotool key Return
        echo "Done"
        ;;

    screenshot)
        # Take screenshot focused on where dialogs usually appear
        DISPLAY="$DISPLAY" import -window root /tmp/_dialog_screen.png
        # Crop the center area where modals appear
        python3 -c "
from PIL import Image
img = Image.open('/tmp/_dialog_screen.png')
w, h = img.size
# Crop center 60% where dialogs appear
cx, cy = w//2, h//2
dw, dh = int(w*0.4), int(h*0.4)
crop = img.crop((cx-dw, cy-dh, cx+dw, cy+dh))
crop.save('/tmp/_dialog_crop.png')
print('Dialog area saved')
"
        echo "Dialog screenshot: /tmp/_dialog_crop.png"
        ;;

    *)
        usage
        ;;
esac
