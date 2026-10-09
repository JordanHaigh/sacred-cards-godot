#!/usr/bin/env python3
"""Export card metadata, terrain modifiers, level thresholds and initial deck."""
import argparse
import csv
import hashlib
import html
import json
import re
import struct
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path)
    ap.add_argument('--out',type=Path,default=Path('build/assets/gameplay'));a=ap.parse_args()
    rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    a.out.mkdir(parents=True,exist_ok=True);sources=[]
    def table(name,offset,count,fmt):
        size=struct.calcsize('<'+fmt);raw=rom[offset:offset+count*size]
        (a.out/(name+'.bin')).write_bytes(raw)
        sources.append(dict(name=name,rom_offset=hex(offset),count=count,element_format=fmt,
                            file=name+'.bin',sha256=hashlib.sha256(raw).hexdigest()))
        return [v[0] for v in struct.iter_unpack('<'+fmt,raw)]
    def text_at(at):
        raw=rom[at:rom.index(b'\0',at)]
        match=re.search(rb'\$0(.*?)(?=\$[1-6]|$)',raw)
        return match[1].decode('ascii','backslashreplace').strip() if match else ''
    def labels(name,offset,count):
        return [text_at(p-0x8000000) for p in table(name,offset,count,'I')]
    types=labels('type-label-pointers',0xD4BC3C,24)
    summons=labels('summon-label-pointers',0xD419E0,12)
    names=labels('card-name-pointers',0xD310E0,901)
    fields={}
    for name,at,fmt in [('attack',0x886E6,'H'),('defense',0x87FDC,'H'),('cost',0x88DF0,'I'),
                        ('type',0x8A30E,'B'),('summon',0x89C04,'B'),('level',0x89F89,'B'),
                        ('frame',0x8A693,'B'),('metadata_1a',0x8AD9D,'B'),
                        ('metadata_1b',0x8AA18,'B'),('metadata_1c',0x8B122,'B'),('base_shop_price',0xD32D08,'Q')]:
        fields[name]=table(name,at,901,fmt)
    category=table('metadata-1d-lookup',0x8B4A7,max(fields['metadata_1a'])+1,'B')
    cards=[dict(id=i,name=names[i],**{k:v[i] for k,v in fields.items()},
                type_name=types[fields['type'][i]],summon_name=summons[fields['summon'][i]],
                metadata_1d=category[fields['metadata_1a'][i]]) for i in range(901)]
    flat=table('terrain-modifiers',0x8B533,7*24,'B')
    terrain=[flat[i*24:(i+1)*24] for i in range(7)]
    levels=table('level-capacity-thresholds',0xB3EC0,1000,'H')
    preset=table('untraced-deck-preset',0xB4690,40,'H')
    deck=table('initial-deck',0xEBAF0,40,'H')
    tribute=table('tributes-by-level',0xD4C6D0,max(fields['level'])+1,'b')
    classes=table('duel-card-type-classes',0xD4BD48,24,'b')
    requirements=table('category-requirements',0xBA25C,max(category)+1,'B')
    result=dict(rom_sha256=EXPECTED_SHA256,cards=cards,type_labels=types,summon_labels=summons,
                terrain_modifiers=terrain,terrain_names=['default','Forest','Wasteland','Mountain','Sogen','Umi','Yami'],
                tributes_by_level=tribute,duel_card_type_classes=classes,category_requirements=requirements,
                level_capacity_thresholds=levels,initial_deck=deck,untraced_deck_preset=preset,
                sources=sources,initial_capacity=1600,initial_duelist_level=72,
                notes=['Semantic reconstruction; no execution comparison or compiler match.',
                       'Metadata fields 1a..1d retain neutral names; only 1a == 2 takes the stat-modifier path.',
                       'Terrain names 1..6 traced to field spell handlers 0802B378..0802B558; row 0 retains the default label.',
                       'Modifier 1 multiplies by binary64 0.7; 3 by binary64 1.3; others are unchanged.',
                       'Terrain conversion wraps to u16 before its upper clamp. Stage adds signed i8 times 500 and clamps to 0..65534.',
                       'Level entry zero is retained. Raising a level compares capacity against the next entry; subtracting capacity does not lower level.'])
    (a.out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    def csvfile(name,rows):
        with (a.out/name).open('w',newline='') as f:
            w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    csvfile('cards.csv',cards)
    csvfile('levels.csv',[dict(level=i,capacity_threshold=n) for i,n in enumerate(levels)])
    csvfile('initial-deck.csv',[dict(slot=i,card_id=n,name=names[n],cost=fields['cost'][n]) for i,n in enumerate(deck)])
    csvfile('terrain.csv',[dict(terrain=i,type=j,type_name=types[j],modifier=v) for i,row in enumerate(terrain) for j,v in enumerate(row)])
    page='''<!doctype html><html lang="en"><meta charset="utf-8"><title>Sacred Cards gameplay data</title>
<style>body{background:#171c24;color:#eee;font:16px system-ui;max-width:1100px;margin:32px auto;padding:0 20px}a{color:#91d3ff}select,input{font:inherit;padding:8px;max-width:100%}label{display:block;margin:12px 0}table{border-collapse:collapse;width:100%}td,th{padding:8px;border-bottom:1px solid #445;text-align:left}output{display:block;font-size:24px;margin:20px 0}.note{color:#bcc8d8}img{image-rendering:pixelated}</style>
<h1>Gameplay data</h1><p><a href="../index.html">All assets</a> · <a href="manifest.json">Raw manifest</a> · <a href="cards.csv">901 card records</a> · <a href="terrain.csv">Terrain table</a> · <a href="effects.html">Card handlers and battle tables</a> · <a href="effect-rules.html">Equipment and ritual rules</a> · <a href="ai.html">AI action table</a> · <a href="levels.csv">1,000 level thresholds</a></p>
<h2>Card stat explorer</h2><p class="note">Assembly-derived behavior, not yet compared by execution. Field spell handlers establish terrain names; unresolved metadata fields retain numeric names.</p>
<label>Card <select id="card"></select></label><label>Terrain ID <select id="terrain"></select></label>
<label>Stage (signed byte) <input id="stage" type="number" min="-128" max="127" value="0"></label><output id="stats"></output><p id="details"></p>
<h2>Starting deck</h2><p>Initial capacity: 1,600. Initial Duelist Level: 72. <a href="initial-deck.csv">Download 40 slots</a>.</p><table><thead><tr><th>Slot</th><th>Card</th><th>Cost</th></tr></thead><tbody>DECKROWS</tbody></table>
<script>
const data=DATA;
const card=document.getElementById('card'),terrain=document.getElementById('terrain'),stage=document.getElementById('stage');
data.cards.forEach(c=>card.add(new Option(`${c.id}: ${c.name || '(blank)'}`,c.id)));card.value=1;
data.terrain_modifiers.forEach((_,i)=>terrain.add(new Option(`${i}: ${data.terrain_names[i]}`,i)));
function update(){const c=data.cards[+card.value],m=data.terrain_modifiers[+terrain.value][c.type];let s=Math.max(-128,Math.min(127,Math.trunc(Number(stage.value)||0)));
function stat(v){if(c.metadata_1a!==2)return v;if(m===1)v=Math.trunc(v*0.7)&65535;else if(m===3)v=Math.min(65534,Math.trunc(v*1.3)&65535);return Math.max(0,Math.min(65534,v+s*500));}
document.getElementById('stats').textContent=`ATK ${c.attack} → ${stat(c.attack)} · DEF ${c.defense} → ${stat(c.defense)}`;
document.getElementById('details').textContent=`${c.type_name} · ${c.summon_name} · Level ${c.level} · Cost ${c.cost} · Terrain modifier ${m}. ${c.metadata_1a===2?'Terrain is applied before stage.':'Metadata 1a is not 2: this routine leaves stats unchanged.'}`;}
[card,terrain,stage].forEach(e=>e.addEventListener('input',update));update();
</script></html>'''
    rows=''.join(f'<tr><td>{i+1}</td><td>{n}: {html.escape(names[n])}</td><td>{fields["cost"][n]}</td></tr>' for i,n in enumerate(deck))
    data=json.dumps(dict(cards=cards,terrain_modifiers=terrain,terrain_names=result['terrain_names'])).replace('<','\\u003c')
    (a.out/'index.html').write_text(page.replace('DECKROWS',rows).replace('DATA',data))
    print('Exported 901 card records, 168 terrain modifiers, 1000 level thresholds and 40 starting-deck slots')

if __name__=='__main__':main()
