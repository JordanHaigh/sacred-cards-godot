#!/usr/bin/env python3
"""Expand reviewed state views with declaration types, users and overlap groups."""
import json,re,math
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]

def main():
    registry=json.loads((ROOT/'state_views.json').read_text())
    contracts=json.loads((ROOT/'build/research/source-contracts.json').read_text())
    linkage=json.loads((ROOT/'build/research/semantic-linkage.json').read_text())
    literals=json.loads((ROOT/'build/disassembly/reachable_report.json').read_text())['resolved_pc_relative_literals']
    ramrefs={}
    for r in literals:ramrefs.setdefault(int(r['value'],16),set()).add(r.get('instruction_address',r.get('instruction',r.get('from',r.get('address','')))))
    types=contracts['variables'];record_cache={}
    scalars={'uint8_t':(1,1),'int8_t':(1,1),'uint16_t':(2,2),'int16_t':(2,2),'uint32_t':(4,4),'int32_t':(4,4),'uint64_t':(8,8),'int64_t':(8,8),'uintptr_t':(4,4),'unsigned char':(1,1),'signed char':(1,1),'unsigned short':(2,2),'short':(2,2),'unsigned int':(4,4),'int':(4,4),'unsigned long':(4,4),'long':(4,4)}
    scalars.update({'unsigned long long':(8,8),'long long':(8,8)})
    def size_align(t):
        dims=re.findall(r'\[(\d*)\]',t);base=re.sub(r'\[[^]]*\]','',t)
        base=re.sub(r'\b(?:const|volatile|restrict)\b','',base);base=' '.join(base.split())
        if '*' in base:size,alignment=4,4
        elif base in scalars:size,alignment=scalars[base]
        elif base.startswith('struct '):
            name=base[7:]
            if name not in record_cache:
                fields=contracts['records'][name][0]['fields'];offset=0;alignment=1
                for f in fields:
                    n,a=size_align(f['type']);offset=(offset+a-1)//a*a;offset+=n;alignment=max(alignment,a)
                record_cache[name]=((offset+alignment-1)//alignment*alignment,alignment)
            size,alignment=record_cache[name]
        else:raise ValueError('Unknown declaration type '+t)
        for d in dims:
            if not d:return None,alignment
            size*=int(d)
        return size,alignment
    views=[]
    for r in registry['views']:
        name=r['symbol'];decls=types[name];ts=sorted({d['type'] for d in decls})
        sizes=[size_align(t)[0] for t in ts];known={n for n in sizes if n is not None}
        if len(known)>1:raise ValueError(f'Conflicting declared sizes: {name}: {sizes}')
        size=r.get('view_size',next(iter(known),None))
        if size is None:raise ValueError('Unbounded view without reviewed extent: '+name)
        if 'record_type' in r:
            layout=contracts['record_layouts'][r['record_type']]
            record_extent=layout['size']*math.prod(r.get('record_dimensions',[]))
            if record_extent!=size:raise ValueError(f'Record view extent differs for {name}: {record_extent} != {size}')
        at=int(r['native_address'],16) if r['native_address'] else None
        v=dict(r,size=size,declaration_types=ts,sources=sorted({d['source'] for d in decls}),object_users=linkage['unresolved_symbols'].get(name,[]),literal_code_references=sorted(ramrefs.get(at,set())))
        views.append(v)
    for v in views:
        if v['kind']=='rom_pointer_view' and v.get('pointee_address'):
            target=int(v['pointee_address'],16)
            v['pointee_storage_views']=[b['symbol'] for b in views if b['kind']=='ram_view' and int(b['native_address'],16)<=target<int(b['native_address'],16)+b['size']]
    have={r['symbol'] for r in views};expected={s for s in linkage['unresolved_symbols'] if s.startswith('g')}
    if expected-have:raise ValueError('Unmapped state symbols: '+str(sorted(expected-have)))
    # Address intersections are physical views, including named fields nested in
    # larger records. A connected component is a storage group, not a lifetime.
    edges=[];parent=list(range(len(views)))
    def find(i):
        while parent[i]!=i:parent[i]=parent[parent[i]];i=parent[i]
        return i
    for i,a in enumerate(views):
        if a['kind']!='ram_view':continue
        aa=int(a['native_address'],16)
        for j in range(i):
            b=views[j]
            if b['kind']!='ram_view':continue
            bb=int(b['native_address'],16);lo=max(aa,bb);hi=min(aa+a['size'],bb+b['size'])
            if lo<hi:
                edges.append(dict(a=a['symbol'],b=b['symbol'],start=f'0x{lo:08X}',size=hi-lo))
                parent[find(i)]=find(j)
    groups={}
    for i,v in enumerate(views):
        if v['kind']=='ram_view':groups.setdefault(find(i),[]).append(v)
    groups=[dict(start=f'0x{min(int(v["native_address"],16) for v in vs):08X}',end_exclusive=f'0x{max(int(v["native_address"],16)+v["size"] for v in vs):08X}',views=[v['symbol'] for v in vs]) for vs in groups.values()]
    result=dict(rom_sha256=registry['rom_sha256'],kind='Reviewed data views with statically inventoried types and physical aliasing',pointer_width=4,byte_order='little',views=views,overlaps=edges,storage_groups=groups,
                records={k:dict(fields=v[0]['fields'],target_layout=contracts.get('record_layouts',{}).get(k,{})) for k,v in contracts['records'].items() if k.startswith('Ay7e') or k in ('AiAction','EffectInput','MonsterInput','TrapInput','LinkState','MusicPlayer')},
                notes=['View extents are native declared/accessed contracts, not allocations of independent host variables.',
                       'Native addresses are provenance. Rebuilds may use typed state and IDs while preserving aliases and observable lifetime behavior.',
                       'The register-context entry has no original global address; its value must come from emulated/native caller context.',
                       'Literal references are evidence of address use, not proof of a whole declaration contract.'])
    for p in [ROOT/'build/research/state-contracts.json',ROOT/'build/assets/runtime/state-contracts.json']:
        p.write_text(json.dumps(result,indent=2)+'\n')
    print(f'{len(views)} state views, {len(groups)} RAM storage groups, {len(edges)} physical intersections; all {len(expected)} object data dependencies mapped')
if __name__=='__main__':main()
