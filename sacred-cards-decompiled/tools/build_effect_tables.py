#!/usr/bin/env python3
"""Generate C dispatch tables from the explicit reviewed handler registry."""
import json,re
from pathlib import Path

root=Path(__file__).resolve().parents[1]
registry=json.loads((root/'semantic_handlers.json').read_text())
lines=['/* Generated from semantic_handlers.json; semantic, not native-layout matched. */']
for e in registry['entries']:
    if not re.fullmatch(r'[A-Za-z_]\w*',e['function']):raise ValueError('Invalid C identifier')
    lines.append(f'extern void {e["function"]}(void);')
for field,count,symbol in [('metadata_1a',132,'gMetadata1aHandlers'),('metadata_1b',85,'gMetadata1bHandlers')]:
    entries=sorted((e for e in registry['entries'] if e['field']==field),key=lambda e:e['index'])
    if [e['index'] for e in entries]!=list(range(count)):raise ValueError('Incomplete handler table')
    lines.append(f'void (*const {symbol}[{count}])(void) = {{')
    lines.extend(f'    {e["function"]}, /* {e["index"]}: {e["address"]} */' for e in entries)
    lines.append('};')
out=root/'build/semantic/effect_tables.c';out.parent.mkdir(parents=True,exist_ok=True)
out.write_text('\n'.join(lines)+'\n')
print('Generated both semantic effect dispatch tables (217 entries)')
