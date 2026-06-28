"""
Enterprise grade screen analyzer for browser automation.
Captures screenshots, detects UI elements, modals, buttons, text regions.
"""

import os
import sys
import json
import subprocess
from collections import defaultdict
from dataclasses import dataclass, field, asdict
from typing import Optional

try:
    from PIL import Image
except ImportError:
    Image = None


@dataclass
class Region:
    x: int
    y: int
    width: int
    height: int
    center_x: int = 0
    center_y: int = 0
    pixel_count: int = 0
    color: tuple = (0, 0, 0)
    label: str = ""

    def __post_init__(self):
        self.center_x = self.x + self.width // 2
        self.center_y = self.y + self.height // 2

    def to_dict(self):
        return {
            "x": self.x, "y": self.y,
            "width": self.width, "height": self.height,
            "center_x": self.center_x, "center_y": self.center_y,
            "pixel_count": self.pixel_count,
            "label": self.label,
        }


@dataclass
class ScreenAnalysis:
    width: int = 0
    height: int = 0
    modals: list = field(default_factory=list)
    buttons: list = field(default_factory=list)
    links: list = field(default_factory=list)
    text_regions: list = field(default_factory=list)
    top_bar: Optional[Region] = None
    bottom_bar: Optional[Region] = None
    content_area: Optional[Region] = None
    sidebar: Optional[Region] = None
    dominant_colors: dict = field(default_factory=dict)
    summary: str = ""


class ScreenAnalyzer:
    """
    Analyzes screenshots to find UI elements for browser automation.

    Color profiles for detection:
      - MODAL (purple gradient): R 80-130, G 0-80, B 120-255
      - BUTTON (warm gradient): R > 200, G 80-200, B < 140
      - LINK (blue text): R 0-80, G 80-180, B 150-255
      - DARK (footer/header): R < 30, G < 30, B < 30
    """

    COLOR_MODAL_PURPLE = lambda self, r, g, b: 80 <= r <= 130 and g < 80 and b > 120
    COLOR_BUTTON_WARM = lambda self, r, g, b: r > 200 and 80 <= g <= 200 and b < 140
    COLOR_LINK_BLUE = lambda self, r, g, b: r < 80 and 80 <= g <= 180 and b > 120
    COLOR_TEXT_DARK = lambda self, r, g, b: r < 40 and g < 40 and b < 40
    COLOR_WHITE = lambda self, r, g, b: r > 240 and g > 240 and b > 240

    def __init__(self, image_path=None, image=None):
        self.image_path = image_path
        if image:
            self.img = image
        elif image_path:
            self.img = Image.open(image_path)
        else:
            self.img = None
        self.w = self.img.width if self.img else 0
        self.h = self.img.height if self.img else 0
        # Initialize all attributes to prevent AttributeError
        self.modals = []
        self.buttons = []
        self.links = []
        self.text_regions = []
        self.top_bar = None
        self.bottom_bar = None
        self.content_area = None
        self.sidebar = None
        self.dominant_colors = {}

    @classmethod
    def capture(cls, display=":99", output_path="/tmp/screen.png"):
        """Capture screenshot from the X display using ImageMagick import."""
        subprocess.run(
            ["import", "-window", "root", output_path],
            env={**os.environ, "DISPLAY": display},
            capture_output=True, timeout=15,
        )
        return cls(output_path)

    def pixel_at(self, x, y):
        """Get RGB tuple at pixel coordinates."""
        return self.img.getpixel((x, y))[:3]

    def scan_color(self, color_check, step=2, min_count=5):
        """
        Find all pixels matching a color check function.
        Returns list of (x, y, r, g, b) tuples.
        """
        pixels = []
        for y in range(0, self.h, step):
            for x in range(0, self.w, step):
                r, g, b = self.pixel_at(x, y)
                if color_check(r, g, b):
                    pixels.append((x, y, r, g, b))
        return pixels

    def find_regions(self, color_check, min_width=30, min_height=10, step=2):
        """
        Find contiguous regions of matching color.
        Returns list of Region objects.
        """
        pixels = self.scan_color(color_check, step=step)
        if not pixels:
            return []

        # Group into horizontal bands
        bands = defaultdict(list)
        for x, y, r, g, b in pixels:
            bands[y].append((x, r, g, b))

        # Merge consecutive rows into regions
        regions = []
        current_region = None

        for y in sorted(bands.keys()):
            xs = [p[0] for p in bands[y]]
            min_x, max_x = min(xs), max(xs)
            width = max_x - min_x

            if width < min_width:
                continue

            if current_region is None:
                current_region = {
                    "y_start": y, "y_end": y,
                    "x_min": min_x, "x_max": max_x,
                    "rows": 1,
                }
            elif y - current_region["y_end"] <= 3:
                current_region["y_end"] = y
                current_region["x_min"] = min(current_region["x_min"], min_x)
                current_region["x_max"] = max(current_region["x_max"], max_x)
                current_region["rows"] += 1
            else:
                if current_region["y_end"] - current_region["y_start"] >= min_height:
                    regions.append(current_region)
                current_region = {
                    "y_start": y, "y_end": y,
                    "x_min": min_x, "x_max": max_x,
                    "rows": 1,
                }

        if current_region and current_region["y_end"] - current_region["y_start"] >= min_height:
            regions.append(current_region)

        # Convert to Region objects
        result = []
        for r in regions:
            result.append(Region(
                x=r["x_min"],
                y=r["y_start"],
                width=r["x_max"] - r["x_min"],
                height=r["y_end"] - r["y_start"],
                pixel_count=r["rows"],
            ))
        return result

    def find_modal(self):
        """Detect overlay modal/popup by finding purple gradient regions."""
        regions = self.find_regions(self.COLOR_MODAL_PURPLE, min_width=100, min_height=30)
        for r in regions:
            r.label = "modal"
        self.modals = regions

        # Check for a large centered purple region (the actual modal overlay)
        for r in regions:
            if r.width > 200 and r.height > 100:
                r.label = "overlay_modal"
        return regions

    def find_buttons(self):
        """Detect buttons by finding warm gradient (orange) regions."""
        regions = self.find_regions(self.COLOR_BUTTON_WARM, min_width=40, min_height=15)
        for r in regions:
            r.label = "button"
        self.buttons = regions
        return regions

    def find_links(self):
        """Detect links by finding blue text regions."""
        regions = self.find_regions(self.COLOR_LINK_BLUE, min_width=20, min_height=8)
        for r in regions:
            r.label = "link"
        self.links = regions
        return regions

    def detect_layout(self):
        """Detect overall page layout (header, content, sidebar, footer)."""
        # Analyze horizontal strips
        dark_strips = []
        white_strips = []

        for y in range(0, self.h, 10):
            dark_count = 0
            white_count = 0
            for x in range(0, self.w, 10):
                r, g, b = self.pixel_at(x, y)
                if self.COLOR_TEXT_DARK(r, g, b):
                    dark_count += 1
                elif self.COLOR_WHITE(r, g, b):
                    white_count += 1

            if dark_count > 20:
                dark_strips.append(y)
            if white_count > 50:
                white_strips.append(y)

        # Top bar: first dark strip at top (0-50px)
        top_bar_strips = [y for y in dark_strips if y < 50]
        if top_bar_strips:
            self.top_bar = Region(x=0, y=min(top_bar_strips), width=self.w,
                                  height=max(top_bar_strips) - min(top_bar_strips) + 10,
                                  label="top_bar")

        # Bottom bar: dark strip at bottom
        bottom_bar_strips = [y for y in dark_strips if y > self.h - 60]
        if bottom_bar_strips:
            self.bottom_bar = Region(x=0, y=min(bottom_bar_strips), width=self.w,
                                     height=max(bottom_bar_strips) - min(bottom_bar_strips) + 10,
                                     label="bottom_bar")

        # Content area: white area in middle
        if white_strips:
            self.content_area = Region(x=0, y=min(white_strips), width=self.w,
                                       height=max(white_strips) - min(white_strips),
                                       label="content_area")

        return {
            "top_bar": self.top_bar.to_dict() if self.top_bar else None,
            "bottom_bar": self.bottom_bar.to_dict() if self.bottom_bar else None,
            "content_area": self.content_area.to_dict() if self.content_area else None,
        }

    def get_dominant_colors(self):
        """Sample colors across the image to get a color palette."""
        colors = defaultdict(int)
        for y in range(0, self.h, 20):
            for x in range(0, self.w, 20):
                r, g, b = self.pixel_at(x, y)
                key = (r // 32 * 32, g // 32 * 32, b // 32 * 32)
                colors[key] += 1

        total = sum(colors.values())
        dominant = {}
        for (r, g, b), count in sorted(colors.items(), key=lambda x: -x[1])[:10]:
            pct = count / total * 100
            if pct > 1:
                name = self._describe_color(r, g, b)
                dominant[name] = round(pct, 1)

        self.dominant_colors = dominant
        return dominant

    def _describe_color(self, r, g, b):
        if r > 200 and g > 200 and b > 200:
            return "white"
        if r < 30 and g < 30 and b < 30:
            return "black/dark"
        if r > 200 and g < 100 and b < 100:
            return "red"
        if r > 200 and g > 100 and b < 100:
            return "orange"
        if r > 200 and g > 200 and b < 100:
            return "yellow"
        if r < 100 and g > 150 and b < 100:
            return "green"
        if r < 100 and g < 100 and b > 150:
            return "blue"
        if r > 150 and g < 100 and b > 150:
            return "purple"
        if r > 100 and g > 100 and b > 100:
            return "gray"
        return f"rgb({r},{g},{b})"

    def summarize(self):
        """Generate a human-readable summary of the screen."""
        parts = []

        if self.modals:
            m = max(self.modals, key=lambda r: r.width * r.height)
            parts.append(f"MODAL DETECTED at ({m.center_x}, {m.center_y}) "
                         f"size {m.width}x{m.height}")

        if self.buttons:
            b = max(self.buttons, key=lambda r: r.width * r.height)
            parts.append(f"BUTTON at ({b.center_x}, {b.center_y}) "
                         f"size {b.width}x{b.height}")

        if self.links:
            parts.append(f"{len(self.links)} link(s) detected")

        layout = self.detect_layout()
        if layout.get("top_bar"):
            parts.append("Top bar detected")
        if layout.get("content_area"):
            parts.append(f"Content area: y={layout['content_area']['y']}-"
                         f"{layout['content_area']['y']+layout['content_area']['height']}")
        if layout.get("bottom_bar"):
            parts.append("Bottom bar detected")

        colors = self.get_dominant_colors()
        if colors:
            parts.append(f"Colors: {', '.join(f'{k}={v}%' for k,v in colors.items())}")

        summary = " | ".join(parts) if parts else "Empty or blank page"
        self.summary = summary
        return summary

    def analyze(self):
        """Run full analysis pipeline."""
        self.find_modal()
        self.find_buttons()
        self.find_links()
        self.detect_layout()
        self.get_dominant_colors()
        self.summarize()
        return self

    def to_dict(self):
        return {
            "screen_size": {"width": self.w, "height": self.h},
            "modals": [r.to_dict() for r in self.modals],
            "buttons": [r.to_dict() for r in self.buttons],
            "links": [r.to_dict() for r in self.links],
            "layout": {
                "top_bar": self.top_bar.to_dict() if self.top_bar else None,
                "bottom_bar": self.bottom_bar.to_dict() if self.bottom_bar else None,
                "content_area": self.content_area.to_dict() if self.content_area else None,
            },
            "dominant_colors": self.dominant_colors,
            "summary": self.summary,
        }


def main():
    """CLI entry point."""
    if len(sys.argv) < 2:
        print("Usage: screen_analyzer.py <image.png> [--json]")
        print("       screen_analyzer.py --capture [--json]")
        sys.exit(1)

    output_json = "--json" in sys.argv

    if sys.argv[1] == "--capture":
        analyzer = ScreenAnalyzer.capture()
    else:
        analyzer = ScreenAnalyzer(image_path=sys.argv[1])

    analyzer.analyze()

    if output_json:
        print(json.dumps(analyzer.to_dict(), indent=2))
    else:
        print(analyzer.summarize())


if __name__ == "__main__":
    main()
