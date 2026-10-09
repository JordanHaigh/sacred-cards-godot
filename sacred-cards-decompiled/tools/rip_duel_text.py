#!/usr/bin/env python3
"""Export native duel message tables, substitutions and card-name wrap edges."""
import argparse,csv,hashlib,html,json,re,struct
from pathlib import Path
from collections import Counter
from rip_asset_tables import EXPECTED_SHA256

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('rom',type=Path)
    p.add_argument('--out',type=Path,default=Path('build/assets/duel-text'));a=p.parse_args()
    rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    a.out.mkdir(parents=True,exist_ok=True);(a.out/'strings').mkdir(exist_ok=True)
    files={};messages=[];commands=Counter();edges=[]
    def text_at(address):
        at=address-0x8000000
        if not 0<=at<len(rom):raise ValueError(hex(address))
        return rom[at:rom.index(b'\0',at)]
    def segments(raw):
        # Preserve native # commands; Shift-JIS is a readable candidate only.
        matches=list(re.finditer(rb'\$([0-6])',raw))
        if not matches:return {'unmarked':raw.decode('shift_jis','backslashreplace')}
        return {m[1].decode():raw[m.end():matches[i+1].start() if i+1<len(matches) else len(raw)].decode('shift_jis','backslashreplace') for i,m in enumerate(matches)}
    def add(family,index,address):
        raw=text_at(address);name=f'strings/{address:08X}.bin'
        if name not in files:
            (a.out/name).write_bytes(raw+b'\0');files[name]=dict(file=name,address=f'0x{address:08X}',size=len(raw)+1,sha256=hashlib.sha256(raw+b'\0').hexdigest())
        c=Counter(x.decode() for x in re.findall(rb'#([0-9])',raw));commands.update(c)
        messages.append(dict(family=family,index=index,address=f'0x{address:08X}',file=name,languages=segments(raw),commands=dict(c),uses_second_card='3' in c))
    for family,table,indices in [('effect',0xDFC054,range(901)),('message',0xD36130,range(23)),('opponent-turn',0xD3618C,range(103)),('tribute',0xD4C168,range(1,4))]:
        for i in indices:add(family,i,struct.unpack_from('<I',rom,table+i*4)[0])
    add('immune-trap',0,0x08D4C178)
    long_names=0
    for card in range(901):
        raw=text_at(struct.unpack_from('<I',rom,0xD310E0+card*4)[0])
        for m in re.finditer(rb'\$([0-6])([^$]*)',raw):
            b=m[2];at=0;glyphs=[]
            while at<len(b):
                count=2 if b[at]&128 else 1;glyphs.append(b[at:at+count]);at+=count
            if len(glyphs)>=26:
                long_names+=1
                if b' ' not in glyphs[:28]:edges.append(dict(card=card,language=m[1].decode(),glyphs=len(glyphs),text=b.decode('shift_jis','backslashreplace'),raw_hex=b.hex()))
    manifest=dict(rom_sha256=EXPECTED_SHA256,messages=messages,files=list(files.values()),command_counts=dict(commands),
                  command_meanings={'0':'next28-glyph line, capped at84','1':'confirmation and clear','2':'first card name','3':'second card name','5':'player name','6':'first number','7':'second number'},
                  long_localized_card_names=long_names,inherited_r8_name_wrap_edges=edges,
                  notes=['Duel message VM, not scene bytecode. Markup is retained in readable text.',
                         'The23-entry message table is followed by103 opponent-turn pointers up to the ritual table at08D36328. Tribute slot0 is not a pointer and is excluded.',
                         'Shift-JIS decoding is a readable candidate; original strings and native font atlases preserve exact bytes/glyphs.',
                         'Two German names reach the native uninitialized-R8 wrap branch; entry context remains unresolved in semantic C.'])
    (a.out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2)+'\n')
    with (a.out/'messages.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['family','index','address','language','text'])
        for m in messages:
            for language,text in m['languages'].items():w.writerow([m['family'],m['index'],m['address'],language,text])
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><title>Duel messages</title>',
          '<style>body{font:16px system-ui;background:#171c24;color:#eee;max-width:1000px;margin:32px auto;padding:0 20px}a{color:#91d3ff}article{border-top:1px solid #456;padding:12px}pre{white-space:pre-wrap}input,select{font:inherit;padding:8px}article[hidden]{display:none}</style>',
          '<h1>Duel messages</h1><p><a href="../index.html">All assets</a> · <a href="manifest.json">Manifest and command meanings</a> · <a href="messages.csv">All language rows</a></p>',
          '<p>901 card-effect slots,23 message slots,103 opponent-turn slots,three tribute prompts and the immunity response. Native substitution markup is retained.</p><input id="search" type="search" placeholder="Search messages"><main>']
    for m in messages:
        page.append(f'<article><h2>{m["family"]} {m["index"]}</h2><pre>{html.escape(m["languages"].get("0",m["languages"].get("unmarked","")))}</pre><details><summary>Language slots and original bytes</summary><pre>{html.escape(json.dumps(m["languages"],ensure_ascii=False,indent=2))}</pre><a href="{m["file"]}">Raw string</a></details></article>')
    page.append('</main><script>document.querySelector("#search").oninput=e=>document.querySelectorAll("article").forEach(a=>a.hidden=!a.textContent.toLowerCase().includes(e.target.value.toLowerCase()));</script></html>')
    (a.out/'index.html').write_text('\n'.join(page)+'\n')
    print(f'Exported {len(messages)} duel text slots, {len(files)} unique strings and {len(edges)} inherited-register name edges')
if __name__=='__main__':main()
