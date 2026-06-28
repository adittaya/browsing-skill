#!/usr/bin/env bash
# ============================================================================
# Desktop Environment Skill — Enterprise Installer
# Auto-detects: Termux, proot-distro, Debian/Ubuntu, Fedora/RHEL, Arch, Alpine,
#               openSUSE/SLES, macOS, and any Debian-derived environment.
#
# One-liner:  curl -fsSL https://raw.githubusercontent.com/adittaya/browsing-skill/master/setup/install.sh | bash
# ============================================================================
set -euo pipefail

INSTALL_DIR="${INSTALL_DIR:-}"
REPO_URL="https://github.com/adittaya/browsing-skill.git"

# ─── Utilities ──────────────────────────────────────────────────────────────

log()  { printf "\033[;32m✓\033[0m %s\n" "$*"; }
warn() { printf "\033[;33m!\033[0m %s\n" "$*"; }
err()  { printf "\033[;31m✗\033[0m %s\n" "$*"; }
die()  { err "$*"; exit 1; }

# ─── Environment Detection ──────────────────────────────────────────────────

detect_environment() {
    # Detect Termux (Android native)
    if [ -n "${TERMUX_VERSION:-}" ] || command -v termux-setup-storage >/dev/null 2>&1; then
        echo "termux"
        return
    fi

    # Detect proot-distro container
    if [ -f "/data/data/com.termux/files/usr/bin/proot-distro" ] || \
       [ -n "${PROOT_L2S_DIR:-}" ] || \
       grep -q "PROot-Distro" /proc/version 2>/dev/null; then
        echo "proot-distro"
        return
    fi

    # Detect macOS
    if [ "$(uname -s)" = "Darwin" ]; then
        echo "macos"
        return
    fi

    # Detect /etc/os-release
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "${ID:-}" in
            ubuntu|debian|linuxmint|pop|elementary|kali|parrot|deepin|uos)
                echo "debian" ; return ;;
            fedora)           echo "fedora" ; return ;;
            rhel|centos|rocky|almalinux|ol|nobara)
                echo "rhel" ; return ;;
            arch|manjaro|endeavouros|artix|garuda)
                echo "arch" ; return ;;
            alpine)           echo "alpine" ; return ;;
            suse|sles|opensuse*)
                echo "suse" ; return ;;
            *)
                # Check package manager as fallback
                if command -v apt >/dev/null 2>&1; then echo "debian"; return; fi
                if command -v dnf >/dev/null 2>&1; then echo "fedora"; return; fi
                if command -v pacman >/dev/null 2>&1; then echo "arch"; return; fi
                if command -v apk >/dev/null 2>&1; then echo "alpine"; return; fi
                if command -v zypper >/dev/null 2>&1; then echo "suse"; return; fi
                if command -v yum >/dev/null 2>&1; then echo "rhel"; return; fi
                echo "unknown"
                ;;
        esac
    fi

    # Fallback: check package managers
    if command -v apt >/dev/null 2>&1; then echo "debian"; return; fi
    if command -v dnf >/dev/null 2>&1; then echo "fedora"; return; fi
    if command -v pacman >/dev/null 2>&1; then echo "arch"; return; fi
    if command -v apk >/dev/null 2>&1; then echo "alpine"; return; fi
    if command -v zypper >/dev/null 2>&1; then echo "suse"; return; fi

    echo "unknown"
}

print_env_info() {
    echo "  Environment:  $(uname -s) $(uname -m)"
    echo "  Distro:       $( (cat /etc/os-release 2>/dev/null && echo "$PRETTY_NAME") || echo unknown)"
    echo "  Kernel:       $(uname -r)"
    echo "  User:         $(whoami) (UID:$EUID)"
    echo "  Termux:       $( [ -n "${TERMUX_VERSION:-}" ] && echo "v$TERMUX_VERSION" || echo no )"
    echo "  proot-distro: $( [ -f /data/data/com.termux/files/usr/bin/proot-distro ] && echo yes || echo no )"
}

# ─── Package Managers ───────────────────────────────────────────────────────

NEEDS_SUDO=true
if [ "$(id -u)" = "0" ]; then
    NEEDS_SUDO=false
fi

sudoer() {
    if [ "$NEEDS_SUDO" = true ]; then
        sudo "$@"
    else
        "$@"
    fi
}

install_pkg_debian() {
    log "Installing packages (apt)..."
    sudoer apt-get update -qq
    sudoer apt-get install -y -qq \
        xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python3 python3-pip python3-pil \
        imagemagick x11-utils x11-xserver-utils \
        curl wget git ca-certificates 2>&1 | tail -3

    for pkg in surf qutebrowser links2 chromium-browser firefox; do
        if command -v "$pkg" >/dev/null 2>&1; then
            log "$pkg already installed"; break
        fi
        sudoer apt-get install -y -qq "$pkg" 2>/dev/null && log "installed $pkg" && break || true
    done

    pip3 install --quiet --break-system-packages Pillow 2>/dev/null || \
    pip3 install --quiet Pillow 2>/dev/null || true
}

install_pkg_fedora() {
    log "Installing packages (dnf)..."
    sudoer dnf install -y \
        xorg-x11-server-Xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python3 python3-pillow python3-pip \
        ImageMagick xwd git curl wget 2>&1 | tail -3

    for pkg in surf qutebrowser links2 chromium firefox; do
        if command -v "$pkg" >/dev/null 2>&1; then log "$pkg already installed"; break; fi
        sudoer dnf install -y "$pkg" 2>/dev/null && log "installed $pkg" && break || true
    done

    pip3 install --quiet Pillow 2>/dev/null || true
}

install_pkg_rhel() {
    log "Installing packages (yum)..."
    sudoer yum install -y epel-release 2>/dev/null || true
    sudoer yum install -y \
        xorg-x11-server-Xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python3 python3-pillow python3-pip \
        ImageMagick git curl wget 2>&1 | tail -3

    pip3 install --quiet Pillow 2>/dev/null || true
}

install_pkg_arch() {
    log "Installing packages (pacman)..."
    sudoer pacman -Sy --noconfirm \
        xorg-server-xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python python-pillow python-pip \
        imagemagick xorg-xwd xorg-xrandr \
        git curl wget 2>&1 | tail -3

    for pkg in surf qutebrowser links2 chromium firefox; do
        if command -v "$pkg" >/dev/null 2>&1; then log "$pkg already installed"; break; fi
        sudoer pacman -S --noconfirm "$pkg" 2>/dev/null && log "installed $pkg" && break || true
    done

    pip3 install --quiet Pillow 2>/dev/null || true
}

install_pkg_alpine() {
    log "Installing packages (apk)..."
    sudoer apk add --no-cache \
        xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python3 py3-pillow py3-pip \
        imagemagick xrandr \
        git curl wget 2>&1 | tail -3
    
    for pkg in surf qutebrowser links2 chromium firefox; do
        if command -v "$pkg" >/dev/null 2>&1; then log "$pkg already installed"; break; fi
        sudoer apk add --no-cache "$pkg" 2>/dev/null && log "installed $pkg" && break || true
    done

    pip3 install --quiet Pillow 2>/dev/null || true
}

install_pkg_suse() {
    log "Installing packages (zypper)..."
    sudoer zypper install -y \
        xvfb x11vnc fluxbox xdotool wmctrl xterm \
        python3 python3-pillow python3-pip \
        ImageMagick git curl wget 2>&1 | tail -3

    for pkg in surf qutebrowser links2 chromium firefox; do
        if command -v "$pkg" >/dev/null 2>&1; then log "$pkg already installed"; break; fi
        sudoer zypper install -y "$pkg" 2>/dev/null && log "installed $pkg" && break || true
    done

    pip3 install --quiet Pillow 2>/dev/null || true
}

install_pkg_termux() {
    log "Installing packages (termux)..."

    # Termux:X11 for display
    pkg update -y
    pkg install -y \
        x11-repo tur-repo \
        xvfb x11vnc fluxbox xdotool \
        python python-pillow \
        imagemagick \
        git curl wget termux-x11-nightly 2>&1 | tail -5

    # Browsers in Termux
    for pkg in surf qutebrowser links2 firefox chromium; do
        if command -v "$pkg" >/dev/null 2>&1; then log "$pkg already installed"; break; fi
        pkg install -y "$pkg" 2>/dev/null && log "installed $pkg" && break || true
    done

    pip install --quiet Pillow 2>/dev/null || true
}

install_pkg_proot_distro() {
    log "Installing packages for proot-distro container..."
    # Inside proot-distro, we're usually root in a standard distro
    # Use apt if available (most proot-distro containers are Ubuntu/Debian)
    if command -v apt >/dev/null 2>&1; then
        install_pkg_debian
    elif command -v dnf >/dev/null 2>&1; then
        install_pkg_fedora
    elif command -v pacman >/dev/null 2>&1; then
        install_pkg_arch
    else
        warn "proot-distro: unknown package manager, trying apt..."
        install_pkg_debian 2>/dev/null || true
    fi

    # proot-distro may not support Xvfb (depends on seccomp)
    # Check and warn
    if ! command -v Xvfb >/dev/null 2>&1; then
        warn "Xvfb may not work in proot containers (seccomp restrictions)"
        warn "The skill will fall back to headless screenshot mode"
    fi
}

# ─── Repository Setup ───────────────────────────────────────────────────────

setup_repo() {
    local target="$1"

    if [ -d "$target" ]; then
        log "Repository already exists at $target"
        if git -C "$target" remote -v 2>/dev/null | grep -q "$REPO_URL"; then
            log "Updating..."
            git -C "$target" pull --ff-only 2>/dev/null || warn "Could not update, continuing"
        fi
        echo "$target"
        return
    fi

    mkdir -p "$(dirname "$target")"
    log "Cloning repository..."
    git clone --depth 1 "$REPO_URL" "$target" || die "Failed to clone repository"
    log "Cloned to $target"
    echo "$target"
}

# ─── Main ───────────────────────────────────────────────────────────────────

main() {
    echo ""
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║   Desktop Environment Skill — Installer          ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo ""

    # Detect environment
    ENV_TYPE=$(detect_environment)
    print_env_info
    echo ""
    log "Detected environment: $ENV_TYPE"
    echo ""

    # Determine REPO_DIR
    # Check if we're inside the repo already
    SCRIPT_PATH="$(cd "$(dirname "$0")" 2>/dev/null && pwd -P 2>/dev/null || true)"
    REPO_DIR=""

    if [ -n "$SCRIPT_PATH" ] && [ -f "${SCRIPT_PATH}/../skill.jsonc" ] 2>/dev/null; then
        REPO_DIR="$(dirname "$SCRIPT_PATH")"
    elif [ -n "$SCRIPT_PATH" ] && [ -f "${SCRIPT_PATH}/skill.jsonc" ] 2>/dev/null; then
        REPO_DIR="$SCRIPT_PATH"
    elif [ -f "./skill.jsonc" ] 2>/dev/null; then
        REPO_DIR="$PWD"
    fi

    # If not in repo, determine install target
    if [ -z "$REPO_DIR" ]; then
        if [ -n "$INSTALL_DIR" ]; then
            TARGET="$INSTALL_DIR"
        elif [ "$ENV_TYPE" = "termux" ]; then
            TARGET="$HOME/.local/share/desktop-skill"
        else
            TARGET="${XDG_DATA_HOME:-$HOME/.local/share}/desktop-skill"
        fi
        REPO_DIR=$(setup_repo "$TARGET")
    else
        log "Running from repository at $REPO_DIR"
    fi

    cd "$REPO_DIR"

    # ── Install packages ──
    case "$ENV_TYPE" in
        termux)       install_pkg_termux ;;
        proot-distro) install_pkg_proot_distro ;;
        debian)       install_pkg_debian ;;
        fedora)       install_pkg_fedora ;;
        rhel)         install_pkg_rhel ;;
        arch)         install_pkg_arch ;;
        alpine)       install_pkg_alpine ;;
        suse)         install_pkg_suse ;;
        macos)
            warn "macOS detected — installing Python deps only"
            pip3 install --quiet Pillow 2>/dev/null || true
            warn "macOS requires XQuartz for X11. Install manually: https://www.xquartz.org/"
            ;;
        *)
            warn "Unknown environment — attempting apt install"
            install_pkg_debian 2>/dev/null || true
            ;;
    esac

    # ── Verify core dependencies ──
    echo ""
    log "Verifying dependencies..."

    CRITICAL=(python3)
    OPTIONAL=(Xvfb x11vnc fluxbox xdotool)

    ALL_OK=true
    for cmd in "${CRITICAL[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log "$cmd: $(command -v "$cmd")"
        else
            err "$cmd: NOT FOUND (this is required)"
            ALL_OK=false
        fi
    done

    for cmd in "${OPTIONAL[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log "$cmd: $(command -v "$cmd")"
        else
            warn "$cmd: not found (optional — will use fallback)"
        fi
    done

    if python3 -c "from PIL import Image; print('PIL OK')" 2>/dev/null; then
        log "Python Pillow: OK"
    else
        err "Python Pillow: NOT FOUND (pip3 install Pillow)"
        ALL_OK=false
    fi

    if ! command -v surf >/dev/null 2>&1 && ! command -v qutebrowser >/dev/null 2>&1; then
        warn "No WebKit browser found (surf/qutebrowser) — will use links2 or fallback"
    fi

    # ── Make scripts executable ──
    chmod +x setup/*.sh scripts/*.sh test/*.sh 2>/dev/null || true

    # ── Done ──
    if [ "$ALL_OK" = false ]; then
        echo ""
        die "Some critical dependencies missing. See messages above."
    fi

    echo ""
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║   Installation complete                          ║"
    echo "  ╠══════════════════════════════════════════════════╣"
    echo "  ║  Environment: $ENV_TYPE"
    echo "  ║  Location:    $REPO_DIR"
    echo "  ╠══════════════════════════════════════════════════╣"
    echo "  ║  Start:  bash $REPO_DIR/setup/start.sh           ║"
    echo "  ║  Status: bash $REPO_DIR/scripts/status.sh        ║"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo ""
    echo "  Give an AI agent the prompt in: AGENTS.md"
    echo ""
}

main "$@"
