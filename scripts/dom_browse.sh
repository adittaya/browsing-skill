#!/usr/bin/env bash
# DOM Engine: Browse — navigate to a URL using headless Playwright
# Supercedes browser.sh for modern JS-heavy sites.
# Usage: bash scripts/dom_browse.sh open <url>
#        bash scripts/dom_browse.sh scan
#        bash scripts/dom_browse.sh status
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

case "${1:-}" in
    open)
        URL="${2:-}"
        [ -z "$URL" ] && echo "Usage: $0 open <url>" && exit 1
        python3 -c "
import asyncio, sys, json
sys.path.insert(0, '$LIB_DIR')
from dom_engine import DOMEngine

async def main():
    engine = DOMEngine()
    page = await engine.start()
    final_url = await engine.navigate('$URL')
    text_len = await engine.get_text_length()
    elements = await engine.scan_dom()
    ptype = await engine.get_page_type()
    first_line = (await engine.get_text()).strip().split('\n')[0][:80]
    result = {
        'final_url': final_url,
        'text_length': text_len,
        'page_type': ptype,
        'first_line': first_line,
        'elements': elements[:8],
    }
    print(json.dumps(result, indent=2))
    await engine.close()

asyncio.run(main())
"
        ;;
    scan)
        python3 -c "
import asyncio, json, sys
sys.path.insert(0, '$LIB_DIR')
from dom_engine import DOMEngine

async def main():
    engine = DOMEngine()
    page = await engine.start()
    await engine.navigate('about:blank')
    elements = await engine.scan_dom()
    text_len = await engine.get_text_length()
    ptype = await engine.get_page_type()
    print(json.dumps({'elements': elements, 'text_length': text_len, 'page_type': ptype}, indent=2))
    await engine.close()

asyncio.run(main())
"
        ;;
    status)
        python3 -c "
try:
    import playwright
    print('Playwright: INSTALLED')
except ImportError:
    print('Playwright: MISSING (run: pip install playwright && playwright install chromium)')
"
        ;;
    *)
        echo "Usage: $0 open <url> | scan | status"
        exit 1
        ;;
esac
