#!/usr/bin/env bash
# ============================================================================
# Health Watchdog — monitors Xvfb, x11vnc, fluxbox, and browser.
# Auto-recovers crashed services. Runs as a background daemon.
# ============================================================================
set -euo pipefail

source "$(cd "$(dirname "$0")" && pwd)/../lib/config.sh"

PID_FILE="$DATA_DIR/watchdog.pid"
LOG_FILE="$DATA_DIR/watchdog.log"
INTERVAL="${WATCHDOG_INTERVAL:-10}"

log() {
    echo "[$(date '+%H:%M:%S')] $*" >> "$LOG_FILE"
    printf "\033[;32m[watchdog]\033[0m %s\n" "$*"
}

warn() {
    echo "[$(date '+%H:%M:%S')] WARN: $*" >> "$LOG_FILE"
    printf "\033[;33m[watchdog]\033[0m %s\n" "$*"
}

start_daemon() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        log "Watchdog already running (PID: $(cat "$PID_FILE"))"
        return
    fi

    log "Starting watchdog (interval: ${INTERVAL}s)..."
    nohup bash "$0" _daemon &>/dev/null &
    echo "$!" > "$PID_FILE"
    log "Watchdog started (PID: $!)"
}

stop_daemon() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID" 2>/dev/null || true
            log "Watchdog stopped (PID: $PID)"
        fi
        rm -f "$PID_FILE"
    else
        # Find any running watchdog
        P=$(pgrep -f "watchdog.sh _daemon" 2>/dev/null | head -1 || true)
        if [ -n "$P" ]; then
            kill "$P" 2>/dev/null || true
            log "Watchdog stopped (orphaned PID: $P)"
        fi
    fi
}

status() {
    if [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Watchdog: RUNNING (PID: $(cat "$PID_FILE"), interval: ${INTERVAL}s)"
        echo "Log:      $LOG_FILE"
        tail -5 "$LOG_FILE" 2>/dev/null | sed 's/^/  /' || true
    else
        echo "Watchdog: STOPPED"
    fi
}

# ─── Daemon Loop ─────────────────────────────────────────────

_daemon_loop() {
    log "Watchdog daemon started (PID: $$)"

    RECOVERY_COUNT=0
    # Load session if available
    SESSION_FILE="${DATA_DIR}/session"

    while true; do
        # Source config in case it changed
        [ -f "$SESSION_FILE" ] && source "$SESSION_FILE" 2>/dev/null || true

        # ── Check Xvfb ──
        if command -v Xvfb >/dev/null 2>&1; then
            if ! pgrep -f "Xvfb $DISPLAY" >/dev/null 2>&1; then
                warn "Xvfb not running — restarting..."
                Xvfb "$DISPLAY" -screen 0 "${SCREEN_SIZE:-1280x720x24}" &>/tmp/xvfb_watchdog.log &
                sleep 2
                RECOVERY_COUNT=$((RECOVERY_COUNT + 1))
            fi
        fi

        # ── Check fluxbox ──
        if command -v fluxbox >/dev/null 2>&1; then
            if ! pgrep -f "fluxbox.*$DISPLAY" >/dev/null 2>&1; then
                warn "Fluxbox not running — restarting..."
                DISPLAY="$DISPLAY" fluxbox &>/tmp/fluxbox_watchdog.log &
                sleep 1
                RECOVERY_COUNT=$((RECOVERY_COUNT + 1))
            fi
        fi

        # ── Check x11vnc ──
        if command -v x11vnc >/dev/null 2>&1 && xdpyinfo -display "$DISPLAY" >/dev/null 2>&1; then
            if ! pgrep -f "x11vnc.*$DISPLAY" >/dev/null 2>&1; then
                warn "x11vnc not running — restarting..."
                x11vnc -display "$DISPLAY" -forever -nopw -rfbport "${VNC_PORT:-5900}" -bg \
                    -o /tmp/x11vnc_watchdog.log 2>&1
                sleep 1
                RECOVERY_COUNT=$((RECOVERY_COUNT + 1))
            fi
        fi

        # ── Check browser ──
        BROWSER_BIN="${BROWSER:-surf}"
        if command -v "$BROWSER_BIN" >/dev/null 2>&1; then
            # Check if any window exists
            WIN=$(DISPLAY="$DISPLAY" xdotool search --name ".+" 2>/dev/null | head -1 || true)
            if [ -z "$WIN" ] || [ "$WIN" = "0" ]; then
                warn "Browser window missing — browser may have crashed"
                # Don't auto-restart browser (user navigates via Ctrl+L)
                # Just log it
                RECOVERY_COUNT=$((RECOVERY_COUNT + 1))
            fi
        fi

        sleep "$INTERVAL"
    done
}

# ─── Main ─────────────────────────────────────────────────────

case "${1:-}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon
        sleep 1
        start_daemon
        ;;
    status)
        status
        ;;
    _daemon)
        _daemon_loop
        ;;
    *)
        echo "Usage: watchdog.sh <start|stop|restart|status>"
        exit 1
        ;;
esac
