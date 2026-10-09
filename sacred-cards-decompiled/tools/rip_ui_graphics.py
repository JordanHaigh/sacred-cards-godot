#!/usr/bin/env python3
"""Extract loader-backed UI backgrounds, card frames/icons and bitmap fonts."""
import argparse
import hashlib
import html
import json
from pathlib import Path
import struct
from gba_formats import rgb555, untile8
from render_candidates import png_indexed
from rip_asset_tables import EXPECTED_SHA256
from rom_scan import lz77


def render_map(tiles, tilemap, width, height, bpp):
    if len(tilemap)!=width*height*2:raise ValueError('Map extent mismatch')
    pixels=bytearray(width*8*height*8)
    for n,(entry,) in enumerate(struct.iter_unpack('<H',tilemap)):
        for y in range(8):
            for x in range(8):
                sx=7-x if entry&1024 else x; sy=7-y if entry&2048 else y
                if bpp==8: color=tiles[(entry&1023)*64+sy*8+sx]
                else:
                    value=tiles[(entry&1023)*32+sy*4+sx//2]
                    color=((value>>(4*(sx&1)))&15)+(entry>>12)*16
                pixels[(n//width*8+y)*width*8+n%width*8+x]=color
    return bytes(pixels)


def glyph_index(code):
    """Semantic character-index arithmetic at Thumb 0x080178B0."""
    code=code&65535
    if code<0x8140:code=0x8140
    original=(code-0x8140)&65535; value=original
    if original>0x400:value=(value-0x200)&65535
    if original>0x700:value=(value-0x100)&65535
    if original>0x5F00:value=(value-0x4000)&65535
    result=(value-(value>>8)*68)&65535
    if value&255>0x3F:result=(result-1)&65535
    return result


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path)
    ap.add_argument('--out',type=Path,default=Path('build/assets/ui'));a=ap.parse_args()
    rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    out=a.out;out.mkdir(parents=True,exist_ok=True);files=[];items=[]
    def save(name,data,offset=None):
        (out/name).parent.mkdir(parents=True,exist_ok=True);(out/name).write_bytes(data)
        files.append({'file':name,'rom_offset':hex(offset) if offset is not None else None,'size':len(data),'sha256':hashlib.sha256(data).hexdigest()})
        return name
    def source(name,offset,length):return save(name,rom[offset:offset+length],offset)
    def mapped(name,label,tile_at,map_at,w,h,bpp,pal_at,pal_size,pal_first,loader):
        tiles,consumed=lz77(rom,tile_at)
        source(name+'.lz77',tile_at,consumed);save(name+'.tiles.bin',tiles)
        source(name+'.map.u16',map_at,w*h*2);source(name+'.pal',pal_at,pal_size)
        colors=[(255,0,255)]*256;colors[0]=(0,0,0)
        colors[pal_first:pal_first+pal_size//2]=rgb555(rom[pal_at:pal_at+pal_size])
        pix=render_map(tiles,rom[map_at:map_at+w*h*2],w,h,bpp)
        png_indexed(out/(name+'.png'),pix,w*8,h*8,256,colors)
        items.append({'name':label,'file':name+'.png','dimensions':[w*8,h*8],'loader':loader,
                      'kind':'background layer','bpp':bpp,'unresolved_palette_indices':sorted(set(pix)-set(range(pal_first,pal_first+pal_size//2))-{0})})
    mapped('city-map','City-map menu background',0x56D28,0x5FFBC,30,20,8,0x5FE3C,384,0,'0x08000A64')
    mapped('name-entry','Name-entry background',0x70A84,0x776D8,30,20,4,0x774D8,512,0,'0x0800181C')
    mapped('card-detail','Card-detail label/background layer',0x8BA8C,0x8E2D0,31,20,4,0x8E1D0,256,128,'0x08006E58')
    # Preserve additional loader-backed layers whose final layout uses dynamic text/OAM.
    for name,at in [('city-objects',0x6AABC),('name-entry-objects',0x75388)]:
        data,n=lz77(rom,at);source(name+'.lz77',at,n);save(name+'.tiles.bin',data)
    for name,at,n in [('name-entry-object-palette',0x77B88,512),('city-overlay-map',0x6A46C,120),
                      ('city-object-palette',0x69A6C,256),('card-detail-text-map',0x8B5DC,1200)]:source(name+'.bin',at,n)
    tiles_at=struct.unpack_from('<I',rom,0xD53580)[0]-0x8000000
    source('frames.tiles8.bin',tiles_at,8192);source('frames.map.u16',0x9489A8,532)
    for index in range(9):
        pal=struct.unpack_from('<I',rom,0xD53584+index*4)[0]-0x8000000
        source(f'frame-{index}.pal',pal,40)
        colors=[(255,0,255)]*256;colors[0]=(0,0,0);colors[64:84]=rgb555(rom[pal:pal+40])
        pix=render_map(rom[tiles_at:tiles_at+8192],rom[0x9489A8:0x948BBC],14,19,8)
        name=f'frame-{index}.png';png_indexed(out/name,pix,112,152,256,colors,transparent_index=0)
        items.append({'name':f'Card frame palette {index}','kind':'card frame','file':name,'dimensions':[112,152],
                      'loader':'0x08018F44','unresolved_palette_indices':sorted(set(pix)-set(range(64,84))-{0})})
    for family,count,table,paltable,first,ncolors in [('type',24,0xD535A8,0xD53608,93,11),('summon',12,0xD53668,0xD53698,86,7)]:
        for index in range(count):
            at=struct.unpack_from('<I',rom,table+4*index)[0]-0x8000000
            pal=struct.unpack_from('<I',rom,paltable+4*index)[0]-0x8000000
            width=32 if family=='type' and index>=21 else 16;size=width*16
            source(f'{family}-{index:02d}.tiles8.bin',at,size);source(f'{family}-{index:02d}.pal',pal,ncolors*2)
            colors=[(255,0,255)]*256;colors[0]=(0,0,0);colors[first:first+ncolors]=rgb555(rom[pal:pal+ncolors*2])
            pix=untile8(rom[at:at+size],width,16);name=f'{family}-{index:02d}.png'
            png_indexed(out/name,pix,width,16,256,colors,transparent_index=0)
            items.append({'name':f'{family.title()} icon {index}','kind':'card icon','file':name,'dimensions':[width,16],
                          'unresolved_palette_indices':sorted(set(pix)-set(range(first,first+ncolors))-{0})})
    # Both font accessors use the same character-index function. The small bank
    # has exactly 806 ten-byte records before the large bank begins.
    fonts=[]
    for label,at,stride,height in [('small',0xD2AAEA,10,8),('large',0xD2CA66,18,16)]:
        source(f'font-{label}.bin',at,806*stride)
        atlas=bytearray(32*8*26*height);glyphs=[]
        for index in range(806):
            rows=rom[at+index*stride:at+index*stride+height]
            pix=bytes((row>>(6-x))&1 if x<7 else 0 for row in rows for x in range(8))
            name=f'font-{label}/{index:03d}.png';(out/name).parent.mkdir(exist_ok=True)
            png_indexed(out/name,pix,8,height,2,[(0,0,0),(255,255,255)],transparent_index=0)
            for y in range(height):
                off=(index//32*height+y)*256+(index%32)*8;atlas[off:off+8]=pix[y*8:y*8+8]
            glyphs.append({'index':index,'file':name,'rom_offset':hex(at+index*stride)})
        name=f'font-{label}.png';png_indexed(out/name,atlas,256,26*height,2,[(0,0,0),(255,255,255)])
        fonts.append({'name':label,'count':806,'stride':stride,'visible_dimensions':[8,height],'file':name,'glyphs':glyphs})
    mapping=[]
    for code in range(0x8140,0xF000):
        try: character=code.to_bytes(2,'big').decode('shift_jis')
        except UnicodeDecodeError:continue
        index=glyph_index(code)
        if index<806:mapping.append({'encoded':f'0x{code:04X}','glyph_index':index,'unicode_candidate':character})
    (out/'font-mapping.json').write_text(json.dumps(mapping,ensure_ascii=False,indent=2)+'\n')
    ascii_mapping=[]
    source('script-ascii-glyph-pointers.bin',0xD35FB8,91*4)
    for code in range(32,123):
        # 0x080323B0 maps only switch entries that target its conversion path.
        target=struct.unpack_from('<I',rom,0x32244+(code-32)*4)[0]
        if target!=0x080323B0:continue
        at=struct.unpack_from('<I',rom,0xD35FB8+(code-32)*4)[0]-0x8000000
        encoded=int.from_bytes(rom[at:at+2],'big')
        ascii_mapping.append(dict(ascii=chr(code),ascii_code=code,source_offset=hex(at),
                                  encoded=f'0x{encoded:04X}',glyph_index=glyph_index(encoded)))
    (out/'script-ascii-mapping.json').write_text(json.dumps(ascii_mapping,indent=2)+'\n')
    # In card-detail view, the upper 128 colors come from 8E1D0. Its color255
    # is black. Keep source-art exceptions separate from these context previews.
    for card_id in (835,844):
        stem=out.parent/'cards'/f'{card_id:04d}'
        if not stem.with_suffix('.tiles8.bin').exists():continue
        tiles=stem.with_suffix('.tiles8.bin').read_bytes()
        pal=rgb555(stem.with_suffix('.pal').read_bytes())+[(255,0,255)]*192
        pal[128:256]=rgb555(rom[0x8E1D0:0x8E2D0])
        name=f'card-{card_id:04d}-detail-context.png'
        png_indexed(out/name,untile8(tiles,80,80),80,80,256,pal)
        items.append(dict(name=f'Card {card_id} in card-detail palette context',file=name,
                          dimensions=[80,80],kind='context preview',loader='0x08006E58',
                          unresolved_palette_indices=[]))
    manifest={'rom_sha256':EXPECTED_SHA256,'items':items,'fonts':fonts,'files':files,
              'notes':['Backgrounds are isolated ROM layers; runtime overlays and sprites are not composited.',
                       'Nine full-card frame palettes and 36 icon slots include blank slot zero.',
                       'Font rasterizers consume 8/16 bytes from 10/18-byte records, discarding bit7 and appending a blank eighth column.',
                       '806 shared font slots inferred from small-bank boundary and shared indexing; Unicode mapping is a Shift-JIS candidate, not verified localization semantics.',
                       'Original font records preserve the two bytes not used by these rasterizer paths.',
                       'script-ascii-mapping.json follows 0x080323B0 and its character dispatch table.',
                       'Two art previews resolve index255 using the card-detail upper palette only; other screen contexts remain separate.']}
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><title>Sacred Cards UI and fonts</title>',
          '<style>body{background:#16191e;color:#eee;font:16px system-ui;margin:24px}a{color:#8cd1ff}main{display:flex;flex-wrap:wrap;gap:16px}article{background:#252b34;padding:16px}img{image-rendering:pixelated;max-width:100%;background:#111}h2{font-size:18px}.icon{width:128px}</style>',
          '<h1>UI, card frames, icons and fonts</h1><p><a href="../index.html">All assets</a> · <a href="manifest.json">Manifest</a></p><p>Source layers reconstructed from loaders. Runtime text and sprite overlays are separate. Magenta marks unresolved palette indices.</p><main>']
    for i in items:
        page.append(f'<article><h2>{html.escape(i["name"])}</h2><a href="{i["file"]}"><img class="{"icon" if i["kind"]=="card icon" else "layer"}" src="{i["file"]}"></a></article>')
    page.append('</main><h2>Bitmap fonts</h2><p>806 slots each, with individual transparent glyph PNGs. <a href="font-mapping.json">Candidate character mapping</a>.</p>')
    for f in fonts:page.append(f'<h3>{f["name"]}</h3><a href="{f["file"]}"><img src="{f["file"]}" style="width:768px"></a>')
    (out/'index.html').write_text('\n'.join(page)+'\n')
    print(f'Exported {len(items)} UI/context previews, 1612 font glyphs and {len(ascii_mapping)} script character mappings')

if __name__=='__main__':main()
