#!/usr/bin/env python3
"""Export equipment eligibility masks, ritual recipes and effect immunity IDs."""
import argparse,csv,hashlib,html,json,struct
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path)
    ap.add_argument('--out',type=Path,default=Path('build/assets/gameplay'));a=ap.parse_args()
    rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    a.out.mkdir(parents=True,exist_ok=True)
    families=json.loads((Path(__file__).resolve().parents[1]/'effect_families.json').read_text())
    cards=json.loads((a.out/'manifest.json').read_text())['cards']
    masks=struct.unpack_from('<8H',rom,0xD4BCFC);equipment=[]
    for r in families:
        if r['kind']!='equipment':continue
        at=int(r['table'],16)-0x08000000;raw=rom[at:at+113]
        ids=[i for i in range(901) if raw[i>>3]&masks[i&7]]
        entry=dict(r,name=cards[r['card_id']]['name'],eligible_card_ids=ids,count=len(ids))
        (a.out/f'equipment-mask-{r["mask"]:02d}.bin').write_bytes(raw);equipment.append(entry)
    recipes=[]
    for i in range(30):
        material,result,other1,other2=struct.unpack_from('<4H',rom,0xD36328+i*8)
        recipes.append(dict(index=i,material=material,result=result,other_materials=[other1,other2],
                            raw_words=[material,result,other1,other2]))
    (a.out/'ritual-recipes.bin').write_bytes(rom[0xD36328:0xD36418])
    immune=[]
    for at in range(0xD36678,0xD36778,2):
        card=struct.unpack_from('<H',rom,at)[0]
        if not card:break
        immune.append(card)
    else:raise ValueError('No immunity-list terminator')
    (a.out/'effect-immunity.bin').write_bytes(rom[0xD36678:at+2])
    trap_lists={}
    for name,offset in [('damage_spells',0xD5113C),('healing_spells',0xD51148),('equipment_spells',0xD51154),('raigeki',0xD51198)]:
        values=[]
        for at in range(offset,offset+512,2):
            v=struct.unpack_from('<H',rom,at)[0]
            if v==0xFFFF:break
            values.append(v)
        else:raise ValueError('Missing trap-list terminator')
        (a.out/f'trap-{name}.bin').write_bytes(rom[offset:at+2])
        trap_lists[name]=dict(rom_address=f'0x{offset+0x08000000:08X}',metadata_1a_indices=values,
                             triggering_card_ids=[c['id'] for c in cards if c['metadata_1a'] in values])
    traps=[dict(kind=i,card_ids=[c['id'] for c in cards if c['metadata_1c']==i]) for i in range(20)]
    guardian_pairs=[list(struct.unpack_from('<2H',rom,0xFB8F4+i*4)) for i in range(3)]
    (a.out/'gate-guardian-material-pairs.bin').write_bytes(rom[0xFB8F4:0xFB900])
    result=dict(rom_sha256=EXPECTED_SHA256,equipment=equipment,ritual_recipes=recipes,
                simple_rituals=[r for r in families if r['kind']=='ritual'],immune_card_ids=immune,
                trap_trigger_lists=trap_lists,trap_kinds=traps,gate_guardian_material_pairs=guardian_pairs,
                notes=['Eligibility tests exact card-ID bits, not a guessed type/category rule.',
                       'Ritual recipes retain raw words. Which recipe is used is selected by the handler.',
                       'Native immunity routine 08018D68 scans the zero-terminated list at08D36678.'])
    (a.out/'effect-rules.json').write_text(json.dumps(result,indent=2)+'\n')
    with (a.out/'equipment-compatibility.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['equipment_id','equipment_name','target_id','target_name'])
        for r in equipment:
            for card in r['eligible_card_ids']:w.writerow([r['card_id'],r['name'],card,cards[card]['name']])
    page=['<!doctype html><meta charset="utf-8"><title>Equipment and ritual rules</title>',
          '<style>body{font:16px system-ui;background:#171c24;color:#eee;margin:2rem}a{color:#9bd7ff}details{padding:1rem;margin:.7rem 0;background:#293243}li{margin:.3rem}table{border-collapse:collapse}td,th{padding:.5rem;text-align:left}</style>',
          '<h1>Equipment and ritual rules</h1><p><a href="index.html">Gameplay</a> · <a href="effect-rules.json">JSON</a> · <a href="equipment-compatibility.csv">Compatibility CSV</a></p>',
          '<h2>Exact equipment eligibility</h2><p>33 ROM bitsets; expand an equipment card to see every accepted target.</p>']
    for r in equipment:
        page.append(f'<details><summary>{html.escape(r["name"])} — {r["count"]} targets</summary><ul>')
        for i in r['eligible_card_ids']:page.append(f'<li>{i}: {html.escape(cards[i]["name"])}</li>')
        page.append('</ul></details>')
    page.append('<h2>Single-material rituals</h2><table><tr><th>Spell</th><th>Required card</th><th>Result</th></tr>')
    for r in result['simple_rituals']:
        page.append('<tr>'+''.join(f'<td>{v}: {html.escape(cards[v]["name"])}</td>' for v in (r['card_id'],r['material'],r['result']))+'</tr>')
    page.append('</table><h2>Immunity list</h2><ul>'+''.join(f'<li>{i}: {html.escape(cards[i]["name"])}</li>' for i in immune)+'</ul>')
    page.append('<h2>Trap rules</h2><p>First eligible opposing trap slot wins. Kinds 2–6 require trigger attack at most 500, 1000, 1500, 2000 or 3000. Immunity is handled during activation. Kinds 0, 10 and 15–19 have empty validation/activation cases.</p>')
    for name,table in trap_lists.items():
        page.append(f'<details><summary>{html.escape(name)} — metadata-1A eligibility list</summary><p>{table["metadata_1a_indices"]}</p><ul>'+''.join(f'<li>{i}: {html.escape(cards[i]["name"])}</li>' for i in table['triggering_card_ids'])+'</ul></details>')
    (a.out/'effect-rules.html').write_text('\n'.join(page)+'\n')
    print(f'Exported {len(equipment)} equipment masks, {len(recipes)} ritual recipes, {len(immune)} immunity IDs')

if __name__=='__main__':main()
