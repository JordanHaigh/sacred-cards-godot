#!/usr/bin/env python3
"""Export AI actions, reviewed callback mappings and card-scoring table views."""
import argparse,csv,hashlib,html,json,struct
from collections import Counter
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256

ROOT=Path(__file__).resolve().parents[1]
KINDS=['none','discard','summon zero','summon one','summon two','defense','attack position',
       'direct attack','monster attack','trapped direct attack','trapped monster attack',
       'summon three','hidden monster attack','trapped hidden attack','set trap','set equipment',
       'targeted spell','trapped targeted spell','set spell','spell','trapped spell','set ritual',
       'ritual','monster effect','set special piece']


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path)
    ap.add_argument('--out',type=Path,default=Path('build/assets/gameplay'));a=ap.parse_args()
    rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    a.out.mkdir(parents=True,exist_ok=True)
    actions=[]
    for i in range(616):
        raw=rom[0xAAED4+i*8:0xAAEDC+i*8]
        kind=int.from_bytes(raw[:2],'little')
        actions.append(dict(id=i,kind=kind,name=KINDS[kind],operands=list(raw[2:]),raw=raw.hex()))
    semantic=json.loads((ROOT/'semantic_ai_callbacks.json').read_text())
    scorer_path=ROOT/'build/semantic/ai_card_scorers.json'
    scorers=json.loads(scorer_path.read_text()) if scorer_path.exists() else None
    tables={}
    for name,at in [('simulate',0xD349EC),('execute',0xD34A50),('score_before',0xD34AB8),('score_after',0xD34B1C),('validate',0xD356C0)]:
        raw=rom[at:at+100];(a.out/f'ai-{name}.bin').write_bytes(raw)
        tables[name]=dict(rom_address=f'0x{at+0x08000000:08X}',pointers=[f'0x{p:08X}' for p in struct.unpack('<25I',raw)],
                         semantic_entries=[e for e in semantic['entries'] if e['family']==name])
    views=[]
    for name,at,count in [('spell_before',0xD34B80,132),('spell_after',0xD34D88,132),('monster_before',0xD353A0,85),('monster_after',0xD35530,85)]:
        raw=rom[at:at+count*4];(a.out/f'ai-{name}.bin').write_bytes(raw)
        views.append(dict(name=name,address=f'0x{at+0x08000000:08X}',count=count,pointers=[f'0x{v:08X}' for v in struct.unpack('<'+'I'*count,raw)]))
    target_classes=list(struct.unpack('<132b',rom[0xD4BD60:0xD4BDE4]))
    (a.out/'ai-spell-target-classes.bin').write_bytes(rom[0xD4BD60:0xD4BDE4])
    (a.out/'ai-actions.bin').write_bytes(rom[0xAAED4:0xAC214])
    result=dict(rom_sha256=EXPECTED_SHA256,actions=actions,callbacks=tables,
                kind_counts=dict(Counter(x['kind'] for x in actions)),kind_names=KINDS,
                card_scoring_views=views,card_scoring_recovery=scorers,
                spell_target_classes=target_classes,opposite_side=list(rom[0xAAED0:0xAAED2]),
                notes=['Operand bytes are raw; many handlers use high nibble=row and low nibble=column.',
                       'All five top-level callback families have maintained C entry bodies; native presentation, globals and integration remain dependencies.',
                       'Card-scoring views retain native overlap at spell indices 130/131. The manifest distinguishes maintained bodies and exact instruction-template recovery.',
                       '616 candidates; highest unsigned score wins, with first positive-score tie retained.'])
    (a.out/'ai.json').write_text(json.dumps(result,indent=2)+'\n')
    with (a.out/'ai-actions.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['id','kind','name',*[f'operand_{i}' for i in range(6)]])
        for x in actions:w.writerow([x['id'],x['kind'],x['name'],*x['operands']])
    rows=''.join(f'<tr><td>{x["id"]}</td><td>{x["kind"]}: {html.escape(x["name"])}</td><td>{" ".join(f"{v:02X}" for v in x["operands"])}</td></tr>' for x in actions)
    callbacks=''.join(f'<tr><td>{html.escape(e["family"])}</td><td>{e["index"]}</td><td>{e["address"]}</td><td><a href="../../../{html.escape(e["source"],quote=True)}">{html.escape(e["function"])}</a></td></tr>' for e in semantic['entries'])
    scorer_summary=html.escape(str(dict(Counter(e['kind'] for e in scorers['functions'])))) if scorers else 'Run make semantic-objects to generate the recovery manifest.'
    (a.out/'ai.html').write_text('<!doctype html><meta charset="utf-8"><title>AI action definitions</title>'
        '<style>body{font:16px system-ui;background:#171c24;color:#eee;margin:2rem}a{color:#9bd7ff}td,th{padding:.4rem;text-align:left}</style>'
        '<h1>AI action definitions</h1><p><a href="index.html">Gameplay</a> · <a href="ai.json">JSON + callback tables</a> · <a href="ai-actions.csv">CSV</a></p>'
        '<p>616 action definitions. Each decision simulates valid candidates, scores and restores state, then executes the best. All 125 top-level callback slots have recovered entry bodies. C is not linked or execution-compared.</p>'
        '<h2>Card-specific scoring</h2><p>'+scorer_summary+'</p>'
        '<details><summary>Top-level callback mappings</summary><table><tr><th>Family</th><th>Index</th><th>Native entry</th><th>C function</th></tr>'+callbacks+'</table></details>'
        '<h2>Actions</h2><table><tr><th>ID</th><th>Kind</th><th>Six operand bytes</th></tr>'+rows+'</table>')
    print(f'Exported {len(actions)} AI actions, {len(tables)} callback tables; kinds {sorted(result["kind_counts"])}')

if __name__=='__main__':main()
