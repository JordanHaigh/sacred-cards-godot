#!/usr/bin/env python3
"""Extract dialogue portrait tiles, palettes, OAM parts and static compositions."""
import argparse
import hashlib
import json
import struct
from pathlib import Path
from gba_formats import huffman8, rgb555, untile8
from render_candidates import png_indexed
from rip_asset_tables import EXPECTED_SHA256

SIZES = (((8,8),(16,16),(32,32),(64,64)),
         ((16,8),(32,8),(32,16),(64,32)),
         ((8,16),(8,32),(16,32),(32,64)))


def render(tiles, objects):
    """GBA 8bpp, 2D OBJ mapping, as selected by native DISPCNT 0x5D00.
    GBATEK: https://mgba-emu.github.io/gbatek/#lcd-obj---vram-character-tile-mapping
    Native 08031C58 retains OAM order and forces 8bpp/priority 1.
    """
    pixels = bytearray(240*160)
    for a0, a1, a2, _ in reversed(objects):
        if a0 & 0x100 or a0 >> 14 == 3:
            raise ValueError('Unsupported affine/reserved portrait object')
        if a0 & 0x200:
            continue
        w,h = SIZES[a0 >> 14][a1 >> 14]
        x0,y0 = a1 & 511,a0 & 255
        base = (a2 & 1022)*32
        for y in range(h):
            dy = (y0+y) & 255
            if dy >= 160:continue
            sy = h-1-y if a1 & 0x2000 else y
            for x in range(w):
                dx = (x0+x) & 511
                if dx >= 240:continue
                sx = w-1-x if a1 & 0x1000 else x
                at = base+(sy//8)*1024+(sx//8)*64+(sy%8)*8+sx%8
                v = tiles[at & 0x7FFF]
                if v:pixels[dy*240+dx]=v
    return bytes(pixels)


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('rom',type=Path)
    ap.add_argument('--out',type=Path,default=Path('build/assets/portraits'))
    args=ap.parse_args();rom=args.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    args.out.mkdir(parents=True,exist_ok=True)
    def u32(at):return struct.unpack_from('<I',rom,at)[0]
    portraits=[];frame_count=0;previews=0
    for i in range(33):
        stem=f'portrait-{i:02d}'
        art,pal,parts=[u32(t+i*4)-0x08000000 for t in (0xD4EDBC,0xD4EE40,0xD4EEC4)]
        delta,consumed=huffman8(rom,art)
        tiles=bytearray();previous=0
        # Native 08009160: one cumulative byte chain across the entire buffer.
        for v in delta:
            previous=(previous+v)&255;tiles.append(previous)
        if len(tiles)!=0x8000:raise ValueError('Unexpected portrait tile size')
        palette=rgb555(rom[pal:pal+512])
        for suffix,raw in [('.huff',rom[art:art+consumed]),('.delta.bin',delta),
                           ('.tiles.bin',tiles),('.pal',rom[pal:pal+512])]:
            (args.out/(stem+suffix)).write_bytes(raw)
        png_indexed(args.out/(stem+'.sheet.png'),untile8(tiles,128,256),128,256,256,palette,0)
        groups=[]
        for part in range(4):
            ptr=u32(parts+part*4)
            if ptr==0:groups.append([]);continue
            frames=[]
            for frame in range(64):
                at=ptr-0x08000000+frame*8
                descriptor=rom[at:at+8];count=descriptor[1];oam=u32(at+4)
                if count==0 and oam==0:break
                if not 0x08000000<=oam<0x09000000 or count>128:
                    raise ValueError(f'Invalid OAM descriptor {i}/{part}/{frame}')
                objects=[struct.unpack_from('<4H',rom,oam-0x08000000+k*8) for k in range(count)]
                image=f'{stem}.part-{part}.frame-{frame}.png'
                png_indexed(args.out/image,render(tiles,objects),240,160,256,palette,0)
                (args.out/f'{stem}.part-{part}.frame-{frame}.oam').write_bytes(rom[oam-0x08000000:oam-0x08000000+count*8])
                frames.append(dict(index=frame,descriptor_address=f'0x{at+0x08000000:08X}',
                                   descriptor=descriptor.hex(),oam_address=f'0x{oam:08X}',objects=objects,image=image))
                frame_count+=1
            else:raise ValueError('Portrait descriptors lack terminator')
            groups.append(frames)
        images=[]
        for extra in ([False,True] if groups[3] else [False]):
            objects=[obj for g in groups[:4 if extra else 3] if g for obj in g[0]['objects']]
            image=stem+('.extra.png' if extra else '.png')
            png_indexed(args.out/image,render(tiles,objects),240,160,256,palette,0)
            images.append(image);previews+=1
        portraits.append(dict(id=i,art_address=f'0x{art+0x08000000:08X}',palette_address=f'0x{pal+0x08000000:08X}',
                              parts_address=f'0x{parts+0x08000000:08X}',images=images,groups=groups))
    animation=dict(blink_durations=list(struct.unpack_from('<30H',rom,0x17578C)),
                   blink_frames=list(struct.unpack_from('<30H',rom,0x1757C8)),
                   mouth_durations=list(struct.unpack_from('<4H',rom,0xD4F10C)),
                   mouth_frames=list(struct.unpack_from('<4H',rom,0xD4F114)))
    manifest=dict(rom_sha256=EXPECTED_SHA256,portraits=portraits,part_frames=frame_count,compositions=previews,
                  animation_tables=animation,notes=['33 table slots include placeholder 0; portrait 0 uses the no-portrait runtime path.',
                  'Static frame-zero compositions, plus optional part 3. No background/dialogue window included.',
                  'Raw animation tables retained; native frame timing not execution-compared.'])
    (args.out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    page=['<!doctype html><meta charset="utf-8"><title>Dialogue portraits</title>',
          '<style>body{background:#161c28;color:white;font:16px system-ui;margin:2rem}a{color:#8fcfff}main{display:flex;flex-wrap:wrap;gap:1rem}figure{margin:0;background:#344050;padding:.5rem}img{image-rendering:pixelated;width:480px;max-width:100%}</style>',
          '<h1>Dialogue portraits</h1><p><a href="../index.html">All assets</a> · <a href="manifest.json">Raw data, part frames and animation tables</a></p>',
          f'<p>33 table slots, {frame_count} individual part frames, {previews} static compositions. Slot 0 is a placeholder. Extra-part variants are labelled; runtime selection depends on script state.</p><main>']
    for p in portraits:
        for image in p['images']:
            page.append(f'<figure><a href="{image}"><img src="{image}" loading="lazy"></a><figcaption>{image}</figcaption><a href="portrait-{p["id"]:02d}.sheet.png">Tile sheet</a></figure>')
    page.append('</main>');(args.out/'index.html').write_text('\n'.join(page))
    print(f'Extracted {len(portraits)} portrait slots, {frame_count} part frames, {previews} compositions')

if __name__=='__main__':main()
