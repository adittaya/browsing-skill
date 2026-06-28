#!/usr/bin/env bash
# DOM Engine: Trace — full redirect chain resolver using the observation methodology
# Usage: bash scripts/dom_trace.sh <gate-url> [output-dir]
# Example: bash scripts/dom_trace.sh https://example.com/gate-link
set -euo pipefail

URL="${1:-}"
OUTPUT_DIR="${2:-/tmp/gate_trace}"
[ -z "$URL" ] && echo "Usage: $0 <gate-url> [output-dir]" && exit 1

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
LIB_DIR="$SCRIPT_DIR/lib"
mkdir -p "$OUTPUT_DIR"

python3 -c "
import asyncio, json, sys, os
sys.path.insert(0, '$LIB_DIR')
from dom_engine import DOMEngine

async def main():
    engine = DOMEngine()
    await engine.start()

    result = await engine.trace_chain('$URL')
    result['output_dir'] = '$OUTPUT_DIR'

    # Save log
    with open('$OUTPUT_DIR/log.txt', 'w') as f:
        f.write('\n'.join(result['log']))

    # Save result JSON
    with open('$OUTPUT_DIR/result.json', 'w') as f:
        json.dump(result, f, indent=2)

    # Screenshot final page
    try:
        await engine.screenshot('$OUTPUT_DIR/final.png', full_page=True)
    except:
        pass

    print('=' * 50)
    print(f'CHAIN TRACE COMPLETE')
    print(f'  Pages traversed: {result[\"total_pages\"]}')
    print(f'  Destination:      {result[\"destination_url\"]}')
    print(f'  Log:              $OUTPUT_DIR/log.txt')
    print(f'  Screenshot:       $OUTPUT_DIR/final.png')
    print('=' * 50)

    await engine.close()

asyncio.run(main())
"
