#!/usr/bin/env python3
"""Extract actor sheets, palettes, and frame selections from the AY7E ROM."""
import argparse
import hashlib
import html
import json
import struct
from collections import defaultdict
from pathlib import Path
from gba_formats import actor_frame_tiles, rgb555, untile4
from render_candidates import png_indexed
from rip_asset_tables import EXPECTED_SHA256


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('rom', type=Path)
    ap.add_argument('--out', type=Path, default=Path('build/assets/actors'))
    args = ap.parse_args()
    rom = args.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest() != EXPECTED_SHA256:
        raise SystemExit('Unsupported ROM')
    args.out.mkdir(parents=True, exist_ok=True)
    sheets = [p - 0x08000000 for p in struct.unpack_from('<102I', rom, 0xD511A0)]
    palettes = [p - 0x08000000 for p in struct.unpack_from('<102I', rom, 0xD51338)]
    sheet_boundaries = sorted(set(sheets) | {0x2B16EC})
    palette_boundaries = sorted(set(palettes) | {0x2B268C})
    offsets = list(struct.unpack_from('<18H', rom, 0xFBB10))
    phases = list(rom[0xD4C71C:0xD4C730])
    special_frames = list(rom[0xD4C730:0xD4C737])
    used_by = defaultdict(set)
    world_path = args.out.parent / 'world/manifest.json'
    if world_path.exists():
        world = json.loads(world_path.read_text())
        if world['rom_sha256'] != EXPECTED_SHA256:
            raise ValueError('Wrong world-data revision')
        for scene in world['scenes']:
            for variant in scene['variants']:
                for actor in variant['actors'] + variant['player_spawns']:
                    used_by[actor['actor_id']].add(scene['scene'])

    def save(name, data, source=None):
        path = args.out / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
        return {'file': name, 'size': len(data), 'sha256': hashlib.sha256(data).hexdigest(),
                'rom_offset': f'0x{source:X}' if source is not None else None}

    shared = [save('frame-offsets.u16', rom[0xFBB10:0xFBB34], 0xFBB10),
              save('walking-phases.u8', bytes(phases), 0xD4C71C),
              save('special-frames.u8', bytes(special_frames), 0xD4C730)]
    actors = []
    for i, (sheet_at, palette_at) in enumerate(zip(sheets, palettes)):
        sheet_end = sheet_boundaries[sheet_boundaries.index(sheet_at) + 1]
        palette_end = palette_boundaries[palette_boundaries.index(palette_at) + 1]
        raw = rom[sheet_at:sheet_end]
        if len(raw) not in (12288, 16384) or palette_end - palette_at not in (32, 64):
            raise ValueError(f'Unexpected resource extent for actor {i}')
        palette_count = (palette_end - palette_at) // 32
        height = len(raw) * 2 // 128
        sheet_pixels = untile4(raw, 128, height)
        folder = f'{i:03d}'
        binaries = [save(f'{folder}/sheet.tiles4.bin', raw, sheet_at)]
        palette_values, sheet_images = [], []
        for bank in range(palette_count):
            pal_at = palette_at + bank * 32
            palette_data = rom[pal_at:pal_at + 32]
            binaries.append(save(f'{folder}/palette-{bank}.pal', palette_data, pal_at))
            colors = rgb555(palette_data)
            palette_values.append(colors)
            filename = f'{folder}/sheet-p{bank}.png'
            png_indexed(args.out / filename, sheet_pixels, 128, height, 16, colors, transparent_index=0)
            sheet_images.append(filename)
        frames = []
        for index, tile in enumerate(offsets):
            packed = actor_frame_tiles(raw, tile)
            pixels = untile4(packed, 32, 32)
            binary = save(f'{folder}/frame-{index:02d}.tiles4.bin', packed)
            binary['source_rows'] = [{'rom_offset': f'0x{sheet_at + tile * 32 + row * 512:X}',
                                      'size': 128} for row in range(4)]
            binaries.append(binary)
            images = []
            for bank, colors in enumerate(palette_values):
                filename = f'{folder}/frame-{index:02d}-p{bank}.png'
                png_indexed(args.out / filename, pixels, 32, 32, 16, colors, transparent_index=0)
                images.append(filename)
            frames.append({'index': index, 'tile_offset': tile, 'images': images,
                           'blank': not any(pixels), 'raw_file': binary['file']})
        actors.append({'id': i, 'sheet_rom_offset': f'0x{sheet_at:X}',
                       'palette_rom_offset': f'0x{palette_at:X}', 'dimensions': [128, height],
                       'palette_count': palette_count, 'sheet_images': sheet_images,
                       'same_sheet_as': sheets.index(sheet_at) if sheets.index(sheet_at) != i else None,
                       'scene_references': sorted(used_by[i]), 'frames': frames, 'files': binaries})
    result = {'rom_sha256': EXPECTED_SHA256, 'actor_slots': 102, 'unique_sheets': len(set(sheets)),
              'frame_tile_offsets': offsets, 'walking_phases': phases,
              'special_orientation_frames': special_frames,
              'walking_frame_rule': 'orientation * 3 + phase[animation_state] for orientation 0..3',
              'notes': ['Index zero is transparent in GBA 4bpp objects.',
                        '18 frame selections exported per actor; presence does not prove runtime use.',
                        'Full sheets include unused/blank cells; preview timing is not runtime-verified.',
                        'Actor names and special animation sequencing remain unresolved.'],
              'shared_files': shared, 'actors': actors}
    (args.out / 'manifest.json').write_text(json.dumps(result, indent=2) + '\n')
    page = ['<!doctype html><html lang="en"><meta charset="utf-8"><title>Sacred Cards actors</title>',
            '<style>body{background:#16191e;color:#eee;font:16px system-ui;margin:24px}a{color:#8cd1ff}main{display:flex;gap:16px;flex-wrap:wrap}article{background:#252b34;padding:16px;width:280px}article[hidden]{display:none}img{image-rendering:pixelated;background:#343e4d}.animation{width:96px;height:96px}.sheet{width:256px}input,select{padding:8px;margin:4px}small{display:block;color:#c0c8d5}</style>',
            '<h1>Character sprite sheets and frames</h1><p><a href="../index.html">All assets</a> · <a href="manifest.json">Actor manifest</a></p>',
            '<p>102 actor slots, 101 distinct sheets. Frames use recovered palettes and transparent backgrounds. Walking previews cycle the ROM phase table; preview timing is adjustable and has not been matched to in-game timing.</p>',
            '<label>Actor ID <input id="filter" type="search" placeholder="e.g. 025"></label><label>Preview step <input id="speed" type="range" min="40" max="250" value="100"> ms</label><button id="pause">Pause previews</button><main>']
    for a in actors:
        i = a['id']
        palette_options = ''.join(f'<option value="{p}">Palette {p}</option>' for p in range(a['palette_count']))
        scene_links = ', '.join(f'<a href="../world/{s:02d}.json">{s:02d}</a>' for s in a['scene_references']) or 'None in extracted configurations'
        alias = f'<small>Shares its sheet with actor {a["same_sheet_as"]:03d}.</small>' if a['same_sheet_as'] is not None else ''
        page.append(f'<article data-id="{i:03d}"><h2>Actor {i:03d}</h2><img class="animation" loading="lazy" src="{i:03d}/frame-00-p0.png" alt="Actor {i} walking preview"><br><select class="direction" aria-label="Orientation">'+''.join(f'<option value="{d}">Orientation {d}</option>' for d in range(4))+f'</select><select class="palette" aria-label="Palette">{palette_options}</select>{alias}<details><summary>Sheet and source files</summary><a class="sheetlink" href="{i:03d}/sheet-p0.png"><img class="sheet" loading="lazy" src="{i:03d}/sheet-p0.png" alt="Actor {i} sheet"></a><br><a href="{i:03d}/sheet.tiles4.bin">Raw sheet</a></details><details><summary>Scene references</summary>{scene_links}</details></article>')
    page.append('</main><script>const phases='+json.dumps(phases)+';let tick=0,paused=false;const visible=new Set();const observer=new IntersectionObserver(es=>es.forEach(e=>e.isIntersecting?visible.add(e.target):visible.delete(e.target)));document.querySelectorAll("article").forEach(a=>{observer.observe(a);a.querySelector(".palette").addEventListener("change",()=>{let src=`${a.dataset.id}/sheet-p${a.querySelector(".palette").value}.png`;a.querySelector(".sheet").src=src;a.querySelector(".sheetlink").href=src;});});document.querySelector("#filter").addEventListener("input",e=>{document.querySelectorAll("article").forEach(a=>a.hidden=!a.dataset.id.includes(e.target.value));});document.querySelector("#pause").onclick=()=>{paused=!paused;document.querySelector("#pause").textContent=paused?"Resume previews":"Pause previews";};function animate(){if(!paused){for(const a of visible){if(a.hidden)continue;const f=Number(a.querySelector(".direction").value)*3+phases[tick%phases.length];a.querySelector(".animation").src=`${a.dataset.id}/frame-${String(f).padStart(2,"0")}-p${a.querySelector(".palette").value}.png`;}tick++;}setTimeout(animate,Number(document.querySelector("#speed").value));}animate();</script></html>')
    (args.out / 'index.html').write_text('\n'.join(page)+'\n')
    print(f'Extracted {len(actors)} actor slots, {len(set(sheets))} distinct sheets, {sum(a["palette_count"] for a in actors)} palette selections and {len(actors)*18} frame selections')


if __name__ == '__main__':
    main()
