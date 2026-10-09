#!/usr/bin/env python3
"""Prepare reviewed ROM roots and control flow for local Ghidra export."""
import csv
import json
import re
import struct
from pathlib import Path

root=Path(__file__).resolve().parents[2];out=root/'build/ghidra-input';out.mkdir(exist_ok=True)
report=json.loads((root/'build/disassembly/reachable_report.json').read_text())
listing=(root/'build/disassembly/reachable.asm').read_text()
with (root/'symbols.csv').open() as f:symbols={int(r['address'],16):r['name'] for r in csv.DictReader(f)}
with (root/'function_entries.csv').open() as f:
 for r in csv.DictReader(f):symbols[int(r['address'],0)]=r['name']
# Names derive from table index + card names, not guessed behavior.
effects=json.loads((root/'build/assets/gameplay/effects.json').read_text())
game=json.loads((root/'build/assets/gameplay/manifest.json').read_text())
for table in effects['tables']:
 for e in table['entries']:
  address=int(e['address'],16)
  if address in symbols:continue
  name=game['cards'][e['card_ids'][0]]['name'] if len(e['card_ids'])==1 else 'Shared'
  slug=re.sub(r'[^A-Za-z0-9]+','_',name).strip('_') or 'None'
  symbols[address]=f'Handler_{table["field"][-2:]}_{e["index"]:03d}_{slug}'
functions=[]
for r in report['direct_function_roots']:
 address=int(r['address'],16);name=symbols.get(address,f'sub_{address:08X}')
 functions.append(f'{address:08X}\t{r["mode"]}\t{name}')
(out/'functions.tsv').write_text('\n'.join(functions)+'\n')
ranges=[]
for line in listing.splitlines():
 m=re.match(r'^([0-9A-F]{8})\s+(arm|thumb)\s+(\S+)',line)
 if not m:continue
 a=int(m[1],16);mode=m[2];size=4 if mode=='arm' or m[3] in ('bl','blx') else 2
 if ranges and ranges[-1][1]+1==a and ranges[-1][2]==mode:ranges[-1][1]=a+size-1
 else:ranges.append([a,a+size-1,mode])
(out/'ranges.tsv').write_text(''.join(f'{a:08X}\t{b:08X}\t{m}\n' for a,b,m in ranges))
(out/'jumps.tsv').write_text(''.join(f'{int(t["branch_address"],16):08X}\t{v:08X}\n' for t in report['followed_manual_jump_tables'] for v in t['targets']))
print(f'Prepared {len(functions)} reviewed function roots and {len(ranges)} instruction spans')

returns=[]
previous=None
for line in listing.splitlines():
 m=re.match(r'^([0-9A-F]{8})\s+(arm|thumb)\s+(\S+)\s*(.*)',line)
 if not m:continue
 a=int(m[1],16);op=m[3];operand=m[4].strip()
 if op=='bx' and previous==(a-2,'pop','{'+operand+'}'):
  returns.append(f'{a:08X}')
 previous=(a,op,operand)
(out/'returns.tsv').write_text('\n'.join(returns)+'\n')
print(f'Marked {len(returns)} explicit pop/BX return epilogues')
