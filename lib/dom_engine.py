"""
DOM Engine — Playwright headless browser automation.
Parallel engine to the visual desktop (Xvfb + surf).
Finds elements by DOM introspection, not screen pixels.
"""
import asyncio, sys, os, json, random, re
from datetime import datetime
from pathlib import Path

try:
    from playwright.async_api import async_playwright, TimeoutError as PwTimeout
    HAS_PLAYWRIGHT = True
except ImportError:
    HAS_PLAYWRIGHT = False


class DOMEngine:
    """
    Headless browser engine using Playwright Chromium.
    Provides DOM-level element detection, clicking, and observation.
    """

    # Common button/action selectors ordered by priority
    BUTTON_SELECTORS = [
        ("#continueBtn",            "popup continue"),
        ("#tp-snp2",                "bottom continue (tp-snp2)"),
        ("#btn7",                   "bottom continue (btn7)"),
        ("#cross-snp2",             "bottom continue (cross-snp2)"),
        ("#get-link",               "get link (id)"),
        ("#gt-link",                "get link (gt)"),
        ("a:has-text('Get Link')",  "get link (a)"),
        ("button:has-text('Get Link')", "get link (button)"),
        ("a:has-text('GET LINK')",  "get link caps (a)"),
        ("button:has-text('GET LINK')", "get link caps (button)"),
        ("a:has-text('CONTINUE')",  "continue (a)"),
        ("button:has-text('CONTINUE')", "continue (button)"),
        ("a:has-text('Continue')",  "continue title (a)"),
        ("button:has-text('Continue')", "continue title (button)"),
        ("a:has-text('Proceed')",   "proceed (a)"),
        ("button:has-text('Proceed')", "proceed (button)"),
        ("a:has-text('Skip')",      "skip ad (a)"),
        ("button:has-text('Skip')", "skip ad (button)"),
        ("#skip-btn",               "skip btn id"),
        (".skip-button",            "skip button class"),
        (".get-link",               "get link class"),
        ("[onclick*='getlink']",    "onclick getlink"),
        ("[onclick*='redirect']",   "onclick redirect"),
    ]

    def __init__(self, headless=True, viewport=(1280, 720)):
        self.headless = headless
        self.viewport = viewport
        self.playwright = None
        self.browser = None
        self.context = None
        self.page = None
        self._destination_url = None
        self._pages_traversed = []

    async def start(self, stealth=True):
        """Launch Playwright and open a browser context."""
        if not HAS_PLAYWRIGHT:
            raise RuntimeError("Playwright not installed. Run: pip install playwright && playwright install chromium")

        self.playwright = await async_playwright().__aenter__()
        self.browser = await self.playwright.chromium.launch(
            headless=self.headless,
            args=[
                '--no-sandbox',
                '--disable-gpu',
                '--disable-dev-shm-usage',
                '--disable-setuid-sandbox',
            ]
        )

        self.context = await self.browser.new_context(
            viewport={'width': self.viewport[0], 'height': self.viewport[1]},
            user_agent='Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 '
                       '(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
        )

        if stealth:
            await self.context.add_init_script('''
                Object.defineProperty(navigator, 'webdriver', { get: () => false });
                Object.defineProperty(navigator, 'plugins', {
                    get: () => [1, 2, 3, 4, 5]
                });
                window.chrome = { runtime: {} };
            ''')

        self.page = await self.context.new_page()
        self._destination_url = None
        self._pages_traversed = []

        # Register new-tab capture
        async def on_page(new_page):
            await new_page.wait_for_load_state()
            self._destination_url = new_page.url
        self.context.on('page', on_page)

        return self.page

    async def navigate(self, url, timeout=30000):
        """Navigate to URL and return the final URL after redirects."""
        try:
            await self.page.goto(url, wait_until='domcontentloaded', timeout=timeout)
        except Exception as e:
            pass  # Partial load is often fine for gate pages
        await asyncio.sleep(3)
        self._pages_traversed.append(self.page.url)
        return self.page.url

    async def scan_dom(self):
        """
        Dump all visible interactive elements with their properties.
        Returns list of dicts: {tag, id, class, text, href, y, w, visible}
        """
        return await self.page.evaluate('''() => {
            return Array.from(document.querySelectorAll(
                'a, button, [role=button], input[type=submit]'
            )).filter(el => el.offsetParent !== null).map(el => ({
                tag: el.tagName,
                id: el.id,
                cls: el.className.substring(0, 60),
                text: el.textContent.trim().substring(0, 100),
                href: el.href || '',
                y: Math.round(el.getBoundingClientRect().y),
                w: Math.round(el.getBoundingClientRect().width),
                h: Math.round(el.getBoundingClientRect().height),
            }));
        }''')

    async def get_text(self):
        """Get all visible text from the page."""
        return await self.page.evaluate('document.body.innerText')

    async def get_text_length(self):
        text = await self.get_text()
        return len(text.strip())

    async def scroll_to(self, position: str):
        """Scroll to top, bottom, or by pixels."""
        if position == 'bottom':
            await self.page.evaluate('window.scrollTo(0, document.body.scrollHeight)')
        elif position == 'top':
            await self.page.evaluate('window.scrollTo(0, 0)')
        else:
            try:
                pixels = int(position)
                await self.page.evaluate(f'window.scrollBy(0, {pixels})')
            except ValueError:
                pass
        await asyncio.sleep(0.5)

    async def find_and_click(self, selectors=None, max_steps=60):
        """
        Scroll incrementally and try each selector.
        Auto-resets to top and retries once if first pass fails.
        Returns dict with success, element_name, y_position.
        """
        selectors = selectors or self.BUTTON_SELECTORS

        for attempt in range(2):
            for step in range(max_steps):
                try:
                    await self.page.evaluate(f'window.scrollBy(0, 400)')
                except:
                    pass
                await asyncio.sleep(0.25)
                for sel, name in selectors:
                    try:
                        el = await self.page.query_selector(sel)
                        if not el:
                            continue
                        r = await el.bounding_box()
                        if r and r['width'] > 0 and r['y'] > 50:
                            await el.click(force=True, timeout=5000)
                            await asyncio.sleep(6)
                            return {
                                'success': True,
                                'element': name,
                                'y': round(r['y']),
                                'step': step,
                                'attempt': attempt,
                            }
                    except:
                        continue
                at_bottom = await self.page.evaluate(
                    'window.innerHeight + window.scrollY >= document.body.scrollHeight - 50'
                ) if step < 59 else False
                if at_bottom:
                    break
            if attempt == 0:
                try:
                    await self.page.evaluate('window.scrollTo(0, 0)')
                except:
                    pass
                await asyncio.sleep(3)

        return {'success': False}

    async def js_click_text(self, pattern=r'CONTINUE|Get.?Link|continue|Proceed'):
        """
        Click any visible element whose text matches pattern.
        Returns dict with success and text clicked.
        """
        text = await self.page.evaluate(f'''() => {{
            const re = new RegExp({json.dumps(pattern)}, 'i');
            const els = document.querySelectorAll('a, button, span, div');
            for (const el of els) {{
                if (re.test(el.textContent.trim()) && el.offsetParent !== null) {{
                    el.click();
                    return el.textContent.trim().substring(0, 80);
                }}
            }}
            return null;
        }}''')
        if text:
            await asyncio.sleep(5)
            return {'success': True, 'text': text}
        return {'success': False}

    async def poll_for_element(self, selectors, timeout=60, interval=1):
        """
        Poll page until an element matching any selector appears.
        Returns dict with selector, name, y_position, and time.
        """
        for sec in range(timeout):
            for sel, name in selectors:
                try:
                    el = await self.page.query_selector(sel)
                    if el:
                        r = await el.bounding_box()
                        if r and r['width'] > 0:
                            return {
                                'success': True,
                                'selector': sel,
                                'name': name,
                                'y': round(r['y']),
                                'time_sec': sec,
                            }
                except:
                    continue
            await asyncio.sleep(interval)
        return {'success': False}

    async def get_page_type(self):
        """
        Auto-detect page type based on content characteristics.
        Returns one of: redirect, gate, gate_action, content, content_action, destination
        """
        text_len = await self.get_text_length()
        url = self.page.url.lower()
        elements = await self.scan_dom()

        has_popup = False
        try:
            btn = await self.page.query_selector('#continueBtn')
            if btn:
                r = await btn.bounding_box()
                if r and r['width'] > 0:
                    has_popup = True
        except:
            pass

        if text_len < 100:
            return 'redirect'
        if text_len < 800 and not elements:
            return 'gate'
        if text_len < 800 and elements:
            return 'gate_action'
        if text_len >= 800 and elements:
            return 'content_action'
        return 'content'

    async def screenshot(self, path='screenshot.png', full_page=False):
        """Take a screenshot."""
        await self.page.screenshot(path=path, full_page=full_page)

    async def trace_chain(self, url, max_pages=60):
        """
        Full redirect chain tracer.
        Follows the observation methodology:
          1. Navigate and observe
          2. Scan DOM for interactive elements
          3. Poll for timer-revealed elements
          4. Click popups if present
          5. Scroll for bottom buttons
          6. Handle gate pages (Get Link, new tabs)
          7. Detect when we reach a destination
        Returns dict with destination_url, pages_traversed, log.
        """
        log = []
        def _log(msg):
            ts = datetime.now().strftime('%H:%M:%S')
            line = f'[{ts}] {msg}'
            print(line)
            log.append(line)

        _log(f'Starting chain trace: {url}')
        dest_url = None
        gate_domains = set()

        await self.navigate(url)

        for pg in range(1, max_pages + 1):
            await asyncio.sleep(3)
            url_lower = self.page.url.lower()
            text_len = await self.get_text_length()
            text = await self.get_text()
            elements = await self.scan_dom()

            from urllib.parse import urlparse
            host = urlparse(self.page.url).hostname or ''

            _log(f'--- PAGE {pg}: {self.page.url} ({text_len} chars, {len(elements)} elements)')

            # Snapshot first line of text
            first_line = text.strip().split('\n')[0][:80] if text.strip() else '(empty)'
            _log(f'  First: {first_line}')

            # Show interactive elements
            for el in elements[:6]:
                _log(f'  [{el["tag"]}#{el["id"]}] "{el["text"][:50]}" @y={el["y"]}')

            # Auto-learn gate domains
            if 50 < text_len < 800 and any(kw in text.lower()
                for kw in ['your link', 'get link', 'continue', 'seconds', 'almost ready']):
                gate_domains.add(host)
                _log(f'  [learn] gate domain: {host}')

            # Destination detection
            if text_len < 50 and pg > 1:
                _log('  Very short page — likely destination')
                dest_url = self.page.url
                break

            if pg > 1 and text_len > 200 and host not in gate_domains:
                text_lower = text.lower()
                has_gate = any(kw in text_lower for kw in
                    ['get link', 'continue', 'your link', 'seconds', 'skip'])
                if not has_gate:
                    _log(f'  No gate keywords — likely destination')
                    dest_url = self.page.url
                    break

            # Popup handler
            btn = await self.page.query_selector('#continueBtn')
            if btn:
                r = await btn.bounding_box()
                if r and r['width'] > 0:
                    _log('  Popup #continueBtn — clicking')
                    await btn.click(force=True, timeout=5000)
                    await asyncio.sleep(3)
                    _log('  Waiting 25s for timer...')
                    await asyncio.sleep(25)

            # Gate page handler
            ptype = await self.get_page_type()
            _log(f'  Type: {ptype}')

            if ptype in ('gate', 'gate_action'):
                _log('  Gate page — polling for Get Link / Continue...')
                for sec in range(60):
                    # Try all button selectors
                    result = await self.poll_for_element(
                        self.BUTTON_SELECTORS, timeout=1, interval=0
                    )
                    if result['success']:
                        _log(f'  [{result["name"]}] appeared at t={sec}s')
                        # Now click it
                        el = await self.page.query_selector(result['selector'])
                        if el:
                            await el.click(force=True, timeout=5000)
                            await asyncio.sleep(5)
                            if self._destination_url:
                                dest_url = self._destination_url
                                _log(f'  New tab destination: {dest_url}')
                                break
                        break
                    # JS fallback
                    js_result = await self.js_click_text()
                    if js_result['success']:
                        _log(f'  JS clicked: {js_result["text"]}')
                        await asyncio.sleep(3)
                        if self._destination_url:
                            dest_url = self._destination_url
                        break
                    await asyncio.sleep(1)
                if dest_url:
                    break
                continue

            # Content page — find and click bottom button
            _log('  Searching for bottom Continue button...')
            click_result = await self.find_and_click()
            if not click_result['success']:
                _log('  JS fallback...')
                click_result = await self.js_click_text()
            if click_result['success']:
                _log(f'  Clicked: {click_result.get("element") or click_result.get("text")}')
            else:
                _log('  No button found — possible destination')
                if text_len > 200:
                    dest_url = self.page.url
                    break

            if self._destination_url:
                dest_url = self._destination_url
                break

            _log(f'  URL: {self.page.url}')

        return {
            'destination_url': dest_url or self.page.url,
            'pages_traversed': self._pages_traversed,
            'total_pages': len(self._pages_traversed),
            'log': log,
        }

    async def close(self):
        """Close the browser."""
        if self.browser:
            await self.browser.close()
        if self.playwright:
            await self.playwright.__aexit__(None, None, None)
