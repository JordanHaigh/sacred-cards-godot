#!/usr/bin/env python3
"""Heuristically rank Thumb PUSH/LR function-entry candidates.

The first large LZ77 block supplies a provisional code/data frontier. Results
are candidates for manual review, not confirmed function boundaries.
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "build" / "python-deps"))
try:
    from capstone import Cs, CS_ARCH_ARM, CS_MODE_THUMB, CS_MODE_LITTLE_ENDIAN
    from capstone.arm import ARM_OP_IMM
except ImportError as e:
    raise SystemExit("Capstone missing; run make setup") from e

BASE = 0x08000000


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("rom", nargs="?", type=Path, default=ROOT / "Yu-Gi-Oh! - The Sacred Cards (USA).gba")
    ap.add_argument("--max-frontier", type=lambda x: int(x, 0), default=None,
                    help="override provisional code/data frontier as ROM offset")
    args = ap.parse_args()
    data = args.rom.read_bytes()
    scan = json.loads((ROOT / "build" / "rom_report.json").read_text())
    reachable = json.loads((ROOT / "build" / "disassembly" / "reachable_report.json").read_text())
    large = [c["rom_offset"] for c in scan["lz77_candidates"] if c["decompressed_size"] >= 8192]
    frontier = args.max_frontier if args.max_frontier is not None else min(large, default=len(data))
    if not 0xC0 < frontier <= len(data):
        raise SystemExit("invalid provisional frontier")

    known = {(int(x["address"], 16), x["mode"]) for x in reachable["direct_function_roots"]}
    call_targets = {int(x["to"], 16) for x in reachable["direct_call_edges"] if x["to"]}
    md = Cs(CS_ARCH_ARM, CS_MODE_THUMB | CS_MODE_LITTLE_ENDIAN)
    md.detail = True
    rows = []
    for off in range(0xC0, frontier - 1, 2):
        halfword = int.from_bytes(data[off:off + 2], "little")
        # Thumb PUSH with LR in the register list is a common compiler prologue.
        if halfword & 0xFE00 != 0xB400 or not halfword & 0x0100:
            continue
        address = BASE + off
        insns = list(md.disasm(data[off:min(off + 128, frontier)], address, count=32))
        if not insns or insns[0].mnemonic.lower() != "push" or "lr" not in insns[0].op_str:
            continue
        early = [i for i in insns if i.address < address + 64]
        has_return = any((i.mnemonic.lower() == "pop" and "pc" in i.op_str) or
                         (i.mnemonic.lower() == "bx" and i.op_str.strip() == "lr")
                         for i in early)
        direct_calls = [f"0x{i.operands[-1].imm:08X}" for i in early
                        if i.mnemonic.lower() in {"bl", "blx"} and i.operands and
                        getattr(i.operands[-1], "type", None) == ARM_OP_IMM]
        reachable_entry = (address, "thumb") in known
        rows.append({"address": f"0x{address:08X}", "rom_offset": f"0x{off:X}",
                     "reachable_from_reset": reachable_entry,
                     "direct_call_target": address in call_targets,
                     "returns_within_64_bytes": has_return,
                     "calls_in_first_64_bytes": len(direct_calls),
                     "sample_calls": ";".join(direct_calls[:6]),
                     "first_instructions": " | ".join(f"{i.mnemonic} {i.op_str}" for i in insns[:6])})
    rows.sort(key=lambda r: (not r["reachable_from_reset"], not r["direct_call_target"],
                             not r["returns_within_64_bytes"], -r["calls_in_first_64_bytes"],
                             int(r["rom_offset"], 16)))
    out = ROOT / "build" / "disassembly" / "candidate_functions.csv"
    with out.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]) if rows else
                                ["address", "rom_offset", "reachable_from_reset", "direct_call_target",
                                 "returns_within_64_bytes", "calls_in_first_64_bytes", "sample_calls",
                                 "first_instructions"])
        writer.writeheader()
        writer.writerows(rows)
    print(f"Provisional code/data frontier: ROM +0x{frontier:X}")
    print(f"Found {len(rows)} Thumb PUSH/LR candidates; see {out}")


if __name__ == "__main__":
    main()
