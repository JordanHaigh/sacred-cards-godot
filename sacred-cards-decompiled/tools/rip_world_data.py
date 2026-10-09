#!/usr/bin/env python3
"""Extract AY7E scene attribute grids and scene configuration records."""
import argparse
import hashlib
import html
import json
import struct
from collections import Counter
from pathlib import Path
from render_candidates import png_indexed
from rip_asset_tables import EXPECTED_SHA256


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('rom', type=Path)
    ap.add_argument('--out', type=Path, default=Path('build/assets/world'))
    args = ap.parse_args()
    rom = args.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest() != EXPECTED_SHA256:
        raise SystemExit('Unsupported ROM')
    args.out.mkdir(parents=True, exist_ok=True)
    boundaries = list(struct.unpack_from('<58I', rom, 0xD548B8)) + [0x08D548B8]
    if boundaries[0] != 0x08D54504:
        raise ValueError('Unexpected scene table boundary')
    palette = [(35, 105, 86), (190, 75, 76), (75, 123, 188), (151, 91, 180)]
    all_variants = 0
    scenes = []

    def save(name, offset, size):
        data = rom[offset:offset + size]
        if len(data) != size:
            raise ValueError('Truncated ROM resource')
        (args.out / name).write_bytes(data)
        return {'file': name, 'rom_offset': f'0x{offset:X}', 'size': size,
                'sha256': hashlib.sha256(data).hexdigest()}

    def actor(offset):
        raw = rom[offset:offset + 20]
        ident, orientation, reserved, x, y, script_a, script_b, flags = struct.unpack('<hBBhhIII', raw)
        return {'rom_offset': f'0x{offset:X}', 'actor_id': ident,
                'orientation_raw': orientation, 'reserved_byte': reserved, 'x': x, 'y': y,
                'script_a': f'0x{script_a:08X}', 'script_b': f'0x{script_b:08X}',
                'flags_raw': f'0x{flags:08X}'}

    for scene_id in range(58):
        grid_at = struct.unpack_from('<I', rom, 0xD51870 + scene_id * 4)[0] - 0x08000000
        # The next grid (or start of the following card-art family) proves size.
        next_at = (struct.unpack_from('<I', rom, 0xD51870 + (scene_id + 1) * 4)[0] - 0x08000000
                   if scene_id < 57 else 0x5A6C38)
        if next_at - grid_at != 19200:
            raise ValueError('Scene grid extent mismatch')
        grid_file = save(f'{scene_id:02d}.attributes.u16', grid_at, 19200)
        words = struct.unpack_from('<9600H', rom, grid_at)
        # Visualize separately verified flags without assigning guessed meanings.
        colors = bytes((1 if v & 1 else 0) + (2 if v & 0xFE00 else 0) for v in words)
        png_indexed(args.out / f'{scene_id:02d}.attributes.png', colors, 120, 80, 16, palette)
        start, end = boundaries[scene_id:scene_id + 2]
        if (end - start) % 4 or not 0 < end - start <= 128:
            raise ValueError('Invalid scene variant table extent')
        default_music = struct.unpack_from('<H',rom,0xD4C87C+scene_id*2)[0]
        overrides = {(a,b):c for a,b,c in struct.iter_unpack('<hhh',rom[0xD4C8F4:0xD4C8F4+27*6])}
        variants = []
        for variant_id in range((end - start) // 4):
            at = struct.unpack_from('<I', rom, start - 0x08000000 + variant_id * 4)[0] - 0x08000000
            raw_file = save(f'{scene_id:02d}-{variant_id:02d}.config.bin', at, 428)
            slots = [actor(at + i * 20) for i in range(16)]
            sentinel = next((i for i, a in enumerate(slots) if a['actor_id'] == -1), None)
            if sentinel is None:
                raise ValueError('Scene actor list missing terminator')
            variants.append({'variant': variant_id, 'raw_file': raw_file,
                             'music_id': overrides.get((scene_id,variant_id),default_music),
                             'actors': slots[:sentinel], 'actor_slots_raw': slots,
                             'scene_script_a': f'0x{struct.unpack_from("<I", rom, at + 0x140)[0]:08X}',
                             'scene_script_b': f'0x{struct.unpack_from("<I", rom, at + 0x144)[0]:08X}',
                             'player_spawns': [actor(at + 0x148 + i * 20) for i in range(5)]})
            all_variants += 1
        scene = {'scene': scene_id, 'default_music_id': default_music, 'grid_file': grid_file, 'grid_dimensions': [120, 80],
                 'attribute_frequencies': {f'0x{k:04X}': v for k, v in sorted(Counter(words).items())},
                 'variant_pointer_table': f'0x{start:08X}', 'variants': variants}
        (args.out / f'{scene_id:02d}.json').write_text(json.dumps(scene, indent=2) + '\n')
        scenes.append(scene)
    result = {'rom_sha256': EXPECTED_SHA256, 'scene_count': 58, 'variant_count': all_variants,
              'grid_loader': '0x0802FD2A', 'grid_accessor': '0x080311B0',
              'config_loader': '0x0802FD18',
              'notes': ['Actor names and script command semantics remain unresolved.',
                        'Grid preview colors show bit 0 and mask 0xFE00, not inferred walkability.',
                        'Actor orientation and flags remain raw; signed coordinates are preserved.'],
              'scenes': scenes}
    (args.out / 'manifest.json').write_text(json.dumps(result, indent=2) + '\n')
    page = ['<!doctype html><meta charset="utf-8"><title>Sacred Cards world data</title>',
            '<style>body{background:#16191e;color:#eee;font:16px system-ui;margin:24px}a{color:#8cd1ff}section{display:inline-block;vertical-align:top;background:#252b34;margin:8px;padding:16px;width:300px}img{image-rendering:pixelated;width:240px}pre{white-space:pre-wrap;font-size:12px}</style>',
            '<h1>Scene attributes and configurations</h1><p><a href="../index.html">Asset gallery</a> · <a href="manifest.json">Full world manifest</a></p>',
            '<p>58 attribute grids and 237 scene configuration variants. Grid colors: green = neither bit 0 nor mask 0xFE00; red = bit 0; blue = mask 0xFE00; purple = both. These are raw categories, not confirmed walkability labels.</p>']
    for s in scenes:
        i = s['scene']
        text = '\n'.join(f'Variant {v["variant"]}: music {v["music_id"]:03d}; {len(v["actors"])} actors; IDs ' + ', '.join(str(a['actor_id']) for a in v['actors']) for v in s['variants'])
        page.append(f'<section><h2>Scene {i:02d}</h2><p><a href="../audio/index.html#song-{s["default_music_id"]:03d}">Default music {s["default_music_id"]:03d}</a></p><img src="../scenes/{i:02d}.normal.png" alt="Scene background"><br><img src="{i:02d}.attributes.png" alt="Attribute grid"><p>{len(s["variants"])} variants · <a href="{i:02d}.json">Decoded configuration</a> · <a href="{i:02d}.attributes.u16">Raw grid</a></p><pre>{html.escape(text)}</pre></section>')
    (args.out / 'index.html').write_text('\n'.join(page) + '\n')
    print(f'Extracted 58 scene attribute grids and {all_variants} scene configurations to {args.out}')


if __name__ == '__main__':
    main()
