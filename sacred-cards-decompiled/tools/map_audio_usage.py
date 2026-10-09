#!/usr/bin/env python3
"""Conservatively resolve audio IDs within recovered Thumb basic blocks."""
import argparse
import csv
import hashlib
import html
import json
import re
import struct
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256

TARGETS={0x08021E50:'PlayGameAudio',0x080379B4:'m4aSongNumStart',0x080379E0:'m4aSongNumStartOrChange'}
CONTEXTS={0x08000958:'City-map menu entry (calls background loader 0x08000A64)',
          0x0800182E:'Name-entry screen initialization',
          0x080018DC:'Name-entry input: mode change',
          0x0800192E:'Name-entry input: alternate mode-change path'}


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path)
    ap.add_argument('--disassembly',type=Path,default=Path('build/disassembly'))
    ap.add_argument('--out',type=Path,default=Path('build/assets/audio'));a=ap.parse_args()
    rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    report_path=a.disassembly/'expanded_report.json';listing_path=a.disassembly/'expanded.asm'
    if not report_path.exists() or not listing_path.exists():
        print('Audio usage map requires make expand first; skipped');return
    report=json.loads(report_path.read_text());listing=listing_path.read_text()
    if int(report['rom_size'])!=len(rom):raise SystemExit('Disassembly ROM size differs')
    # Report coverage includes heuristic seeds; record that limitation explicitly.
    blocks={int(b['address'],16) for b in report['basic_block_starts']}
    calls={int(e['from'],16):int(e['to'],16) for e in report['direct_call_edges'] if int(e['to'],16) in TARGETS}
    regs={};rows=[];history=[];previous=None
    def value(token):
        if token.startswith('#'):
            try:return int(token[1:],0)
            except ValueError:return None
        return regs.get(token)
    for line in listing.splitlines():
        m=re.match(r'^([0-9A-F]{8})\s+thumb\s+(\S+)\s*(.*)',line)
        if not m:continue
        at=int(m[1],16);op=m[2];args=m[3].split(';')[0].strip();parts=[p.strip() for p in args.split(',')]
        if at in blocks or previous!=at:regs={};history=[]
        previous=at+(4 if op in ('bl','blx') else 2)
        if at in calls:
            raw=regs.get('r0');song=(raw&65535) if raw is not None else None
            rows.append(dict(callsite=f'0x{at:08X}',target=TARGETS[calls[at]],song_id=song,
                             resolution='constant in same basic block' if song is not None else 'dynamic or unresolved',
                             context=CONTEXTS.get(at,''),evidence=history[-8:]+[line]))
        history.append(line)
        if op in ('bl','blx'):
            # Only retain values in callee-saved registers.
            for reg in ['r0','r1','r2','r3','r12','lr']:regs.pop(reg,None)
            continue
        if op in ('mov','movs') and len(parts)==2:
            v=value(parts[1]);regs.pop(parts[0],None)
            if v is not None:regs[parts[0]]=v&0xFFFFFFFF
        elif op in ('adds','subs','lsls','lsrs') and len(parts) in (2,3):
            left=value(parts[-2] if len(parts)==3 else parts[0]);right=value(parts[-1]);regs.pop(parts[0],None)
            if left is not None and right is not None:
                v=(left+right if op=='adds' else left-right if op=='subs' else left<<right if op=='lsls' else left>>right)
                regs[parts[0]]=v&0xFFFFFFFF
        elif op=='ldr' and (lit:=re.fullmatch(r'(r\d+), \[pc(?:, #(0x[0-9a-f]+|\d+))?\]',args)):
            offset=((at+4)&~3)+int(lit[2] or '0',0)-0x08000000
            regs[lit[1]]=struct.unpack_from('<I',rom,offset)[0]
        elif op in ('cmp','cmn','tst','str','strb','strh','push','nop'):pass
        else:
            # Unknown instructions and branches discard all facts rather than
            # infer through memory, flag-dependent paths, or multi-register writes.
            regs={}
    a.out.mkdir(parents=True,exist_ok=True)
    groups={}
    for row in rows:
        if row['song_id'] is not None:groups.setdefault(row['song_id'],[]).append(row)
    decoded_path=a.out.parent/'scripts/decoded.json'
    script_audio=[]
    if decoded_path.exists():
        decoded=json.loads(decoded_path.read_text())
        if decoded['rom_sha256']!=EXPECTED_SHA256:raise SystemExit('Script revision differs')
        script_audio=decoded['audio_references']
    # Reviewed sources for all ten nonconstant callsites in this listing.
    # Domains are table/input possibilities, not observed runtime choices.
    opponent_songs=sorted({struct.unpack_from('<I',rom,struct.unpack_from('<I',rom,0xD35C28+i*4)[0]-0x08000000+36)[0] for i in range(200)})
    dynamic={
        '0x08017D54':('Opponent record +0x24, copied to RAM02020D38 by08017CA8',opponent_songs),
        '0x080183C8':('Merged menu branches: navigation54 or confirmation55',[54,55]),
        '0x0801A75E':('Merged shop branches: cancel56 or rejected action57',[56,57]),
        '0x0801ADB4':('Merged shop branches: cancel56 or rejected action57',[56,57]),
        '0x08021E8A':('PlayGameAudio argument, category1',[i for i in range(225) if rom[0xD1278+i*2]==1]),
        '0x08021E92':('PlayGameAudio argument, categories2/3',[i for i in range(225) if rom[0xD1278+i*2] in (2,3)]),
        '0x08021EA6':('PlayGameAudio argument, category5',[i for i in range(225) if rom[0xD1278+i*2]==5]),
        '0x0803117A':('Matched scene/variant override at08D4C8F4',sorted({r[2]&65535 for r in struct.iter_unpack('<hhh',rom[0xD4C8F4:0xD4C8F4+27*6])})),
        '0x080311A2':('Scene default music at08D4C87C',sorted(set(struct.unpack_from('<58H',rom,0xD4C87C)))),
        '0x08032120':('Script @8 byte operand, excluding111/122/123; domain is the traced449-root graph',sorted({r['song_id'] for r in script_audio if not r['suppressed']}))}
    for row in rows:
        if row['song_id'] is None and row['callsite'] in dynamic:
            row['value_source'],row['possible_song_ids']=dynamic[row['callsite']]
            row['resolution']='reviewed dynamic source; possible IDs are not runtime observations'
    payload=dict(rom_sha256=EXPECTED_SHA256,listing_sha256=hashlib.sha256(listing.encode()).hexdigest(),
                 script_audio_references=script_audio,
                 dynamic_sources_classified=sum('value_source' in r for r in rows),
                 calls=rows,known_song_ids=sorted(groups),notes=[
                     'Static direct call sites in the expanded heuristic listing, not runtime playback observations.',
                     'Constants propagate only within one recovered basic block. Reviewed dynamic sources are annotated separately, with bounded table/branch domains.',
                     'Absence from this map does not mean unused: scene tables, scripts and indirect calls also select audio.',
                     'Context labels describe demonstrated uses, not official track or sound-effect titles.'])
    (a.out/'usage.json').write_text(json.dumps(payload,indent=2)+'\n')
    with (a.out/'usage.csv').open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=['callsite','target','song_id','resolution','context','value_source','possible_song_ids']);w.writeheader()
        w.writerows({k:v for k,v in r.items() if k!='evidence'} for r in rows)
    catalog_path=a.out/'catalog.csv';catalog={}
    if catalog_path.exists():
        with catalog_path.open() as f:catalog={int(r['id']):r for r in csv.DictReader(f)}
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><title>Audio uses</title>',
          '<style>body{background:#171c24;color:#eee;font:16px system-ui;margin:30px;max-width:1100px}a{color:#9bd7ff}article{padding:16px;margin:16px 0;background:#252c38}code,pre{font-size:13px}pre{overflow:auto}audio{width:100%;max-width:450px}</style>',
          '<h1>Audio call-site map</h1><p><a href="index.html">Listening gallery</a> · <a href="usage.json">Evidence JSON</a> · <a href="usage.csv">CSV</a></p>',
          f'<p>{len(rows)} recovered direct calls; {sum(r["song_id"] is not None for r in rows)} constant IDs; {len(groups)} distinct IDs. Coverage is partial and includes heuristic code candidates. Scene mappings remain in the listening gallery.</p>']
    script_groups={}
    for ref in script_audio:script_groups.setdefault(ref['song_id'],[]).append(ref)
    for song in sorted(set(groups)|set(script_groups)):
        uses=groups.get(song,[])
        row=catalog.get(song,{});wav=row.get('wav','')
        page.append(f'<article id="song-{song:03d}"><h2>Audio {song:03d} · {html.escape(row.get("kind","unknown"))}</h2>')
        if wav:page.append(f'<audio controls preload="none" src="{html.escape(wav,quote=True)}"></audio>')
        for use in uses:
            page.append(f'<details><summary>{use["callsite"]} — {html.escape(use["context"] or use["target"])}</summary><pre>{html.escape(chr(10).join(use["evidence"]))}</pre></details>')
        if song in script_groups:
            refs=script_groups[song]
            page.append(f'<details><summary>{len(refs)} script references</summary>')
            for ref in refs:
                suffix=' (suppressed by the native handler)' if ref['suppressed'] else ''
                page.append(f'<p><a href="../scripts/decoded.html#{ref["node"]}">{ref["node"]}</a> +{ref["offset"]:X}, language {ref["language"]}{suffix}</p>')
            page.append('</details>')
        page.append('</article>')
    page.append('<h2>Dynamic calls</h2><p>Reviewed sources and possible IDs are static evidence, not playback observations. Table domains assume valid game inputs.</p>')
    for r in rows:
        if r['song_id'] is None:page.append(f'<details><summary>{r["callsite"]} → {r["target"]}</summary><p>{html.escape(r.get("value_source","Source not recovered"))}</p><p>Possible IDs: {html.escape(str(r.get("possible_song_ids",[])))}</p></details>')
    (a.out/'usage.html').write_text('\n'.join(page)+'\n')
    print(f'Audio usage: {len(rows)} direct calls, {sum(r["song_id"] is not None for r in rows)} resolved constants, {len(groups)} distinct IDs')

if __name__=='__main__':main()
