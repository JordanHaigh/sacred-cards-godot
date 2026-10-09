#!/usr/bin/env python3
"""Export loader-backed credits, city-map and startup-logo source assets."""
import argparse,hashlib,json,struct
from pathlib import Path
from gba_formats import rgb555
from rom_scan import lz77
from rip_ui_graphics import render_map
from rip_asset_tables import EXPECTED_SHA256
from render_candidates import png_indexed

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path);ap.add_argument('--out',type=Path,default=Path('build/assets/remaining-screens'));a=ap.parse_args();rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    out=a.out;out.mkdir(parents=True,exist_ok=True);files=[];images=[];strings=[]
    def save(name,data,at=None):
        (out/name).write_bytes(data);files.append(dict(file=name,size=len(data),rom_address=None if at is None else f'0x{0x8000000+at:08X}',sha256=hashlib.sha256(data).hexdigest()));return data
    def raw(name,at,size):return save(name,rom[at:at+size],at)
    def compressed(name,at):
        tiles,size=lz77(rom,at);raw(name+'.lz77',at,size);return save(name+'.tiles4.bin',tiles)
    def picture(name,tiles,tilemap,w,h,bpp,palette,loader):
        pixels=render_map(tiles,tilemap,w,h,bpp);png_indexed(out/(name+'.png'),pixels,w*8,h*8,256,palette)
        images.append(dict(file=name+'.png',width=w*8,height=h*8,loader=loader))
    def string(at,role):
        # Native strings use NUL as terminator; retain multilingual separators.
        end=rom.index(0,at);data=rom[at:end+1];name=f'text-{at:06x}.bin'
        if not any(f['file']==name for f in files):save(name,data,at)
        strings.append(dict(address=f'0x{at+0x8000000:08X}',role=role,file=name))
    pal=raw('credits.pal',0x54348,512);raw('credits.text-map.u16',0x54548,0x3C0)
    for i,(tile_at,map_at) in enumerate([(0x3B61C,0x50748),(0x3C44C,0x50EC8),(0x3F128,0x51648),(0x41D44,0x51DC8),(0x44B54,0x52548),(0x477A0,0x52CC8),(0x4A26C,0x53448),(0x4CFEC,0x53BC8)]):
        name=f'credits-background-{i:02d}';tiles=compressed(name,tile_at);tilemap=raw(name+'.map.u16',map_at,32*60+(2 if i<2 else 0))
        picture(name,tiles,tilemap[:32*60],30,32,4,rgb555(pal),'08000224/0800053C')
    raw('credits.header-pointers.u32',0xD30310,20*8);raw('credits.name-pointers.u32',0xD303B0,20*5*4);raw('credits.page-layouts.bin',0xD30544,20);raw('credits.page-durations.u16',0xD30558,6*2)
    for page in range(20):
        for line in range(2):string(struct.unpack_from('<I',rom,0xD30310+page*8+line*4)[0]-0x8000000,f'credits page{page} header{line}')
        for line in range(5):string(struct.unpack_from('<I',rom,0xD303B0+(page*5+line)*4)[0]-0x8000000,f'credits page{page} name{line}')
    tiles,n=lz77(rom,0x56D28);raw('city-map.lz77',0x56D28,n);save('city-map.tiles8.bin',tiles);tilemap=raw('city-map.map.u16',0x5FFBC,1200);pal=raw('city-map.pal',0x5FE3C,384)
    picture('city-map-background',tiles,tilemap,30,20,8,rgb555(pal)+[(0,0,0)]*64,'08000A64')
    raw('city-map.label-map.u16',0x6A46C,10*2*60);raw('city-map.label-pal',0x6A91C,32)
    raw('city-map.markers.pal',0x6A93C,64);raw('city-map.selection.pal',0x6A9FC,32);compressed('city-map-markers',0x6AABC)
    for i in range(10):
        t=raw(f'city-location-{i}.tiles4.bin',0x6046C+i*0xF00,0xF00);p=raw(f'city-location-{i}.pal',0x69A6C+i*0x100,256)
        # Six source rows of20 tiles; native upload scatters to32-tile rows.
        picture(f'city-location-{i}-atlas',t,struct.pack('<120H',*range(120)),20,6,4,rgb555(p),'08000E58')
    raw('city-map.unlock-masks.u16',0xD3065C,20);raw('city-map.location-order.bin',0xD30670,10);raw('city-map.scene-destinations.u16',0xD4C6E0,60)
    for table,label in [(0xD305B4,'selection'),(0xD30630,'unlocked')]:
        raw(f'city-map.{label}-pointers.u32',table,40)
        for i in range(10):
            ptr=struct.unpack_from('<I',rom,table+i*4)[0]-0x8000000;d=raw(f'city-{label}-{i}.descriptor.bin',ptr,8);o=struct.unpack_from('<I',d,4)[0]-0x8000000;raw(f'city-{label}-{i}.oam',o,d[1]*8)
    for i,at in enumerate([0x6B308,0x6B37C,0x6B3C0,0x6B3E8,0x6B418,0x6B454,0x6B47C,0x6B4A0,0x6B500,0x6B53C]):string(at,f'city location label{i}')
    for name,tile_at,tile_size,map_at,pal_at,pal_size,bpp in [('intro-copyright',0xD366AC,0x3C0,0xD36A6C,0xD3668C,32,4),('intro-first-logo',0xD3716C,0x2000,0xD3792C,0xD36F6C,512,4),('intro-second-logo',0xD3816C,0xFC0,0xD3912C,0xD3812C,64,4)]:
        t=raw(name+'.tiles4.bin',tile_at,tile_size);m=raw(name+'.map.u16',map_at,20*64);p=raw(name+'.pal',pal_at,pal_size)
        picture(name,t,b''.join(m[y*64:y*64+60] for y in range(20)),30,20,bpp,rgb555(p),'080196D4')
    # Dormant alternate-intro graphics and the duel-record viewer.
    for i,offset in enumerate([0xD39B2C,0xD3BB2C,0xD3DB2C]):raw(f'intro-alternate-bank-{i}.tiles4.bin',offset,0x2000)
    raw('intro-alternate-extra.tiles4.bin',0xD3FB2C,0xA0);raw('intro-alternate-base.map.u16',0xD3FBCC,20*64);raw('intro-alternate.pal',0xD3992C,512)
    for i,offset in enumerate([0xD400CC,0xD405CC,0xD40ACC,0xD40FCC,0xD414CC]):raw(f'intro-alternate-choice-{i}.map.u16',offset,20*64)
    t=compressed('duel-record-viewer',0xC08BC);p=raw('duel-record-viewer.pal',0xC4B30,0xE0)
    for i,offset in enumerate([0xC4C10,0xC50C0,0xC5570,0xC5A20]):
        m=raw(f'duel-record-viewer-map-{i}.u16',offset,1200);picture(f'duel-record-viewer-map-{i}',t,m,30,20,4,rgb555(p)+[(0,0,0)]*144,'0801A278')
    raw('duel-record-digits.tiles4.bin',0xC5ED0,0x2C0);raw('duel-record-digits.pal',0xC6190,32);raw('duel-record-cursors.tiles4.bin',0xC61B0,1024);raw('duel-record-cursors.pal',0xC65B0,32)
    raw('duel-record-opponent-order.bin',0xC0880,28);raw('duel-record-grade-gates.bin',0xC089C,28);raw('duel-record-last-page.bin',0xC08B8,4);raw('duel-record-grade-lists.bin',0xB6A9C,3)
    raw('diagnostic.map.u16',0xB6AA0,20*60+4)
    for i,offset in enumerate([0xB7008,0xB6F50,0xB6F5C,0xB6F68,0xB6F70,0xB6F78,0xB6F88,0xB6F94,0xB6FA8,0xB6FC0,0xB6FD0,0xB6FE0,0xB6FEC,0xB6FFC,0xB7020]):string(offset,f'diagnostic label{i}')
    for i,offset in enumerate([0xD3788,0xD37D0,0xD3850,0xD38D0]):string(offset,f'communication menu label{i}')
    # Loader-backed movement/animation/transition views used by overworld C.
    raw('world.walk-phases.bin',0xD4C71C,20);raw('world.run-phases.bin',0xD4C737,26);raw('world.facing-opposites.bin',0xD4C99C,4)
    raw('world.movement-and-collision.bin',0xD4C9A0,0x40);raw('world.debug-scene-cycle.bin',0xD4C751,58);raw('world.debug-sprite-cycle.bin',0xD4C78D,102)
    at=0xD4C7F4;end=at
    while struct.unpack_from('<I',rom,end)[0]!=0xFFFFFFFF:end+=8
    raw('world.fade-scene-spawn-pairs.u32',at,end-at+8);raw('interrupt-callbacks.u32',0x7F420,56)
    manifest=dict(rom_sha256=EXPECTED_SHA256,files=files,images=images,strings=strings,notes=['Loader-backed source layers and atlases, not emulator captures.','Credits initial map reads retain the extra overlapping source halfword.','Dynamic label text, sprite placement, offsets and blend timing are implemented in src/.','Source tile loads can overlap adjacent ROM structures; exported reads retain native sizes.'])
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    figures=''.join(f'<figure><img src="{i["file"]}" width="{i["width"]*2}"><figcaption>{i["file"]}</figcaption></figure>' for i in images)
    (out/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Credits, city map, intro and dormant screens</title><style>body{background:#17202b;color:white;font:16px system-ui;margin:24px}img{image-rendering:pixelated;max-width:100%}figure{display:inline-block;vertical-align:top}</style><h1>Credits, city map, intro and dormant screens source assets</h1><p>Decoded source layers; dynamic composition is in the recovered C.</p>'+figures)
    print(f'Exported {len(files)} source files, {len(images)} previews, {len(strings)} text uses')
if __name__=='__main__':main()
