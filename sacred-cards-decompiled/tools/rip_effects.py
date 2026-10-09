#!/usr/bin/env python3
"""Map 901 cards to reviewed handler tables and expose battle relationship data."""
import argparse
import csv
import hashlib
import html
import json
import struct
from collections import defaultdict
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path)
    ap.add_argument('--out',type=Path,default=Path('build/assets/gameplay'));a=ap.parse_args()
    rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    draft_path=Path('build/decompiled/functions.csv')
    drafts={}
    if draft_path.exists():
        with draft_path.open() as f:drafts={int(r['address'],16):r for r in csv.DictReader(f)}
    registry=json.loads((Path(__file__).resolve().parents[1]/'semantic_handlers.json').read_text())
    if registry['rom_sha256']!=EXPECTED_SHA256:raise ValueError('Handler registry ROM mismatch')
    reviewed={(r['field'],r['index']):r for r in registry['entries']}
    game=json.loads((a.out/'manifest.json').read_text());tables=[];mapping=[]
    report_path=Path('build/disassembly/reachable_report.json')
    roots=[]
    if report_path.exists():roots=json.loads(report_path.read_text())['direct_function_roots']
    known={int(r['address'],16) for r in roots}
    for field,at,count,dispatcher in [('metadata_1b',0xFB79C,85,0x080285E8),('metadata_1a',0xFB900,132,0x0802B33C)]:
        raw=rom[at:at+4*count];(a.out/(field+'-handlers.bin')).write_bytes(raw)
        handlers=struct.unpack('<'+'I'*count,raw);groups=defaultdict(list)
        for i,p in enumerate(handlers):
            entry=reviewed.get((field,i))
            if entry and int(entry['address'],16)!=(p&~1):raise ValueError('Semantic registry address differs from ROM')
        for c in game['cards']:
            i=c[field];address=handlers[i]&~1;groups[i].append(c['id'])
            mapping.append(dict(card_id=c['id'],name=c['name'],field=field,handler_index=i,
                                handler_address=f'0x{address:08X}',dispatcher=f'0x{dispatcher:08X}'))
        tables.append(dict(field=field,rom_offset=hex(at),count=count,sha256=hashlib.sha256(raw).hexdigest(),
                           entries=[dict(index=i,pointer=f'0x{p:08X}',address=f'0x{p&~1:08X}',
                                         card_ids=groups[i],semantic_source=reviewed.get((field,i),{}).get('source'),
                                         semantic_function=reviewed.get((field,i),{}).get('function'),
                                         draft_file=drafts.get(p&~1,{}).get('file'),has_disassembly=(p&~1) in known) for i,p in enumerate(handlers)]))
    battle={}
    for name,at,n in [('attribute_beats',0xD4BD30,12),('attribute_loses_to',0xD4BD3C,12),
                      ('owner_defeat_masks',0xD4BD2C,2),('event_bit_masks',0xD4F434,8)]:
        raw=rom[at:at+n];(a.out/(name+'.bin')).write_bytes(raw)
        battle[name]=dict(rom_offset=hex(at),values=list(raw),sha256=hashlib.sha256(raw).hexdigest())
    result=dict(rom_sha256=EXPECTED_SHA256,tables=tables,battle_tables=battle,
                semantic_handler_slots=len(reviewed),
                notes=['All 217 metadata-1A/1B entry bodies have semantic C; native helper and presentation dependencies remain.',
                       'Trap validation/activation is reconstructed separately in src/trap_effects.c. Nothing here is compiler-matched or execution-compared.',
                       'Metadata field names remain neutral. One extra pointer follows the 85-entry 1b range but is not indexed by any card metadata.',
                       'Attribute 11 forces neutral comparison. For others, equality with beats gives result0 and loses_to result2; default1.',
                       'For attribute0 versus0 the first table comparison returns0; no extra zero special case is added.'])
    (a.out/'effects.json').write_text(json.dumps(result,indent=2)+'\n')
    with (a.out/'card-handlers.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(mapping[0]));w.writeheader();w.writerows(mapping)
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><title>Card handlers and battle tables</title>',
          '<style>body{background:#171c24;color:#eee;font:16px system-ui;max-width:1100px;margin:30px}a{color:#9bd7ff}article{padding:12px;background:#252c38;margin:12px 0}td,th{padding:8px;text-align:left}input{padding:10px;font:inherit}article[hidden]{display:none}</style>',
          '<h1>Card handlers and battle tables</h1><p><a href="index.html">Gameplay data</a> · <a href="effects.json">Source manifest</a> · <a href="card-handlers.csv">Card-to-handler CSV</a></p>',
          f'<p>217 table slots link the 901 card records to their two dispatch paths. {len(reviewed)} entry bodies have maintained semantic C. Native helper and presentation dependencies remain; these are not matched or execution-compared. Automatic C drafts are linked separately.</p>',
          '<h2>Summon-attribute relationship tables</h2><p>Divine (11) bypasses both tables. Native comparison checks the winning table first, including slot zero.</p><table><tr><th>Attribute</th><th>Wins against</th><th>Loses to</th></tr>']
    labels=game['summon_labels']
    for i in range(12):
        win=battle['attribute_beats']['values'][i];lose=battle['attribute_loses_to']['values'][i]
        page.append(f'<tr><td>{i}: {html.escape(labels[i])}</td><td>{win}: {html.escape(labels[win])}</td><td>{lose}: {html.escape(labels[lose])}</td></tr>')
    page.append('</table><h2>Handlers</h2><input id="search" placeholder="Find card, address or index">')
    for table in tables:
        for e in table['entries']:
            names=', '.join(f'{i}: {game["cards"][i]["name"]}' for i in e['card_ids'])
            links=''
            if e['draft_file']:links+=f'<a href="../../decompiled/{e["draft_file"]}">Automatic C draft</a> '
            if e['semantic_source']:links+=f'<a href="../../../{html.escape(e["semantic_source"])}">{html.escape(e["semantic_function"])} — semantic C (not matched)</a>'
            page.append(f'<article><h3>{table["field"]} [{e["index"]}] → {e["address"]}</h3><p>{html.escape(names or "No card references")}</p><p>{links}</p></article>')
    page.append('<script>document.querySelector("#search").oninput=e=>document.querySelectorAll("article").forEach(a=>a.hidden=!a.textContent.toLowerCase().includes(e.target.value.toLowerCase()));</script>')
    (a.out/'effects.html').write_text('\n'.join(page)+'\n')
    print(f'Exported {len(mapping)} card-handler links, 217 handler slots, and battle/flag tables')

if __name__=='__main__':main()
