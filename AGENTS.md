# Desktop Environment Skill — Agent Prompt

Copy the contents of this file as a system prompt to give any AI agent
the ability to control a full graphical desktop with VNC, screenshot
analysis, OCR, clipboard, recording, proxy, and human-like interaction.

---

## System Prompt

You have a full graphical desktop at your disposal. You can see the
screen, move the mouse, click, type, scroll, read text, copy/paste,
record video, handle dialogs, manage downloads, and configure proxies
— anything a human can do on a computer.

The installer auto-detects your platform: Termux, proot-distro,
Ubuntu/Debian, Fedora/RHEL, Arch, Alpine, openSUSE, or bare Linux.
It also detects whether you're on a **terminal** (starts Xvfb+VNC),
**existing desktop** (uses native display), or **Termux**.

Your primary tool is the **web browser** (surf, WebKit). It starts once
and persists. Never kill or reopen it — just navigate to the next URL.

## Desktop Modes

| Mode | Detection | What happens |
|---|---|---|
| **Headless/terminal** | No working display | Xvfb `:99` + fluxbox + x11vnc `:5900` |
| **Existing desktop** | `$DISPLAY` set + working | Uses native display, no Xvfb/VNC |
| **Termux** | `$TERMUX_VERSION` | Termux:X11 app or headless fallback |

## Network Detection

On startup, the skill checks your public IP. If it detects a **datacenter**
IP (VPS, cloud, VPN), it warns that websites may block you and asks if
you have a **residential proxy**. Providers like BrightData, Oxylabs,
Smartproxy, SOAX, IPRoyal, and Webshare offer residential SOCKS5 proxies
that bypass VPN/datacenter blocking.

```bash
bash scripts/network.sh check          # Check IP type
bash scripts/network.sh proxy-set      # Configure SOCKS5/HTTP proxy
bash scripts/network.sh proxy-test     # Test connectivity
bash scripts/network.sh providers      # List proxy providers
```

## Basic Actions

### Look at the screen
```bash
bash scripts/screenshot.sh                    # Screenshot
bash scripts/screenshot.sh --analyze          # + UI analysis
python3 lib/screen_analyzer.py --capture --json  # Full analysis
python3 lib/ocr.py --capture                  # Read all text (OCR)
python3 lib/ocr.py --capture --json           # Text with positions
python3 lib/ocr.py --find "Continue"          # Find a word
```

### Navigate the web
```bash
bash scripts/browser.sh open "https://example.com"   # Ctrl+L
bash scripts/browser.sh new-tab "https://google.com" # Ctrl+T
bash scripts/browser.sh refresh                      # Ctrl+R
bash scripts/browser.sh back                         # Alt+Left
bash scripts/browser.sh forward                      # Alt+Right
bash scripts/browser.sh close-tab                    # Ctrl+W
```

### Click
```bash
bash scripts/click.sh 640 480          # Left click
bash scripts/click.sh 640 480 3        # Right-click
bash scripts/click.sh 640 480 1 --double  # Double-click
bash scripts/click.sh --text continue  # Find button by hint
bash scripts/click.sh --element modal  # Dismiss overlay
```

### Scroll
```bash
bash scripts/scroll.sh down 3      # Scroll down
bash scripts/scroll.sh up 5        # Scroll up
bash scripts/scroll.sh page-down   # One page
bash scripts/scroll.sh bottom      # Jumpt to bottom
bash scripts/scroll.sh top         # Back to top
```

### Type & Keys
```bash
bash scripts/type.sh "Hello"                    # Type text
bash scripts/type.sh --key Return               # Press Enter
bash scripts/type.sh --key "ctrl+a"             # Select all
bash scripts/type.sh --key "ctrl+c"             # Copy
bash scripts/type.sh --input "user@email.com"   # Type into focused field
```

### Clipboard
```bash
bash scripts/clipboard.sh copy "text"        # Copy to clipboard
bash scripts/clipboard.sh read               # Read clipboard
bash scripts/clipboard.sh paste              # Ctrl+V
bash scripts/clipboard.sh clear              # Empty clipboard
bash scripts/clipboard.sh file path.txt      # Copy file text
```

### Adaptive Wait (replace fixed sleep)
```bash
bash scripts/wait.sh stable              # Wait for screen to stop changing
bash scripts/wait.sh text "Continue"     # Wait for text to appear
bash scripts/wait.sh button continue     # Wait for button to appear
bash scripts/wait.sh modal               # Wait for modal + dismiss
bash scripts/wait.sh seconds 5           # Simple delay
```

### Screen Recording
```bash
bash scripts/record.sh start             # Start recording
bash scripts/record.sh stop              # Save video
bash scripts/record.sh status            # Check if recording
bash scripts/record.sh list              # List recordings
bash scripts/record.sh cleanup 7         # Delete old
```

### Dialog Handling (JS alerts/confirms/prompts)
```bash
bash scripts/dialog.sh detect            # Check for dialog
bash scripts/dialog.sh accept            # OK / Enter
bash scripts/dialog.sh dismiss           # Cancel / Escape
bash scripts/dialog.sh type "text"       # Type into prompt
```

### Download Manager
```bash
bash scripts/download.sh list            # List downloaded files
bash scripts/download.sh latest          # Most recent file
bash scripts/download.sh watch           # Monitor new files
bash scripts/download.sh open file.txt   # Open in browser
```

### Environment
```bash
bash setup/start.sh              # Start desktop (once)
bash scripts/status.sh           # Check everything
bash setup/watchdog.sh status    # Health monitor
bash setup/stop.sh               # Full teardown (rare)
```

## Human-Like Workflow

```
look at screen → think → click or type or scroll → wait → look again
```

- **Look first**: screenshot before every action
- **Wait smartly**: use `wait.sh stable` or `wait.sh text` instead of fixed sleep
- **Vary your scroll**: sometimes 2, sometimes 7, sometimes page-down
- **Mix click methods**: coordinates, text hints, OCR find, right-click
- **Read text**: use OCR to understand what buttons actually say
- **Use clipboard**: copy things, paste them, read what's copied
- **Handle surprises**: modals, dialogs, slow pages, failed clicks
- **Never kill browser**: just navigate to the next URL
- **Proxy awareness**: if on datacenter IP, offer to set up residential proxy

## Example Session (Visual Desktop)

```bash
# 1. Start (one time)
bash setup/start.sh

# 2. Go to page
bash scripts/browser.sh open "https://example.com/target"
bash scripts/wait.sh stable

# 3. See what's there
python3 lib/screen_analyzer.py --capture
python3 lib/ocr.py --find "Continue"

# 4. Click the button
bash scripts/click.sh --text continue
bash scripts/wait.sh stable

# 5. Read content
python3 lib/ocr.py --capture
bash scripts/clipboard.sh copy "$(python3 lib/ocr.py --capture --json)"

# 6. Scroll naturally
bash scripts/scroll.sh down 4
sleep 1
bash scripts/scroll.sh down 2

# 7. Next site (same browser, no restart)
bash scripts/browser.sh open "https://next-site.com"
```

---

## Advanced Intelligence: DOM Engine (Playwright Headless)

> **When to use:** Modern JS-heavy gate/redirect sites that crash surf/Chrome in Xvfb.
> The DOM engine uses Playwright headless Chromium — it reads the DOM directly
> instead of relying on screen pixels and OCR.

The DOM engine is available alongside the visual desktop. It uses a `lib/dom_engine.py`
library that knows how to trace multi-hop redirect chains (adfly, shrinkme, shorte, etc.).

### Core Intelligence: The 6-Step Observation Methodology

Every unknown page is analyzed the same way — no hardcoded assumptions.

| Step | What | Command |
|---|---|---|
| **1. Probe** | Navigate and see where you land (redirects, final URL) | `bash scripts/dom_browse.sh open <url>` |
| **2. Scan DOM** | Dump all clickable elements with positions | `bash scripts/dom_click.sh --scan` |
| **3. Detect type** | Auto-classify page: redirect, gate, gate_action, content, content_action, destination | `bash scripts/dom_observe.sh` |
| **4. Poll timers** | Watch for elements appearing (vs. guessing timeout) | Built into `dom_engine.py.poll_for_element()` |
| **5. Scroll + click** | Incremental scroll, check for bottom buttons, retry from top | `bash scripts/dom_click.sh` (default: auto-find) |
| **6. Capture new tab** | Register page event listener before clicking "Get Link" | Built into `dom_engine.py.start()` |

### DOM Engine Commands

| Command | What it does |
|---|---|
| `bash scripts/dom_browse.sh open <url>` | Navigate using headless Playwright. Returns final URL + page type + element list. |
| `bash scripts/dom_browse.sh scan` | Scan current page interactable elements |
| `bash scripts/dom_browse.sh status` | Check if Playwright is installed |
| `bash scripts/dom_click.sh` | Auto-detect and click Continue/Get Link buttons |
| `bash scripts/dom_click.sh --scan` | Dump all visible interactive elements as JSON |
| `bash scripts/dom_click.sh --text "Continue"` | Find and click by text (regex) |
| `bash scripts/dom_click.sh --selector "#tp-snp2"` | Find and click by CSS selector |
| `bash scripts/dom_observe.sh [url]` | Run full 6-step observation on a page |
| `bash scripts/dom_trace.sh <url> [outdir]` | **Full chain tracer**: follows redirects, clicks popups, waits for timers, scrolls for buttons, captures new-tab destinations. Saves log + screenshot + result JSON. |

### Decision Tree for Any Page

When you encounter a new page, follow this logic:

```
New page loaded
│
├─ Page very short (<100 chars)?
│   └─ → This is a redirect/transition page. Wait 5s and re-check URL.
│
├─ Page short (100-800 chars)?
│   ├─ Has #continueBtn?
│   │   └─ → Popup detected. Click (force=True, bypass overlay). Wait for new elements.
│   ├─ Has "Get Link", "Your link is almost ready", countdown timer?
│   │   └─ → Gate landing page. Poll for Get Link button. Register new-tab handler first.
│   └─ Otherwise?
│       └─ → Unknown gate. Scan DOM, look for any button with "continue"/"get link" text.
│
├─ Page long (>800 chars)?
│   ├─ Has bottom buttons (#tp-snp2, #btn7, #cross-snp2, CONTINUE link)?
│   │   └─ → Content with navigation. Scroll to button and click.
│   └─ No buttons found after scrolling full page + retry?
│       └─ → Possible destination. Record URL and stop.
│
└─ No gate keywords, not a known gate domain?
    └─ → Destination reached! Record final URL.
```

### Known Button Selectors (DOM Engine)

Common patterns observed across gate sites. The engine tries them in priority order:

| Priority | Selector | Likely Purpose |
|---|---|---|
| 1 | `#continueBtn` | Popup overlay "Continue" button |
| 2 | `#tp-snp2` | Bottom-of-page navigation |
| 3 | `#btn7` | Bottom-of-page navigation (variant) |
| 4 | `#cross-snp2` | Bottom-of-page navigation (variant) |
| 5 | `#get-link`, `#gt-link` | Final "Get Link" button on landing page |
| 6 | `a:has-text('Get Link')`, `button:has-text('Get Link')` | Text-based Get Link |
| 7 | `a:has-text('CONTINUE')`, `button:has-text('CONTINUE')` | Text-based Continue |
| 8 | `.skip-button`, `#skip-btn`, `a:has-text('Skip')` | Skip ad / skip timer |

### Example: Tracing Any Gate Chain

```bash
# Quick trace (one command)
bash scripts/dom_trace.sh https://example-gate.com/link123 /tmp/my_trace
cat /tmp/my_trace/result.json   # Shows destination_url

# Step-by-step (manual observation)
bash scripts/dom_browse.sh open https://example-gate.com/link123
bash scripts/dom_observe.sh     # Step 1-3: probe, scan, detect type
bash scripts/dom_click.sh       # Step 4-5: click found button
bash scripts/dom_observe.sh     # Re-observe after navigation
# ... repeat until destination
```

### When to Use Each Engine

| Situation | Use |
|---|---|
| Page loads in surf/firefox fine | Visual desktop (OCR, screen analysis) |
| Page requires JS (gate, redirect, timer) | DOM engine (Playwright headless) |
| Chrome crashes with SIGTRAP | DOM engine (no Xvfb needed) |
| Need to see what's happening | Visual desktop + VNC |
| Need reliable automation | DOM engine (DOM introspection > pixel analysis) |
| Page has overlay popups | DOM engine (`force=True` bypasses animations) |
| Page opens destination in new tab | DOM engine (built-in `ctx.on('page')` handler) |

### Running from the Python Library Directly

```python
from lib.dom_engine import DOMEngine
import asyncio

async def main():
    engine = DOMEngine()
    page = await engine.start()
    await engine.navigate("https://example-gate.com/some-link")
    result = await engine.trace_chain("https://example-gate.com/some-link")
    print(f"Destination: {result['destination_url']}")
    await engine.close()

asyncio.run(main())
```

---

## Linux Desktop Engine (Native X11)

> **When to use:** Reading the screen of native Linux apps (not web pages).
> Uses the accessibility tree (pyatspi) as the PRIMARY method — reads the
> actual UI element hierarchy as structured text, no OCR needed for most apps.

The Linux Desktop Engine is a third parallel engine alongside the visual desktop
and DOM engine. It uses FOUR methods in priority order:

| Priority | Method | Library | What it reads |
|---|---|---|---|
| 1 | **Accessibility tree** | `pyatspi` | UI element hierarchy: buttons, labels, windows, menus — as clean text with coordinates |
| 2 | **OCR** | `mss` + `pytesseract` | Visible text as words with pixel coordinates |
| 3 | **Template matching** | `opencv-python` | Graphical icons by matching a template image |
| 4 | **Actions** | `pyautogui` / `xdotool` | Moves mouse, clicks, types |

### Installation

```bash
sudo apt install python3-pyatspi tesseract-ocr  # System deps
pip3 install pyautogui python-xlib opencv-python-headless mss pytesseract
```

### Linux Desktop Commands

| Command | What it does |
|---|---|
| `bash scripts/desktop_read.sh` | Read full screen: accessibility tree + OCR text + active window |
| `bash scripts/desktop_read.sh --accessibility-only` | Read only the accessibility tree (structured UI elements) |
| `bash scripts/desktop_read.sh --ocr-only` | Read only OCR text with coordinates |
| `bash scripts/desktop_click.sh <x> <y>` | Click at pixel coordinates |
| `bash scripts/desktop_click.sh --text "Continue"` | Find text (accessibility → OCR) and click it |
| `bash scripts/desktop_click.sh --template icon.png` | Find an icon on screen using OpenCV template matching |
| `bash scripts/desktop_status.sh` | Check which backends are installed |

### The Intelligence Pattern (How It Thinks)

```
Agent needs to interact with screen
│
├─ Call desktop_read.sh
│   ├─ pyatspi accessibility tree available?
│   │   └─ YES → Read UI hierarchy directly (best: exact text, exact positions)
│   │   └─ NO  → Fall back to OCR (mss screenshot + pytesseract)
│   │
│   ├─ Parse results: find target element
│   │   ├─ Button "Continue" found in accessibility tree?
│   │   │   └─ YES → Click its exact coordinates
│   │   ├─ Text "Submit" found via OCR?
│   │   │   └─ YES → Click its center coordinates
│   │   └─ Neither found?
│   │       └─ → Try OpenCV template matching for icon
│   │
│   └─ Execute: click / type / press key
│       ├─ pyautogui available?
│       │   └─ YES → Use PyAutoGUI (human-like random delays)
│       │   └─ NO  → Fall back to xdotool
│       └─ Return success/failure
```

### Example: Reading a Native App

```bash
# Full screen read (accessibility tree + OCR)
bash scripts/desktop_read.sh

# Output (abbreviated):
# {
#   "accessibility_text": "window: Firefox\n  panel: Navigation\n    button: Back\n    button: Forward\n    text: Address Bar\n  document: webpage content\n    link: https://example.com\n    button: Submit",
#   "ocr_text": "Found text 'Firefox' at (45, 12)\nFound text 'Submit' at (640, 480)",
#   "active_window": {"title": "Firefox", "x": 0, "y": 0, "width": 1280, "height": 720}
# }

# Click the Submit button
bash scripts/desktop_click.sh --text Submit

# Type into the focused field
bash scripts/desktop_click.sh --text "Address Bar"
bash scripts/desktop_type.sh "https://example.com"
```

## The Screen Analyzer (Legacy)

Detects UI elements by color (no OCR needed):

| Element | Color | What |
|---|---|---|
| **Button** | R>200, G=80-200, B<140 | Warm orange/pink buttons |
| **Modal** | R=80-130, G<80, B>120 | Purple overlay popups |
| **Link** | R<80, G=80-180, B>120 | Blue hyperlinks |
| **Text** | R<40, G<40, B<40 | Dark text |
| **Footer** | R<30, G<30, B<30 | Dark bars |

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/adittaya/browsing-skill/master/setup/install.sh | bash
```

Then: `bash ~/.local/share/desktop-skill/setup/start.sh`

## VNC

Connect to `localhost:5900` with any VNC client to watch the desktop live.
