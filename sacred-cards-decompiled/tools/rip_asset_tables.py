#!/usr/bin/env python3
"""Rip AY7E scenes, full card artwork, miniatures, and card metadata."""
import argparse
import csv
import hashlib
import html
import json
import re
import struct
from pathlib import Path
from gba_formats import card_delta_decode, compose_mini_card, huffman8, rgb555, tilemap8, untile8
from render_candidates import png_indexed
from rom_scan import lz77

EXPECTED_SHA256 = '093f986a92d73c48e11de0a83c6678c3620f8def6173f5e69133815301b40d8f'


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('rom', type=Path)
    ap.add_argument('--out', type=Path, default=Path('build/assets'))
    args = ap.parse_args()
    rom = args.rom.read_bytes()
    digest = hashlib.sha256(rom).hexdigest()
    if digest != EXPECTED_SHA256:
        raise SystemExit('Offsets require the supported AY7E USA Rev. 00 SHA-256')
    args.out.mkdir(parents=True, exist_ok=True)
    cards_dir, scenes_dir = args.out / 'cards', args.out / 'scenes'
    cards_dir.mkdir(exist_ok=True)
    scenes_dir.mkdir(exist_ok=True)

    def pointer(table, index):
        offset = struct.unpack_from('<I', rom, table + index * 4)[0] - 0x08000000
        if not 0 <= offset < len(rom):
            raise ValueError(f'Bad pointer at {table + index * 4:#x}')
        return offset

    def save(folder, filename, data, source=None):
        (folder / filename).write_bytes(data)
        return {'file': str((folder / filename).relative_to(args.out)), 'size': len(data),
                'sha256': hashlib.sha256(data).hexdigest(),
                'rom_offset': f'0x{source:X}' if source is not None else None}

    shared_dir = args.out / 'shared'
    shared_dir.mkdir(exist_ok=True)
    mini_pal_raw = rom[0x9C54B0:0x9C55F0]
    mini_palette = rgb555(mini_pal_raw)
    shared_files = [save(shared_dir, 'miniatures.pal', mini_pal_raw, 0x9C54B0)]
    frames = []
    for kind in range(10):
        offset = pointer(0xD536C8, kind)
        raw = rom[offset:offset + 1024]
        frames.append(raw)
        shared_files.append(save(shared_dir, f'frame-{kind}.tiles8.bin', raw, offset))
        png_indexed(shared_dir / f'frame-{kind}.png', untile8(raw, 32, 32), 32, 32, 256, mini_palette)
    cards = []
    for i in range(901):
        art_at, palette_at, mini_at, name_at = [pointer(t, i) for t in
                                               (0xD51958, 0xD5276C, 0xD536F0, 0xD310E0)]
        delta, consumed = huffman8(rom, art_at)
        tiles = card_delta_decode(delta)
        pixels = untile8(tiles, 80, 80)
        unresolved = sorted(x for x in set(pixels) if x >= 64)
        pal_raw = rom[palette_at:palette_at + 128]
        miniature = lz77(rom, mini_at)
        if miniature is None or len(miniature[0]) != 576:
            raise ValueError(f'Card {i}: invalid miniature')
        mini_raw, mini_size = miniature
        end = rom.find(b'\0', name_at, name_at + 4096)
        if end < 0:
            raise ValueError(f'Card {i}: unterminated name')
        name_raw = rom[name_at:end]
        match = re.search(rb'\$0(.*?)(?=\$[1-5]|$)', name_raw)
        name = match.group(1).decode('ascii', 'backslashreplace') if match else ''
        description_at = pointer(0xE94E78, i)
        description_end = rom.find(b'\0', description_at, description_at + 8192)
        if description_end < 0:
            raise ValueError(f'Card {i}: unterminated description')
        description_raw = rom[description_at:description_end]
        english = re.search(rb'\$0(.*?)(?=\$[1-5]|$)', description_raw)
        description = english.group(1).decode('ascii', 'backslashreplace') if english else ''
        frame_type = rom[0x8A693 + i]
        if frame_type >= len(frames) or max(mini_raw) >= 160:
            raise ValueError(f'Card {i}: bad frame type or miniature color')
        stem = f'{i:04d}'
        files = [save(cards_dir, stem + '.huff', rom[art_at:art_at + consumed], art_at),
                 save(cards_dir, stem + '.delta.bin', delta),
                 save(cards_dir, stem + '.tiles8.bin', tiles),
                 save(cards_dir, stem + '.pal', pal_raw, palette_at),
                 save(cards_dir, stem + '.name.bin', name_raw + b'\0', name_at),
                 save(cards_dir, stem + '.mini.lz', rom[mini_at:mini_at + mini_size], mini_at),
                 save(cards_dir, stem + '.mini.tiles8.bin', mini_raw),
                 save(cards_dir, stem + '.description.bin', description_raw + b'\0', description_at)]
        palette = rgb555(pal_raw) + [(255, 0, 255)] * 192
        png_indexed(cards_dir / (stem + '.png'), pixels, 80, 80, 256, palette)
        png_indexed(cards_dir / (stem + '.mini-gray.png'), untile8(mini_raw, 24, 24), 24, 24, 256)
        png_indexed(cards_dir / (stem + '.mini.png'), untile8(mini_raw, 24, 24), 24, 24, 256, mini_palette)
        png_indexed(cards_dir / (stem + '.framed.png'), compose_mini_card(mini_raw, frames[frame_type]),
                    32, 32, 256, mini_palette)
        cards.append({'id': i, 'name': name, 'unresolved_palette_indices': unresolved,
                      'description_markup': description, 'description_rom_offset': f'0x{description_at:X}',
                      'frame_type': frame_type,
                      'art_rom_offset': f'0x{art_at:X}',
                      'palette_rom_offset': f'0x{palette_at:X}', 'mini_rom_offset': f'0x{mini_at:X}',
                      'name_rom_offset': f'0x{name_at:X}',
                      'attack_raw': struct.unpack_from('<H', rom, 0x886E6 + i * 2)[0],
                      'defense_raw': struct.unpack_from('<H', rom, 0x87FDC + i * 2)[0],
                      'cost_raw': struct.unpack_from('<I', rom, 0x88DF0 + i * 4)[0],
                      'image': f'cards/{stem}.png', 'miniature': f'cards/{stem}.mini.png',
                      'framed_miniature': f'cards/{stem}.framed.png',
                      'files': files})
    scenes = []
    for i in range(58):
        art_at, map_at, alternate_at, pal_at = [pointer(t, i) for t in
                                               (0xD514D0, 0xD515B8, 0xD516A0, 0xD51788)]
        decoded = lz77(rom, art_at)
        if decoded is None or len(decoded[0]) != 44544:
            raise ValueError(f'Scene {i}: unexpected tile data')
        tiles, consumed = decoded
        pal_raw = rom[pal_at:pal_at + 480]
        palette = [(0, 0, 0)] * 16 + rgb555(pal_raw)
        stem = f'{i:02d}'
        files = [save(scenes_dir, stem + '.lz', rom[art_at:art_at + consumed], art_at),
                 save(scenes_dir, stem + '.tiles8.bin', tiles),
                 save(scenes_dir, stem + '.pal', pal_raw, pal_at)]
        images = []
        for variant, offset in [('normal', map_at), ('alternate', alternate_at)]:
            tilemap = rom[offset:offset + 2048]
            files.append(save(scenes_dir, f'{stem}.{variant}.map', tilemap, offset))
            pixels = tilemap8(tiles, tilemap)
            unknown = sorted(set(pixels) & set(range(1, 16)))
            if unknown:
                raise ValueError(f'Scene {i}: unresolved palette entries {unknown}')
            file = f'scenes/{stem}.{variant}.png'
            png_indexed(args.out / file, pixels, 256, 256, 256, palette)
            images.append(file)
        scenes.append({'id': i, 'images': images, 'files': files,
                       'palette_note': 'ROM supplies indices 16..255; index 0 displayed black'})
    manifest = {'rom_sha256': digest, 'cards': cards, 'scenes': scenes, 'shared_files': shared_files,
                'miniature_note': '24x24 8bpp tiles; 160-color shared palette at 0x9C54B0; framed form uses ROM compositor layout',
                'description_note': 'English markup is preserved, including controls, padding, and escaped non-ASCII bytes; no text-layout interpretation yet',
                'scope': '901 card slots including slot zero; 58 scene slots with two tilemap variants'}
    (args.out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    fields = [k for k in cards[0] if k != 'files']
    with (args.out / 'cards.csv').open('w', newline='') as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows({k: c[k] for k in fields} for c in cards)
    page = ['<!doctype html><html lang="en"><meta charset="utf-8">',
            '<title>Sacred Cards — extracted assets</title>',
            '<style>body{background:#16191e;color:#eee;font:16px system-ui;margin:24px}a{color:#8cd1ff}input{padding:12px;width:320px;max-width:85%}main{display:flex;flex-wrap:wrap;gap:12px}figure{margin:0;padding:12px;background:#252b34;width:180px}img{image-rendering:pixelated}figure img.art{width:160px;height:160px}figcaption{padding-top:8px;font-size:13px}.scene{width:256px}.scene img{width:256px}figure[hidden]{display:none}</style>',
            '<h1>Sacred Cards: decoded assets</h1><p>901 card slots and 58 scenes, reconstructed from the local ROM. Slot 0 is a blank card placeholder. Miniatures use the recovered shared palette and card frames. Magenta marks pixels outside a full-size card’s recovered 64-color palette; these are recorded in the manifest.</p>',
            '<p><a href="#scenes">Scenes</a> · <a href="full-cards/index.html">Composed cards</a> · <a href="portraits/index.html">Dialogue portraits</a> · <a href="world/index.html">World data</a> · <a href="actors/index.html">Character sprites</a> · <a href="audio/index.html">Music and sound effects</a> · <a href="scripts/decoded.html">Decoded scene scripts</a> · <a href="ui/index.html">UI and fonts</a> · <a href="gameplay/index.html">Gameplay data</a> · <a href="audio/usage.html">Audio uses</a> · <a href="opponents/index.html">Opponent decks</a> · <a href="duel/index.html">Duel graphics</a> · <a href="duel-text/index.html">Duel messages</a> · <a href="passwords/index.html">Passwords</a> · <a href="player-menus/index.html">Player menus and battle animations</a> · <a href="deck-builder/index.html">Deck builder and shop sources</a> · <a href="runtime/index.html">Runtime tables and scene rules</a> · <a href="save/index.html">Save layout</a> · <a href="remaining-screens/index.html">Credits, map and logos</a> · <a href="rom-data/manifest.json">Complete original data archive</a> · <a href="../decompiled/index.html">Draft C catalog</a> · <a href="cards.csv">Card data CSV</a> · <a href="manifest.json">Extraction manifest</a></p>',
            '<input id="filter" type="search" placeholder="Find a card by name or ID" aria-label="Find card"><h2>Cards</h2><main id="cards">']
    for c in cards:
        title = f'{c["id"]:04d} · {c["name"] or "Blank slot"}'
        page.append(f'<figure data-search="{html.escape(title.lower(), quote=True)}"><a href="{c["image"]}"><img class="art" loading="lazy" src="{c["image"]}" alt="{html.escape(title, quote=True)}"></a><figcaption>{html.escape(title)}<br><a href="{c["miniature"]}"><img loading="lazy" src="{c["miniature"]}" alt="Color miniature"></a> <a href="{c["framed_miniature"]}"><img loading="lazy" src="{c["framed_miniature"]}" alt="Framed miniature" style="width:64px;height:64px"></a><details><summary>Description markup</summary><code style="white-space:pre-wrap;overflow-wrap:anywhere">{html.escape(c["description_markup"])}</code></details></figcaption></figure>')
    page.append('</main><h2 id="scenes">Scenes</h2><p>Full 256×256 tilemaps; runtime scrolling and layers are not simulated. Each scene has two map variants.</p><main>')
    for s in scenes:
        for variant, file in zip(('normal', 'alternate'), s['images']):
            page.append(f'<figure class="scene"><a href="{file}"><img loading="lazy" src="{file}" alt="Scene {s["id"]} {variant}"></a><figcaption>Scene {s["id"]:02d} · {variant}</figcaption></figure>')
    page.append('</main><script>document.querySelector("#filter").addEventListener("input",e=>{const q=e.target.value.toLowerCase();document.querySelectorAll("#cards figure").forEach(f=>f.hidden=!f.dataset.search.includes(q));});</script></html>')
    (args.out / 'index.html').write_text('\n'.join(page) + '\n')
    print(f'Extracted {len(cards)} card art slots, color/framed miniatures and descriptions, plus {len(scenes)} scenes with two map variants to {args.out}')


if __name__ == '__main__':
    main()
