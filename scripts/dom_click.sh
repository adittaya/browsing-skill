#!/usr/bin/env bash
# DOM Engine: Click — find and click elements via DOM introspection
# Supercedes click.sh for modern JS-heavy sites.
# Usage: bash scripts/dom_click.sh [--text "Continue"] [--selector "#tp-snp2"]
#        bash scripts/dom_click.sh --scan          # Dump all interactive elements
#        bash scripts/dom_click.sh --text continue  # Find + click by text
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"

if [ "${1:-}" = "--scan" ]; then
    python3 -c "
import asyncio, json, sys
sys.path.insert(0, '$LIB_DIR')
from dom_engine import DOMEngine

async def main():
    engine = DOMEngine()
    await engine.start()
    elements = await engine.scan_dom()
    text = (await engine.get_text())[:500] if (await engine.get_text_length()) > 0 else '(empty)'
    print(json.dumps({'elements': elements, 'text_snippet': text}, indent=2))
    await engine.close()

asyncio.run(main())
"
elif [ "${1:-}" = "--text" ]; then
    TEXT="${2:-continue}"
    python3 -c "
import asyncio, json, sys
sys.path.insert(0, '$LIB_DIR')
from dom_engine import DOMEngine

async def main():
    engine = DOMEngine()
    await engine.start()
    result = await engine.js_click_text('$TEXT|CONTINUE|Get.?Link|Proceed')
    print(json.dumps(result, indent=2))
    await asyncio.sleep(3)
    final_url = engine.page.url if engine.page else '(no page)'
    print(f'URL after click: {final_url}')
    await engine.close()

asyncio.run(main())
"
elif [ "${1:-}" = "--selector" ]; then
    SEL="${2:-}"
    [ -z "$SEL" ] && echo "Usage: $0 --selector '#id'" && exit 1
    python3 -c "
import asyncio, json, sys
sys.path.insert(0, '$LIB_DIR')
from dom_engine import DOMEngine

async def main():
    engine = DOMEngine()
    await engine.start()
    el = await engine.page.query_selector('$SEL')
    if el:
        r = await el.bounding_box()
        if r and r['width'] > 0:
            await el.click(force=True, timeout=5000)
            await asyncio.sleep(5)
            print(json.dumps({'success': True, 'selector': '$SEL', 'y': r['y']}))
        else:
            print(json.dumps({'success': False, 'error': 'Element not visible'}))
    else:
        print(json.dumps({'success': False, 'error': 'Element not found'}))
    await engine.close()

asyncio.run(main())
"
else
    # Default: find and click any Continue/Get Link button
    python3 -c "
import asyncio, json, sys
sys.path.insert(0, '$LIB_DIR')
from dom_engine import DOMEngine

async def main():
    engine = DOMEngine()
    await engine.start()
    result = await engine.find_and_click()
    if not result['success']:
        result = await engine.js_click_text()
    print(json.dumps(result, indent=2))
    await asyncio.sleep(3)
    if engine.page:
        print(f'URL: {engine.page.url}')
    await engine.close()

asyncio.run(main())
"
fi
