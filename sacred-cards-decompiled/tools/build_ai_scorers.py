#!/usr/bin/env python3
"""Recover exact tiny Thumb scorer templates and emit card-scoring tables.

Only BX LR, a reviewed seven-instruction constant store and a reviewed
push/BL/pop/BX wrapper are recognized. Everything else stays an explicit native
dependency unless a maintained AiCardScore_ADDRESS implementation exists.
This is semantic template recovery, not compiler matching or execution proof.
"""
import argparse,csv,hashlib,json,re,struct
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256

ROOT=Path(__file__).resolve().parents[1]
TABLES=[('gAiSpellBefore',0xD34B80,132),('gAiSpellAfter',0xD34D88,132),
        ('gAiMonsterBefore',0xD353A0,85),('gAiMonsterAfter',0xD35530,85)]

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path);args=ap.parse_args()
    rom=args.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    def word(address):return struct.unpack_from('<I',rom,address-0x08000000)[0]
    tables={name:list(struct.unpack_from('<'+'I'*count,rom,at)) for name,at,count in TABLES}
    manual={}
    for p in (ROOT/'src').glob('*.c'):
        for a in re.findall(r'\bvoid AiCardScore_([0-9A-F]{8})\(void\)\s*\{',p.read_text()):manual[int(a,16)]=str(p.relative_to(ROOT))
    records={}
    def recover(address):
        if address in records:return
        entry=dict(address=f'0x{address:08X}',kind='native_dependency',function=f'Native_{address:08X}')
        records[address]=entry
        if address in manual:
            entry.update(kind='maintained',source=manual[address],function=f'AiCardScore_{address:08X}');return
        at=address-0x08000000
        if not 0<=at<len(rom)-28:return
        h=struct.unpack_from('<7H',rom,at)
        if h[0]==0x4770:entry.update(kind='immediate_return')
        elif address%4==0 and h==(0x4803,0x6800,0x4903,0x1840,0x4903,0x6001,0x4770):
            pointer,offset,value=struct.unpack_from('<3I',rom,at+16)
            if not 0x08000000<=pointer<0x09000000 or word(pointer)!=0x02018800 or offset!=0x14F0:return
            entry.update(kind='constant_score',score=f'0x{value:08X}',scratch_pointer_literal=f'0x{pointer:08X}')
        elif h[0]==0xB500 and h[1]&0xF800==0xF000 and h[2]&0xF800==0xF800 and h[3:5]==(0xBC01,0x4700):
            displacement=((h[1]&0x7FF)<<12)|((h[2]&0x7FF)<<1)
            if displacement&0x400000:displacement-=0x800000
            target=address+6+displacement
            entry.update(kind='call_wrapper',target=f'0x{target:08X}');recover(target)
        else:return
        entry['function']=f'AiCardScore_{address:08X}'
        entry['source']='build/semantic/ai_card_scorers.c'
    for values in tables.values():
        for p in values:recover(p&~1)
    # The ROM also retains unused score setters outside the active tables.
    # Recover only the same exact instruction templates, from discovered roots.
    for row in csv.DictReader((ROOT/'build/decompiled/functions.csv').open()):
        address=int(row['address'],16)
        if not 0x08009248<=address<0x08011400 or address in records:continue
        h=struct.unpack_from('<7H',rom,address-0x08000000)
        if h[0]==0x4770 or (address%4==0 and h==(0x4803,0x6800,0x4903,0x1840,0x4903,0x6001,0x4770)):
            recover(address)
    lines=['/* Generated from exact reviewed Thumb templates; unsupported bodies remain Native dependencies. */',
           '#include <stdint.h>','extern uint8_t *gAiScratch;',
           'static void StoreScore(uint32_t n) { for (unsigned i=0;i<4;++i) gAiScratch[0x14F0+i]=(uint8_t)(n>>(i*8)); }']
    for a,e in sorted(records.items()):lines.append(f'extern void {e["function"]}(void);')
    for a,e in sorted(records.items()):
        kind=e['kind']
        if kind in ('native_dependency','maintained'):continue
        if kind=='immediate_return':body=''
        elif kind=='constant_score':body=f'StoreScore({e["score"]}u);'
        else:body=records[int(e['target'],16)]['function']+'();'
        lines.append(f'void {e["function"]}(void) {{ {body} }}')
    for name,values in tables.items():
        lines.append(f'void (*const {name}[{len(values)}])(void) = {{')
        lines.extend(f'    {records[p&~1]["function"]}, /* {i}: 0x{p:08X} */' for i,p in enumerate(values))
        lines.append('};')
    out=ROOT/'build/semantic';out.mkdir(parents=True,exist_ok=True)
    (out/'ai_card_scorers.c').write_text('\n'.join(lines)+'\n')
    manifest=dict(rom_sha256=EXPECTED_SHA256,kind='Reviewed instruction-template recovery with explicit unsupported native bodies',
                  execution_compared=False,compiler_matched=False,
                  notes=['Spell views retain all 132 metadata indices. Entries 130/131 overlap the adjacent physical pointer table; no invented bounds guard is added.',
                         'Wrapper recovery does not mean its callee is recovered.'],
                  tables=[dict(name=name,address=f'0x{at+0x08000000:08X}',count=count,entries=[records[p&~1]['address'] for p in tables[name]]) for name,at,count in TABLES],
                  functions=[e for a,e in sorted(records.items())])
    (out/'ai_card_scorers.json').write_text(json.dumps(manifest,indent=2)+'\n')
    from collections import Counter
    print(dict(Counter(e['kind'] for e in records.values())))

if __name__=='__main__':main()
