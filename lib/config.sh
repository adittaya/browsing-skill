# ──────────────────────────────────────────────────────────────────────────────
# Config loader — source this in every script with:  source lib/config.sh
# Looks for config in: $DESKTOP_SKILL_CONFIG, then ~/.config/desktop-skill/config
# ──────────────────────────────────────────────────────────────────────────────

export DESKTOP_SKILL_DIR
DESKTOP_SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Locate config file
CONFIG_PATHS=(
    "${DESKTOP_SKILL_CONFIG:-}"
    "$HOME/.config/desktop-skill/config"
    "$HOME/.desktop-skill.cfg"
    "${DESKTOP_SKILL_DIR}/.config"
)

CONFIG_FILE=""
for p in "${CONFIG_PATHS[@]}"; do
    if [ -n "$p" ] && [ -f "$p" ]; then
        CONFIG_FILE="$p"
        break
    fi
done

# Load config if found
if [ -n "$CONFIG_FILE" ]; then
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"
fi

# ─── Apply defaults for anything not set ────────────────────────────────────

export DISPLAY_NUM="${DISPLAY_NUM:-99}"
export DISPLAY="${DISPLAY:-:$DISPLAY_NUM}"
export VNC_PORT="${VNC_PORT:-5900}"
export SCREEN_SIZE="${SCREEN_SIZE:-1280x720x24}"
export BROWSER="${BROWSER:-surf}"
export DATA_DIR="${DATA_DIR:-/tmp/desktop-skill}"
export RECORD_DIR="${RECORD_DIR:-$DATA_DIR/recordings}"
export DOWNLOAD_DIR="${DOWNLOAD_DIR:-$DATA_DIR/downloads}"
export OCR_LANG="${OCR_LANG:-eng}"
export WAIT_TIMEOUT="${WAIT_TIMEOUT:-15}"
export WATCHDOG_INTERVAL="${WATCHDOG_INTERVAL:-10}"
export SESSION_FILE="$DATA_DIR/session"
export LOG_FILE="$DATA_DIR/skill.log"

mkdir -p "$DATA_DIR" "$RECORD_DIR" "$DOWNLOAD_DIR" 2>/dev/null || true

# ─── Write default config if none exists ────────────────────────────────────

DEFAULT_CONFIG_DIR="$HOME/.config/desktop-skill"
DEFAULT_CONFIG="$DEFAULT_CONFIG_DIR/config"

if [ ! -f "$DEFAULT_CONFIG" ]; then
    mkdir -p "$DEFAULT_CONFIG_DIR" 2>/dev/null || true
    cat > "$DEFAULT_CONFIG" <<- 'CONFIGEOF'
# Desktop Environment Skill — Configuration
# This file was auto-generated. Edit to change defaults.

# Display
DISPLAY_NUM=99
DISPLAY=:99
SCREEN_SIZE=1280x720x24

# VNC
VNC_PORT=5900

# Browser (surf, qutebrowser, links2, firefox, chromium)
BROWSER=surf

# Directories
DATA_DIR=/tmp/desktop-skill
RECORD_DIR=${DATA_DIR}/recordings
DOWNLOAD_DIR=${DATA_DIR}/downloads

# OCR language (see tesseract --list-langs)
OCR_LANG=eng

# Adaptive wait: max seconds to wait for an element
WAIT_TIMEOUT=15

# Watchdog: seconds between health checks
WATCHDOG_INTERVAL=10
CONFIGEOF
fi

log()  { printf "\033[;32m[config]\033[0m %s\n" "$*"; }
warn() { printf "\033[;33m[config]\033[0m %s\n" "$*"; }
