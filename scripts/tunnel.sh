#!/usr/bin/env bash
# Tunnel — expose VNC (port 5900) to the internet via bore.pub
# No account, no auth needed. Just a public URL.
# Usage: bash scripts/tunnel.sh start
#        bash scripts/tunnel.sh stop
#        bash scripts/tunnel.sh status
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BORE="${BORE:-$SCRIPT_DIR/bin/bore}"
BORE_LOG="${BORE_LOG:-/tmp/bore.log}"
BORE_PORT="${BORE_PORT:-5900}"
BORE_SERVER="${BORE_SERVER:-bore.pub}"
TUNNEL_URL=""

if [ ! -f "$BORE" ]; then
    mkdir -p "$(dirname "$BORE")"
    echo "[tunnel] Downloading bore client..."
    curl -sL "https://github.com/ekzhang/bore/releases/download/v0.5.2/bore-v0.5.2-x86_64-unknown-linux-musl.tar.gz" -o /tmp/bore.tar.gz
    tar xzf /tmp/bore.tar.gz -C "$(dirname "$BORE")"
    chmod +x "$BORE"
fi

case "${1:-}" in
    start)
        if pgrep -f "bore local $BORE_PORT" >/dev/null 2>&1; then
            echo "[tunnel] Already running"
            exit 0
        fi
        echo "[tunnel] Starting bore tunnel (VNC :$BORE_PORT -> $BORE_SERVER)..."
        nohup "$BORE" local "$BORE_PORT" --to "$BORE_SERVER" > "$BORE_LOG" 2>&1 &
        sleep 2
        _port=$(grep -o 'remote_port=[0-9]*' "$BORE_LOG" 2>/dev/null | cut -d= -f2 || echo "unknown")
        if [ "$_port" != "unknown" ]; then
            echo "[tunnel] VNC доступен по адресу: $BORE_SERVER:$_port"
            echo "[tunnel] Connect your VNC client to: $BORE_SERVER:$_port"
        else
            echo "[tunnel] Started, checking log:"
            cat "$BORE_LOG"
        fi
        ;;
    stop)
        echo "[tunnel] Stopping bore..."
        pkill -f "bore local $BORE_PORT" 2>/dev/null || true
        echo "[tunnel] Stopped"
        ;;
    status)
        if pgrep -f "bore local $BORE_PORT" >/dev/null 2>&1; then
            _port=$(grep -o 'remote_port=[0-9]*' "$BORE_LOG" 2>/dev/null | cut -d= -f2 || echo "unknown")
            echo "[tunnel] ACTIVE: $BORE_SERVER:$_port"
        else
            echo "[tunnel] INACTIVE"
        fi
        ;;
    url)
        _port=$(grep -o 'remote_port=[0-9]*' "$BORE_LOG" 2>/dev/null | cut -d= -f2 || echo "")
        if [ -n "$_port" ]; then
            echo "$BORE_SERVER:$_port"
        else
            echo "[tunnel] Not active"
            exit 1
        fi
        ;;
    *)
        echo "Usage: tunnel.sh start|stop|status|url"
        exit 1
        ;;
esac
