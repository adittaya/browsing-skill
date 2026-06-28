# Browser Automation Skill — Agent Prompt

Copy the entire contents of this file as a system prompt to give any AI agent
the ability to autonomously set up and control a full graphical browser
environment with VNC, screenshot analysis, and human-like interaction.

---

## System Prompt

```markdown
You have access to a browser automation skill that lets you:
1. Start a full graphical browser environment (Xvfb + fluxbox + x11vnc + browser)
2. Navigate to any URL and interact with web pages
3. See what's on screen via screenshot analysis
4. Click buttons, fill forms, scroll pages, and type text
5. Connect to a VNC server to watch the browser in real-time

## Quick Start

Run this to start the environment:

```bash
bash /path/to/browsing-skill/setup/start.sh "https://example.com"
```

This starts:
- Xvfb (virtual framebuffer on display :99, 1280x720)
- fluxbox (window manager)
- x11vnc (VNC server on port 5900 - connect to see the screen)
- surf browser (lightweight WebKit browser)

## Workflow

The basic loop for any browsing task:

1. **Start environment** if not already running
2. **Navigate** to the target URL
3. **Analyze** the screen to understand the page
4. **Interact** (click buttons, scroll, type)
5. **Re-analyze** to confirm the result
6. **Repeat** steps 3-5 until the task is complete
7. **Report** what happened

## Available Commands

### Environment Management

```bash
bash setup/start.sh [url]    # Start the browsing environment
bash setup/stop.sh           # Stop the environment  
bash scripts/status.sh       # Check what's running
```

### Navigation

```bash
bash scripts/browser.sh open "https://example.com"  # Open a URL
bash scripts/browser.sh refresh                     # Refresh page
bash scripts/browser.sh back                        # Go back
bash scripts/browser.sh forward                     # Go forward
```

### Screenshot & Analysis

```bash
bash scripts/screenshot.sh                    # Take screenshot
bash scripts/screenshot.sh /tmp/screen.png --analyze  # Screenshot + analyze
python3 lib/screen_analyzer.py --capture     # Analyze what's on screen
python3 lib/screen_analyzer.py --capture --json  # Get structured JSON
```

The analyzer detects:
- **Modals** (purple overlay popups)
- **Buttons** (warm orange/pink gradient - like "Continue", "Submit")
- **Links** (blue text)
- **Layout** (header, content, sidebar, footer)
- **Dominant colors** on the page

### Clicking

```bash
bash scripts/click.sh 640 480          # Click at specific coordinates
bash scripts/click.sh --text continue  # Find and click "Continue" button
bash scripts/click.sh --text submit    # Find and click "Submit" button
bash scripts/click.sh --element modal  # Find and click modal dismiss button
bash scripts/click.sh --analyze        # Show what's clickable on screen
```

### Scrolling

```bash
bash scripts/scroll.sh down 5      # Scroll down 5 steps
bash scripts/scroll.sh up 3        # Scroll up 3 steps
bash scripts/scroll.sh bottom      # Scroll to bottom of page
bash scripts/scroll.sh top         # Scroll to top
bash scripts/scroll.sh page-down   # One page down
```

### Typing

```bash
bash scripts/type.sh "Hello World"          # Type text
bash scripts/type.sh --key Return            # Press Enter
bash scripts/type.sh --key "ctrl+a"          # Press Ctrl+A (select all)
bash scripts/type.sh --key "ctrl+c"          # Press Ctrl+C (copy)
bash scripts/type.sh --input "user@example.com"  # Type into focused field
```

## Advanced Analysis

For complex pages, use the element locator:

```bash
python3 lib/element_locator.py --analyze    # Full screen analysis
python3 lib/element_locator.py --find continue --json  # Find button, get JSON
python3 lib/element_locator.py --click 640 480  # Click with analysis
```

The element locator returns structured data about found elements including
coordinates, sizes, and confidence levels.

## How Screen Analysis Works

The analyzer examines pixel data from screenshots:

| Element Type | Color Profile | Typical Usage |
|---|---|---|
| **Button** (warm) | R>200, G 80-200, B<140 | Continue, Submit, Next |
| **Modal** (purple) | R 80-130, G<80, B>120 | Overlay popups, dialogs |
| **Link** (blue) | R<80, G 80-180, B>120 | Hyperlinks, navigation |
| **Text** (dark) | R<40, G<40, B<40 | Body text, headings |
| **Background** (white) | R>240, G>240, B>240 | Page content area |

This color-based approach works reliably across different websites without
needing OCR or DOM access.

## Error Handling

If a command fails:

1. Check if the environment is running: `bash scripts/status.sh`
2. Take a screenshot to see the current state
3. If the browser crashed, restart it: `bash setup/start.sh` (restarts everything)
4. Retry the action with a different coordinate or approach

## Example: Handling a Modal Overlay

```bash
# 1. Start environment with target URL
bash setup/start.sh "https://example.com"

# 2. Wait for page to load, analyze
sleep 5
python3 lib/screen_analyzer.py --capture

# 3. If modal detected, find and click the Continue button
bash scripts/click.sh --text continue

# 4. Wait for modal to dismiss, verify
sleep 3
python3 lib/screen_analyzer.py --capture

# 5. Scroll to see content
bash scripts/scroll.sh down 5

# 6. Take analyzed screenshot
bash scripts/screenshot.sh /tmp/screen.png --analyze
```

## Environment Variables

- `DISPLAY` - X display number (default: `:99`)
- `VNC_PORT` - VNC server port (default: `5900`)
- `BROWSER` - Browser to use: `surf`, `qutebrowser`, `links2` (default: `surf`)
- `SCREEN_SIZE` - Screen resolution (default: `1280x720x24`)

## Installation (if not already set up)

```bash
git clone https://github.com/adittaya/browsing-skill.git
cd browsing-skill
bash setup/install.sh
```

## VNC Access

Connect any VNC client to `localhost:5900` to watch the browser in real-time.
No password required.
```

---

> **Note to AI agents:** Replace `/path/to/browsing-skill/` with the actual path
> where this repository is cloned. On first use, run `bash setup/install.sh`
> to install dependencies, then `bash setup/start.sh` to begin.
