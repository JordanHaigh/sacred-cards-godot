#!/usr/bin/env python3
"""Connect native resource addresses, exported bytes and maintained C users.

Only byte-identical file slices are called original spans. Manifest relationships
and pointer-table entries retain their provenance; an address-shaped word is not
by itself a newly identified asset.
"""
import argparse,bisect,csv,hashlib,json,math,re,struct
from collections import defaultdict
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256

ROOT=Path(__file__).resolve().parents[1]
BASE=0x08000000
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path);a=ap.parse_args()
    rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    assets=ROOT/'build/assets';out=assets/'runtime';out.mkdir(parents=True,exist_ok=True)
    archive=json.loads((assets/'rom-data/manifest.json').read_text());archive_base=int(archive['native_base'],16)
    spans={};uses=defaultdict(list);relations=[]
    def address(value,offset=False):
        if not isinstance(value,(int,str)):return None
        try:n=int(value,16) if isinstance(value,str) and re.fullmatch(r'(?:0x)?[0-9a-fA-F]+',value) else int(value)
        except (ValueError,TypeError):return None
        if offset:n+=BASE
        return n if BASE<=n<BASE+len(rom) else None
    def add_span(path,at,provenance):
        if at is None or not path.is_file() or path.suffix.lower() in ('.png','.wav','.mid','.sf2','.html','.csv','.json'):return
        data=path.read_bytes()
        if not data:return
        relative=str(path.relative_to(assets));same=data==rom[at-BASE:at-BASE+len(data)]
        relations.append(dict(address=f'0x{at:08X}',file=relative,byte_identical=same,provenance=provenance))
        if same:
            spans[(at,relative)]=dict(id='asset:'+relative,file=relative,address=f'0x{at:08X}',size=len(data),sha256=hashlib.sha256(data).hexdigest())
    def walk(value,path,trail):
        if isinstance(value,list):
            for i,v in enumerate(value):walk(v,path,trail+'/'+str(i))
        elif isinstance(value,dict):
            for key,v in value.items():
                # Explicit address fields, not arbitrary values such as music
                # IDs, color words or dimensions.
                if 'address' in key or key.endswith('rom_offset') or key in ('next_if_zero','next_if_nonzero'):
                    for index,item in enumerate(v if isinstance(v,list) else [v]):
                        at=address(item,'rom_offset' in key)
                        suffix='/'+str(index) if isinstance(v,list) else ''
                        if at is not None:uses[at].append(dict(kind='manifest',file=str(path.relative_to(assets)),field=trail+'/'+key+suffix))
            pairs=[('file','rom_offset',True),('file','address',False),('file','rom_address',False),
                   ('record_file','address',False),('deck_file','deck_address',False),
                   ('raw_header','header_rom_offset',True),('raw_node','address',False),
                   ('raw_payload_window','payload_address',False)]
            for file_key,at_key,is_offset in pairs:
                if isinstance(value.get(file_key),str) and value.get(at_key) is not None:
                    add_span(path.parent/value[file_key],address(value[at_key],is_offset),str(path.relative_to(assets))+trail)
            for k,v in value.items():walk(v,path,trail+'/'+k)
    for path in sorted(assets.rglob('manifest.json')):
        if path.parent.name!='rom-data':walk(json.loads(path.read_text()),path,'')
    # Native immutable table views are also independently usable byte files.
    tables=json.loads((ROOT/'build/semantic/runtime_tables.json').read_text())['tables'];table_records=[];pointer_edges=[]
    widths={'uint8_t':1,'int8_t':1,'uint16_t':2,'int16_t':2,'uint32_t':4,'int32_t':4,'uint64_t':8,
            'struct AiAction':8,'struct AiAttackTag':8,'struct SceneVariantRule':24,'struct SceneMusicOverride':6,
            'struct SongEntry':8,'struct PlayerEntry':12,'struct SaveRegion':8}
    for t in tables:
        at=int(t['address'],16);count=math.prod(t['dimensions']);width=4 if '*' in t['type'] else widths[t['type']]
        path=out/'tables'/(t['symbol']+'.bin');path.parent.mkdir(parents=True,exist_ok=True)
        path.write_bytes(rom[at-BASE:at-BASE+count*width]);add_span(path,at,'build/semantic/runtime_tables.json')
        table_records.append(dict(t,file=str(path.relative_to(assets)),element_size=width,size=count*width))
        if '*' in t['type'] or t['symbol'] in ('gCardNameAddresses','gCardDescriptionAddresses'):
            for i in range(count):
                target=struct.unpack_from('<I',rom,at-BASE+i*4)[0]
                edge=dict(table=t['symbol'],index=i,slot=f'0x{at+i*4:08X}',target=f'0x{target:08X}')
                pointer_edges.append(edge)
                if BASE<=target<BASE+len(rom):uses[target].append(dict(kind='table_pointer',table=t['symbol'],index=i))
    # Pointer fields inside reviewed records are distinct from scalar words
    # that merely happen to resemble addresses. Read and check their slots.
    def edge(slot,origin,expected=None):
        target=struct.unpack_from('<I',rom,slot-BASE)[0]
        if expected is not None and target!=expected:raise ValueError('Pointer field differs: '+origin)
        kind='null' if target==0 else 'rom' if BASE<=target<BASE+len(rom) else 'ram' if 0x02000000<=target<0x02040000 or 0x03000000<=target<0x03008000 else 'other_native_address'
        pointer_edges.append(dict(origin=origin,slot=f'0x{slot:08X}',target=f'0x{target:08X}',target_kind=kind))
        if BASE<=target<BASE+len(rom):uses[target].append(dict(kind='record_pointer',slot=f'0x{slot:08X}',origin=origin))
    for t in tables:
        at=int(t['address'],16)
        fields={'struct SongEntry':[(0,'header')],'struct PlayerEntry':[(0,'player'),(4,'tracks')],'struct SaveRegion':[(0,'ram')]}.get(t['type'],[])
        for i in range(math.prod(t['dimensions'])):
            for offset,name in fields:edge(at+i*widths[t['type']]+offset,f'{t["symbol"]}[{i}].{name}')
    scripts=json.loads((assets/'scripts/manifest.json').read_text())
    for n in scripts['nodes']:
        at=int(n['address'],16)
        for offset,key in [(0,'payload_address'),(4,'next_if_zero'),(8,'next_if_nonzero')]:edge(at+offset,'script:'+n['address']+'.'+key,int(n[key],16) if n[key] else 0)
    opponents=json.loads((assets/'opponents/manifest.json').read_text())
    for r in opponents['records']:
        at=int(r['address'],16);edge(at+4,f'opponent:{r["index"]}.deck',int(r['deck_address'],16))
        for offset,key in [(8,'normal'),(12,'shop'),(16,'special')]:edge(at+offset,f'opponent:{r["index"]}.reward.{key}',int(r['reward_tables'][key],16))
    portraits=json.loads((assets/'portraits/manifest.json').read_text())
    for p in portraits['portraits']:
        for part,frames in enumerate(p['groups']):
            edge(int(p['parts_address'],16)+part*4,f'portrait:{p["id"]}.part:{part}')
            for f in frames:edge(int(f['descriptor_address'],16)+4,f'portrait:{p["id"]}.part:{part}.frame:{f["index"]}.oam',int(f['oam_address'],16))
    world=json.loads((assets/'world/manifest.json').read_text())
    for scene in world['scenes']:
        sid=scene['scene'];edge(BASE+0xD51870+sid*4,f'scene:{sid}.grid',BASE+int(scene['grid_file']['rom_offset'],16))
        edge(BASE+0xD548B8+sid*4,f'scene:{sid}.variants',int(scene['variant_pointer_table'],16))
        for v in scene['variants']:
            vid=v['variant'];at=BASE+int(v['raw_file']['rom_offset'],16)
            edge(int(scene['variant_pointer_table'],16)+vid*4,f'scene:{sid}.variant:{vid}',at)
            for offset,key in [(0x140,'scene_script_a'),(0x144,'scene_script_b')]:edge(at+offset,f'scene:{sid}.variant:{vid}.{key}',int(v[key],16))
            for actor in v['actors']+v['player_spawns']:
                pos=BASE+int(actor['rom_offset'],16)
                for offset,key in [(8,'script_a'),(12,'script_b')]:edge(pos+offset,f'actor-config:{pos:08X}.{key}',int(actor[key],16))
    audio=json.loads((assets/'audio/manifest.json').read_text())
    for song in audio['slots']:
        if not song['tracks']:continue
        at=BASE+int(song['header_rom_offset'],16)
        edge(at+4,f'audio:{song["id"]}.bank',BASE+int(song['bank_rom_offset'],16))
        for i,offset in enumerate(song['track_rom_offsets']):edge(at+8+i*4,f'audio:{song["id"]}.track:{i}',BASE+int(offset,16))
    # Gameplay callback tables are stored in separate semantic catalogs rather
    # than manifest.json. Preserve their native slots and link code targets to
    # the existing source-location inventory below.
    ai_path=assets/'gameplay/ai.json';ai=json.loads(ai_path.read_text());walk(ai,ai_path,'')
    for name,table in ai['callbacks'].items():
        at=int(table['rom_address'],16)
        for i,pointer in enumerate(table['pointers']):edge(at+i*4,f'ai:{name}[{i}]',int(pointer,16))
    for table in ai['card_scoring_views']:
        at=int(table['address'],16)
        for i,pointer in enumerate(table['pointers']):edge(at+i*4,f'ai-card-score:{table["name"]}[{i}]',int(pointer,16))
    effects_path=assets/'gameplay/effects.json';effects=json.loads(effects_path.read_text());walk(effects,effects_path,'')
    for table in effects['tables']:
        at=BASE+int(table['rom_offset'],16)
        for entry in table['entries']:edge(at+entry['index']*4,f'card-effect:{table["field"]}[{entry["index"]}]',int(entry['pointer'],16))
    # Comments and quoted text contain source locators and prose, not reads.
    strip=re.compile(r'/\*.*?\*/|//[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'',re.S)
    for p in sorted((ROOT/'src').glob('*')):
        if p.suffix not in ('.c','.h'):continue
        text=strip.sub(lambda m:'\n'*m.group().count('\n') if m.group().startswith(('/', '"', "'")) else m.group(),p.read_text())
        for m in re.finditer(r'\b0x0[89][0-9a-fA-F]{6}\b',text):
            at=int(m.group(),16)
            if at<BASE+len(rom):uses[at].append(dict(kind='source_literal',file=str(p.relative_to(ROOT)),line=text.count('\n',0,m.start())+1))
    report=json.loads((ROOT/'build/disassembly/reachable_report.json').read_text())
    for r in report['resolved_pc_relative_literals']:
        at=int(r['value'],16)
        if BASE<=at<BASE+len(rom):uses[at].append(dict(kind='native_literal',instruction=r['instruction'],pool=r['literal_address']))
    spans=sorted(spans.values(),key=lambda s:(int(s['address'],16),s['file']))
    starts=[int(s['address'],16) for s in spans];maximum=[];end=0
    for at,s in zip(starts,spans):end=max(end,at+s['size']);maximum.append(end)
    roots={int(r['address'],16) for r in csv.DictReader((ROOT/'build/decompiled/functions.csv').open())}
    coverage=json.loads((ROOT/'build/research/function-coverage.json').read_text())
    functions={int(r['address'],16):dict(name=r['name'],source_locations=r['source_locations'],
               shared_implementation=r['shared_implementation'],inventory_status=r['status']) for r in coverage['functions']}
    def resolve(at):
        matches=[];i=bisect.bisect_right(starts,at)-1
        while i>=0 and maximum[i]>at:
            s=spans[i]
            if starts[i]+s['size']>at:matches.append(dict(id=s['id'],file_offset=at-starts[i]))
            i-=1
        native_code=(at&~1) in roots
        return dict(address=f'0x{at:08X}',id=f'native:{at:08X}',known_function_entry=native_code,
                    native_function=functions.get(at&~1),
                    exported_spans=matches,archive=None if at<archive_base else dict(file='rom-data/'+archive['file'],offset=at-archive_base))
    references=[]
    for at,rows in sorted(uses.items()):
        unique=list({json.dumps(r,sort_keys=True):r for r in rows}.values())
        references.append(dict(resolve(at),uses=unique))
    result=dict(rom_sha256=EXPECTED_SHA256,kind='Native resource provenance and address translation',
                address_width=4,byte_order='little',archive=archive,original_file_spans=spans,
                tables=table_records,pointer_edges=pointer_edges,manifest_file_relationships=relations,references=references,
                notes=['IDs are address/file provenance, not invented asset names.',
                       'An original span was compared to the ROM as static data; decoded products may have different layouts.',
                       'Archive fallback retains bytes without claiming their semantic type or object boundary.',
                       'Source and native literal references include code pointers and base constants; they are not all asset dereferences.',
                       'native_function is a source-location inventory; it does not certify behavioral equivalence.',
                       'Use exported_spans.file_offset or archive.offset to translate a native address; preserve pointer arithmetic and overlapping views.'])
    (out/'resources.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'{len(spans)} original file spans, {len(tables)} table exports, {len(pointer_edges)} typed pointer edges, {len(references)} referenced ROM addresses')
if __name__=='__main__':main()
