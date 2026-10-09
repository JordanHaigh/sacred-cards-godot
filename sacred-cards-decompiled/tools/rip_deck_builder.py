#!/usr/bin/env python3
"""Export deck/collection/hub/status sources and remaining shop UI data.
PNG files show static source layers, not emulator captures. Dynamic tile writes,
sprites, text, offsets and blending are defined by the maintained C.
"""
import argparse,hashlib,html,json,re,struct
from pathlib import Path
from gba_formats import rgb555
from rom_scan import lz77
from rip_ui_graphics import render_map
from rip_asset_tables import EXPECTED_SHA256
from render_candidates import png_indexed


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('rom',type=Path)
    parser.add_argument('--out',type=Path,default=Path('build/assets/deck-builder'));args=parser.parse_args()
    rom=args.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    out=args.out;out.mkdir(parents=True,exist_ok=True);files=[];images=[];strings=[]
    def save(name,data,at=None):
        (out/name).parent.mkdir(parents=True,exist_ok=True);(out/name).write_bytes(data)
        files.append(dict(file=name,address=None if at is None else f'0x{at+0x8000000:08X}',size=len(data),sha256=hashlib.sha256(data).hexdigest()));return data
    def raw(name,at,n):return save(name,rom[at:at+n],at)
    def compressed(name,at):
        tiles,n=lz77(rom,at);raw(name+'.lz77',at,n);save(name+'.tiles4.bin',tiles);return tiles
    def picture(name,tiles,tilemap,palette,loader):
        pixels=render_map(tiles,tilemap,30,20,4);png_indexed(out/(name+'.png'),pixels,240,160,256,palette)
        images.append(dict(file=name+'.png',name=name,loader=loader,dimensions=[240,160]))
    tiles=compressed('collection-deck',0x7F458);pal=raw('collection-deck.pal',0x8248C,128)
    colors=rgb555(pal)+[(255,0,255)]*192
    for name,at,loader in [('collection-backdrop',0x81B2C,'08004878'),('deck-backdrop',0x81FDC,'08014B28')]:
        picture(name,tiles,raw(name+'.map.u16',at,1200),colors,loader)
    hub=compressed('hub',0x6B5B0);compressed('hub-objects',0x6ECA4)
    raw('hub-text.pal',0x6F480,32);raw('hub-objects.pal',0x6F4A0,32);hubpal=raw('hub-backdrop.pal',0x6F4C0,32)
    colors=[(255,0,255)]*256;colors[0]=(0,0,0);colors[240:]=rgb555(hubpal)
    picture('hub-backdrop',hub,raw('hub-backdrop.map.u16',0x6F4E0,1200),colors,'08001460')
    for name,at in [('hub-options',0x6F990),('hub-capacity-error',0x6FD50),('hub-count-error',0x70200),('player-status',0x7E9E0),
                    ('collection-actions',0x8250C),('collection-sort',0x829BC),('deck-actions',0x83C7C),('deck-sort',0x8412C),('card-list',0x84AEC),
                    ('shop-buy-popup',0xC86E8),('shop-sell-popup',0xC8B98),('shop-sort-popup',0xC9048),('shop-status',0xC94F8)]:raw(name+'.map.u16',at,1200)
    for name,at,n in [('player-status.pal',0x7E4F0,32),('player-status.divisors.bin',0x7F126,122),
                     ('list-static.tiles4.bin',0x845DC,96),('list-enabled.pal',0x84F9C,32),('list-disabled.pal',0x84FBC,32),
                     ('list-cursor.tiles4.bin',0x86EFC,4096),('list-cursor.pal',0x87EFC,32),('list-scrollbar.tiles4.bin',0x87F3C,64),
                     ('list-scrollbar-extra.tiles4.bin',0x87F7C,64),('list-scrollbar.pal',0x87FBC,32),
                     ('collection-action-navigation.bin',0xD30D90,12),('collection-sort-navigation.bin',0xD30F04,60),
                     ('deck-action-navigation.bin',0xD35BD4,10),('deck-sort-navigation.bin',0xD35BEC,60),
                     ('glyph-tile-indices.bin',0xD30D70,32),('shop-miniatures.map.u16',0xC99A8,2160),('shop-empty-card.tiles8.bin',0xCA218,1024),
                     ('shop-selection.tiles4.bin',0xCB3C4,512),('shop-selection.pal',0xCB5C4,32),('shop-shadow.tiles4.bin',0xCB5E4,512),
                     ('shop-action-cursor.tiles4.bin',0xCB324,128),('shop-action-cursor.pal',0xCB3A4,32),
                     ('shop-scrollbar.tiles4.bin',0xCB2C4,64),('shop-scrollbar.pal',0xCB304,32),('shop-cursor-coordinates.bin',0xCBDA6,100),
                     ('shop-row-ring.bin',0xC868C,35)]:raw(name,at,n)
    limits={}
    for name,at in [('one-copy',0xB4B1C),('two-copy',0xB4B34)]:
        ids=[];cursor=at
        while (card:=struct.unpack_from('<H',rom,cursor)[0]):ids.append(card);cursor+=2
        raw(name+'.u16',at,cursor-at+2);limits[name]=ids
    save('copy-limits.json',(json.dumps(dict(default_limit=3,lists=limits),indent=2)+'\n').encode())
    groups={
        'hub':[0x706B0,0x7082C,0x709A8,0x709F4,0x70A3C],
        'status':list(range(0x7EE90,0x7EEC0,4))+[0x7EEC0,0x7EEF8,0x7EF7C,0x7F000,0x7F080,0x7F098,0x7F0E0],
        'collection':[0x86AC4,0x86C00,0x86E38,0x86E3C,0x86EB8,0x86EE4],
        'deck':[0xB46E0,0xB4820,0xB4A58,0xB4A5C,0xB4AD8,0xB4B04],
        'shop':[0xCB7E4,0xCB89C,0xCB954,0xCBB74,0xCBB9C,0xCBC3C,0xCBCC4,0xCBD5C,0xCBD74]}
    for family,addresses in groups.items():
        for at in addresses:
            data=rom[at:rom.index(b'\0',at)];name=f'text/{at+0x8000000:08X}.bin';save(name,data+b'\0',at)
            matches=list(re.finditer(rb'\$([0-6])',data))
            languages={m[1].decode():data[m.end():matches[i+1].start() if i+1<len(matches) else len(data)].decode('shift_jis','backslashreplace') for i,m in enumerate(matches)} if matches else {'unmarked':data.decode('shift_jis','backslashreplace')}
            strings.append(dict(family=family,address=f'0x{at+0x8000000:08X}',file=name,languages=languages))
    save('strings.json',(json.dumps(strings,indent=2,ensure_ascii=False)+'\n').encode())
    manifest=dict(rom_sha256=EXPECTED_SHA256,images=images,files=files,copy_limits=limits,strings=strings,notes=[
        'Source-layer previews only. Native dynamic composition is in src/deck_builder_graphics.c, pre_duel_graphics.c, deck_management.c and shop_*.c.',
        'Shared card art, miniatures, type/attribute icons, font glyphs, sort name ranks and audio are linked from the gallery; ROM addresses are preserved.',
        'Copy-list terminators are retained. Raw localized text is authoritative; Shift-JIS is a readable candidate.',
        'Hub options, errors, status and popups use runtime-generated text tiles; raw maps alone are not complete images.',
        'Palette entries outside loaded ranges are magenta.'])
    (out/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n')
    page=['<!doctype html><html lang="en"><meta charset="utf-8"><title>Deck builder sources</title><style>body{font:16px system-ui;background:#171c24;color:#eee;margin:24px}a{color:#9bd7ff}img{image-rendering:pixelated;width:480px;max-width:100%}figure{display:inline-block;margin:12px}td{padding:6px;vertical-align:top}pre{white-space:pre-wrap}</style><h1>Deck builder and shop source assets</h1>',
          '<p><a href="../index.html">All assets</a> · <a href="manifest.json">Manifest and raw files</a> · <a href="copy-limits.json">Copy limits</a> · <a href="strings.json">Localized text</a></p>',
          '<p>Static source layers, not executing game screenshots. Text, cards, cursors and blending are composed by the recovered C.</p>',
          '<p>Shared: <a href="../ui/index.html">Fonts and icons</a> · <a href="../player-menus/index.html">Shop background and battle effects</a> · <a href="../duel/index.html">Duel graphics</a> · <a href="../full-cards/index.html">Cards</a> · <a href="../audio/index.html">Audio</a></p>']
    page += [f'<figure><img src="{i["file"]}"><figcaption>{i["name"]} — {i["loader"]}</figcaption></figure>' for i in images]
    page += ['<h2>Text sources</h2><table>']+[f'<tr><td>{s["family"]}<br><a href="{s["file"]}">{s["address"]}</a></td><td><pre>{html.escape(json.dumps(s["languages"],ensure_ascii=False,indent=2))}</pre></td></tr>' for s in strings]+['</table></html>']
    (out/'index.html').write_text('\n'.join(page));print(f'Exported {len(images)} source previews, {len(files)} files, {len(strings)} text records and {sum(map(len,limits.values()))} copy-limited IDs')

if __name__=='__main__':main()
