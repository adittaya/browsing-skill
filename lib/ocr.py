#!/usr/bin/env python3
"""
OCR engine — extracts text from screenshots using Tesseract.

Usage:
  python3 lib/ocr.py --capture                  # Screenshot + OCR everything
  python3 lib/ocr.py --capture --json            # JSON output with positions
  python3 lib/ocr.py /path/to/screenshot.png     # OCR an existing image
  python3 lib/ocr.py --region 100 200 300 50     # OCR a region: x y w h
"""

import json
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    Image = None

# Add parent to path for config
sys.path.insert(0, str(Path(__file__).resolve().parent))
from config import load_config


def check_tesseract():
    try:
        subprocess.run(["tesseract", "--version"], capture_output=True, check=True)
        return True
    except (FileNotFoundError, subprocess.CalledProcessError):
        return False


def capture_screenshot(output_path=None):
    """Take a screenshot using ImageMagick import or Python fallback."""
    if output_path is None:
        output_path = str(Path(tempfile.mkdtemp()) / "ocr_screen.png")

    cfg = load_config()
    display = cfg.get("DISPLAY", ":99")

    # Try ImageMagick
    try:
        subprocess.run(
            ["import", "-window", "root", output_path],
            env={"DISPLAY": display},
            capture_output=True,
            check=True,
            timeout=10,
        )
        return output_path
    except Exception:
        pass

    # Try Python fallback (Xlib or mss)
    try:
        import mss

        with mss.mss() as sct:
            sct.shot(output=output_path)
        return output_path
    except ImportError:
        pass

    try:
        import Xlib.display

        disp = Xlib.display.Display(display)
        root = disp.screen().root
        geom = root.get_geometry()
        width, height = geom.width, geom.height
        raw = root.get_image(0, 0, width, height, Xlib.X.ZPixmap, 0xFFFFFFFF)
        img = Image.frombuffer("RGB", (width, height), raw.data, "raw", "BGRX", 0, 1)
        img.save(output_path)
        return output_path
    except Exception:
        pass

    return None


def ocr_image(image_path, lang="eng", psm=None):
    """Run Tesseract OCR on an image. Returns list of word dicts."""
    if not check_tesseract():
        return None

    cfg = load_config()
    lang = lang or cfg.get("OCR_LANG", "eng")

    args = ["tesseract", image_path, "stdout", "-l", lang, "--psm", str(psm or 3)]
    args += ["tsv"]  # TSV output includes position data

    try:
        result = subprocess.run(
            args, capture_output=True, text=True, check=True, timeout=30
        )
    except (subprocess.CalledProcessError, FileNotFoundError):
        # Fall back to plain text
        args = ["tesseract", image_path, "stdout", "-l", lang]
        try:
            result = subprocess.run(
                args, capture_output=True, text=True, check=True, timeout=30
            )
            return {"text": result.stdout.strip(), "words": []}
        except (subprocess.CalledProcessError, FileNotFoundError):
            return None

    # Parse TSV output
    words = []
    lines = result.stdout.strip().split("\n")
    if len(lines) < 2:
        return {"text": "", "words": []}

    headers = lines[0].split("\t")
    for line in lines[1:]:
        if not line.strip():
            continue
        parts = line.split("\t")
        row = dict(zip(headers, parts))

        if row.get("text", "").strip() and int(row.get("conf", -1)) > 0:
            words.append(
                {
                    "text": row["text"].strip(),
                    "conf": int(row.get("conf", 0)),
                    "x": int(row.get("left", 0)),
                    "y": int(row.get("top", 0)),
                    "w": int(row.get("width", 0)),
                    "h": int(row.get("height", 0)),
                }
            )

    full_text = " ".join(w["text"] for w in words)
    # Also get full plain text for good measure
    try:
        plain = subprocess.run(
            ["tesseract", image_path, "stdout", "-l", lang],
            capture_output=True,
            text=True,
            check=True,
            timeout=30,
        )
        full_text = plain.stdout.strip()
    except Exception:
        pass

    return {"text": full_text, "words": words}


def find_text(target, words, case_sensitive=False):
    """Find word(s) matching target text. Returns list of matching word dicts."""
    results = []
    target = target.strip()
    for w in words:
        wtext = w["text"] if case_sensitive else w["text"].lower()
        t = target if case_sensitive else target.lower()
        if wtext == t:
            results.append(w)
        elif len(target) > 2 and t in wtext:
            results.append(w)
    return results


def main():
    cfg = load_config()

    output_json = False
    region = None
    lang = cfg.get("OCR_LANG", "eng")
    psm = None

    args = sys.argv[1:]
    image_path = None

    i = 0
    while i < len(args):
        if args[i] == "--capture":
            image_path = capture_screenshot()
            if image_path is None:
                print("Failed to capture screenshot", file=sys.stderr)
                sys.exit(1)
        elif args[i] == "--json":
            output_json = True
        elif args[i] == "--region" and i + 4 < len(args):
            region = (int(args[i + 1]), int(args[i + 2]), int(args[i + 3]), int(args[i + 4]))
            i += 4
        elif args[i] == "--lang" and i + 1 < len(args):
            lang = args[i + 1]
            i += 1
        elif args[i] == "--psm" and i + 1 < len(args):
            psm = int(args[i + 1])
            i += 1
        elif args[i] == "--find" and i + 1 < len(args):
            target = args[i + 1]
            i += 1
            # Capture and search
            img = image_path or capture_screenshot()
            if img:
                result = ocr_image(img, lang, psm)
                if result and result["words"]:
                    matches = find_text(target, result["words"])
                    if matches:
                        # Click the first match
                        m = matches[0]
                        cx = m["x"] + m["w"] // 2
                        cy = m["y"] + m["h"] // 2
                        print(f"Found '{target}' at ({cx}, {cy}) (conf: {m['conf']}%)")
                        if output_json:
                            print(
                                json.dumps(
                                    {
                                        "text": target,
                                        "x": cx,
                                        "y": cy,
                                        "confidence": m["conf"],
                                        "matches": matches,
                                    }
                                )
                            )
                    else:
                        print(f"Text '{target}' not found on screen")
                else:
                    print("OCR failed or no text detected")
            return
        elif not args[i].startswith("--"):
            image_path = args[i]
        i += 1

    # Fallback: capture if no image provided
    if image_path is None:
        image_path = capture_screenshot()
        if image_path is None:
            print("No image provided and screenshot failed", file=sys.stderr)
            sys.exit(1)

    # Crop if region specified
    if region and Image:
        img = Image.open(image_path)
        x, y, w, h = region
        cropped = img.crop((x, y, x + w, y + h))
        cropped_path = image_path.replace(".png", "_region.png")
        cropped.save(cropped_path)
        image_path = cropped_path

    result = ocr_image(image_path, lang, psm)

    if result is None:
        print("OCR not available. Install tesseract-ocr.")
        sys.exit(1)

    if output_json:
        print(json.dumps(result, indent=2))
    else:
        print("─" * 50)
        print("  OCR TEXT")
        print("─" * 50)
        print(result["text"])
        if result["words"]:
            print()
            print(f"  Words detected: {len(result['words'])}")
            print(f"  Coordinates available with --json")
        print("─" * 50)

    # Clean up temp screenshots
    if "ocr_screen" in image_path:
        Path(image_path).unlink(missing_ok=True)


if __name__ == "__main__":
    main()
