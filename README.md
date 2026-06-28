# Browser Automation Skill

Enterprise-grade browser automation for AI agents. Starts a full graphical browser
environment (Xvfb + VNC + fluxbox) that any AI can control with simple bash commands
and pixel-based screen analysis.

## 🚀 Quick Start

```bash
git clone https://github.com/adittaya/browsing-skill.git
cd browsing-skill
bash setup/install.sh    # Install dependencies (one-time)
bash setup/start.sh      # Start browser environment
bash scripts/status.sh   # Verify everything is running
```

## 🎯 What It Does

| Capability | How |
|---|---|
| **Start a browser** | Xvfb virtual framebuffer + fluxbox + x11vnc + surf/qutebrowser |
| **See the screen** | Screenshot analysis detects modals, buttons, links, layout |
| **Click elements** | By coordinates or by finding buttons automatically |
| **Scroll pages** | Step scroll, page scroll, jump to top/bottom |
| **Type text** | Type into focused input fields, press keyboard keys |
| **Handle modal popups** | Detect and dismiss overlay modals automatically |
| **VNC monitoring** | Watch everything in real-time via any VNC client |
| **Structured output** | All analysis returns JSON for programmatic use |

## 🖥️ Architecture

```
┌──────────────────────────────────────────────┐
│  AI Agent                                     │
│  (reads this prompt, issues commands)         │
├──────────────────────────────────────────────┤
│  bash scripts/click.sh, scroll.sh, type.sh    │
│  python3 lib/screen_analyzer.py               │
│  python3 lib/element_locator.py               │
├──────────────────────────────────────────────┤
│  xdotool → X11 → Xvfb (display :99)          │
│  fluxbox (window manager)                     │
│  surf/qutebrowser (WebKit browser)            │
│  x11vnc (port 5900 - watch in real-time)      │
└──────────────────────────────────────────────┘
```

## 📋 Requirements

- **OS**: Linux (Ubuntu/Debian, Fedora, Arch tested)
- **Packages**: Xvfb, x11vnc, fluxbox, xdotool, wmctrl, Python 3, Pillow
- **Browser**: surf (default), qutebrowser, or links2
- **Architecture**: x86_64 or arm64/aarch64

## 🧠 How Screen Analysis Works

The skill uses **color-based pixel analysis** (no OCR needed) to detect:

| Element | Color Signature | Example |
|---|---|---|
| **Button** | R>200, G=80-200, B<140 | "Continue", "Submit" buttons |
| **Modal** | R=80-130, G<80, B>120 | Purple gradient overlay popups |
| **Link** | R<80, G=80-180, B>120 | Blue hyperlinks |
| **Footer** | R<30, G<30, B<30 | Dark navigation bar |

This approach works on any website without needing DOM access or OCR.

## 📖 Full Command Reference

### Environment

| Command | Purpose |
|---|---|
| `bash setup/start.sh [url]` | Start Xvfb + fluxbox + x11vnc + browser |
| `bash setup/stop.sh` | Stop everything |
| `bash scripts/status.sh` | Check environment status |

### Navigation

| Command | Purpose |
|---|---|
| `bash scripts/browser.sh open <url>` | Open URL in browser |
| `bash scripts/browser.sh refresh` | Refresh page |
| `bash scripts/browser.sh back` | Go back |
| `bash scripts/browser.sh forward` | Go forward |

### Interaction

| Command | Purpose |
|---|---|
| `bash scripts/click.sh <x> <y>` | Click at coordinates |
| `bash scripts/click.sh --text <hint>` | Find button by hint and click |
| `bash scripts/click.sh --element modal` | Dismiss modal overlay |
| `bash scripts/scroll.sh down/up <n>` | Scroll N steps |
| `bash scripts/scroll.sh bottom` | Jump to bottom |
| `bash scripts/type.sh "text"` | Type text |
| `bash scripts/type.sh --key Return` | Press a key |

### Analysis

| Command | Purpose |
|---|---|
| `bash scripts/screenshot.sh` | Take screenshot |
| `bash scripts/screenshot.sh /tmp/s.png --analyze` | Screenshot + analyze text |
| `python3 lib/screen_analyzer.py --capture` | Full screen analysis |
| `python3 lib/screen_analyzer.py --capture --json` | Analysis as JSON |
| `python3 lib/element_locator.py --find continue` | Find element and click |

## 🤖 Agent Integration

Give your AI agent the prompt in **[AGENTS.md](AGENTS.md)** to enable full
browser automation capability. The agent will:

1. Start the browser environment
2. Navigate to any URL
3. Analyze screenshots to understand the page
4. Click buttons, fill forms, scroll pages
5. Handle modals and popups automatically
6. Report results back to you

## 🔧 Configuration

Set these environment variables:

```bash
export DISPLAY=:99           # X display (default: :99)
export VNC_PORT=5900         # VNC port (default: 5900)
export BROWSER=surf          # Browser: surf, qutebrowser, links2
export SCREEN_SIZE="1280x720x24"  # Screen resolution
```

## 🐳 Docker

```dockerfile
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y xvfb x11vnc fluxbox xdotool surf python3-pil
COPY browsing-skill /opt/browsing-skill
CMD ["bash", "/opt/browsing-skill/setup/start.sh"]
```

## 📁 Repository Structure

```
browsing-skill/
├── skill.jsonc              # opencode skill manifest
├── AGENTS.md                # AI agent prompt (copy-paste)
├── README.md                # This file
├── setup/
│   ├── install.sh           # One-time dependency installer
│   ├── start.sh             # Start environment
│   └── stop.sh              # Stop environment
├── scripts/
│   ├── browser.sh           # Browser navigation
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

## 📄 License

MIT
