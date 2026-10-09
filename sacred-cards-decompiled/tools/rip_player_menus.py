#!/usr/bin/env python3
"""Export loader-backed title/shop/wager layers and battle animation source sheets.
These are source layers and atlases, not captures of the executing game.
"""
import argparse, hashlib, json, struct
from pathlib import Path
from gba_formats import rgb555
from rom_scan import lz77
from rip_ui_graphics import render_map
from rip_asset_tables import EXPECTED_SHA256
from render_candidates import png_indexed


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('rom',type=Path)
    parser.add_argument('--out',type=Path,default=Path('build/assets/player-menus'))
    args=parser.parse_args();rom=args.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    out=args.out;out.mkdir(parents=True,exist_ok=True);files=[];images=[];animations=[]
    def save(name,data,offset=None):
        (out/name).write_bytes(data)
        files.append(dict(file=name,rom_offset=None if offset is None else f'0x{offset:X}',size=len(data),sha256=hashlib.sha256(data).hexdigest()))
    def raw(name,at,size):
        data=rom[at:at+size];save(name,data,at);return data
    def picture(name,tiles,tilemap,width,height,bpp,palette,loader):
        pixels=render_map(tiles,tilemap,width,height,bpp)
        png_indexed(out/(name+'.png'),pixels,width*8,height*8,256,palette)
        images.append(dict(name=name,file=name+'.png',width=width*8,height=height*8,loader=loader))
    # Title uses8bpp BG3 with32 source entries per row and a240px viewport.
    title=raw('title.tiles8.bin',0xD41B48,0x9640)
    titlemap=raw('title.map.u16',0xD4B388,32*20*2)
    titlepal=raw('title.pal',0xD4B188,512)
    visible=b''.join(titlemap[y*64:y*64+60] for y in range(20))
    picture('title-background',title,visible,30,20,8,rgb555(titlepal),'08022600')
    raw('title.objects.tiles4.bin',0xD1500,0x2000);raw('title.objects.pal',0xD3500,96)
    raw('title.sprite-descriptors.bin',0xD3560,96);raw('title.alpha-cycle.u16',0xD4BC00,60)
    for name,tile_at,map_at,pal_at,pal_bytes,pal_first,loader in [
        ('shop-backdrop',0xCA618,0xCAE14,0xCADB4,96,208,'0801E15C'),
        ('wager-backdrop',0x7F458,0x81B2C,0x8248C,128,0,'08007E34')]:
        tiles,consumed=lz77(rom,tile_at);raw(name+'.lz77',tile_at,consumed);save(name+'.tiles4.bin',tiles)
        tilemap=raw(name+'.map.u16',map_at,1200);pal=raw(name+'.pal',pal_at,pal_bytes)
        colors=[(255,0,255)]*256;colors[0]=(0,0,0);colors[pal_first:pal_first+pal_bytes//2]=rgb555(pal)
        picture(name,tiles,tilemap,30,20,4,colors,loader)
    for name,at,count,pal_at,loader in [
        ('battle-destruction',0xAC3C0,128,0xAD3C0,'08012DDC'),
        ('battle-hit',0xAD3E0,256,0xAFDE0,'08013330'),
        ('battle-hit-extra',0xAF3E0,80,0xAFDE0,'08013330'),
        ('battle-attribute',0xAFE00,256,0xB1E00,'0801384C'),
        ('battle-life-points',0xB1EA0,256,0xB3EA0,'08013658')]:
        tiles=raw(name+'.tiles4.bin',at,count*32);pal=raw(name+'.pal',pal_at,32)
        tilemap=struct.pack('<'+'H'*count,*range(count))
        picture(name,tiles,tilemap,16,count//16,4,rgb555(pal),loader)
    # Hit frames end when consecutive OAM pointers repeat; attribute frames
    # have a zero duration sentinel. Retain the sentinel records in the export.
    for name,table in [('battle-hit',0xAC2A0),('battle-attribute',0xAC390)]:
        frames=[];i=0
        while True:
            at=table+i*8;duration,parts,unused,pointer=struct.unpack_from('<BBHI',rom,at)
            if name=='battle-attribute' and duration==0:break
            if i and name=='battle-hit' and pointer==frames[-1]['oam_address']:break
            if i>=128:raise ValueError('Unexpected animation terminator')
            oam_name=f'{name}-frame-{i:02d}.oam';raw(oam_name,pointer-0x8000000,parts*8)
            frames.append(dict(index=i,duration_field=duration,part_count=parts,oam_address=pointer,oam_file=oam_name));i+=1
        raw(name+'.frames.bin',table,(i+1)*8)
        animations.append(dict(name=name,frames=frames,native_frames_per_descriptor=2))
    raw('battle-destruction.frames.bin',0xAC26C,6*8)
    raw('battle-destruction.alpha.bin',0xAC29C,3)
    raw('battle-destruction.seeds.u32',0xD35750,16)
    raw('battle-attribute.affine.u16',0xB1E20,0x80)
    raw('card-sort.callbacks.u32',0xD41A50,54*4)
    raw('card-sort.name-ranks.u16',0xCE83C,6*901*2)
    raw('shop.buy-sort-methods.bin',0xC86AF,9);raw('shop.sell-sort-methods.bin',0xC82F8,9)
    manifest=dict(rom_sha256=EXPECTED_SHA256,images=images,animations=animations,files=files,notes=[
        'Eight source-layer/atlas previews. Dynamic text, card data, sprites, offsets and blending require the recovered C.',
        'Name-entry background/fonts were previously exported in ../ui/. This export does not duplicate them.',
        'Animation atlases retain the16-tile source row width; CopyObjectTileRows scatters them into32-tile object rows.',
        'Frame OAM retains native coordinates, palette/priority/affine bits. Attribute-hit also draws a dynamic affine object.',
        'Palette indices outside loaded ranges are magenta. This is a source-family export, not exhaustive ROM asset coverage.'])
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    figures=''.join(f'<figure><img src="{v["file"]}" width="{v["width"]*2}"><figcaption>{v["name"]} — loader {v["loader"]}</figcaption></figure>' for v in images)
    (out/'index.html').write_text('<!doctype html><html lang="en"><meta charset="utf-8"><title>Player menus and battle animations</title><style>body{font:16px system-ui;margin:24px;background:#171c24;color:#eee}a{color:#9bd7ff}img{image-rendering:pixelated;max-width:100%}figure{display:inline-block;vertical-align:top;margin:12px}figcaption{font-size:13px}</style><h1>Player menus and battle animations</h1><p><a href="../index.html">All assets</a> · <a href="manifest.json">Raw assets and animation frames</a> · <a href="../ui/index.html">Name-entry background and fonts</a></p><p>Decoded background layers and animation source sheets. These omit dynamic composition and are not emulator screenshots.</p>'+figures+'</html>')
    print(f'Exported {len(images)} menu/battle previews, {len(files)} raw files and {sum(len(a["frames"]) for a in animations)} animation descriptors')

if __name__=='__main__':main()
