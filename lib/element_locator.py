"""
Element locator - finds specific UI elements on screen for clicking.
Uses screen_analyzer to detect regions, then refines targeting.
"""

import sys
import json
import subprocess
import os
import re

try:
    from PIL import Image
except ImportError:
    Image = None

from screen_analyzer import ScreenAnalyzer, Region


class ElementLocator:
    """
    Locates specific UI elements on screen for interaction.
    Supports finding by text (OCR), color, and position.
    """

    def __init__(self, display=":99"):
        self.display = display
        self.analyzer = None
        self.last_capture = None

    def capture(self):
        """Capture current screen and run analysis."""
        self.analyzer = ScreenAnalyzer.capture(display=self.display)
        self.analyzer.analyze()
        self.last_capture = self.analyzer.img
        return self.analyzer

    def find_continue_button(self):
        """
        Find a 'Continue' or 'CONTINUE' button on screen.
        Looks for warm gradient (orange/pink) button regions.
        """
        self.capture()
        buttons = self.analyzer.buttons

        if not buttons:
            # Fallback: look for any warm-colored region in the modal or center area
            warm_pixels = self.analyzer.scan_color(
                self.analyzer.COLOR_BUTTON_WARM, step=2
            )
            if warm_pixels:
                # Group into clusters
                from collections import defaultdict
                clusters = defaultdict(list)
                for x, y, r, g, b in warm_pixels:
                    clusters[(x // 30, y // 30)].append((x, y))
                
                best = None
                best_count = 0
                for key, pixels in clusters.items():
                    if len(pixels) > best_count:
                        best_count = len(pixels)
                        best = (key, pixels)
                
                if best and best_count > 15:
                    xs = [p[0] for p in best[1]]
                    ys = [p[1] for p in best[1]]
                    buttons = [Region(
                        x=min(xs), y=min(ys),
                        width=max(xs)-min(xs),
                        height=max(ys)-min(ys),
                        pixel_count=best_count,
                        label="continue_button",
                    )]

        if buttons:
            # Return the largest button by area
            return max(buttons, key=lambda r: r.width * r.height)

        return None

    def find_modal_dismiss_button(self):
        """
        Find and return the button to dismiss a modal/popup.
        Looks for 'Continue', 'OK', 'Close', 'X' buttons.
        """
        self.capture()

        # First check for orange warm buttons (Continue, Next, etc.)
        button = self.find_continue_button()
        if button:
            return button

        # Check for small close buttons (X) in top-right of modals
        if self.analyzer.modals:
            modal = max(self.analyzer.modals, key=lambda r: r.width * r.height)
            # Look for red/dark buttons in the top-right quadrant of modal
            red_pixels = []
            for y in range(modal.y, modal.y + 60):
                for x in range(modal.x + modal.width - 80, modal.x + modal.width):
                    if x < self.analyzer.w and y < self.analyzer.h:
                        r, g, b = self.analyzer.pixel_at(x, y)
                        if r > 150 and g < 100 and b < 100:
                            red_pixels.append((x, y))
            if red_pixels:
                xs = [p[0] for p in red_pixels]
                ys = [p[1] for p in red_pixels]
                return Region(
                    x=min(xs), y=min(ys),
                    width=max(xs)-min(xs),
                    height=max(ys)-min(ys),
                    pixel_count=len(red_pixels),
                    label="close_button",
                )

        return None

    def find_by_text_approximate(self, text_hint):
        """
        Find a button/element by approximate text hint.
        Uses color analysis since OCR may not be available.
        Common patterns:
          - "continue" -> warm orange/pink gradient button
          - "submit" -> blue or green button
          - "close", "x" -> small button in corner
        """
        text_lower = text_hint.lower()
        self.capture()

        if "continue" in text_lower or "next" in text_lower or "proceed" in text_lower:
            return self.find_continue_button()
        elif "close" in text_lower or "dismiss" in text_lower:
            return self.find_modal_dismiss_button()
        elif "submit" in text_lower or "send" in text_lower or "ok" in text_lower:
            # Look for blue or green buttons
            regions = self.analyzer.find_regions(
                lambda r, g, b: (r < 100 and g > 100 and b > 150) or
                                (r < 100 and g > 150 and b < 100),
                min_width=40, min_height=15
            )
            return max(regions, key=lambda r: r.width * r.height) if regions else None
        elif "scroll" in text_lower or "down" in text_lower:
            # Find the bottom bar
            self.analyzer.detect_layout()
            return self.analyzer.bottom_bar
        elif "link" in text_lower or "url" in text_lower:
            regions = self.analyzer.find_links()
            if regions:
                return max(regions, key=lambda r: r.width * r.height)

        # Generic: return largest warm button
        return self.find_continue_button()

    def click_element(self, element, button=1):
        """Click on a detected element using xdotool."""
        if not element:
            return {"success": False, "error": "No element to click"}

        x, y = element.center_x, element.center_y

        # Add slight randomness to simulate human click
        import random
        x += random.randint(-3, 3)
        y += random.randint(-3, 3)

        result = subprocess.run(
            ["xdotool", "mousemove", str(x), str(y), "click", str(button)],
            env={**os.environ, "DISPLAY": self.display},
            capture_output=True, text=True, timeout=10,
        )

        return {
            "success": result.returncode == 0,
            "x": x,
            "y": y,
            "element": element.to_dict() if element else None,
        }

    def locate_and_click(self, text_hint=None, coordinates=None):
        """
        High-level locate and click.
        If coordinates given, click there directly.
        If text_hint given, find element by hint and click.
        """
        if coordinates:
            x, y = coordinates
            result = subprocess.run(
                ["xdotool", "mousemove", str(x), str(y), "click", "1"],
                env={**os.environ, "DISPLAY": self.display},
                capture_output=True, timeout=10,
            )
            return {
                "success": result.returncode == 0,
                "x": x, "y": y,
                "method": "direct",
            }

        if text_hint:
            element = self.find_by_text_approximate(text_hint)
            if element:
                click_result = self.click_element(element)
                click_result["method"] = f"element:{text_hint}"
                return click_result

        # Fallback: find any interactive element
        self.capture()
        if self.analyzer.buttons:
            return self.click_element(max(self.analyzer.buttons, key=lambda r: r.width * r.height))
        if self.analyzer.links:
            return self.click_element(max(self.analyzer.links, key=lambda r: r.width * r.height))

        return {"success": False, "error": "No clickable elements found"}


def main():
    """CLI entry point."""
    import argparse
    parser = argparse.ArgumentParser(description="Locate and click UI elements")
    parser.add_argument("--find", help="Element hint to find (continue, close, etc)")
    parser.add_argument("--click", nargs=2, type=int, metavar=("X", "Y"),
                        help="Click at coordinates")
    parser.add_argument("--analyze", action="store_true",
                        help="Just analyze screen without clicking")
    parser.add_argument("--json", action="store_true", help="JSON output")

    args = parser.parse_args()

    locator = ElementLocator()

    if args.analyze:
        analyzer = locator.capture()
        if args.json:
            print(json.dumps(analyzer.to_dict(), indent=2))
        else:
            print(analyzer.summarize())
        return

    if args.click:
        result = locator.locate_and_click(coordinates=tuple(args.click))
    elif args.find:
        result = locator.locate_and_click(text_hint=args.find)
    else:
        # Default: find and click continue button
        btn = locator.find_continue_button()
        if btn:
            result = locator.click_element(btn)
            result["method"] = "auto:continue"
        else:
            result = {"success": False, "error": "No button found"}

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        if result.get("success"):
            print(f"Clicked at ({result['x']}, {result['y']}) via {result.get('method', 'unknown')}")
        else:
            print(f"Failed: {result.get('error', 'unknown error')}")


if __name__ == "__main__":
    main()
