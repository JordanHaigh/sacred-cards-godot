#!/usr/bin/env python3
"""Compare recovered C and Python against the original Thumb delta routine.

Unicorn executes the original routine and its original memcpy implementation.
No BIOS emulation is needed. On macOS, JIT execution needs an unsandboxed run.
This verifies the filter for every extracted card, not a matching ROM build.
"""
import argparse
import ctypes
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / 'build/python-deps'))
from unicorn import Uc, UC_ARCH_ARM, UC_MODE_THUMB
from unicorn.arm_const import (UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_R2,
    UC_ARM_REG_R4, UC_ARM_REG_R5, UC_ARM_REG_R6, UC_ARM_REG_R7, UC_ARM_REG_R8,
    UC_ARM_REG_R9, UC_ARM_REG_R10, UC_ARM_REG_R11, UC_ARM_REG_SP, UC_ARM_REG_LR,
    UC_ARM_REG_PC)
from gba_formats import card_delta_decode, tile_offset
from rip_asset_tables import EXPECTED_SHA256


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('rom', type=Path)
    args = ap.parse_args()
    rom = args.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest() != EXPECTED_SHA256:
        raise SystemExit('Wrong ROM revision')
    out = ROOT / 'build/validation'
    out.mkdir(parents=True, exist_ok=True)
    lib_path = out / 'card_art.so'
    subprocess.run(['cc', '-shared', '-fPIC', '-O2', '-std=c99', '-Wall', '-Wextra',
                    '-Werror', str(ROOT / 'src/card_art.c'), '-o', str(lib_path)], check=True)
    library = ctypes.CDLL(str(lib_path))
    array_type = ctypes.c_uint8 * 6400
    library.CardArtUndoRowDeltas.argtypes = [ctypes.POINTER(ctypes.c_uint8)]
    library.CardArtUndoRowDeltas.restype = None
    uc = Uc(UC_ARCH_ARM, UC_MODE_THUMB)
    uc.mem_map(0x08000000, 0x1000000)
    uc.mem_write(0x08000000, rom)
    uc.mem_map(0x02000000, 0x40000)
    uc.mem_map(0x03000000, 0x8000)
    saved_regs = [UC_ARM_REG_R4, UC_ARM_REG_R5, UC_ARM_REG_R6, UC_ARM_REG_R7,
                  UC_ARM_REG_R8, UC_ARM_REG_R9, UC_ARM_REG_R10, UC_ARM_REG_R11]
    sentinel = 0x03007F00
    cases = []
    for i in range(901):
        prefix = ROOT / f'build/assets/cards/{i:04d}'
        raw = prefix.with_suffix('.delta.bin').read_bytes()
        expected = prefix.with_suffix('.tiles8.bin').read_bytes()
        if card_delta_decode(raw) != expected:
            raise AssertionError(f'Stale asset at card {i}')
        native = array_type.from_buffer_copy(raw)
        library.CardArtUndoRowDeltas(native)
        if bytes(native) != expected:
            raise AssertionError(f'C mismatch at card {i}')
        guard = bytes([0xA5]) * 32
        uc.mem_write(0x020000E0, guard + raw + guard)
        for reg, value in [(UC_ARM_REG_R0, 0x02000100), (UC_ARM_REG_R1, 10),
                           (UC_ARM_REG_R2, 10), (UC_ARM_REG_SP, 0x03007E00),
                           (UC_ARM_REG_LR, sentinel | 1)]:
            uc.reg_write(reg, value)
        for reg in saved_regs:
            uc.reg_write(reg, 0x11223344)
        uc.emu_start(0x0800917D, sentinel, count=500000)
        if uc.reg_read(UC_ARM_REG_PC) != sentinel:
            raise AssertionError('Instruction budget exhausted')
        actual = bytes(uc.mem_read(0x02000100, 6400))
        if actual != expected:
            raise AssertionError(f'Original ROM mismatch at card {i}')
        if bytes(uc.mem_read(0x020000E0, 32)) != guard or bytes(uc.mem_read(0x02001A00, 32)) != guard:
            raise AssertionError('Output buffer overrun')
        if uc.reg_read(UC_ARM_REG_SP) != 0x03007E00 or any(uc.reg_read(r) != 0x11223344 for r in saved_regs):
            raise AssertionError('Original routine violated expected return state')
        # Recreate the stored deltas from the decoded pixels.
        inverse = bytearray(6400)
        for y in range(80):
            previous = 0
            for x in range(80):
                offset = tile_offset(x, y, 80)
                inverse[offset] = (actual[offset] - previous) & 255
                previous = actual[offset]
        if bytes(inverse) != raw:
            raise AssertionError('Delta inverse mismatch')
        cases.append({'id': i, 'output_sha256': hashlib.sha256(actual).hexdigest()})
    result = {'rom_sha256': EXPECTED_SHA256, 'routine': '0x0800917C',
              'domain': '10x10 8bpp tiles, all 901 card slots',
              'checks': ['original Thumb vs Python', 'original Thumb vs compiled C',
                         'inverse delta roundtrip', 'output redzones', 'callee saved registers and SP'],
              'passed': len(cases), 'cases': cases,
              'limitations': 'Does not prove Huffman BIOS equivalence, palette completeness, or a matching ROM build'}
    (out / 'card_art.json').write_text(json.dumps(result, indent=2) + '\n')
    print(f'PASS: {len(cases)} card filters match original Thumb, Python, and compiled C')


if __name__ == '__main__':
    main()
