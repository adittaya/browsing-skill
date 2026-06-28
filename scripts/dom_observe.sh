#!/usr/bin/env bash
# DOM Engine: Observe — use the 6-step observation methodology to understand a page
# Usage: bash scripts/dom_observe.sh [url]
#   If URL given: navigates there first, then observes.
#   If no URL: observes the current page (last browsed).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
URL="${1:-}"

python3 -c "
import asyncio, json, sys
sys.path.insert(0, '$LIB_DIR')
from dom_engine import DOMEngine

async def main():
    engine = DOMEngine()
    await engine.start()

    url = '${URL}' if '${URL}' else None
    if url:
        final = await engine.navigate(url)
        print(f'Navigated to: {final}')
    else:
        print('Observing current state...')

    print('=' * 50)
    print('STEP 1: Page metadata')
    print('=' * 50)
    text_len = await engine.get_text_length()
    ptype = await engine.get_page_type()
    url_lower = engine.page.url.lower()
    print(f'  URL:     {engine.page.url}')
    print(f'  Text:    {text_len} chars')
    print(f'  Type:    {ptype}')

    print()
    print('=' * 50)
    print('STEP 2: Interactive elements')
    print('=' * 50)
    elements = await engine.scan_dom()
    if elements:
        for i, el in enumerate(elements[:15]):
            print(f'  {i+1}. {el[\"tag\"]}#{el[\"id\"]}')
            print(f'     text: \"{el[\"text\"][:60]}\"')
            print(f'     href: {el[\"href\"][:60]}')
            print(f'     pos:  y={el[\"y\"]} w={el[\"w\"]} h={el[\"h\"]}')
    else:
        print('  (no interactive elements detected)')

    print()
    print('=' * 50)
    print('STEP 3: Page text (first 500 chars)')
    print('=' * 50)
    text = await engine.get_text()
    print(f'  {text[:500]}')

    print()
    print('=' * 50)
    print('STEP 4: Gate keyword analysis')
    print('=' * 50)
    text_lower = text.lower()
    keywords = {
        'popup': ['continue', '#continueBtn'],
        'timer': ['seconds', 'wait', 'almost ready', 'your link'],
        'gate': ['get link', 'getlink', 'continue reading'],
        'destination': ['download', 'redirect', 'destination'],
    }
    for category, words in keywords.items():
        found = [w for w in words if w in text_lower]
        if found:
            print(f'  [{category}] {found}')

    print()
    print('=' * 50)
    print('STEP 5: Screenshot')
    print('=' * 50)
    await engine.screenshot('/tmp/dom_observe.png')
    print(f'  Saved: /tmp/dom_observe.png')

    await engine.close()

asyncio.run(main())
"
