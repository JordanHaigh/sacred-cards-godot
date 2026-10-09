#!/usr/bin/env python3
"""Export scene-reachable script nodes and conservative payload windows."""
import argparse
from bisect import bisect_right
from collections import defaultdict, deque
import hashlib
import html
import json
from pathlib import Path
import re
import struct
from rip_asset_tables import EXPECTED_SHA256


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('rom',type=Path)
    ap.add_argument('--out',type=Path,default=Path('build/assets/scripts'))
    args=ap.parse_args();rom=args.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    out=args.out;out.mkdir(parents=True,exist_ok=True)
    (out/'nodes').mkdir(exist_ok=True);(out/'payloads').mkdir(exist_ok=True)
    world=json.loads((out.parent/'world/manifest.json').read_text())
    if world['rom_sha256']!=EXPECTED_SHA256:raise SystemExit('Wrong world revision')
    roots=defaultdict(list)
    for scene in world['scenes']:
        for v in scene['variants']:
            base={'scene':scene['scene'],'variant':v['variant']}
            for field in ['scene_script_a','scene_script_b']:
                if int(v[field],16):roots[int(v[field],16)].append(dict(base,role=field))
            for group in ['actors','player_spawns']:
                for slot,a in enumerate(v[group]):
                    for field in ['script_a','script_b']:
                        if int(a[field],16):roots[int(a[field],16)].append(dict(base,role=f'{group}[{slot}].{field}',actor_id=a['actor_id']))
    q=deque(roots);nodes={}
    while q:
        address=q.popleft()
        if address in nodes:continue
        pos=address-0x08000000
        if pos%4 or not 0<=pos<=len(rom)-12:raise ValueError(f'Invalid node {address:X}')
        payload,zero,nonzero=struct.unpack_from('<III',rom,pos)
        if not 0x08000000<=payload<0x09000000:raise ValueError('Invalid payload pointer')
        for target in (zero,nonzero):
            if target:q.append(target)
        nodes[address]=(payload,zero,nonzero)
    boundaries=sorted(set(nodes)|{v[0] for v in nodes.values()}|{max(nodes)+12})
    files=[]
    def save(name,start,end):
        raw=rom[start-0x08000000:end-0x08000000]
        (out/name).write_bytes(raw)
        files.append({'file':name,'rom_offset':f'0x{start-0x08000000:X}','size':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
        return name
    save('scene-script-region.bin',boundaries[0],boundaries[-1])
    results=[]
    for address,(payload,zero,nonzero) in sorted(nodes.items()):
        end=boundaries[bisect_right(boundaries,payload)]
        window=rom[payload-0x08000000:end-0x08000000]
        raw_node=save(f'nodes/{address:08X}.bin',address,address+12)
        raw_payload=save(f'payloads/{payload:08X}.bin',payload,end)
        # Marker-based preview only: command operands can contain NUL, so do not
        # treat these windows as conventional C strings or decoded bytecode.
        match=re.search(rb'\$0(.*?)(?=\$[1-5]|$)',window,re.S)
        english=None
        if match:
            data=match[1].rstrip(b'\0')
            english=''.join(chr(b) if 32<=b<127 else f'\\x{b:02X}' for b in data)
        results.append({'address':f'0x{address:08X}','payload_address':f'0x{payload:08X}',
                        'next_if_zero':f'0x{zero:08X}' if zero else None,
                        'next_if_nonzero':f'0x{nonzero:08X}' if nonzero else None,
                        'terminal_Z':window.startswith(b'Z'),'raw_node':raw_node,'raw_payload_window':raw_payload,
                        'payload_window_bytes':len(window),'english_markup_candidate':english,
                        'direct_scene_references':roots.get(address,[])})
    manifest={'rom_sha256':EXPECTED_SHA256,'root_count':len(roots),'node_count':len(results),
              'english_candidate_count':sum(s['english_markup_candidate'] is not None for s in results),
              'nodes':results,'files':files,
              'evidence':{'node_loader':'0x08031AA8','interpreter_loop':'0x08031D84','command_dispatch':'0x08031E40'},
              'notes':['Reachability covers the extracted scene configurations, not every possible script root in the game.',
                       'Node edges are selected by interpreter byte +0x1E being zero or nonzero; condition meanings remain unresolved.',
                       'Payload windows end at the next known node or payload boundary; they may include padding or unreferenced bytes.',
                       'English previews select language markers only; commands and binary operands remain uninterpreted.']}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><title>Sacred Cards scene scripts</title>',
          '<style>body{background:#16191e;color:#eee;font:16px system-ui;margin:24px;max-width:1100px}a{color:#8cd1ff}article{background:#252b34;padding:14px;margin:12px 0}article[hidden]{display:none}pre{white-space:pre-wrap;overflow-wrap:anywhere}input{padding:10px;width:350px}small{color:#bdc9d4}</style>',
          '<h1>Scene script graph</h1><p><a href="../index.html">All assets</a> · <a href="manifest.json">Graph manifest</a> · <a href="decoded.html">Decoded commands and dialogue</a></p>',
          f'<p>{len(roots)} scene-referenced roots lead to {len(results)} nodes. {manifest["english_candidate_count"]} nodes have candidate English text. Previews retain markup and escaped binary bytes; command decoding is incomplete.</p>',
          '<input id="filter" type="search" placeholder="Search text or node address">']
    for n in results:
        def edge(key):
            a=n[key]
            return f'<a href="#{a}">{a}</a>' if a else 'null'
        text=n['english_markup_candidate'] or ('Terminal Z' if n['terminal_Z'] else '(Command payload; no English marker)')
        references=', '.join(f'scene {u["scene"]:02d} variant {u["variant"]} {u["role"]}' for u in n['direct_scene_references'][:12])
        page.append(f'<article id="{n["address"]}"><h2>{n["address"]}</h2><pre>{html.escape(text)}</pre><p>State zero → {edge("next_if_zero")} · Nonzero → {edge("next_if_nonzero")}</p><p><a href="{n["raw_node"]}">Node bytes</a> · <a href="{n["raw_payload_window"]}">Payload window ({n["payload_window_bytes"]} bytes)</a></p><small>{html.escape(references)}</small></article>')
    page.append('<script>const search=document.querySelector("#filter");search.oninput=()=>document.querySelectorAll("article").forEach(a=>a.hidden=!a.textContent.toLowerCase().includes(search.value.toLowerCase()));function reveal(){const node=document.getElementById(location.hash.slice(1));if(node){node.hidden=false;node.scrollIntoView();}}window.addEventListener("hashchange",reveal);reveal();</script></html>')
    (out/'index.html').write_text('\n'.join(page)+'\n')
    print(f'Extracted {len(results)} nodes from {len(roots)} roots; {manifest["english_candidate_count"]} English markup candidates')

if __name__=='__main__':main()
