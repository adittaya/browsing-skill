#!/usr/bin/env bash
# Linux Desktop: Status — check which backends are available
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$SCRIPT_DIR/lib/linux_desktop.py" status
