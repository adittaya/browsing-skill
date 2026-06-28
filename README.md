# Browser Automation Skill

Enterprise-grade browser automation for AI agents. Starts a full graphical browser
environment (Xvfb + VNC + fluxbox) that any AI can control with simple bash commands
and pixel-based screen analysis.

**Key principle: the browser starts once and stays open.** Like a real human, you
navigate by typing URLs (Ctrl+L), not by killing and reopening the browser.

## Quick Start

```bash
git clone https://github.com/adittaya/browsing-skill.git
cd browsing-skill
bash setup/install.sh    # Install dependencies (one-time)
bash setup/start.sh      # Start browser environment (opens Google)
bash scripts/status.sh   # Verify everything is running
```

## How It Works

```
┌──────────────────────────────────────────────┐
│  AI Agent                                     │
│  "open this URL, click Continue, scroll down" │
├──────────────────────────────────────────────┤
│  bash scripts/browser.sh open <url>           │
│  bash scripts/click.sh --text continue        │
│  bash scripts/scroll.sh down 5                │
│  python3 lib/screen_analyzer.py --capture     │
├──────────────────────────────────────────────┤
│  xdotool → X11 → Xvfb (display :99)          │
│  fluxbox (window manager)                     │
│  surf/qutebrowser (WebKit browser)            │
│  x11vnc (port 5900 - watch in real-time)      │
└──────────────────────────────────────────────┘
```

The browser opens once on Google homepage. To go to any URL:

```bash
bash scripts/browser.sh open "https://example.com"
```

This simulates Ctrl+L → type URL → Enter. The same browser window is reused
for the entire session — no killing, no restarting, just like a real person.

## What It Detects (Screen Analysis)

| Element | Color Signature | Example |
|---|---|---|
| **Button** | R>200, G=80-200, B<140 | "Continue", "Submit" buttons |
| **Modal** | R=80-130, G<80, B>120 | Purple gradient overlay popups |
| **Link** | R<80, G=80-180, B>120 | Blue hyperlinks |
| **Footer** | R<30, G<30, B<30 | Dark navigation bar |

No OCR or DOM access needed — works on any website by analyzing pixel colors.

## Command Reference

### Environment (one-time setup)

| Command | Purpose |
|---|---|
| `bash setup/start.sh [url]` | Start Xvfb + fluxbox + x11vnc + browser |
| `bash setup/stop.sh` | Destroy everything (rarely needed) |
| `bash scripts/status.sh` | Check environment status |

### Navigation (persistent browser, never kill/reopen)

| Command | Purpose |
|---|---|
| `bash scripts/browser.sh open <url>` | Navigate to URL (Ctrl+L → type → Enter) |
| `bash scripts/browser.sh new-tab <url>` | Open in new tab (Ctrl+T) |
| `bash scripts/browser.sh refresh` | Reload page (Ctrl+R) |
| `bash scripts/browser.sh back` | Go back (Alt+Left) |
| `bash scripts/browser.sh forward` | Go forward (Alt+Right) |
| `bash scripts/browser.sh close-tab` | Close current tab (Ctrl+W) |
| `bash scripts/browser.sh focus` | Bring window to front |

### Interaction

| Command | Purpose |
|---|---|
| `bash scripts/click.sh <x> <y>` | Click at coordinates |
| `bash scripts/click.sh --text <hint>` | Find button by hint and click |
| `bash scripts/click.sh --element modal` | Dismiss modal overlay |
| `bash scripts/scroll.sh down/up <n>` | Scroll N steps |
| `bash scripts/scroll.sh page-down` | One page down |
| `bash scripts/scroll.sh bottom` | Jump to bottom |
| `bash scripts/type.sh "text"` | Type text |
| `bash scripts/type.sh --key Return` | Press a key |

### Analysis

| Command | Purpose |
|---|---|
| `bash scripts/screenshot.sh` | Take screenshot |
| `bash scripts/screenshot.sh --analyze` | Screenshot + analyze |
| `python3 lib/screen_analyzer.py --capture` | Full screen analysis |
| `python3 lib/screen_analyzer.py --capture --json` | Analysis as JSON |
| `python3 lib/element_locator.py --find continue` | Find element by hint |

## Typical AI Session

```bash
# Step 1: Start once
bash setup/start.sh

# Step 2: Navigate
bash scripts/browser.sh open "https://vplink.in/UbpV2D"
sleep 4

# Step 3: Analyze
python3 lib/screen_analyzer.py --capture

# Step 4: Click
bash scripts/click.sh --text continue
sleep 3

# Step 5: Verify
bash scripts/screenshot.sh --analyze

# Step 6: Next task (same browser, no restart)
bash scripts/browser.sh open "https://other-site.com"
```

## Agent Integration

Give your AI agent the prompt in **[AGENTS.md](AGENTS.md)** to enable full
browser automation capability.

## Configuration

```bash
export DISPLAY=:99           # X display (default: :99)
export VNC_PORT=5900         # VNC port (default: 5900)
export BROWSER=surf          # Browser: surf, qutebrowser, links2
export SCREEN_SIZE="1280x720x24"  # Screen resolution
```

## Requirements

- **OS**: Linux (Ubuntu/Debian, Fedora, Arch tested)
- **Packages**: Xvfb, x11vnc, fluxbox, xdotool, Python 3, Pillow
- **Browser**: surf (default), qutebrowser, or links2

## Repository Structure

```
browsing-skill/
├── skill.jsonc              # opencode skill manifest
├── AGENTS.md                # AI agent prompt (copy-paste)
├── README.md                # This file
├── setup/
│   ├── install.sh           # One-time dependency installer
│   ├── start.sh             # Start environment (persistent session)
│   └── stop.sh              # Destroy everything
├── scripts/
│   ├── browser.sh           # Browser navigation (never kill/reopen)
│   ├── click.sh             # Click elements
│   ├── scroll.sh            # Scroll pages
│   ├── type.sh              # Type text
│   ├── screenshot.sh        # Take screenshots
│   └── status.sh            # Environment status
├── lib/
│   ├── screen_analyzer.py   # Screen analysis engine
│   └── element_locator.py   # Element detection + clicking
└── test/
    ├── test_env.sh          # Environment tests
    └── test_browse.sh       # Browsing workflow tests
```

## License

MIT
