#!/usr/bin/env bash
# ============================================================================
# Start Desktop Environment
# Auto-detects: terminal, existing desktop, Termux, proot-distro
# Loads config, starts Xvfb/WM/VNC/browser, launches watchdog + recording
# Browser stays persistent — never killed or reopened.
# ============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

# ─── Load config ─────────────────────────────────────────────────────────────
source "$REPO_DIR/lib/config.sh"

# ─── Runtime environment detection ──────────────────────────────────────────

detect_runtime() {
    if [ -n "${TERMUX_VERSION:-}" ] || command -v termux-setup-storage >/dev/null 2>&1; then
        echo "termux"; return
    fi
    if [ -n "${DISPLAY:-}" ]; then
        if command -v xdpyinfo >/dev/null 2>&1 && xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
            echo "existing-desktop"; return
        fi
    fi
    if [ -n "${WAYLAND_DISPLAY:-}" ] && [ -e "${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY:-wayland-0}" 2>/dev/null ]; then
        echo "existing-desktop"; return
    fi
    echo "terminal"
}

RUNTIME_ENV=$(detect_runtime)

DISTRO_ENV="linux"
if [ -n "${TERMUX_VERSION:-}" ] || command -v termux-setup-storage >/dev/null 2>&1; then
    DISTRO_ENV="termux"
elif [ -f "/data/data/com.termux/files/usr/bin/proot-distro" ] || \
     grep -q "PROot-Distro" /proc/version 2>/dev/null; then
    DISTRO_ENV="proot-distro"
fi

# ─── Session Tracking ───────────────────────────────────────────────────────

session_save() {
    cat > "$SESSION_FILE" <<-EOF
DISPLAY_NUM=$DISPLAY_NUM
DISPLAY=$DISPLAY
VNC_PORT=$VNC_PORT
BROWSER=$BROWSER
SCREEN_SIZE=$SCREEN_SIZE
RUNTIME_ENV=$RUNTIME_ENV
DISTRO_ENV=$DISTRO_ENV
WATCHDOG_PID=$(pgrep -f "watchdog.sh _daemon" 2>/dev/null | head -1 || echo "")
RECORDING_PID=$(pgrep -f "ffmpeg.*x11grab" 2>/dev/null | head -1 || echo "")
XVFB_PID=$(pgrep -f "Xvfb $DISPLAY" 2>/dev/null | head -1 || echo "")
X11VNC_PID=$(pgrep -f "x11vnc.*$DISPLAY" 2>/dev/null | head -1 || echo "")
FLUXBOX_PID=$(pgrep -f "fluxbox.*$DISPLAY" 2>/dev/null | head -1 || echo "")
BROWSER_PID=$(pgrep -f "$BROWSER.*$DISPLAY" 2>/dev/null | head -1 || echo "")
BROWSER_WINDOW=$(DISPLAY="$DISPLAY" xdotool search --name ".+" 2>/dev/null | head -1 || echo "")
EOF
}

# ─── X Server ───────────────────────────────────────────────────────────────

ensure_xserver() {
    if [ "$RUNTIME_ENV" = "existing-desktop" ]; then
        log "Existing desktop detected on $DISPLAY — skipping Xvfb"
        return 0
    fi
    if [ -n "${DISPLAY:-}" ] && xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
        log "Display $DISPLAY already active — skipping Xvfb"
        return 0
    fi
    if [ "$DISTRO_ENV" = "proot-distro" ] && ! command -v Xvfb >/dev/null 2>&1; then
        warn "Xvfb not available in proot-distro"
        log "Continuing with headless mode (screenshots via Python only)"
        return 0
    fi
    if [ "$DISTRO_ENV" = "termux" ] && [ -z "${DISPLAY:-}" ]; then
        warn "Termux detected but no DISPLAY set — falling back to headless mode"
        return 0
    fi
    if pgrep -f "Xvfb $DISPLAY" >/dev/null 2>&1; then
        log "Xvfb already running on $DISPLAY"
        return 0
    fi
    if command -v Xvfb >/dev/null 2>&1; then
        log "Starting Xvfb on $DISPLAY (${SCREEN_SIZE})..."
        Xvfb "$DISPLAY" -screen 0 "$SCREEN_SIZE" &>"$DATA_DIR/xvfb.log" &
        local pid=$!
        for i in $(seq 1 5); do
            if kill -0 "$pid" 2>/dev/null && xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
                log "Xvfb PID: $pid"
                return 0
            fi
            sleep 1
        done
        warn "Xvfb may not have started — check $DATA_DIR/xvfb.log"
        return 0
    fi
    warn "No X server available — running headless"
}

# ─── Window Manager ─────────────────────────────────────────────────────────

ensure_wm() {
    if [ "$RUNTIME_ENV" = "existing-desktop" ]; then
        return 0
    fi
    if command -v fluxbox >/dev/null 2>&1; then
        if pgrep -f "fluxbox.*$DISPLAY" >/dev/null 2>&1; then
            log "Fluxbox already running"
            return 0
        fi
        log "Starting fluxbox..."
        DISPLAY="$DISPLAY" fluxbox &>"$DATA_DIR/fluxbox.log" &
        sleep 2
    elif command -v openbox >/dev/null 2>&1; then
        if pgrep -f "openbox.*$DISPLAY" >/dev/null 2>&1; then
            log "Openbox already running"
            return 0
        fi
        log "Starting openbox..."
        DISPLAY="$DISPLAY" openbox &>"$DATA_DIR/fluxbox.log" &
        sleep 2
    else
        warn "No window manager found — continuing anyway"
    fi
}

# ─── VNC ────────────────────────────────────────────────────────────────────

ensure_vnc() {
    if [ "$RUNTIME_ENV" = "existing-desktop" ]; then
        log "On existing desktop — VNC not needed"
        return 0
    fi
    if [ "$DISTRO_ENV" = "termux" ]; then
        log "Termux — use Termux:X11 app for display"
        return 0
    fi
    if ! command -v x11vnc >/dev/null 2>&1; then
        warn "x11vnc not installed — VNC monitoring unavailable"
        return 0
    fi
    if pgrep -f "x11vnc.*$DISPLAY" >/dev/null 2>&1; then
        log "x11vnc already running on port $VNC_PORT"
        return 0
    fi
    if ! xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
        warn "No X display for x11vnc — skipping"
        return 0
    fi
    log "Starting x11vnc on port $VNC_PORT..."
    x11vnc -display "$DISPLAY" -forever -nopw -rfbport "$VNC_PORT" -bg \
        -o "$DATA_DIR/x11vnc.log" 2>&1
    sleep 2
    if grep -q "Listening for VNC" "$DATA_DIR/x11vnc.log" 2>/dev/null; then
        log "x11vnc listening on port $VNC_PORT"
    else
        warn "x11vnc may not be listening — check $DATA_DIR/x11vnc.log"
    fi
}

# ─── Browser (persistent — never killed) ────────────────────────────────────

ensure_browser() {
    local url="${1:-}"

    local existing_pid
    existing_pid=$(pgrep -f "$BROWSER.*$DISPLAY" 2>/dev/null | head -1 || true)

    if [ -n "$existing_pid" ] && [ "$existing_pid" != "0" ]; then
        log "Browser already running (PID: $existing_pid)"
        if [ -n "$url" ]; then
            log "Navigating to: $url"
            local win
            win=$(DISPLAY="$DISPLAY" xdotool search --name ".+" 2>/dev/null | head -1 || true)
            if [ -n "$win" ]; then
                DISPLAY="$DISPLAY" xdotool windowactivate "$win" 2>/dev/null || true
                sleep 0.5
                DISPLAY="$DISPLAY" xdotool key "ctrl+l" 2>/dev/null || true
                sleep 0.3
                DISPLAY="$DISPLAY" xdotool type --delay 10 "$url" 2>/dev/null || true
                sleep 0.3
                DISPLAY="$DISPLAY" xdotool key Return 2>/dev/null || true
            fi
        fi
        return 0
    fi

    if ! command -v "$BROWSER" >/dev/null 2>&1; then
        for alt in surf qutebrowser links2 chromium-browser chromium firefox; do
            if command -v "$alt" >/dev/null 2>&1; then
                BROWSER="$alt"
                log "Using browser: $BROWSER"
                break
            fi
        done
    fi

    if ! command -v "$BROWSER" >/dev/null 2>&1; then
        warn "No browser found — install surf, qutebrowser, links2, or firefox"
        return 0
    fi

    if [ -z "$url" ]; then
        url="https://www.google.com"
    fi

    log "Starting $BROWSER with homepage: $url"

    case "$BROWSER" in
        surf)            DISPLAY="$DISPLAY" LIBGL_ALWAYS_SOFTWARE=1 "$BROWSER" "$url" &>"$DATA_DIR/browser.log" & ;;
        qutebrowser)     DISPLAY="$DISPLAY" "$BROWSER" "$url" &>"$DATA_DIR/browser.log" & ;;
        links2)          DISPLAY="$DISPLAY" "$BROWSER" -g "$url" &>"$DATA_DIR/browser.log" & ;;
        firefox)         DISPLAY="$DISPLAY" "$BROWSER" --new-instance "$url" &>"$DATA_DIR/browser.log" & ;;
        chromium-browser|chromium) DISPLAY="$DISPLAY" "$BROWSER" --no-sandbox "$url" &>"$DATA_DIR/browser.log" & ;;
        *)               DISPLAY="$DISPLAY" "$BROWSER" "$url" &>"$DATA_DIR/browser.log" & ;;
    esac

    local pid=$!
    log "Browser started PID: $pid"

    for i in $(seq 1 15); do
        local win
        win=$(DISPLAY="$DISPLAY" xdotool search --name ".+" 2>/dev/null | head -1 || true)
        if [ -n "$win" ] && [ "$win" != "0" ]; then
            DISPLAY="$DISPLAY" xdotool windowsize "$win" 1280 720 2>/dev/null || true
            DISPLAY="$DISPLAY" xdotool windowmove "$win" 0 0 2>/dev/null || true
            DISPLAY="$DISPLAY" xdotool windowactivate "$win" 2>/dev/null || true
            log "Browser window detected: $win"
            return 0
        fi
        sleep 1
    done
    warn "Browser started but window not detected yet"
}

# ─── Status helpers ─────────────────────────────────────────────────────────

log()  { printf "\033[;32m[start]\033[0m %s\n" "$*"; }
warn() { printf "\033[;33m[start]\033[0m %s\n" "$*"; }

# ─── Main ───────────────────────────────────────────────────────────────────

echo ""
echo "  ╔══════════════════════════════════════════════════╗"
echo "  ║   Desktop Environment                            ║"
echo "  ╚══════════════════════════════════════════════════╝"
echo ""

log "Config: $DEFAULT_CONFIG"
log "Runtime: $RUNTIME_ENV / Distro: $DISTRO_ENV"

ensure_xserver
ensure_wm
ensure_vnc
ensure_browser "$@"

# Start watchdog (health monitoring)
bash "$REPO_DIR/setup/watchdog.sh" start 2>/dev/null || true

# Load proxy config if exists
if [ -f "$DATA_DIR/proxy.env" ]; then
    log "Loading proxy configuration..."
    source "$DATA_DIR/proxy.env"
fi

# Background network check (non-blocking)
(bash "$REPO_DIR/scripts/network.sh" check 2>&1 | tail -3 >> "$LOG_FILE") &
disown

session_save

echo ""
echo "  Runtime:     $RUNTIME_ENV"
echo "  Distro:      $DISTRO_ENV"
echo "  DISPLAY:     ${DISPLAY}"
echo "  VNC:         localhost:${VNC_PORT}"
echo "  Browser:     ${BROWSER} (persistent)"
echo "  Watchdog:    $(bash "$REPO_DIR/setup/watchdog.sh" status 2>/dev/null | head -1)"
echo "  Config:      $DEFAULT_CONFIG"
echo "  Log:         $LOG_FILE"
if [ -f "$DATA_DIR/proxy.env" ]; then
    echo "  Proxy:       CONFIGURED"
else
    echo "  Proxy:       NONE"
fi
echo ""
echo "  Commands:"
echo "    bash $REPO_DIR/scripts/browser.sh open <url>"
echo "    bash $REPO_DIR/scripts/click.sh --text <hint>"
echo "    bash $REPO_DIR/scripts/screenshot.sh --analyze"
echo "    bash $REPO_DIR/scripts/wait.sh stable"
echo "    bash $REPO_DIR/scripts/ocr.py --capture"
echo "    bash $REPO_DIR/scripts/clipboard.sh copy <text>"
echo "    bash $REPO_DIR/scripts/record.sh start"
echo "    bash $REPO_DIR/scripts/status.sh"
echo "══════════════════════════════════════════════════════"
echo ""
