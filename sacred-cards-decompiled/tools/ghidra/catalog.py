#!/usr/bin/env python3
"""Create a searchable local catalog of auto-generated C, with explicit caveats."""
import collections
import csv
import hashlib
import html
import json
import re
from pathlib import Path

root = Path(__file__).resolve().parents[2]
out = root/'build/decompiled'
rows = list(csv.DictReader((out/'functions.csv').open()))
for r in rows:
    c=(out/r['file']).read_text() if r['file'] else ''
    r['warnings']=re.findall(r'/\* WARNING:.*?\*/',c,flags=re.S)
    r['contains_saved_lr_return_artifact']='in_lr' in c
    r['contains_unaffiliated_register_input']='unaff_' in c
counts = dict(collections.Counter(r['status'] for r in rows))
report = dict(rom_sha256='093f986a92d73c48e11de0a83c6678c3620f8def6173f5e69133815301b40d8f',kind='Ghidra auto-generated C drafts; not reviewed or matched C',
              ghidra='12.1.4', processor='ARM:LE:32:v4t', analysis_abi='apcs',
              known_roots=len(rows), statuses=counts, functions=rows,
              all_game_code_discovered=False, compiler_matched=False,
              reviewed_listing_sha256=hashlib.sha256((root/'build/disassembly/reachable.asm').read_bytes()).hexdigest())
(out/'manifest.json').write_text(json.dumps(report, indent=2)+'\n')
body=[]
for r in rows:
    name=html.escape(r['name'])
    link=f'<a href="{html.escape(r["file"])}">{name}</a>' if r['file'] else name
    body.append(f'<tr><td>{r["address"]}</td><td>{link}</td><td>{r["status"]}</td>'
                f'<td>{r["body_bytes"]}</td><td>{html.escape(r["error"])}</td></tr>')
(out/'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>AY7E draft C catalog</title>
<style>body{font:15px system-ui;background:#101827;color:#edf2ff;margin:2rem}a{color:#8fd0ff}td,th{padding:.4rem;text-align:left}tr:nth-child(even){background:#1d293c}input{font:inherit;padding:.6rem;width:40rem;max-width:90%}table{width:100%}</style>
<h1>AY7E draft C catalog</h1><p>Automatic Ghidra output for reviewed function entry points. These files are <b>not reviewed, execution-compared, compiler-matched, or a standalone build</b>.</p>
<p>Types, return values, calling conventions and control flow remain inferred. Even a file without warnings requires review. The root list does not establish discovery of all game code.</p>
<p>Reviewed C is maintained separately under <code>src/</code>. Original code is preserved in the byte-identical instruction reassembly.</p>
''' + '<p>'+html.escape(str(counts))+'</p>' + '''<input id="q" placeholder="Filter address, card name, function, status" aria-label="Filter functions">
<table><thead><tr><th>Entry</th><th>Function / C file</th><th>Status</th><th>Body bytes</th><th>Diagnostic</th></tr></thead><tbody>'''+''.join(body)+'''</tbody></table>
<script>const rows=[...document.querySelectorAll('tbody tr')];document.querySelector('#q').addEventListener('input',e=>{let q=e.target.value.toLowerCase();rows.forEach(r=>r.hidden=!r.textContent.toLowerCase().includes(q));});</script>''')
print(f'Cataloged {len(rows)} roots: {counts}')
