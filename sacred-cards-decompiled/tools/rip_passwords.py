#!/usr/bin/env python3
"""Extract native password records and the entry screen's background and sprites."""
import argparse,csv,hashlib,html,json,struct
from pathlib import Path
from gba_formats import rgb555
from rom_scan import lz77
from rip_ui_graphics import render_map
from rip_portraits import SIZES
from rip_asset_tables import EXPECTED_SHA256
from render_candidates import png_indexed

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('rom',type=Path)
    p.add_argument('--out',type=Path,default=Path('build/assets/passwords'));a=p.parse_args();r=a.rom.read_bytes()
    if hashlib.sha256(r).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    a.out.mkdir(parents=True,exist_ok=True);records=[];files=[]
    def save(name,raw,offset):
        (a.out/name).write_bytes(raw);files.append(dict(file=name,rom_offset=hex(offset) if offset is not None else None,size=len(raw),sha256=hashlib.sha256(raw).hexdigest()))
    end=r[0xD5108C:0xD51094];skip=r[0xD51094:0xD5109C]
    for family,at,count in [('card',0xD4F43C,902),('bonus',0xD5106C,4)]:
        save(f'{family}-passwords.bin',r[at:at+count*8],at)
        for i in range(count):
            raw=r[at+i*8:at+(i+1)*8];kind='end' if raw==end else 'skip' if raw==skip else 'password'
            records.append(dict(family=family,index=i,kind=kind,digits=list(raw),password=''.join(map(str,raw)) if kind=='password' else None))
    save('terminator.bin',end,0xD5108C);save('skip-marker.bin',skip,0xD51094)
    bg=r[0xBA2E4:0xBE2E4];tilemap=r[0xBE364:0xBE814];bgpal=r[0xBE2E4:0xBE364]
    tiles,consumed=lz77(r,0xBEC5C);objpal=r[0xBE994:0xBE9F4]+r[0xBE814:0xBE854]
    for name,raw,off in [('background.tiles4.bin',bg,0xBA2E4),('background.map.u16',tilemap,0xBE364),('background.pal',bgpal,0xBE2E4),
                         ('objects.lz77',r[0xBEC5C:0xBEC5C+consumed],0xBEC5C),('objects.tiles4.bin',tiles,None),('objects.pal',objpal,None)]:save(name,raw,off)
    bgpixels=render_map(bg,tilemap,30,20,4);bgcolors=rgb555(bgpal)+[(255,0,255)]*192
    png_indexed(a.out/'background.png',bgpixels,240,160,256,bgcolors)
    colors=rgb555(objpal)+[(255,0,255)]*(256-len(objpal)//2);sprites=[]
    for family,table,count,frames in [('digit',0xD364BC,20,1),('key',0xD36568,11,1),('pressed',0xD36648,11,2)]:
        for index in range(count):
            descriptor=struct.unpack_from('<I',r,table+index*4)[0]-0x8000000
            for frame in range(frames):
                at=descriptor+frame*8;oam=struct.unpack_from('<I',r,at+4)[0]-0x8000000
                a0,a1,a2,_=struct.unpack_from('<4H',r,oam);w,h=SIZES[a0>>14][a1>>14];pixels=bytearray(w*h)
                for y in range(h):
                    for x in range(w):
                        sx=w-1-x if a1&0x1000 else x;sy=h-1-y if a1&0x2000 else y
                        off=(a2&1023)*32+(sy//8)*1024+(sx//8)*32+(sy%8)*4+sx%8//2
                        color=tiles[off]>>(4*(sx&1))&15
                        pixels[y*w+x]=color+(a2>>12)*16 if color else 0
                # Input digits are assigned palette bank+3 in08018A88/18B54.
                if family=='digit':pixels=bytes(v+48 if v else 0 for v in pixels)
                file=f'{family}-{index:02d}-{frame}.png';png_indexed(a.out/file,pixels,w,h,256,colors,0)
                save(f'{family}-{index:02d}-{frame}.oam',r[oam:oam+8],oam)
                sprites.append(dict(family=family,index=index,frame=frame,file=file,dimensions=[w,h],descriptor_address=hex(at+0x8000000),oam_address=hex(oam+0x8000000)))
    result=dict(rom_sha256=EXPECTED_SHA256,records=records,sprites=sprites,files=files,notes=[
        '901 card records include8 skipped passwords; the902nd record terminates the search.',
        'Three bonus records precede their terminator. Bonus1 adds50000 money, bonus2 adds100 capacity; bonus0 has no reward action.',
        'Bonus-use flags are checked only for IDs below10. Card passwords add shop stock, not the player collection.',
        '53 sprite views:20 digit variants,11 idle keypad cursors and22 pressed frames. Positions are normalized for individual previews.',
        'Background and object previews are decoded source layers, not a captured emulator screen.'])
    (a.out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    with (a.out/'passwords.csv').open('w',newline='') as f:
        w=csv.writer(f);w.writerow(['family','index','kind','password'])
        for v in records:w.writerow([v['family'],v['index'],v['kind'],v['password']])
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><title>Password assets</title><style>body{font:16px system-ui;background:#171c24;color:#eee;margin:24px}a{color:#9bd7ff}img{image-rendering:pixelated;max-width:100%}main{display:flex;flex-wrap:wrap;gap:16px}figure{margin:0;padding:10px;background:#26303e}figure img{min-width:48px}</style>',
          '<h1>Password entry</h1><p><a href="../index.html">All assets</a> · <a href="manifest.json">Manifest</a> · <a href="passwords.csv">Card and bonus passwords</a></p><h2>Background</h2><img src="background.png" width="480"><h2>Digits and key highlights</h2><main>']
    for v in sprites:page.append(f'<figure><img src="{v["file"]}"><figcaption>{v["family"]} {v["index"]}, frame {v["frame"]}</figcaption></figure>')
    page.append('</main></html>');(a.out/'index.html').write_text('\n'.join(page));print(f'Exported{len(records)} password records and{len(sprites)} sprite views')
if __name__=='__main__':main()
