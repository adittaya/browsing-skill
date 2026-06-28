#!/usr/bin/env bash
# Installer for desktop-environment skill
# One-liner: curl -fsSL https://raw.githubusercontent.com/adittaya/browsing-skill/master/setup/install.sh | bash
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/desktop-skill}"
REPO_URL="https://github.com/adittaya/browsing-skill.git"

log()  { printf "\033[;32m[install]\033[0m %s\n" "$*"; }
warn() { printf "\033[;33m[install]\033[0m %s\n" "$*"; }
err()  { printf "\033[;31m[install]\033[0m %s\n" "$*"; exit 1; }

# ─── Detect how we're being run ──────────────────────────────

SCRIPT_PATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P 2>/dev/null || true)"

# If install.sh is piped via stdin (curl | bash), SCRIPT_PATH will be empty or /
# In that case we need to clone the repo first.
PIPED=false
if [ -z "$SCRIPT_PATH" ] || [ "$SCRIPT_PATH" = "/" ] || [ "$SCRIPT_PATH" = "." ]; then
    PIPED=true
fi

# Also check if we're inside the repo already
IN_REPO=false
if [ -f "${SCRIPT_PATH}/../skill.jsonc" ] 2>/dev/null || \
   [ -f "${SCRIPT_PATH}/skill.jsonc" ] 2>/dev/null || \
   [ -f "./skill.jsonc" ] 2>/dev/null; then
    IN_REPO=true
    if [ -f "${SCRIPT_PATH}/../skill.jsonc" ]; then
        REPO_DIR="$(dirname "$SCRIPT_PATH")"
    elif [ -f "${SCRIPT_PATH}/skill.jsonc" ]; then
        REPO_DIR="$SCRIPT_PATH"
    else
        REPO_DIR="$PWD"
    fi
fi

# ─── Clone if needed ─────────────────────────────────────────

if [ "$IN_REPO" = false ]; then
    if [ "$PIPED" = true ]; then
        log "Running from pipe — cloning repository first..."
    else
        log "Repository not found — cloning..."
    fi

    if [ -d "$INSTALL_DIR" ]; then
        warn "Target directory $INSTALL_DIR already exists"
        warn "Run: cd $INSTALL_DIR && git pull"
        warn "Or:  rm -rf $INSTALL_DIR && curl -fsSL https://raw.githubusercontent.com/adittaya/browsing-skill/master/setup/install.sh | bash"
        exit 1
    fi

    mkdir -p "$(dirname "$INSTALL_DIR")"
    git clone --depth 1 "$REPO_URL" "$INSTALL_DIR"
    REPO_DIR="$INSTALL_DIR"
    log "Cloned to $INSTALL_DIR"
else
    log "Running from repository at $REPO_DIR"
fi

cd "$REPO_DIR"

# ─── Detect OS ───────────────────────────────────────────────

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS="$ID"
    VERSION="$VERSION_ID"
else
    OS="unknown"
fi

log "Detected OS: $OS $VERSION"

# ─── Install dependencies ────────────────────────────────────

install_apt() {
    log "Installing packages via apt..."
    apt-get update -qq
    apt-get install -y -qq \
        xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python3 python3-pip python3-pil \
        imagemagick x11-utils \
        curl wget git 2>&1 | tail -3

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
    pip3 install --quiet --break-system-packages Pillow 2>&1 | tail -1 || \
    pip3 install --quiet Pillow 2>&1 | tail -1 || true
}

install_dnf() {
    log "Installing packages via dnf..."
    dnf install -y \
        xorg-x11-server-Xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python3 python3-pillow \
        ImageMagick xwd git 2>&1 | tail -3
    dnf install -y surf 2>/dev/null || \
    dnf install -y qutebrowser 2>/dev/null || \
    dnf install -y links2 2>/dev/null || true
}

install_pacman() {
    log "Installing packages via pacman..."
    pacman -Sy --noconfirm \
        xorg-server-xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python python-pillow \
        imagemagick xorg-xwd git 2>&1 | tail -3
    pacman -S --noconfirm surf 2>/dev/null || \
    pacman -S --noconfirm qutebrowser 2>/dev/null || \
    pacman -S --noconfirm links 2>/dev/null || true
}

case "$OS" in
    ubuntu|debian|linuxmint|pop) install_apt ;;
    fedora|centos|rhel|rocky|almalinux) install_dnf ;;
    arch|manjaro|endeavouros) install_pacman ;;
    *)
        warn "Unsupported OS: $OS — attempting apt install"
        install_apt || true
        ;;
esac

# ─── Verify ──────────────────────────────────────────────────

MISSING=0
for cmd in Xvfb x11vnc fluxbox xdotool python3; do
    if ! command -v "$cmd" &>/dev/null; then
        err "Missing dependency: $cmd (install manually)"
    fi
done

python3 -c "from PIL import Image; print('PIL OK')" 2>/dev/null || \
    err "Python Pillow not installed (pip3 install Pillow)"

log "All dependencies satisfied"

# ─── Make scripts executable ─────────────────────────────────

chmod +x setup/*.sh scripts/*.sh test/*.sh 2>/dev/null || true

# ─── Done ────────────────────────────────────────────────────

echo ""
echo "  Desktop Environment Skill installed!"
echo ""
echo "  Directory: $REPO_DIR"
echo ""
echo "  Quick start:"
echo "    bash $REPO_DIR/setup/start.sh"
echo "    bash $REPO_DIR/scripts/status.sh"
echo ""
echo "  Or give an AI agent the prompt in AGENTS.md"
echo ""

if [ "$PIPED" = true ]; then
    echo "  To easily run later, add to your shell config:"
    echo "    export DESKTOP_SKILL=\"$REPO_DIR\""
    echo "    alias desktop-start='bash \"\$DESKTOP_SKILL/setup/start.sh\"'"
    echo "    alias desktop-stop='bash \"\$DESKTOP_SKILL/setup/stop.sh\"'"
    echo ""
fi
