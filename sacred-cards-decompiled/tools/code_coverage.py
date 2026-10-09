#!/usr/bin/env python3
"""Classify the reviewed AY7E executable interval; not an execution test.

The interval ends at the final compiler string routine. This inventories every
byte in that interval, distinguishing instructions, literal/table data, original
alignment padding, and manual reset/IRQ boundaries. It does not infer that all
other ROM bytes are fully interpreted assets.
"""
import csv,hashlib,json,re
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
BASE=0x08000000
END=0x3B61C

def main():
    rom=next(ROOT.glob('*.gba')).read_bytes()
    listing=(ROOT/'build/disassembly/reachable.asm').read_text()
    report=json.loads((ROOT/'build/disassembly/reachable_report.json').read_text())
    kinds=['unclassified']*END
    def mark(at,size,kind):
        if 0<=at and at+size<=END:kinds[at:at+size]=[kind]*size
    mark(0,0xC0,'cartridge_header')
    for line in listing.splitlines():
        m=re.match(r'^([0-9A-F]{8})\s+(arm|thumb)\s+(\S+)',line)
        if m:mark(int(m[1],16)-BASE,4 if m[2]=='arm' or m[3] in ('bl','blx') else 2,'instruction')
    for x in report['resolved_pc_relative_literals']:mark(int(x['literal_address'],16)-BASE,4,'literal_data')
    for x in csv.DictReader((ROOT/'jump_tables.csv').open()):mark(int(x['table_rom_offset'],0),int(x['entry_count'])*4,'jump_table')
    # Reset calls Thumb RunGame and returns into this ARM reset branch. The
    # adjacent table pointer is the native IRQ callback table's literal.
    mark(0xF0,4,'instruction_reset_return')
    mark(0x220,4,'literal_irq_callback_table')
    # Veneer padding uses the old assembler's MOV r8,r8 (Thumb NOP).
    for at in range(0x38E24,0x38E60,4):
        mark(at,2,'instruction_register_veneer');mark(at+2,2,'veneer_alignment')
    spans=[];at=0
    while at<END:
        start=at;kind=kinds[at]
        while at<END and kinds[at]==kind:at+=1
        if kind=='unclassified' and all(x==0 for x in rom[start:at]):kind='zero_alignment'
        spans.append(dict(start=f'0x{BASE+start:08X}',end=f'0x{BASE+at:08X}',bytes=at-start,kind=kind))
    counts=Counter()
    for s in spans:counts[s['kind']]+=s['bytes']
    unclassified=[s for s in spans if s['kind']=='unclassified']
    result=dict(rom_sha256=hashlib.sha256(rom).hexdigest(),reviewed_start='0x08000000',reviewed_end=f'0x{BASE+END:08X}',
                scope='Static byte classification of the reviewed executable interval',counts=dict(counts),
                unclassified_spans=unclassified,spans=spans,
                notes=['Zero alignment is original bytes between reviewed code/literal boundaries, not a recovered function.',
                       'Bytes after0803B61C are cartridge data; complete semantic asset classification is not established.',
                       'Instruction classification does not prove C behavior or runtime equivalence.'])
    (ROOT/'build/research/code-coverage.json').write_text(json.dumps(result,indent=2)+'\n')
    print(f'Executable interval: {END} bytes, {len(unclassified)} unclassified spans; {dict(counts)}')
if __name__=='__main__':main()
