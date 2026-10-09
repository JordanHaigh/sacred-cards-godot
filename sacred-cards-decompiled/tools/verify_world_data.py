#!/usr/bin/env python3
"""Check recovered scene predicates exhaustively against their original Thumb."""
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
from unicorn.arm_const import UC_ARM_REG_R0, UC_ARM_REG_R1, UC_ARM_REG_LR, UC_ARM_REG_PC
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
    libfile = out / 'scene_data.so'
    subprocess.run(['cc', '-shared', '-fPIC', '-O2', '-std=c11', '-Wall', '-Wextra',
                    '-Werror', str(ROOT / 'src/scene_data.c'), '-o', str(libfile)], check=True)
    lib = ctypes.CDLL(str(libfile))
    uc = Uc(UC_ARCH_ARM, UC_MODE_THUMB)
    uc.mem_map(0x08000000, 0x1000000)
    uc.mem_write(0x08000000, rom)
    uc.mem_map(0x02000000, 0x40000)
    uc.mem_map(0x03000000, 0x8000)
    sentinel = 0x03007F00
    predicates = [(0x0803181C, 'SceneCellTestBaseFlag'), (0x0803183C, 'SceneCellTestBit8'),
                  (0x08031854, 'SceneCellSelectEventClass')]
    for address, name in predicates:
        fn = getattr(lib, name)
        fn.argtypes = [ctypes.c_uint16]
        fn.restype = ctypes.c_uint32
        for value in range(65536):
            uc.reg_write(UC_ARM_REG_R0, 0xA5A50000 | value)
            uc.reg_write(UC_ARM_REG_LR, sentinel | 1)
            uc.emu_start(address | 1, sentinel, count=100)
            if uc.reg_read(UC_ARM_REG_PC) != sentinel or uc.reg_read(UC_ARM_REG_R0) != fn(value):
                raise AssertionError(f'{name} differs for {value:#x}')
        print(f'PASS: {name}, all 65536 inputs', flush=True)
    lib.SceneCellAt.argtypes = [ctypes.POINTER(ctypes.c_uint16), ctypes.c_uint8, ctypes.c_uint8]
    lib.SceneCellAt.restype = ctypes.c_uint16
    lookup_count = 0
    for scene in range(58):
        address = struct.unpack_from('<I', rom, 0xD51870 + scene * 4)[0]
        offset = address - 0x08000000
        cells = (ctypes.c_uint16 * 9600).from_buffer_copy(rom[offset:offset + 19200])
        uc.mem_write(0x020236F0, struct.pack('<I', address))
        for y in [0, 39, 79]:
            for x in [0, 59, 119]:
                uc.reg_write(UC_ARM_REG_R0, x | 0xABCD0000)
                uc.reg_write(UC_ARM_REG_R1, y | 0x12340000)
                uc.reg_write(UC_ARM_REG_LR, sentinel | 1)
                uc.emu_start(0x080311B1, sentinel, count=100)
                if uc.reg_read(UC_ARM_REG_PC) != sentinel or uc.reg_read(UC_ARM_REG_R0) != lib.SceneCellAt(cells, x, y):
                    raise AssertionError(f'Grid lookup mismatch at scene {scene}, {x}, {y}')
                lookup_count += 1
    report = {'rom_sha256': EXPECTED_SHA256, 'predicate_cases': 3 * 65536,
              'predicate_domain': 'All u16 inputs, with nonzero upper register bits to check truncation',
              'grid_lookup_cases': lookup_count, 'grid_lookup_domain': 'Nine corner/middle coordinates per scene',
              'struct_layout': 'Compiled static assertions: actor 20 bytes; configuration 428 bytes',
              'limitations': 'Not full scene execution or compiler-matched code'}
    (out / 'world_data.json').write_text(json.dumps(report, indent=2) + '\n')
    print(f'PASS: {lookup_count} scene lookups and 196608 predicate cases')


if __name__ == '__main__':
    main()
