#!/usr/bin/env python3
"""Assemble recovered instructions with explicit original-byte gaps.

This is a disassembly reconstruction, not a matching C decompilation. No data
or unclassified bytes are presented as recovered source. Clang emits ARM ELF;
the single payload section is extracted directly so no host linker is needed.
"""
import argparse
import hashlib
import json
import re
import struct
import subprocess
from pathlib import Path
from rip_asset_tables import EXPECTED_SHA256


def section(elf,name):
    if elf[:6]!=b'\x7fELF\x01\x01':raise ValueError('Expected ELF32 little endian')
    shoff=struct.unpack_from('<I',elf,32)[0]
    entsize,count,strindex=struct.unpack_from('<HHH',elf,46)
    headers=[struct.unpack_from('<10I',elf,shoff+i*entsize) for i in range(count)]
    h=headers[strindex];strings=elf[h[4]:h[4]+h[5]]
    for h in headers:
        n=strings[h[0]:strings.index(0,h[0])].decode()
        if n==name:return elf[h[4]:h[4]+h[5]]
    raise ValueError('Missing '+name)


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('rom',type=Path)
    ap.add_argument('--listing',type=Path,default=Path('build/disassembly/reachable.asm'))
    ap.add_argument('--out',type=Path,default=Path('build/reassembly'));a=ap.parse_args()
    rom=a.rom.read_bytes()
    if hashlib.sha256(rom).hexdigest()!=EXPECTED_SHA256:raise SystemExit('Unsupported ROM')
    out=a.out.resolve();out.mkdir(parents=True,exist_ok=True)
    # Stable local basename avoids injecting paths into assembler syntax.
    (out/'original.bin').write_bytes(rom)
    instructions=[]
    for line in a.listing.read_text().splitlines():
        m=re.match(r'^([0-9A-F]{8})\s+(arm|thumb)\s+(\S+)\s*(.*)',line)
        if m:instructions.append((int(m[1],16)-0x08000000,m[2],m[3],m[4].split(';')[0].strip()))
    # Capstone BL pairs take four bytes; other original ARM7 Thumb instructions two.
    lines=['.syntax unified','.cpu arm7tdmi','.section .rom,"ax",%progbits','.Lrom_start:']
    position=0;mode=None;spans=[];codebytes=0
    for offset,state,mnemonic,operands in instructions:
        if offset<position:raise ValueError('Overlapping instruction modes or ranges')
        if offset>position:
            # Thousands of slices of one large incbin can make the assembler
            # retain thousands of copies. Emit the small interior gaps inline.
            for at in range(position, offset, 32):
                lines.append('.byte ' + ','.join(hex(b) for b in rom[at:min(at+32,offset)]))
            spans.append(dict(start=position,end=offset,kind='original_gap'))
        if state!=mode:lines.append('.'+state);mode=state
        size=4 if state=='arm' or mnemonic in ('bl','blx') else 2
        # Local section-relative symbols make all branch deltas assembler-resolved.
        if mnemonic.startswith('b') and re.fullmatch(r'#0x[0-9a-f]+',operands):
            target=int(operands[1:],16)-0x08000000
            operands=f'.Laddr_{target:08X}'
        # Clang unified syntax spells Thumb LDM with an explicit writeback except
        # when its base is itself in the register list (Capstone omits that !).
        lines.append(f'.Laddr_{offset:08X}: {mnemonic} {operands}')
        position=offset+size;codebytes+=size
        spans.append(dict(start=offset,end=position,kind='assembled_instruction'))
    if position<len(rom):lines.append(f'.incbin "original.bin", {position}, {len(rom)-position}')
    source=out/'rom.s';source.write_text('\n'.join(lines)+'\n')
    command=['clang','--target=arm-none-eabi','-mcpu=arm7tdmi','-c','rom.s','-o','rom.o']
    try:
        result=subprocess.run(command,cwd=out,text=True,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,timeout=60)
    except subprocess.TimeoutExpired as error:
        (out/'build.log').write_bytes((error.stdout or b'') + b'\nAssembler exceeded 60 seconds.\n')
        raise SystemExit('Assembler timed out; see build.log')
    (out/'build.log').write_text(result.stdout)
    if result.returncode:raise SystemExit(f'Assembler failed; see {out}/build.log')
    obj=(out/'rom.o').read_bytes()
    try:relocations=section(obj,'.rel.rom')
    except ValueError:relocations=b''
    if relocations:raise SystemExit('Unresolved relocations remain; refusing to emit a ROM')
    rebuilt=section(obj,'.rom');digest=hashlib.sha256(rebuilt).hexdigest()
    (out/'sacred-cards.gba').write_bytes(rebuilt)
    mismatch=[i for i,(x,y) in enumerate(zip(rom,rebuilt)) if x!=y]
    report=dict(kind='instruction reassembly with original-byte gaps; not a C decompilation',
                source_rom_sha256=EXPECTED_SHA256,output_sha256=digest,byte_identical=digest==EXPECTED_SHA256,
                original_size=len(rom),output_size=len(rebuilt),assembled_instruction_count=len(instructions),
                assembled_instruction_bytes=codebytes,original_gap_bytes=len(rom)-codebytes,
                differing_byte_count=len(mismatch),first_differing_offsets=[hex(i) for i in mismatch[:32]],
                compiler_command=command,listing=str(a.listing),listing_sha256=hashlib.sha256(a.listing.read_bytes()).hexdigest())
    (out/'report.json').write_text(json.dumps(report,indent=2)+'\n')
    print(json.dumps(report,indent=2))
    if digest!=EXPECTED_SHA256:raise SystemExit('Reassembly differs; see report.json (original ROM unchanged)')

if __name__=='__main__':main()
