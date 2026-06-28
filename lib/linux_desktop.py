"""
Linux Desktop Engine — Native screen reading & automation for X11 Linux.
Combines FOUR approaches to give text-only AI agents full desktop awareness:

  1. **Accessibility tree** (pyatspi) — read UI hierarchy as structured text
  2. **OCR** (mss + pytesseract) — read visible text with pixel coordinates
  3. **Template matching** (OpenCV) — find icons/buttons by image template
  4. **Mouse/keyboard** (PyAutoGUI/python-xlib) — click, type, move

Every component is optional — missing packages are detected at import time
and the engine degrades gracefully.

System dependencies:
  sudo apt install python3-pyatspi tesseract-ocr
  pip3 install pyautogui python-xlib opencv-python-headless mss pytesseract
"""
import sys, os, json, re, time, subprocess
from pathlib import Path
from dataclasses import dataclass, field, asdict
from typing import Optional

# ── Optional imports with graceful fallback ──

# 1. pyatspi (accessibility tree)
try:
    import pyatspi
    import pyatspi.constants as ATSPI
    HAS_ATSPI = True
except ImportError:
    HAS_ATSPI = False

# 2. mss (screen capture)
try:
    import mss
    HAS_MSS = True
except ImportError:
    HAS_MSS = False

# 3. pytesseract (OCR)
try:
    import pytesseract
    from PIL import Image
    HAS_TESSERACT = True
except ImportError:
    HAS_TESSERACT = False

# 4. OpenCV (template matching)
try:
    import cv2
    import numpy as np
    HAS_OPENCV = True
except ImportError:
    HAS_OPENCV = False

# 5. PyAutoGUI (mouse/keyboard)
try:
    import pyautogui
    HAS_PYAUTOGUI = True
except ImportError:
    HAS_PYAUTOGUI = False

# 6. python-xlib (low-level window control)
try:
    from Xlib import display as xdisplay
    import Xlib.X
    HAS_XLIB = True
except ImportError:
    HAS_XLIB = False


@dataclass
class ScreenElement:
    """A detected element on screen with position and text."""
    text: str = ""
    x: int = 0
    y: int = 0
    width: int = 0
    height: int = 0
    center_x: int = 0
    center_y: int = 0
    source: str = ""  # "accessibility", "ocr", "opencv"
    element_type: str = ""  # "button", "label", "icon", "text", "window"
    confidence: float = 0.0

    def __post_init__(self):
        self.center_x = self.x + self.width // 2
        self.center_y = self.y + self.height // 2


class LinuxDesktop:
    """
    Complete Linux desktop reader and controller.
    Uses all available backends and chooses the best one for each task.

    The intelligence pattern: try accessibility first (structured, exact),
    fall back to OCR (text with coordinates), fall back to OpenCV (icon).
    """

    def __init__(self):
        self.display = os.environ.get('DISPLAY', ':99')
        self.atspi_available = HAS_ATSPI
        self.ocr_available = HAS_TESSERACT and HAS_MSS
        self.opencv_available = HAS_OPENCV
        self.action_available = HAS_PYAUTOGUI or self._has_xdotool()

    def _has_xdotool(self):
        try:
            subprocess.run(['xdotool', '--version'],
                         capture_output=True, timeout=5)
            return True
        except:
            return False

    # ══════════════════════════════════════════════════
    #  METHOD 1: Accessibility Tree (pyatspi)
    # ══════════════════════════════════════════════════

    def get_accessibility_tree(self, app_name=None, max_depth=10):
        """
        Read the Linux accessibility tree as structured text.
        Returns a list of (depth, role, name, state, coordinates) tuples.
        This is the BEST method — it reads the actual UI elements as text.
        """
        if not HAS_ATSPI:
            return {"error": "pyatspi not installed. Run: sudo apt install python3-pyatspi"}

        results = []
        desktop = pyatspi.Registry.getDesktop(0)

        def walk(node, depth=0):
            if depth > max_depth:
                return
            try:
                role = node.getRoleName()
                name = node.name or ""
                state_set = node.getState()
                states = []
                for s in [ATSPI.STATE_FOCUSED, ATSPI.STATE_ENABLED,
                          ATSPI.STATE_VISIBLE, ATSPI.STATE_SENSITIVE,
                          ATSPI.STATE_ACTIVE, ATSPI.STATE_SHOWING]:
                    if state_set.contains(s):
                        states.append(pyatspi.constants.stateToString(s))
                try:
                    extents = node.getExtents(pyatspi.DESKTOP_COORDS)
                    coords = f"x={extents.x} y={extents.y} w={extents.width} h={extents.height}"
                except:
                    coords = ""

                results.append({
                    "depth": depth,
                    "role": role,
                    "name": name[:120],
                    "states": states,
                    "coords": coords,
                })
            except:
                pass

            try:
                for child in node:
                    walk(child, depth + 1)
            except:
                pass

        walk(desktop)
        return results

    def accessibility_to_text(self, results):
        """Flatten accessibility tree into indented text for LLM consumption."""
        lines = []
        for r in results:
            indent = "  " * r["depth"]
            states = f" [{','.join(r['states'])}]" if r['states'] else ""
            coords = f" @{r['coords']}" if r['coords'] else ""
            lines.append(f"{indent}{r['role']}: {r['name']}{states}{coords}")
        return "\n".join(lines)

    def find_in_accessibility(self, text_query, results=None):
        """Find an element by text in the accessibility tree. Returns ScreenElement or None."""
        if results is None:
            results = self.get_accessibility_tree()
        query = text_query.lower()
        for r in results:
            if query in r['name'].lower():
                coords = r.get('coords', '')
                match = re.search(r'x=(\d+)\s+y=(\d+)\s+w=(\d+)\s+h=(\d+)', coords)
                if match:
                    return ScreenElement(
                        text=r['name'],
                        x=int(match.group(1)),
                        y=int(match.group(2)),
                        width=int(match.group(3)),
                        height=int(match.group(4)),
                        source='accessibility',
                        element_type=r['role'],
                    )
        return None

    # ══════════════════════════════════════════════════
    #  METHOD 2: OCR Screen Reading (mss + pytesseract)
    # ══════════════════════════════════════════════════

    def capture_screen(self, output_path="/tmp/desktop_screen.png"):
        """Capture a screenshot using mss. Returns the path or None."""
        if not HAS_MSS:
            # Fallback to ImageMagick import
            try:
                subprocess.run(
                    ['import', '-window', 'root', output_path],
                    env={**os.environ, 'DISPLAY': self.display},
                    capture_output=True, timeout=15,
                )
                return output_path if Path(output_path).exists() else None
            except:
                return None

        with mss.mss() as sct:
            sct.shot(output=output_path)
        return output_path if Path(output_path).exists() else None

    def ocr_screen(self, screenshot_path=None):
        """
        Read all text from the screen using OCR.
        Returns list of ScreenElement with text + coordinates.
        """
        if not HAS_TESSERACT:
            return {"error": "pytesseract not installed. Run: pip install pytesseract"}

        if not screenshot_path:
            screenshot_path = self.capture_screen()
        if not screenshot_path:
            return {"error": "Cannot capture screen"}

        data = pytesseract.image_to_data(
            Image.open(screenshot_path),
            output_type=pytesseract.Output.DICT,
        )

        elements = []
        for i in range(len(data['text'])):
            word = data['text'][i].strip()
            if word and data['conf'][i] > 30:  # Filter low-confidence
                elements.append(ScreenElement(
                    text=word,
                    x=data['left'][i],
                    y=data['top'][i],
                    width=data['width'][i],
                    height=data['height'][i],
                    source='ocr',
                    element_type='text',
                    confidence=data['conf'][i] / 100.0,
                ))
        return elements

    def ocr_find(self, query, screenshot_path=None):
        """Find a specific text string on screen. Returns ScreenElement or None."""
        elements = self.ocr_screen(screenshot_path)
        if isinstance(elements, dict) and 'error' in elements:
            return None
        query_lower = query.lower()
        for el in elements:
            if query_lower in el.text.lower():
                return el
        return None

    def ocr_to_text(self, elements):
        """Format OCR results as text for LLM consumption."""
        if isinstance(elements, dict) and 'error' in elements:
            return elements['error']
        lines = [f"Found text '{e.text}' at ({e.center_x}, {e.center_y}) "
                 f"size {e.width}x{e.height}" for e in elements]
        return "\n".join(lines) if lines else "(no text detected)"

    # ══════════════════════════════════════════════════
    #  METHOD 3: OpenCV Template Matching
    # ══════════════════════════════════════════════════

    def find_template(self, template_path, screenshot_path=None, threshold=0.8):
        """
        Find a template image on screen using OpenCV.
        Returns ScreenElement with coordinates or None.
        """
        if not HAS_OPENCV:
            return None
        if not screenshot_path:
            screenshot_path = self.capture_screen()
        if not screenshot_path:
            return None

        screen = cv2.imread(screenshot_path)
        template = cv2.imread(template_path)
        if screen is None or template is None:
            return None

        result = cv2.matchTemplate(screen, template, cv2.TM_CCOEFF_NORMED)
        _, max_val, _, max_loc = cv2.minMaxLoc(result)

        if max_val >= threshold:
            h, w = template.shape[:2]
            return ScreenElement(
                text=f"template_match:{Path(template_path).name}",
                x=max_loc[0],
                y=max_loc[1],
                width=w,
                height=h,
                source='opencv',
                element_type='icon',
                confidence=max_val,
            )
        return None

    # ══════════════════════════════════════════════════
    #  ACTIONS: Mouse & Keyboard (PyAutoGUI + xdotool)
    # ══════════════════════════════════════════════════

    def click(self, x, y, button='left'):
        """Click at screen coordinates. Uses PyAutoGUI or xdotool fallback."""
        if HAS_PYAUTOGUI:
            try:
                pyautogui.click(x, y, button=button)
                return True
            except:
                pass

        # Fallback to xdotool
        btn_map = {'left': '1', 'middle': '2', 'right': '3'}
        try:
            subprocess.run(
                ['xdotool', 'mousemove', str(x), str(y), 'click', btn_map.get(button, '1')],
                env={**os.environ, 'DISPLAY': self.display},
                capture_output=True, timeout=10,
            )
            return True
        except:
            return False

    def click_element(self, element):
        """Click the center of a ScreenElement."""
        if element:
            return self.click(element.center_x, element.center_y)
        return False

    def click_text(self, text_query):
        """Find text on screen and click it. Returns True/False."""
        # Try accessibility first (most reliable)
        el = self.find_in_accessibility(text_query)
        if el:
            return self.click_element(el)
        # Fall back to OCR
        el = self.ocr_find(text_query)
        if el:
            return self.click_element(el)
        return False

    def type_text(self, text):
        """Type text. Uses PyAutoGUI or xdotool fallback."""
        if HAS_PYAUTOGUI:
            try:
                pyautogui.typewrite(text, interval=0.01)
                return True
            except:
                pass
        try:
            subprocess.run(
                ['xdotool', 'type', text],
                env={**os.environ, 'DISPLAY': self.display},
                capture_output=True, timeout=10,
            )
            return True
        except:
            return False

    def press_key(self, key):
        """Press a key. Uses PyAutoGUI or xdotool fallback."""
        if HAS_PYAUTOGUI:
            try:
                pyautogui.press(key)
                return True
            except:
                pass
        try:
            subprocess.run(
                ['xdotool', 'key', key],
                env={**os.environ, 'DISPLAY': self.display},
                capture_output=True, timeout=10,
            )
            return True
        except:
            return False

    def get_active_window(self):
        """Get the active window title using xdotool or python-xlib."""
        if HAS_XLIB:
            try:
                disp = xdisplay.Display()
                window = disp.get_input_focus().focus
                name = window.get_wm_name() or ""
                geom = window.get_geometry()
                return {
                    "title": name,
                    "x": geom.x, "y": geom.y,
                    "width": geom.width, "height": geom.height,
                }
            except:
                pass
        try:
            result = subprocess.run(
                ['xdotool', 'getactivewindow', 'getwindowgeometry', '--shell'],
                env={**os.environ, 'DISPLAY': self.display},
                capture_output=True, text=True, timeout=10,
            )
            data = {}
            for line in result.stdout.strip().split('\n'):
                if '=' in line:
                    k, v = line.split('=', 1)
                    data[k.lower()] = v
            return {
                "title": data.get('window_name', ''),
                "x": int(data.get('x', 0)),
                "y": int(data.get('y', 0)),
                "width": int(data.get('width', 0)),
                "height": int(data.get('height', 0)),
            }
        except:
            return {"error": "Cannot get active window"}

    # ══════════════════════════════════════════════════
    #  INTELLIGENCE: Full screen read with all methods
    # ══════════════════════════════════════════════════

    def read_screen(self):
        """
        Read the full screen state using ALL available methods.
        Returns a dict with accessibility tree, OCR text, and active window.

        The intelligence pattern:
          1. Accessibility tree (structured, exact, no errors)
          2. OCR text with coordinates (for text that accessibility misses)
          3. Active window info
          4. Status of all backends
        """
        result = {
            "active_window": self.get_active_window(),
            "backends": {
                "atspi": HAS_ATSPI,
                "tesseract": HAS_TESSERACT,
                "mss": HAS_MSS,
                "opencv": HAS_OPENCV,
                "pyautogui": HAS_PYAUTOGUI,
                "xdotool": self._has_xdotool(),
            },
        }

        # Accessibility tree (best source)
        atspi_data = self.get_accessibility_tree()
        if isinstance(atspi_data, list):
            result["accessibility_tree"] = atspi_data
            result["accessibility_text"] = self.accessibility_to_text(atspi_data)
        else:
            result["accessibility_error"] = atspi_data.get("error", "")

        # OCR text (fallback)
        ocr_elements = self.ocr_screen()
        if isinstance(ocr_elements, list):
            result["ocr_elements"] = [
                {"text": e.text, "x": e.x, "y": e.y,
                 "w": e.width, "h": e.height,
                 "center_x": e.center_x, "center_y": e.center_y}
                for e in ocr_elements
            ]
            result["ocr_text"] = self.ocr_to_text(ocr_elements)
        else:
            result["ocr_error"] = ocr_elements.get("error", "")

        return result


# ══════════════════════════════════════════════════
#  CLI ENTRY POINT
# ══════════════════════════════════════════════════

def main():
    """CLI: linux_desktop.py read — read the screen
       linux_desktop.py click <x> <y> — click at coordinates
       linux_desktop.py find <text> — find and click text
       linux_desktop.py type <text> — type text
       linux_desktop.py key <key> — press a key
       linux_desktop.py window — show active window info
    """
    dt = LinuxDesktop()

    if len(sys.argv) < 2:
        result = dt.read_screen()
        print(json.dumps(result, indent=2))
        return

    cmd = sys.argv[1]

    if cmd == "read":
        result = dt.read_screen()
        print(json.dumps(result, indent=2))

    elif cmd == "click":
        if len(sys.argv) >= 4:
            x, y = int(sys.argv[2]), int(sys.argv[3])
            ok = dt.click(x, y)
            print(json.dumps({"success": ok, "x": x, "y": y}))
        else:
            print({"error": "Usage: linux_desktop.py click <x> <y>"})

    elif cmd == "find":
        if len(sys.argv) >= 3:
            query = " ".join(sys.argv[2:])
            el = dt.find_in_accessibility(query)
            if el:
                ok = dt.click_element(el)
                print(json.dumps({"success": ok, "method": "accessibility",
                                   "element": el.__dict__}))
            else:
                el = dt.ocr_find(query)
                if el:
                    ok = dt.click_element(el)
                    print(json.dumps({"success": ok, "method": "ocr",
                                       "element": el.__dict__}))
                else:
                    print(json.dumps({"success": False, "error": f"'{query}' not found"}))
        else:
            print({"error": "Usage: linux_desktop.py find <text>"})

    elif cmd == "type":
        if len(sys.argv) >= 3:
            text = " ".join(sys.argv[2:])
            ok = dt.type_text(text)
            print(json.dumps({"success": ok, "text": text}))
        else:
            print({"error": "Usage: linux_desktop.py type <text>"})

    elif cmd == "key":
        if len(sys.argv) >= 3:
            key = sys.argv[2]
            ok = dt.press_key(key)
            print(json.dumps({"success": ok, "key": key}))
        else:
            print({"error": "Usage: linux_desktop.py key <keyname>"})

    elif cmd == "window":
        win = dt.get_active_window()
        print(json.dumps(win, indent=2))

    elif cmd == "status":
        print(json.dumps({
            "atspi_available": HAS_ATSPI,
            "ocr_available": HAS_TESSERACT and HAS_MSS,
            "opencv_available": HAS_OPENCV,
            "pyautogui_available": HAS_PYAUTOGUI,
            "xdotool_available": dt._has_xdotool(),
            "display": dt.display,
        }, indent=2))

    else:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))


if __name__ == "__main__":
    main()
