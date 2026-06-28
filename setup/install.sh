#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

log() { echo "[install] $*"; }

# Detect OS
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS="$ID"
    VERSION="$VERSION_ID"
else
    OS="unknown"
fi

log "Detected OS: $OS $VERSION"

install_apt() {
    log "Installing packages via apt..."
    apt-get update -qq
    apt-get install -y -qq \
        xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python3 python3-pip python3-pil \
        imagemagick x11-utils \
        curl wget 2>&1 | tail -3

    # Try to install a browser
    if command -v surf &>/dev/null; then
        log "surf already installed"
    else
        apt-get install -y -qq surf 2>/dev/null && log "installed surf" || true
    fi

    if ! command -v surf &>/dev/null; then
        apt-get install -y -qq qutebrowser 2>/dev/null && log "installed qutebrowser" || true
    fi

    if ! command -v surf &>/dev/null && ! command -v qutebrowser &>/dev/null; then
        apt-get install -y -qq links2 2>/dev/null && log "installed links2" || true
    fi

    log "Installing Python packages..."
    pip3 install --quiet --break-system-packages Pillow numpy 2>&1 | tail -1 || \
    pip3 install --quiet Pillow numpy 2>&1 | tail -1 || true
}

install_dnf() {
    log "Installing packages via dnf..."
    dnf install -y \
        xorg-x11-server-Xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python3 python3-pillow python3-numpy \
        ImageMagick xwd 2>&1 | tail -3
    dnf install -y surf 2>/dev/null || \
    dnf install -y qutebrowser 2>/dev/null || \
    dnf install -y links2 2>/dev/null || true
}

install_pacman() {
    log "Installing packages via pacman..."
    pacman -Sy --noconfirm \
        xorg-server-xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python python-pillow python-numpy \
        imagemagick xorg-xwd 2>&1 | tail -3
    pacman -S --noconfirm surf 2>/dev/null || \
    pacman -S --noconfirm qutebrowser 2>/dev/null || \
    pacman -S --noconfirm links 2>/dev/null || true
}

case "$OS" in
    ubuntu|debian) install_apt ;;
    fedora|centos|rhel) install_dnf ;;
    arch|manjaro) install_pacman ;;
    *)
        log "Unsupported OS: $OS. Attempting apt install..."
        install_apt || true
        ;;
esac

# Verify critical tools
MISSING=0
for cmd in Xvfb x11vnc fluxbox xdotool python3; do
    if ! command -v "$cmd" &>/dev/null; then
        log "MISSING: $cmd"
        MISSING=1
    fi
done

# Verify Python libraries
python3 -c "from PIL import Image; print('PIL OK')" 2>/dev/null || { log "Pillow missing"; MISSING=1; }

if [ "$MISSING" -eq 1 ]; then
    log "Some dependencies missing. Attempt manual install."
    exit 1
fi

log "All dependencies satisfied"
