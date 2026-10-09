#!/usr/bin/env python3
"""Execute original Thumb miniature compositor; compare Python and recovered C."""
import argparse
import ctypes
import hashlib
import json
import struct
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'build/python-deps'))
from unicorn import Uc, UC_ARCH_ARM, UC_MODE_THUMB
from unicorn.arm_const import (UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2,
                              UC_ARM_REG_SP, UC_ARM_REG_LR, UC_ARM_REG_PC)
from gba_formats import compose_mini_card, tile_offset
from rip_asset_tables import EXPECTED_SHA256


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('rom', type=Path)
    args = ap.parse_args()
    rom = args.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest() != EXPECTED_SHA256:
        raise SystemExit('Unsupported ROM')
    out = ROOT / 'build/validation'
    out.mkdir(parents=True, exist_ok=True)
    path = out / 'miniature.so'
    subprocess.run(['cc', '-shared', '-fPIC', '-O2', '-std=c99', '-Wall', '-Wextra',
                    '-Werror', str(ROOT / 'src/card_art.c'), '-o', str(path)], check=True)
    lib = ctypes.CDLL(str(path))
    lib.ComposeMiniCard.argtypes = [ctypes.POINTER(ctypes.c_uint8)] * 3
    lib.ComposeMiniCard.restype = None
    uc = Uc(UC_ARCH_ARM, UC_MODE_THUMB)
    uc.mem_map(0x08000000, 0x1000000)
    uc.mem_write(0x08000000, rom)
    uc.mem_map(0x02000000, 0x40000)
    uc.mem_map(0x03000000, 0x8000)
    guard = b'\xa5' * 32
    ids = []
    for i in range(901):
        raw = (ROOT / f'build/assets/cards/{i:04d}.mini.tiles8.bin').read_bytes()
        kind = rom[0x8A693 + i]
        frame_at = struct.unpack_from('<I', rom, 0xD536C8 + 4 * kind)[0]
        frame = rom[frame_at - 0x08000000:frame_at - 0x08000000 + 1024]
        pixels = compose_mini_card(raw, frame)
        expected = bytearray(b'\xa5' * 4096)
        for y in range(32):
            for x in range(32):
                expected[tile_offset(x, y, 128)] = pixels[y * 32 + x]
        native = (ctypes.c_uint8 * 4096).from_buffer_copy(b'\xa5' * 4096)
        native_raw = (ctypes.c_uint8 * 576).from_buffer_copy(raw)
        native_frame = (ctypes.c_uint8 * 1024).from_buffer_copy(frame)
        lib.ComposeMiniCard(native, native_raw, native_frame)
        if bytes(native) != expected:
            raise AssertionError(f'C differs for card {i}')
        uc.mem_write(0x020000E0, guard + bytes([0xA5]) * 4096 + guard)
        uc.mem_write(0x02002000, raw)
        for reg, val in [(UC_ARM_REG_R0, 0x02000100), (UC_ARM_REG_R1, 0x02002000),
                         (UC_ARM_REG_R2, frame_at), (UC_ARM_REG_SP, 0x03007E00),
                         (UC_ARM_REG_LR, 0x03007F01)]:
            uc.reg_write(reg, val)
        uc.emu_start(0x08034B41, 0x03007F00, count=100000)
        if uc.reg_read(UC_ARM_REG_PC) != 0x03007F00:
            raise AssertionError('Routine did not return')
        actual = bytes(uc.mem_read(0x02000100, 4096))
        if actual != expected:
            differences = [j for j in range(4096) if actual[j] != expected[j]]
            raise AssertionError(f'ROM differs for card {i} at {differences[:16]} ({len(differences)} bytes)')
        if bytes(uc.mem_read(0x020000E0, 32)) != guard or bytes(uc.mem_read(0x02001100, 32)) != guard:
            raise AssertionError('Buffer overrun')
        if uc.reg_read(UC_ARM_REG_SP) != 0x03007E00:
            raise AssertionError('SP not restored')
        ids.append({'id': i, 'frame_type': kind, 'sha256': hashlib.sha256(actual).hexdigest()})
    report = {'rom_sha256': EXPECTED_SHA256, 'routine': '0x08034B40', 'passed': len(ids),
              'checks': ['original Thumb vs Python and compiled C', 'unchanged destination gaps',
                         'buffer redzones', 'SP restoration'], 'cases': ids}
    (out / 'miniatures.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS: {len(ids)} framed miniatures match original Thumb, Python, and compiled C')


if __name__ == '__main__':
    main()
