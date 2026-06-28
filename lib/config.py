"""Python config loader — reads the same config file as the bash scripts."""

import os
import configparser
from pathlib import Path


def load_config():
    """Load config from file. Returns a dict with all keys and defaults."""
    cfg = {
        "DISPLAY_NUM": "99",
        "DISPLAY": ":99",
        "VNC_PORT": "5900",
        "SCREEN_SIZE": "1280x720x24",
        "BROWSER": "surf",
        "DATA_DIR": "/tmp/desktop-skill",
        "RECORD_DIR": "/tmp/desktop-skill/recordings",
        "DOWNLOAD_DIR": "/tmp/desktop-skill/downloads",
        "OCR_LANG": "eng",
        "WAIT_TIMEOUT": "15",
        "WATCHDOG_INTERVAL": "10",
        "SESSION_FILE": "/tmp/desktop-skill/session",
        "LOG_FILE": "/tmp/desktop-skill/skill.log",
    }

    # Check env var override
    env_config = os.environ.get("DESKTOP_SKILL_CONFIG", "")
    candidates = [
        env_config,
        os.path.expanduser("~/.config/desktop-skill/config"),
        os.path.expanduser("~/.desktop-skill.cfg"),
    ]

    config_path = None
    for c in candidates:
        if c and Path(c).exists():
            config_path = c
            break

    if config_path:
        parser = configparser.ConfigParser()
        try:
            parser.read(config_path)
            for section in parser.sections():
                for key, value in parser.items(section):
                    cfg[key.upper()] = value
        except Exception:
            pass

    # Shell-style config files use KEY=value, not ini sections
    if config_path:
        try:
            with open(config_path) as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key, _, value = line.partition("=")
                        key = key.strip().upper()
                        value = value.strip().strip("'\"")
                        if key:
                            cfg[key] = value
        except Exception:
            pass

    # Env vars override everything
    for key in list(cfg.keys()):
        env_val = os.environ.get(key)
        if env_val is not None:
            cfg[key] = env_val

    # Apply derived values
    cfg["DISPLAY_NUM"] = cfg["DISPLAY"].lstrip(":")
    cfg["SESSION_FILE"] = f"{cfg['DATA_DIR']}/session"
    cfg["LOG_FILE"] = f"{cfg['DATA_DIR']}/skill.log"
    cfg["RECORD_DIR"] = cfg.get("RECORD_DIR", f"{cfg['DATA_DIR']}/recordings")
    cfg["DOWNLOAD_DIR"] = cfg.get("DOWNLOAD_DIR", f"{cfg['DATA_DIR']}/downloads")

    # Ensure directories exist
    for d in [cfg["DATA_DIR"], cfg["RECORD_DIR"], cfg["DOWNLOAD_DIR"]]:
        Path(d).mkdir(parents=True, exist_ok=True)

    return cfg


def get(key, default=None):
    """Get a single config value."""
    return load_config().get(key, default)
