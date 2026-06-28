# Desktop Environment Skill

A full graphical desktop for AI agents. Xvfb + VNC + fluxbox + browser.
Click, type, scroll, OCR, clipboard, screen recording, download management,
dialog handling, health watchdog, and residential proxy support.

**Auto-detects**: terminal (starts Xvfb+VNC) | existing desktop (uses native display) | Termux | proot-distro

**Auto-detects your IP type**: residential (good to go) or datacenter (needs proxy — prompts user)

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/adittaya/browsing-skill/master/setup/install.sh | bash
bash ~/.local/share/desktop-skill/setup/start.sh
```

## Full Command Reference

### Desktop
| Command | What |
|---|---|
| `bash setup/start.sh [url]` | Start desktop (auto-detect terminal vs existing desktop) |
| `bash setup/stop.sh` | Full teardown (rare) |
| `bash scripts/status.sh` | Check all processes |
| `bash setup/watchdog.sh status` | Health monitor status |

### Browse
| Command | What |
|---|---|
| `bash scripts/browser.sh open <url>` | Ctrl+L → type → Enter (never kill browser) |
| `bash scripts/browser.sh new-tab <url>` | Ctrl+T |
| `bash scripts/browser.sh refresh` | Ctrl+R |
| `bash scripts/browser.sh back` | Alt+Left |
| `bash scripts/browser.sh forward` | Alt+Right |
| `bash scripts/browser.sh close-tab` | Ctrl+W |

### Click
| Command | What |
|---|---|
| `bash scripts/click.sh 640 480` | Left click at coordinates |
| `bash scripts/click.sh 640 480 3` | Right-click |
| `bash scripts/click.sh 640 480 1 --double` | Double-click |
| `bash scripts/click.sh --text continue` | Find button by hint and click |

### Scroll
| Command | What |
|---|---|
| `bash scripts/scroll.sh down 5` | Scroll down N steps |
| `bash scripts/scroll.sh up 3` | Scroll up |
| `bash scripts/scroll.sh bottom` | Jump to bottom |
| `bash scripts/scroll.sh top` | Jump to top |
| `bash scripts/scroll.sh page-down` | One page down |

### Type & Keys
| Command | What |
|---|---|
| `bash scripts/type.sh "Hello"` | Type text |
| `bash scripts/type.sh --key Return` | Press Enter |
| `bash scripts/type.sh --key "ctrl+a"` | Select all |
| `bash scripts/type.sh --key "ctrl+c"` | Copy |

### Screenshot & Analyze
| Command | What |
|---|---|
| `bash scripts/screenshot.sh` | Take screenshot |
| `bash scripts/screenshot.sh --analyze` | Screenshot + UI analysis |
| `python3 lib/screen_analyzer.py --capture --json` | Detect buttons, modals, links, layout |

### OCR (Read text from screen)
| Command | What |
|---|---|
| `python3 lib/ocr.py --capture` | Screenshot + read all text |
| `python3 lib/ocr.py --capture --json` | Text with positions |
| `python3 lib/ocr.py --find 'Continue'` | Find and locate a word |

### Clipboard
| Command | What |
|---|---|
| `bash scripts/clipboard.sh copy "text"` | Copy to clipboard |
| `bash scripts/clipboard.sh read` | Get clipboard content |
| `bash scripts/clipboard.sh paste` | Ctrl+V into active window |
| `bash scripts/clipboard.sh clear` | Clear clipboard |
| `bash scripts/clipboard.sh file path.txt` | Copy file contents |

### Adaptive Wait
| Command | What |
|---|---|
| `bash scripts/wait.sh stable` | Wait until screen stops changing |
| `bash scripts/wait.sh text 'Continue'` | Wait for text to appear (via OCR) |
| `bash scripts/wait.sh button continue` | Wait for button by color analysis |
| `bash scripts/wait.sh modal` | Wait for modal, then dismiss |
| `bash scripts/wait.sh seconds 5` | Simple sleep |

### Screen Recording
| Command | What |
|---|---|
| `bash scripts/record.sh start` | Start recording with ffmpeg |
| `bash scripts/record.sh stop` | Stop and save video |
| `bash scripts/record.sh status` | Check if recording |
| `bash scripts/record.sh list` | List saved recordings |
| `bash scripts/record.sh cleanup 7` | Delete recordings older than 7 days |

### Dialog Handler (JS alerts, confirms, prompts)
| Command | What |
|---|---|
| `bash scripts/dialog.sh detect` | Check if a dialog is open |
| `bash scripts/dialog.sh accept` | Press Enter / click OK |
| `bash scripts/dialog.sh dismiss` | Press Escape / click Cancel |
| `bash scripts/dialog.sh type "text"` | Type into prompt |

### Download Manager
| Command | What |
|---|---|
| `bash scripts/download.sh list` | List downloaded files |
| `bash scripts/download.sh latest` | Show most recent download |
| `bash scripts/download.sh watch` | Monitor for new downloads |
| `bash scripts/download.sh open <file>` | Open in browser |
| `bash scripts/download.sh cleanup 30` | Delete files older than 30 days |

### Network & Proxy
| Command | What |
|---|---|
| `bash scripts/network.sh check` | Detect residential vs datacenter IP |
| `bash scripts/network.sh proxy-set` | Configure SOCKS5/HTTP proxy |
| `bash scripts/network.sh proxy-status` | Show proxy config |
| `bash scripts/network.sh proxy-clear` | Remove proxy |
| `bash scripts/network.sh proxy-test` | Test connectivity through proxy |
| `bash scripts/network.sh providers` | List residential proxy providers |

## IP Detection + Proxy System

On startup, the skill checks your public IP:

- **Residential IP** → "You're on a residential IP. Most websites won't block you."
- **Datacenter IP** → "You're on a datacenter IP. Many websites block these. You need a residential proxy."

If datacenter detected, the skill:
1. Warns about VPN/datacenter blocking
2. Lists recommended residential proxy providers (BrightData, Oxylabs, Smartproxy, SOAX, IPRoyal, Webshare)
3. Asks if the user has a proxy provider
4. Walks through configuring SOCKS5 proxy with provider-specific URL formats

The proxy persists in `$DATA_DIR/proxy.env` and loads automatically on `start.sh`.

## Requirements

| Environment | Manager | Notes |
|---|---|---|
| Ubuntu/Debian/Mint/Kali | `apt` | Full support |
| Fedora/RHEL/CentOS/Rocky | `dnf`/`yum` | Full support |
| Arch/Manjaro/EndeavourOS | `pacman` | Full support |
| Alpine | `apk` | Full support |
| openSUSE/SLES | `zypper` | Full support |
| Termux (Android) | `pkg` | Termux:X11 for display |
| proot-distro (Android) | apt/native | Headless fallback |
| macOS | brew | Limited, needs XQuartz |

## Structure

```
desktop-skill/
├── skill.jsonc              # Skill manifest (v3.0.0)
├── AGENTS.md                # Agent prompt (copy-paste)
├── README.md                # This file
├── lib/
│   ├── config.sh            # Shared config loader (sourced by all scripts)
│   ├── config.py            # Python config loader
│   ├── screen_analyzer.py   # UI element detection (buttons, modals, links)
│   ├── element_locator.py   # Element finding + automatic clicking
│   └── ocr.py              # OCR engine (Tesseract)
├── setup/
│   ├── install.sh           # Auto-detecting installer
│   ├── start.sh             # Start desktop (persistent session)
│   ├── stop.sh              # Destroy environment
│   └── watchdog.sh          # Health monitor daemon
├── scripts/
│   ├── browser.sh           # Web navigation (never kill/reopen)
│   ├── click.sh             # Mouse clicks (left, right, double)
│   ├── scroll.sh            # Scrolling
│   ├── type.sh              # Keyboard typing
│   ├── screenshot.sh        # Screenshots
│   ├── clipboard.sh         # Copy/paste/read clipboard
│   ├── wait.sh              # Adaptive wait (stable, text, button, modal)
│   ├── record.sh            # Screen recording (ffmpeg)
│   ├── dialog.sh            # JS dialog handler
│   ├── download.sh          # Download management
│   ├── network.sh           # IP detection + SOCKS5 proxy setup
│   └── status.sh            # Environment status
└── test/
    ├── test_env.sh
    └── test_browse.sh
```

## License

MIT
