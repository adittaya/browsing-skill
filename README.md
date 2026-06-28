# Desktop Environment Skill

A full graphical Linux desktop for AI agents. Xvfb + fluxbox + VNC + browser
— see the screen, click, type, scroll, navigate the web. Do anything a human
can do on a computer.

**Primary focus is web browsing, but you can handle any desktop task.**
Every action is variable and human-like — not rigid scripts.

## Quick Start

```bash
git clone https://github.com/adittaya/browsing-skill.git
cd browsing-skill
bash setup/install.sh    # Install dependencies (one-time)
bash setup/start.sh      # Start desktop (opens Google)
bash scripts/status.sh   # Verify everything is running
```

## What It Is

```
┌──────────────────────────────────────────────┐
│  AI Agent                                     │
│  looks at screen → decides → acts → repeats   │
├──────────────────────────────────────────────┤
│  bash scripts/click.sh  / scroll.sh / type.sh │
│  python3 lib/screen_analyzer.py               │
│  python3 lib/element_locator.py               │
├──────────────────────────────────────────────┤
│  xdotool → X11 → Xvfb (display :99)          │
│  fluxbox (window manager)                     │
│  surf/qutebrowser (WebKit browser)            │
│  x11vnc (port 5900 - watch live)             │
└──────────────────────────────────────────────┘
```

The desktop starts once and stays running. The browser opens on Google.
Navigate by Ctrl+L → type URL → Enter — like a real person.

**No killing, no restarting.** Just navigate to the next URL.

## What the Analyzer Detects

| Element | Color | What |
|---|---|---|
| **Button** | Warm orange/pink | "Continue", "Submit", "Next" |
| **Modal** | Purple gradient | Overlay popups, cookie banners |
| **Link** | Blue | Hyperlinks |
| **Text** | Dark | Body text, headings |
| **Footer** | Black | Navigation bars |

Works on any visual UI — no OCR, no DOM access.

## Commands

### Desktop
| Command | What |
|---|---|
| `bash setup/start.sh [url]` | Start desktop (default: Google) |
| `bash setup/stop.sh` | Full teardown (rare) |
| `bash scripts/status.sh` | Check running processes |

### Browse
| Command | What |
|---|---|
| `bash scripts/browser.sh open <url>` | Navigate (Ctrl+L → type → Enter) |
| `bash scripts/browser.sh new-tab <url>` | Open tab (Ctrl+T) |
| `bash scripts/browser.sh refresh` | Reload (Ctrl+R) |
| `bash scripts/browser.sh back` | Back (Alt+Left) |
| `bash scripts/browser.sh forward` | Forward (Alt+Right) |
| `bash scripts/browser.sh close-tab` | Close tab (Ctrl+W) |

### Click
| Command | What |
|---|---|
| `bash scripts/click.sh 640 480` | Click coordinates |
| `bash scripts/click.sh --text continue` | Find button by hint |
| `bash scripts/click.sh --element modal` | Dismiss popup |

### Scroll
| Command | What |
|---|---|
| `bash scripts/scroll.sh down 5` | Scroll down N steps |
| `bash scripts/scroll.sh up 3` | Scroll up N steps |
| `bash scripts/scroll.sh bottom` | Jump to bottom |
| `bash scripts/scroll.sh top` | Jump to top |
| `bash scripts/scroll.sh page-down` | One page down |

### Type
| Command | What |
|---|---|
| `bash scripts/type.sh "text"` | Type text |
| `bash scripts/type.sh --key Return` | Press key |
| `bash scripts/type.sh --key "ctrl+a"` | Key combo |

### Analyze
| Command | What |
|---|---|
| `bash scripts/screenshot.sh` | Take screenshot |
| `bash scripts/screenshot.sh --analyze` | Screenshot + analyze |
| `python3 lib/screen_analyzer.py --capture` | Full analysis |
| `python3 lib/screen_analyzer.py --capture --json` | JSON output |

## Human-Like Workflow

```
look at screen → think → click or type or scroll → wait → look again
```

Vary your actions naturally:
- Scroll different amounts each time (3, 7, page-down)
- Wait realistic times (2-5s after load, 1-3s after click)
- Mix click methods (coordinates, text hints)
- Handle modals as they appear
- Never kill the browser — just navigate

## Example

```bash
bash setup/start.sh
bash scripts/browser.sh open "https://vplink.in/UbpV2D"
sleep 4
python3 lib/screen_analyzer.py --capture
bash scripts/click.sh --text continue
sleep 2
bash scripts/screenshot.sh --analyze
bash scripts/scroll.sh down 5
bash scripts/browser.sh open "https://next-site.com"
```

## Agent Integration

Give your AI agent the prompt in **[AGENTS.md](AGENTS.md)** to enable full
desktop control. It will see the screen, decide what to do, and act like
a human at a computer.

## Configuration

```bash
export DISPLAY=:99           # X display
export VNC_PORT=5900         # VNC port
export BROWSER=surf          # surf, qutebrowser, or links2
export SCREEN_SIZE="1280x720x24"
```

## Requirements

Linux (Ubuntu/Debian, Fedora, Arch) — Xvfb, x11vnc, fluxbox, xdotool, Python3, Pillow.

## Structure

```
desktop-skill/
├── skill.jsonc           # Skill manifest
├── AGENTS.md             # Agent prompt (copy-paste)
├── README.md             # This file
├── setup/
│   ├── install.sh        # One-time dependency install
│   ├── start.sh          # Start desktop (persistent)
│   └── stop.sh           # Destroy environment
├── scripts/
│   ├── browser.sh        # Web navigation
│   ├── click.sh          # Mouse clicks
│   ├── scroll.sh         # Scrolling
│   ├── type.sh           # Keyboard typing
│   ├── screenshot.sh     # Screenshots
│   └── status.sh         # Environment status
├── lib/
│   ├── screen_analyzer.py  # Visual analysis engine
│   └── element_locator.py  # Element detection
└── test/
    ├── test_env.sh
    └── test_browse.sh
```

## License

MIT
