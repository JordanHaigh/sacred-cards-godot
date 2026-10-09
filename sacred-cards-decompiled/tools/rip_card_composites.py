#!/usr/bin/env python3
"""Compose full-size card frames, art, icons, stars, stats and native title glyphs."""
import argparse,hashlib,html,json,re,struct
from pathlib import Path
from gba_formats import rgb555
from rip_asset_tables import EXPECTED_SHA256
from rip_ui_graphics import glyph_index,render_map
from render_candidates import png_indexed

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('rom',type=Path)
    p.add_argument('--out',type=Path,default=Path('build/assets/full-cards'));a=p.parse_args();r=a.rom.read_bytes()
    if hashlib.sha256(r).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    a.out.mkdir(parents=True,exist_ok=True);records=[]
    def ptr(table,index):return struct.unpack_from('<I',r,table+index*4)[0]-0x8000000
    def u16(at):return struct.unpack_from('<H',r,at)[0]
    def overlay(tiles,tile,source):
        at=tile*64
        for j,v in enumerate(source):
            if v:tiles[at+j]=v
    for card in range(901):
        name_at=ptr(0xD310E0,card);raw=r[name_at:r.index(b'\0',name_at)];m=re.search(rb'\$0([^$]*)',raw);name=m[1] if m else raw
        tiles=bytearray(0x4000);palette=bytearray(256);tilemap=[(v+101)&65535 for v in struct.unpack_from('<266H',r,0x9489A8)]
        tiles[0x1940:0x3940]=r[0x94681C:0x94881C]
        at=ptr(0xD53584,r[0x8A693+card]);palette[128:168]=r[at:at+40]
        tiles[64:6464]=(a.out.parent/'cards'/f'{card:04d}.tiles8.bin').read_bytes()
        at=ptr(0xD5276C,card);palette[:128]=r[at:at+128];palette[:2]=b'\0\0'
        for row in range(10):tilemap[72+row*14:82+row*14]=struct.unpack_from('<10H',r,0x946754+row*20)
        attr=r[0x89C04+card];kind=r[0x8A30E+card]
        if attr:
            at=ptr(0xD53698,attr);palette[172:186]=r[at:at+14];at=ptr(0xD53668,attr)
            tiles[0x3200:0x3280]=r[at:at+128];tiles[0x3400:0x3480]=r[at+128:at+256]
        if kind:
            at=ptr(0xD53608,kind);palette[186:208]=r[at:at+22];at=ptr(0xD535A8,kind);size=256 if 21<=kind<=23 else 128
            tiles[0x3180:0x3180+size]=r[at:at+size];tiles[0x3380:0x3380+size]=r[at+size:at+size*2]
        for level in range(min(r[0x89F89+card],12),0,-1):overlay(tiles,114-level,r[0x948BBC:0x948BFC])
        for defense,address in [(0,0x886E6),(1,0x87FDC)]:
            value=u16(address+card*2);digits=[10]*5 if value==65535 else [int(c) if c!=' ' else 10 for c in str(value).rjust(5)]
            for i,digit in enumerate(digits):
                at=None
                if digit!=10:at=0x948BFC+(digit+2)*64
                elif i==0 and digits[4]!=10:at=0x948BFC if defense else 0x948C3C
                if at is not None:overlay(tiles,114+defense*5+i,r[at:at+64])
        at=0
        for i in range(10):
            if at>=len(name):break
            if card in (364,670) and i==1:code=0x8144;at+=4
            elif name[at]&128:code=int.from_bytes(name[at:at+2],'big');at+=2
            else:
                off=ptr(0xD35FB8,name[at]-32);code=int.from_bytes(r[off:off+2],'big');at+=1
            off=0xD2AAEA+glyph_index(code)*10
            glyph=bytes(74 if x<7 and row&(1<<(6-x)) else 0 for row in r[off:off+8] for x in range(8))
            overlay(tiles,133+i*2,bytes(40)+glyph[:24]);overlay(tiles,134+i*2,glyph[24:]+bytes(24))
        packed=struct.pack('<266H',*tilemap);pixels=render_map(tiles,packed,14,19,8)
        # The detail viewer supplies the upper128 colors independently of art.
        colors=rgb555(palette+r[0x8E1D0:0x8E2D0]);image=f'{card:04d}.png'
        png_indexed(a.out/image,pixels,112,152,256,colors)
        for suffix,data in [('tiles8.bin',tiles),('map.u16',packed),('pal',palette+r[0x8E1D0:0x8E2D0])]:
            (a.out/f'{card:04d}.{suffix}').write_bytes(data)
        records.append(dict(card=card,name=name.decode('shift_jis','backslashreplace'),image=image,
                            art_pixels_using_upper_palette=sorted(set(pixels)&set(range(128,256)))))
    result=dict(rom_sha256=EXPECTED_SHA256,cards=records,language=0,dimensions=[112,152],evidence='08018F1C..080194B8',notes=[
        'Semantic image composition follows the native full-card loader; not execution-compared.',
        'Includes metadata base ATK/DEF, original title abbreviations for cards364/670, and level cap12.',
        'Palette indices128..255 use the card-detail screen palette. Other screen contexts can differ.',
        'Raw composed tile buffers, map and full palette accompany every PNG.'])
    (a.out/'manifest.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><title>Full card previews</title><style>body{font:16px system-ui;background:#171c24;color:#eee;margin:24px}a{color:#9bd7ff}main{display:flex;gap:16px;flex-wrap:wrap}figure{margin:0;width:224px}img{image-rendering:pixelated;width:224px}figure[hidden]{display:none}input{padding:10px}</style>',
          '<h1>Full card previews</h1><p><a href="../index.html">All assets</a> · <a href="manifest.json">Manifest</a></p><p>901 composed cards using original art, frames, labels and font glyphs. English titles; card-detail palette context.</p><input id="search" placeholder="Search card ID or name"><main>']
    for c in records:page.append(f'<figure><a href="{c["image"]}"><img loading="lazy" src="{c["image"]}"></a><figcaption>{c["card"]}: {html.escape(c["name"])}</figcaption></figure>')
    page.append('</main><script>document.querySelector("#search").oninput=e=>document.querySelectorAll("figure").forEach(f=>f.hidden=!f.textContent.toLowerCase().includes(e.target.value.toLowerCase()));</script></html>')
    (a.out/'index.html').write_text('\n'.join(page));print('Exported901 composed card previews and native tile/map/palette buffers')
if __name__=='__main__':main()
