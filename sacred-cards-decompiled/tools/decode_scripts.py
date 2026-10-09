#!/usr/bin/env python3
"""Decode known script token boundaries and export event/audio references."""
import argparse
from collections import Counter
import csv
import html
import json
from pathlib import Path
from script_commands import COMMANDS,decode


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--assets',type=Path,default=Path('build/assets'));a=ap.parse_args()
    root=a.assets/'scripts';manifest=json.loads((root/'manifest.json').read_text())
    nodes=[];audio=[];flags=[];counts=Counter();statuses=Counter()
    for n in manifest['nodes']:
        tokens,status=decode((root/n['raw_payload_window']).read_bytes());statuses[status]+=1
        texts=[t['text'] for t in tokens if t['kind']=='text' and t['language']==0]
        item=dict(address=n['address'],payload_address=n['payload_address'],status=status,tokens=tokens,
                  english_text=''.join(texts),next_if_zero=n['next_if_zero'],next_if_nonzero=n['next_if_nonzero'])
        nodes.append(item)
        for t in tokens:
            if t['kind']!='command':continue
            counts[t['command']]+=1
            base=dict(node=n['address'],payload=n['payload_address'],offset=t['offset'],language=t['language'])
            if 'audio_id' in t:audio.append(dict(base,song_id=t['audio_id'],suppressed=t['suppressed_by_handler']))
            if 'event_flag' in t:flags.append(dict(base,flag=t['event_flag'],operation=t['operation']))
    result=dict(rom_sha256=manifest['rom_sha256'],nodes=nodes,command_counts=dict(counts),termination_counts=dict(statuses),
                audio_references=audio,event_flag_references=flags,
                command_schema={k:dict(operand_bytes=v[0],operation=v[1],handler=f'0x{v[2]:08X}' if v[2] else None) for k,v in COMMANDS.items()},
                limitations=['Lexical command decoding does not execute the script VM or determine branch outcomes.',
                    'Language segments retain their own commands; references are static, not proof of execution.',
                    'Shift-JIS Unicode text is a display approximation; raw glyph bytes remain authoritative.',
                    'Windows stop at the first NUL outside a command/glyph. Unknown syntax stops with an explicit status.'])
    (root/'decoded.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    for name,rows in [('audio-references.csv',audio),('event-flags.csv',flags)]:
        if rows:
            with (root/name).open('w',newline='') as f:
                w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader();w.writerows(rows)
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><title>Decoded scene scripts</title>',
          '<style>body{background:#171c24;color:#eee;font:16px system-ui;margin:30px;max-width:1100px}a{color:#9bd7ff}article{background:#252c38;padding:16px;margin:16px 0}pre{white-space:pre-wrap;overflow-wrap:anywhere}input{font:inherit;padding:10px}article[hidden]{display:none}</style>',
          '<h1>Decoded scene scripts</h1><p><a href="index.html">Raw graph</a> · <a href="decoded.json">Decoded JSON</a> · <a href="audio-references.csv">Script audio</a> · <a href="event-flags.csv">Event flags</a></p>',
          f'<p>{len(nodes)} nodes; {sum(counts.values())} command occurrences; {len(audio)} static audio references. This is a token decoder, not an executing script engine.</p>',
          '<input id="filter" type="search" placeholder="Search dialogue, commands or address">']
    for n in nodes:
        lines=[]
        for t in n['tokens']:
            if t['kind']=='command':
                args=t.get('operand_u16_le',t['operands']);lines.append(f'+{t["offset"]:04X} {t["command"]} {t["operation"]} {args} [language {t["language"]}]')
        edges=' · '.join(f'{label}: <a href="#{n[key]}">{n[key]}</a>' for label,key in [('zero','next_if_zero'),('nonzero','next_if_nonzero')] if n[key])
        page.append(f'<article id="{n["address"]}"><h2>{n["address"]}</h2><pre>{html.escape(n["english_text"])}</pre><details><summary>Commands ({n["status"]})</summary><pre>{html.escape(chr(10).join(lines))}</pre></details><p>{edges}</p></article>')
    page.append('<script>document.querySelector("#filter").oninput=e=>document.querySelectorAll("article").forEach(a=>a.hidden=!a.textContent.toLowerCase().includes(e.target.value.toLowerCase()));function reveal(){const a=document.getElementById(location.hash.slice(1));if(a){a.hidden=false;a.scrollIntoView()}}addEventListener("hashchange",reveal);reveal();</script>')
    (root/'decoded.html').write_text('\n'.join(page)+'\n')
    print(json.dumps(dict(nodes=len(nodes),commands=sum(counts.values()),audio=len(audio),flags=len(flags),statuses=dict(statuses))))

if __name__=='__main__':main()
