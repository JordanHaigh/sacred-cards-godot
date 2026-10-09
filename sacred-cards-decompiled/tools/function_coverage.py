#!/usr/bin/env python3
"""Inventory recovered source locations and reviewed shared-function mappings.

A source address reference is a locator, not a proof of semantic equivalence.
The explicit family file records reviewed mappings when the C factors several
native entries into one helper. Neither inventory establishes execution parity.
"""
import json,re
from collections import defaultdict,Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BASE=0x08000000
END=0x0803B61C

def address(token):
    n=int(token,16)
    if n<BASE:n+=BASE
    return f'{n:08X}' if BASE<=n<END else None

def main():
    manifest=json.loads((ROOT/'build/decompiled/manifest.json').read_text())
    locations=defaultdict(set)
    paths=list((ROOT/'src').glob('*.[chs]'))+[ROOT/'build/semantic/ai_card_scorers.c']
    texts={str(p.relative_to(ROOT)):p.read_text() for p in paths if p.exists()}
    for path,text in texts.items():
        for match in re.finditer(r'080[0-3][0-9a-fA-F]{4}|(?<![0-9a-fA-F])(?:0x)?([0-9a-fA-F]{5,8})(?![0-9a-fA-F])',text):
            token=match[1] or match[0]
            a=address(token)
            if a:locations[a].add(path)
        # Abbreviated adjacent addresses in source comments, e.g.08019EC4/EF0.
        for comment in re.findall(r'/\*.*?\*/',text,re.S):
            previous=None
            for m in re.finditer(r'(?<![0-9a-fA-F])(?:0x)?([0-9a-fA-F]{3,8})(?![0-9a-fA-F])',comment):
                token=m[1]
                if len(token)>=5:
                    a=address(token)
                    if a:previous=int(a,16)
                elif previous is not None and re.search(r'/\s*$',comment[:m.start()]):
                    n=(previous&~((1<<(4*len(token)))-1))|int(token,16);a=address(f'{n:X}')
                    if a:locations[a].add(path)
    for name in ['semantic_handlers.json','semantic_ai_callbacks.json','semantic_script_events.json','build/semantic/ai_card_scorers.json']:
        p=ROOT/name
        if not p.exists():continue
        data=json.loads(p.read_text())
        for row in data.get('entries',data.get('functions',[])):
            a=address(str(row.get('address','0')).replace('0x',''))
            if a:locations[a].add(name)
    families=json.loads((ROOT/'semantic_function_families.json').read_text())['families']
    explicit={}
    for row in families:
        for a in row['addresses']:
            if a in explicit:raise ValueError(f'duplicate family mapping {a}')
            if not (ROOT/row['source']).is_file():raise ValueError(row['source'])
            explicit[a]={k:v for k,v in row.items() if k!='addresses'}
    results=[]
    for f in manifest['functions']:
        a=f['address'].upper();paths=sorted(locations[a])
        if not f['name'].startswith(('sub_','UnusedNoop_')):
            paths+= [p for p,s in texts.items() if re.search(r'\b'+re.escape(f['name'])+r'\s*\(',s) and p not in paths]
        mapping=explicit.get(a)
        results.append(dict(address=a,name=f['name'],automatic_draft='build/decompiled/'+f['file'],
                            source_locations=paths,shared_implementation=mapping,
                            status='reviewed_shared_mapping' if mapping else 'source_locator' if paths else 'unmapped'))
    out=dict(rom_sha256=manifest['rom_sha256'],scope='Known code roots; static source-location inventory, not execution equivalence',
             function_count=len(results),counts=dict(Counter(r['status'] for r in results)),
             all_rom_code_discovered=False,execution_compared=False,functions=results)
    dest=ROOT/'build/research/function-coverage.json';dest.write_text(json.dumps(out,indent=2)+'\n')
    missing=[r for r in results if r['status']=='unmapped']
    (ROOT/'build/research/unmapped-functions.json').write_text(json.dumps(missing,indent=2)+'\n')
    print(f'{len(results)} roots: {out["counts"]}')
    for r in missing:print(r['address'],r['name'])
if __name__=='__main__':main()
