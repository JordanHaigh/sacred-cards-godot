#!/usr/bin/env python3
"""Export the ROM's save payload region descriptors, retaining unknown fields."""
import argparse
import hashlib
import html
import json
import struct
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('rom', type=Path)
    parser.add_argument('--out', type=Path, default=Path('build/assets/save'))
    args = parser.parse_args()
    rom = args.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest() != EXPECTED_SHA256:
        raise SystemExit('Unsupported ROM')
    args.out.mkdir(parents=True, exist_ok=True)
    # Names only where RAM identities were already recovered in semantic C.
    known = {0x0201FC90: 'player_name_17_bytes', 0x02020DA0: 'money_u64', 0x02020C5A: 'player_deck_40_u16', 0x02020C3C: 'deck_capacity_u32',
             0x02020C40: 'duelist_level_u32', 0x02023700: 'event_flags_first_32_bytes'}
    regions = []
    offset = 0
    for at in range(0xD1490, 0xD14F9, 8):
        ram, size = struct.unpack_from('<II', rom, at)
        if ram == 0:
            break
        regions.append(dict(index=len(regions), descriptor_address=f'0x{at+0x08000000:08X}',
                            ram_address=f'0x{ram:08X}', payload_offset=offset,
                            size=size, name=known.get(ram, f'unknown_{ram:08X}')))
        offset += size
    result = dict(rom_sha256=EXPECTED_SHA256, payload_buffer='0x02018800',
                  payload_size=offset, checksum='sum of payload bytes modulo 65536',
                  checksum_function='0x08021F28', pack_function='0x08021F54',
                  unpack_function='0x08021FB8', regions=regions,
                  container=dict(size=32768,commit_marker_offset=0,signature_offset=1,signature_hex=rom[0xD1480:0xD148F].hex(),
                      primary_payload_offset=0x40,backup_payload_offset=0x4020,primary_checksum_offset=0x401E,backup_checksum_offset=0x7FFE,
                      retry_attempts=3,outcomes_by_marker_primaryvalid_backupvalid=[0,3,2,1,0,3,0,3,0,0,2,2]),
                  limitation='Semantic save lifecycle reconstructed in src/save_storage.c; not execution-compared or matched. Hardware timing and new-game subsystem initialization remain dependencies.')
    (args.out/'layout.json').write_text(json.dumps(result, indent=2)+'\n')
    (args.out/'region-descriptors.bin').write_bytes(rom[0xD1490:0xD1500])
    rows = ''.join(f'<tr><td>{r["index"]}</td><td>{r["payload_offset"]:#05x}</td>'
                   f'<td>{r["ram_address"]}</td><td>{r["size"]}</td><td>{html.escape(r["name"])}</td></tr>' for r in regions)
    (args.out/'index.html').write_text('<!doctype html><meta charset="utf-8"><title>Save payload</title>'
        '<style>body{font:16px system-ui;background:#111827;color:#eee;margin:3rem}td,th{padding:.5rem;text-align:left}a{color:#8ccaff}</style>'
        f'<h1>Save payload</h1><p>{len(regions)} regions, {offset} bytes. Checksum: unsigned byte sum modulo 65536.</p>'
        '<p>The event-flag RAM bank has 50 bytes; this descriptor saves only its first 32 bytes.</p>'
        '<p>32 KiB SRAM: commit marker at0, 15-byte signature at1, primary payload at0x40, backup at0x4020. Checksums at0x401E/0x7FFE. Write/repair lifecycle is reconstructed in C; unknown payload fields retain RAM addresses.</p>'
        '<table><tr><th>Region</th><th>Payload offset</th><th>RAM</th><th>Bytes</th><th>Identity</th></tr>'
        +rows+'</table><p><a href="layout.json">JSON</a></p>')
    print(f'Exported {len(regions)} save regions ({offset} bytes)')

if __name__ == '__main__':
    main()
