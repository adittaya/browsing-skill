"""
ScraperAPI Playwright Navigation Engine.
Integrates ScraperAPI proxy port mode with Playwright/Chromium.
Follows patterns from: https://github.com/adittaya/scraperapi-playwright-guide

Features:
  - Multi-profile proxy (datacenter, premium, country-targeted)
  - VP Link / redirect chain resolver
  - Stealth ad blocking
  - Timer countdown handler for link locking pages
  - Screenshot capture

Usage:
  SCRAPERAPI_KEY=your_key python3 scraperapi_nav.py open <url> [profile] [--screenshot <path>]
  SCRAPERAPI_KEY=your_key python3 scraperapi_nav.py resolve <url> [--screenshot <path>]
  SCRAPERAPI_KEY=your_key python3 scraperapi_nav.py ip [profile]
  SCRAPERAPI_KEY=your_key python3 scraperapi_nav.py profiles
"""

import argparse
import asyncio
import json
import os
import re
import sys
from pathlib import Path

from playwright.async_api import async_playwright, TimeoutError as PwTimeout

API_KEY = os.environ.get("SCRAPERAPI_KEY", "")
PROXY_SERVER = os.environ.get("SCRAPERAPI_PROXY", "http://proxy-server.scraperapi.com:8001")
DATA_DIR = os.environ.get("DATA_DIR", "/tmp/desktop-skill")

PROFILES = {
    "datacenter": "scraperapi",
    "premium": "scraperapi.premium=true",
    "premium_us": "scraperapi.premium=true.country_code=us",
    "premium_india": "scraperapi.premium=true.country_code=in",
    "premium_uk": "scraperapi.premium=true.country_code=uk",
    "premium_ca": "scraperapi.premium=true.country_code=ca",
    "premium_de": "scraperapi.premium=true.country_code=de",
    "premium_fr": "scraperapi.premium=true.country_code=fr",
    "premium_jp": "scraperapi.premium=true.country_code=jp",
    "premium_au": "scraperapi.premium=true.country_code=au",
    "premium_br": "scraperapi.premium=true.country_code=br",
    "premium_render": "scraperapi.premium=true.render=true.country_code=us",
    "ultra_premium": "scraperapi.ultra_premium=true.country_code=us",
}

AD_DOMAINS = [
    "doubleclick.net", "googlesyndication", "googleadservices",
    "adsystem", "adservice", "googletagservices", "adserver",
    "adnxs", "casalemedia", "advertising", "analytics",
    "gtag", "facebook.com/tr", "google-analytics",
    "googletagmanager", "amazon-adsystem",
]


def check_key():
    if not API_KEY:
        print("Error: SCRAPERAPI_KEY env var not set", file=sys.stderr)
        sys.exit(1)


async def launch_browser(use_proxy: bool = True, profile: str = "datacenter"):
    p = await async_playwright().start()
    launch_opts = {
        "headless": True,
        "args": ["--no-sandbox", "--disable-gpu",
                 "--disable-dev-shm-usage",
                 "--disable-blink-features=AutomationControlled"],
    }
    if use_proxy:
        check_key()
        launch_opts["proxy"] = {"server": PROXY_SERVER}

    browser = await p.chromium.launch(**launch_opts)

    context_opts = {
        "user_agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/126.0.0.0 Safari/537.36"
        ),
    }
    if use_proxy:
        username = PROFILES.get(profile, PROFILES["datacenter"])
        context_opts["ignore_https_errors"] = True
        context_opts["http_credentials"] = {"username": username, "password": API_KEY}

    context = await browser.new_context(**context_opts)

    # Stealth: override navigator.webdriver
    await context.add_init_script("""
        Object.defineProperty(navigator, 'webdriver', {get: () => undefined});
        // Override chrome property
        window.chrome = {runtime: {}};
    """)

    page = await context.new_page()

    # Stealth ad blocking (abort without triggering detection)
    async def handle_route(route, req):
        await _handle_route_async(route, req)
    await page.route("**/*", handle_route)

    return p, browser, context, page


async def _handle_route_async(route, request):
    url = request.url
    if any(d in url for d in AD_DOMAINS):
        await route.abort()
        return
    if request.resource_type in ("image", "media", "font") and (
        "ad" in url.lower() or "banner" in url.lower()
    ):
        await route.abort()
        return
    await route.continue_()


async def navigate(
    url: str,
    profile: str = "datacenter",
    screenshot_path: str | None = None,
    use_proxy: bool = True,
    timeout: int = 60000,
) -> dict:
    p, browser, context, page = await launch_browser(use_proxy, profile)

    result = {
        "url": url,
        "profile": profile,
        "success": False,
        "final_url": "",
        "title": "",
        "error": "",
        "redirects": [],
    }
    if screenshot_path:
        result["screenshot"] = screenshot_path

    try:
        # Track redirects
        def on_navigation(frame):
            if frame == page.main_frame and frame.url != "about:blank":
                if not result["redirects"] or result["redirects"][-1] != frame.url:
                    result["redirects"].append(frame.url)

        page.on("framenavigated", on_navigation)

        await page.goto(url, wait_until="commit", timeout=timeout)
        await page.wait_for_timeout(2000)

        result["final_url"] = page.url
        result["title"] = await page.title()
        result["success"] = True

        if screenshot_path:
            await page.screenshot(path=screenshot_path, full_page=False)

    except Exception as e:
        result["error"] = str(e)
        if screenshot_path:
            try:
                await page.screenshot(path=screenshot_path, full_page=False)
            except Exception:
                pass
    finally:
        await browser.close()
        await p.stop()

    return result


async def resolve_chain(
    url: str,
    profile: str = "datacenter",
    screenshot_path: str | None = None,
    max_steps: int = 10,
    use_proxy: bool = False,
) -> dict:
    """
    Resolve a redirect/link-locking chain.
    Uses direct connection by default (proxy often blocked on these pages).
    Handles timer countdowns, ad overlays, and multi-step redirects.
    """
    p, browser, context, page = await launch_browser(use_proxy, profile)

    # Set cookie to bypass ad overlays
    await context.add_init_script('document.cookie = "adcadg=1; path=/;"')

    result = {
        "url": url,
        "profile": profile,
        "success": False,
        "final_url": "",
        "title": "",
        "error": "",
        "steps": [],
        "redirect_chain": [],
    }

    await page.goto(url, wait_until="domcontentloaded", timeout=60000)
    await page.wait_for_timeout(3000)
    result["redirect_chain"].append(page.url)

    visited = set()

    for step in range(max_steps):
        step_info = {"step": step + 1, "url": page.url}

        if page.url in visited:
            step_info["action"] = "already_visited"
            result["steps"].append(step_info)
            break
        visited.add(page.url)

        # Check if we've left the gate network (landed on final destination)
        # Destination detection: page is not a known gate domain, has meaningful content
        text_len = len((await page.evaluate('document.body.innerText')).strip())
        if text_len > 200 and step > 2:
            # Check for gate keywords
            text = (await page.evaluate('document.body.innerText')).lower()
            gate_kw = ['your link', 'get link', 'continue', 'seconds', 'almost ready', 'skip']
            has_gate = any(kw in text for kw in gate_kw)
            if not has_gate:
                result["success"] = True
                step_info["action"] = "target_reached"
                result["steps"].append(step_info)
                break

        # Wait for page to settle (timer countdowns, dynamic content)
        try:
            await page.wait_for_function("""
                () => {
                    var b = document.querySelector('#tp-snp2, #continuebtn, .button-61');
                    return b && b.offsetParent !== null && b.style.display !== 'none' && b.style.visibility !== 'hidden';
                }
            """, timeout=120000)
            step_info["continue_found"] = True
        except PwTimeout:
            step_info["continue_found"] = False

        # Try to find and click Continue button
        btn = await page.query_selector("#tp-snp2, #continuebtn, a.continue-btn, .button-61")

        if btn:
            # Remove overlays
            await page.evaluate("""
                document.querySelectorAll('#gcont, [id^="div-gpt-ad"], '
                    + '.code-block, .ad-overlay, #adOverlay, '
                    + '[class*="advertisement"], [class*="ad-container"]'
                ).forEach(el => el.remove());
            """)
            await page.wait_for_timeout(500)

            step_info["action"] = "click_continue"
            try:
                await btn.click(force=True, timeout=5000)
            except Exception:
                # Fallback: JS dispatch
                await page.evaluate("""
                    function isVisible(el) {
                        return el && el.offsetParent !== null && el.style.display !== 'none';
                    }
                    var b = document.querySelector('#tp-snp2, #continuebtn, .button-61');
                    if (isVisible(b)) b.dispatchEvent(new MouseEvent('click', {bubbles: true}));
                """)

            await page.wait_for_timeout(5000)

            new_url = page.url
            step_info["new_url"] = new_url
            if new_url not in result["redirect_chain"]:
                result["redirect_chain"].append(new_url)

            # If URL didn't change, try other triggers
            if new_url == step_info["url"]:
                # Try clicking "Verify" or "tp-generate" buttons
                for sel in [
                    "button:has-text('Verify'):visible",
                    "#tp-generate:visible",
                    "#tp-verify:visible",
                    "[id*='verify']:visible",
                ]:
                    alt_btn = await page.query_selector(sel)
                    if alt_btn:
                        step_info["action"] = f"click_alt_{sel[:30]}"
                        try:
                            await alt_btn.click(force=True, timeout=5000)
                        except Exception:
                            await page.evaluate(
                                f"document.querySelector('{sel.replace(chr(39), chr(34))}')"
                                "?.click()"
                            )
                        await page.wait_for_timeout(5000)
                        new_url = page.url
                        if new_url not in result["redirect_chain"]:
                            result["redirect_chain"].append(new_url)
                        break
        else:
            step_info["action"] = "no_button_found"

        result["steps"].append(step_info)

    result["final_url"] = page.url
    result["title"] = await page.title()
    # Destination: page has content but no gate keywords
    try:
        final_text = (await page.evaluate('document.body.innerText')).lower()
        result["success"] = len(final_text.strip()) > 200 and not any(
            kw in final_text for kw in
            ['your link', 'get link', 'continue reading', 'seconds', 'almost ready']
        )
    except:
        result["success"] = False

    if screenshot_path:
        try:
            await page.screenshot(path=screenshot_path, full_page=False)
            result["screenshot"] = screenshot_path
        except Exception:
            pass

    await browser.close()
    await p.stop()
    return result


async def get_ip(profile: str = "datacenter") -> dict:
    check_key()
    username = PROFILES.get(profile, PROFILES["datacenter"])

    async with async_playwright() as p:
        browser = await p.chromium.launch(
            headless=True,
            proxy={"server": PROXY_SERVER},
            args=["--no-sandbox", "--disable-gpu"],
        )
        context = await browser.new_context(
            ignore_https_errors=True,
            http_credentials={"username": username, "password": API_KEY},
        )
        page = await context.new_page()

        try:
            await page.goto(
                "https://httpbin.org/ip", wait_until="commit", timeout=30000
            )
            body = await page.text_content("body")
            if body:
                return {"ip": body.strip(), "profile": profile}
            return {"ip": "unknown", "profile": profile}
        except Exception as e:
            return {"ip": "unknown", "profile": profile, "error": str(e)}
        finally:
            await browser.close()


def main():
    parser = argparse.ArgumentParser(description="ScraperAPI Playwright Navigation")
    sub = parser.add_subparsers(dest="command")

    # open
    op = sub.add_parser("open", help="Navigate to URL through ScraperAPI proxy")
    op.add_argument("url", help="Target URL")
    op.add_argument("profile", nargs="?", default="datacenter",
                    help=f"Proxy profile (default: datacenter)")
    op.add_argument("--screenshot", "-s", help="Save screenshot to path")
    op.add_argument("--timeout", "-t", type=int, default=60000)

    # resolve (VP Link)
    rp = sub.add_parser("resolve", help="Resolve VP Link / link-locking redirect chain")
    rp.add_argument("url", help="VP Link URL")
    rp.add_argument("--profile", default="datacenter", help="Proxy profile")
    rp.add_argument("--screenshot", "-s", help="Save screenshot to path")
    rp.add_argument("--proxy", action="store_true", help="Use ScraperAPI proxy for resolution")

    # ip
    ip_p = sub.add_parser("ip", help="Check IP through proxy profile")
    ip_p.add_argument("profile", nargs="?", default="datacenter")

    # profiles
    sub.add_parser("profiles", help="List proxy profiles")

    args = parser.parse_args()

    if args.command == "profiles":
        print("Available ScraperAPI Proxy Profiles:")
        print(f"  {'Profile':<20} {'Username':<55}")
        print(f"  {'-'*20} {'-'*55}")
        for name, username in PROFILES.items():
            print(f"  {name:<20} {username:<55}")
        print()
        print("Usage: SCRAPERAPI_KEY=your_key python3 scraperapi_nav.py open <url> <profile>")
        return

    if args.command == "ip":
        result = asyncio.run(get_ip(args.profile))
        print(json.dumps(result, indent=2))
        return

    if args.command == "open":
        result = asyncio.run(navigate(
            args.url, args.profile, args.screenshot, timeout=args.timeout
        ))
        print(json.dumps(result, indent=2))
        return

    if args.command == "resolve":
        result = asyncio.run(resolve_chain(
            args.url, args.profile, args.screenshot, use_proxy=args.proxy
        ))
        print(json.dumps(result, indent=2))
        return

    parser.print_help()


if __name__ == "__main__":
    main()
