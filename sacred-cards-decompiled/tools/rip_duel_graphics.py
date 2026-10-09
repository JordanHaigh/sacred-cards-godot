#!/usr/bin/env python3
"""Extract native duel terrain backgrounds and the two traced viewport positions."""
import argparse,hashlib,json,struct
from pathlib import Path
from gba_formats import huffman8,rgb555,untile8
from render_candidates import png_indexed
from rip_asset_tables import EXPECTED_SHA256

def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path)
    ap.add_argument('--out',type=Path,default=Path('build/assets/duel'));a=ap.parse_args();rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    a.out.mkdir(parents=True,exist_ok=True);items=[]
    for terrain in range(7):
        art,mp,pal=[struct.unpack_from('<I',rom,table+terrain*4)[0]-0x08000000 for table in (0xD4BE58,0xD4BE74,0xD4BE90)]
        tiles,consumed=huffman8(rom,art);palette=rgb555(rom[pal:pal+96])
        # Exact forty CpuSet rows: 32 halfwords with source stride31 halfwords.
        copied=b''.join(rom[mp+row*62:mp+row*62+64] for row in range(40))
        stem=f'terrain-{terrain}';files=[]
        for suffix,raw in [('.huff',rom[art:art+consumed]),('.tiles.bin',tiles),('.palette.bin',rom[pal:pal+96]),('.map-source-read.bin',rom[mp:mp+39*62+64]),('.map-copied.bin',copied)]:
            filename=stem+suffix;(a.out/filename).write_bytes(raw);files.append(dict(file=filename,size=len(raw),sha256=hashlib.sha256(raw).hexdigest()))
        views=[]
        for view in range(2):
            sx0=4;sy0=rom[0xD4C2C1+view];pixels=bytearray(240*160)
            for y in range(160):
                for x in range(240):
                    sx,sy=sx0+x,sy0+y;entry=struct.unpack_from('<H',copied,((sy//8)*32+sx//8)*2)[0]
                    tx,ty=sx%8,sy%8
                    if entry&1024:tx=7-tx
                    if entry&2048:ty=7-ty
                    at=(entry&1023)*32+ty*4+tx//2
                    if at>=len(tiles):raise ValueError(f'Viewport needs retained tile RAM: terrain{terrain}, view{view}')
                    color=((tiles[at]>>(4*(tx&1)))&15)+(entry>>12)*16
                    if color>=len(palette):raise ValueError('Viewport requires another palette family')
                    pixels[y*240+x]=color
            filename=f'{stem}-view-{view}.png';png_indexed(a.out/filename,pixels,240,160,256,palette)
            views.append(dict(index=view,x=sx0,y=sy0,file=filename))
        items.append(dict(terrain=terrain,tiles_address=f'0x{art+0x08000000:08X}',map_address=f'0x{mp+0x08000000:08X}',palette_address=f'0x{pal+0x08000000:08X}',tile_bytes=len(tiles),files=files,views=views))
    sprites=[]
    def sprite(name,at,width,height,bpp,palette_at,palette_bytes,loader):
        size=width*height*bpp//8;raw=rom[at:at+size];pal=rom[palette_at:palette_at+palette_bytes]
        if bpp==8:pixels=untile8(raw,width,height)
        else:
            pixels=bytearray(width*height)
            for y in range(height):
                for x in range(width):
                    p=((y//8)*(width//8)+x//8)*32+(y%8)*4+(x%8)//2
                    pixels[y*width+x]=(raw[p]>>(4*(x&1)))&15
        png_indexed(a.out/(name+'.png'),pixels,width,height,256,rgb555(pal),transparent_index=0)
        (a.out/(name+'.tiles.bin')).write_bytes(raw);(a.out/(name+'.palette.bin')).write_bytes(pal)
        sprites.append(dict(name=name,file=name+'.png',tiles=name+'.tiles.bin',palette=name+'.palette.bin',width=width,height=height,bpp=bpp,address=f'0x{at+0x08000000:08X}',loader=loader))
    def overlay(name,at,loader,width=8,height=8):sprite(name,at,width,height,8,0x9C54B0,320,loader)
    overlay('miniature-back',0x94B8B4,'08035840',32,32)
    overlay('miniature-used',0x9C5470,'08035874');overlay('miniature-hidden',0x9C57B0,'080358E4')
    for i in range(11):overlay(f'stage-{i}',0x9C65F0+i*64,'08035890')
    overlay('stage-minus',0x9C68B0,'08035890')
    for name,at in [('attack-tens',0x9C5DB0),('attack-ones',0x9C5AF0),('defense-tens',0x9C6330),('defense-ones',0x9C6070)]:
        for i in range(11):overlay(f'{name}-{i}',at+i*64,'08035990 /08035A18')
    for i in range(12):overlay(f'miniature-attribute-{i}',struct.unpack_from('<I',rom,0xD5109C+i*4)[0]-0x08000000,'08035900')
    for i in range(4):overlay(f'miniature-requirement-{i}',0x9C56B0+i*64,'08035938 /08035964')
    sprite('cursor',0xD4694,32,32,4,0xD4894,32,'08024598 /080245D0')
    for family,count,table,paltable in [('hud-type',24,0xD30DFC,0xD30D9C),('hud-attribute',12,0xD30E8C,0xD30E5C)]:
        for i in range(count):
            at=struct.unpack_from('<I',rom,table+i*4)[0]-0x08000000;pal=struct.unpack_from('<I',rom,paltable+i*4)[0]-0x08000000
            sprite(f'{family}-{i}',at,32 if family=='hud-type' and i>=21 else 16,16,4,pal,32,'080041C8 /08004284')
    for name,at in [('hud-level',0x845DC),('hud-attack',0x845FC),('hud-defense',0x8461C)]:sprite(name,at,8,8,4,0x84F9C,32,'080042CC /080042E0 /080042F4')
    result=dict(rom_sha256=EXPECTED_SHA256,loader='0x08024980',items=items,sprites=sprites,notes=[
        'Native BG2 uses 4bpp, forty copied rows, 32-entry destination stride and 31-entry source stride.',
        'Source reads overlap following map/palette data. Raw reads are preserved. Previews show only two traced visible viewports and their loaded 48-color palette.',
        'Terrain previews omit cards, text, sprites and blending. Sprite tiles are exported separately with loader-selected palettes.',
        'Digit10 is the blank marker. Requirement0 and stage0 raw slots are retained even where the native overlays skip drawing them.',
        'HUD type21..23 occupy the combined type/attribute area; their full source image is32x16.'])
    (a.out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n')
    rows=''.join(f'<section><h2>Terrain {i["terrain"]}</h2>'+''.join(f'<figure><img src="{v["file"]}"><figcaption>View {v["index"]}: offset ({v["x"]}, {v["y"]})</figcaption></figure>' for v in i['views'])+'</section>' for i in items)
    rows+='<h2>Native miniature overlays and HUD graphics</h2>'+''.join(f'<figure><img style="width:{s["width"]*4}px" src="{s["file"]}"><figcaption>{s["name"]}</figcaption></figure>' for s in sprites)
    (a.out/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Duel graphics</title><style>body{font:16px system-ui;background:#171c24;color:#eee;margin:2rem}a{color:#9bd7ff}figure{display:inline-block;margin:1rem}img{width:480px;image-rendering:pixelated}figcaption{font-size:13px}</style><h1>Duel graphics</h1><p><a href="../index.html">Assets</a> · <a href="manifest.json">Raw data manifest</a></p><p>Seven backgrounds, two native viewport positions each, plus115 miniature overlays, cursor and HUD images.</p>'+rows)
    print(f'Exported seven duel terrains, fourteen viewports and{len(sprites)} overlay/HUD images')
if __name__=='__main__':main()
