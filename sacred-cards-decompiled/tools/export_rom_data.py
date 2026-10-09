#!/usr/bin/env python3
"""Preserve all original bytes after the reviewed executable interval.

This is a lossless data archive, not a claim that every byte is an interpreted
asset. Decoded image/audio/script families remain in their own directories.
"""
import argparse
import hashlib
import json
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256

ROOT = Path(__file__).resolve().parents[1]
DATA_OFFSET = 0x3B61C


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('rom', type=Path)
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest() != EXPECTED_SHA256:
        raise SystemExit('Unsupported ROM')
    data = rom[DATA_OFFSET:]
    out = ROOT / 'build/assets/rom-data'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'original-data.bin').write_bytes(data)
    manifest = dict(
        rom_sha256=EXPECTED_SHA256,
        file='original-data.bin',
        sha256=hashlib.sha256(data).hexdigest(),
        rom_offset=f'0x{DATA_OFFSET:X}',
        native_base=f'0x{0x08000000 + DATA_OFFSET:08X}',
        size=len(data),
        end_exclusive=f'0x{0x08000000 + len(rom):08X}',
        native_address_to_file_offset='address - 0x0803B61C',
        notes=[
            'Includes decoded families, unused data, adjacent table views and original padding.',
            'Retention is complete for this interval; semantic classification of every byte is not established.',
            'Native addresses in source/table records require translation or an appropriate runtime mapping.'])
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (out / 'README.txt').write_text(
        'Original AY7E cartridge data, native range 0803B61C..09000000.\n'
        'For an original data pointer A, the file offset is A - 0803B61C.\n'
        'This archive preserves unused and uninterpreted bytes too.\n'
        'Use the sibling asset directories for decoded PNG/WAV/MIDI/JSON files.\n')
    print(f'Preserved {len(data):,} original ROM data bytes')


if __name__ == '__main__':
    main()
