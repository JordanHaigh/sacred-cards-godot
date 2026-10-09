#!/usr/bin/env python3
"""Conservative control-flow disassembly from GBA entry and direct calls.

Only reachable code discovered through static control flow is emitted. This is
not a complete code/data classifier: indirect calls, jump tables, and code
referenced only through data tables need additional analysis.
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "build" / "python-deps"))
try:
    from capstone import (Cs, CS_ARCH_ARM, CS_MODE_ARM, CS_MODE_THUMB,
                          CS_MODE_LITTLE_ENDIAN, CS_GRP_RET,
                          CS_GRP_CALL, CS_GRP_JUMP)
    from capstone.arm import ARM_OP_IMM, ARM_CC_AL, ARM_INS_BL, ARM_INS_BLX
    from capstone.arm import ARM_OP_MEM, ARM_OP_REG, ARM_REG_PC
except ImportError as e:
    raise SystemExit("Capstone missing. Install project dependency with: "
                     "python3 -m pip install --target build/python-deps -r requirements.txt") from e

BASE = 0x08000000


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("rom", nargs="?", type=Path, default=ROOT / "Yu-Gi-Oh! - The Sacred Cards (USA).gba")
    ap.add_argument("--entry-offset", type=lambda x: int(x, 0), default=0)
    ap.add_argument("--entry-mode", choices=("arm", "thumb"), default="arm")
    ap.add_argument("--max-instructions", type=int, default=500_000)
    ap.add_argument("--trace", action="store_true", help="print each decoded instruction during analysis")
    ap.add_argument("--seed-candidates", type=Path,
                    help="also analyze non-reachable PUSH/LR candidates with a nearby return and call")
    ap.add_argument("--out", type=Path, default=ROOT / "build" / "disassembly")
    args = ap.parse_args()
    rom = args.rom.read_bytes()
    if args.entry_offset < 0 or args.entry_offset >= len(rom):
        raise SystemExit("entry offset is outside ROM")
    symbol_path = ROOT / "symbols.csv"
    symbols = {}
    if symbol_path.exists():
        with symbol_path.open(newline="") as f:
            for row in csv.DictReader(f):
                symbols[(int(row["address"], 16), row["mode"])] = {
                    "name": row["name"], "evidence": row.get("evidence", "")}

    manual_jump_tables = {}
    table_path = ROOT / "jump_tables.csv"
    if table_path.exists():
        with table_path.open(newline="") as f:
            for row in csv.DictReader(f):
                address = int(row["branch_address"], 16)
                offset = int(row["table_rom_offset"], 16)
                count = int(row["entry_count"])
                targets = [int.from_bytes(rom[offset+i*4:offset+i*4+4], "little") for i in range(count)]
                if any(t % 2 or not BASE <= t < BASE + len(rom) for t in targets):
                    raise SystemExit(f"Invalid manual jump table at {offset:X}")
                manual_jump_tables[address] = dict(row, targets=targets)
    followed_jump_tables = set()

    disassemblers = {}
    for mode, flag in (("arm", CS_MODE_ARM), ("thumb", CS_MODE_THUMB)):
        md = Cs(CS_ARCH_ARM, flag | CS_MODE_LITTLE_ENDIAN)
        md.detail = True
        disassemblers[mode] = md

    # Block work items are virtual addresses plus the CPU state at entry.
    initial_mode = args.entry_mode
    queue = deque([(BASE + args.entry_offset, initial_mode, True)])
    seen_blocks: set[tuple[int, str]] = set()
    instructions: dict[tuple[int, str], tuple[str, int, str, list[int]]] = {}
    function_roots: set[tuple[int, str]] = {(BASE + args.entry_offset, initial_mode)}
    indirect_transfers = []
    resolved_literals = []
    call_edges = []
    seeded_candidates = []
    if args.seed_candidates:
        reachable_listing = args.out / "reachable.asm"
        known_addresses = set()
        if reachable_listing.exists():
            for line in reachable_listing.read_text().splitlines():
                if len(line) >= 8 and all(c in "0123456789ABCDEF" for c in line[:8]):
                    known_addresses.add(int(line[:8], 16))
        with args.seed_candidates.open(newline="") as f:
            for row in csv.DictReader(f):
                addr = int(row["address"], 16)
                if (row["reachable_from_reset"] == "False" and
                        row["returns_within_64_bytes"] == "True" and
                        int(row["calls_in_first_64_bytes"]) > 0 and
                        addr not in known_addresses):
                    seed = (addr, "thumb")
                    queue.append((addr, "thumb", True))
                    function_roots.add(seed)
                    seeded_candidates.append(f"0x{addr:08X}")
    # Reviewed function-pointer tables: unlike jump tables these entries carry
    # Thumb bit 0 and each target is a function root. Keep provenance separate
    # from reset reachability and heuristic PUSH/LR candidates.
    seeded_tables = []
    function_table_path = ROOT / 'function_tables.csv'
    if function_table_path.exists():
        with function_table_path.open(newline='') as f:
            for row in csv.DictReader(f):
                offset, count = int(row['table_rom_offset'], 0), int(row['entry_count'])
                targets = []
                for index in range(count):
                    target = int.from_bytes(rom[offset + index*4:offset + index*4 + 4], 'little')
                    if not target & 1 or not BASE <= (target & ~1) < BASE + len(rom):
                        raise SystemExit(f'Invalid Thumb callback at {offset + index*4:X}')
                    targets.append(f'0x{target & ~1:08X}')
                    queue.append((target & ~1, 'thumb', True))
                    function_roots.add((target & ~1, 'thumb'))
                seeded_tables.append(dict(row, targets=targets))
    # Reviewed non-table entries, e.g. routines copied into RAM then executed.
    seeded_entries = []
    entry_path = ROOT / 'function_entries.csv'
    if entry_path.exists():
        with entry_path.open(newline='') as f:
            for row in csv.DictReader(f):
                addr, mode = int(row['address'], 0), row['mode']
                alignment = 4 if mode == 'arm' else 2
                if mode not in disassemblers or addr % alignment or not BASE <= addr < BASE + len(rom):
                    raise SystemExit(f'Invalid reviewed entry {row}')
                queue.append((addr, mode, True))
                function_roots.add((addr, mode))
                symbols[(addr, mode)] = dict(name=row['name'], evidence=row['evidence'])
                seeded_entries.append(row)
    # Reset and IRQ use hand-built LR returns around BX calls. These are
    # continuation blocks, not additional function roots. Generic BX handling
    # cannot infer their return address after the callee clobbers registers.
    queue.extend([(BASE + 0xF0, 'arm', False), (BASE + 0x1F4, 'arm', False)])
    while queue and len(instructions) < args.max_instructions:
        address, mode, is_root = queue.popleft()
        key = (address, mode)
        if key in seen_blocks:
            continue
        seen_blocks.add(key)
        pc = address
        reg_values: dict[int, int] = {}
        while BASE <= pc < BASE + len(rom) and len(instructions) < args.max_instructions:
            off = pc - BASE
            insn_key = (pc, mode)
            if insn_key in instructions:
                break
            md = disassemblers[mode]
            # Some Thumb calls are 32-bit (BL/BLX), so provide four bytes and
            # let Capstone select the instruction width.
            chunk = rom[off:min(off + 4, len(rom))]
            insn = next(md.disasm(chunk, pc, count=1), None)
            if insn is None:
                break
            groups = list(insn.groups)
            imm_targets = [op.imm for op in insn.operands if op.type == ARM_OP_IMM]
            instructions[insn_key] = (insn.mnemonic, insn.size, insn.op_str, groups)
            if args.trace:
                print(f"TRACE {pc:08X} {mode} {insn.mnemonic} {insn.op_str} groups={groups}")
            mnemonic = insn.mnemonic.lower()
            is_call = CS_GRP_CALL in groups
            is_jump = CS_GRP_JUMP in groups
            target = imm_targets[0] if imm_targets and (is_call or is_jump) else None
            operands_text = insn.op_str.lower()
            prev = instructions.get((pc - 2, mode)) if mode == "thumb" else None
            popped_return_reg = False
            if mnemonic == "bx" and prev and prev[0] == "pop":
                prev_regs = {part.strip() for part in prev[2].strip("{}").split(",")}
                popped_return_reg = operands_text.strip() in prev_regs
            is_return = (CS_GRP_RET in groups or
                         (mnemonic in {"pop", "ldm", "ldmia", "ldmfd"} and "pc" in operands_text) or
                         (mnemonic == "bx" and operands_text.strip() == "lr") or
                         popped_return_reg or
                         (mnemonic == "mov" and operands_text.startswith("pc, lr")))

            # Track simple PC-relative literal loads, which are common for GBA
            # startup trampolines and indirect function tables.
            try:
                _, regs_written = insn.regs_access()
                for reg in regs_written:
                    reg_values.pop(reg, None)
            except Exception:
                pass
            literal = None
            if (len(insn.operands) >= 2 and insn.operands[0].type == ARM_OP_REG and
                    insn.operands[1].type == ARM_OP_MEM and
                    insn.operands[1].mem.base == ARM_REG_PC):
                pc_value = (pc + 8) if mode == "arm" else ((pc + 4) & ~3)
                literal_address = pc_value + insn.operands[1].mem.disp
                literal_offset = literal_address - BASE
                if 0 <= literal_offset <= len(rom) - 4:
                    literal = int.from_bytes(rom[literal_offset:literal_offset + 4], "little")
                    reg_values[insn.operands[0].reg] = literal
                    resolved_literals.append({"instruction": f"0x{pc:08X}",
                                              "literal_address": f"0x{literal_address:08X}",
                                              "value": f"0x{literal:08X}"})

            # In-place ARM/Thumb switches in the copied audio mixer use ADR
            # then BX, or ARM ADD register,PC,#offset then BX. Capstone reports
            # ADR's displacement, not the computed destination address.
            if getattr(insn, "cc", ARM_CC_AL) == ARM_CC_AL:
                if (mnemonic == "adr" and len(insn.operands) == 2 and
                        insn.operands[0].type == ARM_OP_REG and insn.operands[1].type == ARM_OP_IMM):
                    base_pc = pc + 8 if mode == "arm" else ((pc + 4) & ~3)
                    reg_values[insn.operands[0].reg] = base_pc + insn.operands[1].imm
                elif (mnemonic in {"add", "sub"} and len(insn.operands) == 3 and
                        insn.operands[0].type == ARM_OP_REG and
                        insn.operands[1].type == ARM_OP_REG and insn.operands[1].reg == ARM_REG_PC and
                        insn.operands[2].type == ARM_OP_IMM):
                    base_pc = pc + 8 if mode == "arm" else ((pc + 4) & ~3)
                    displacement = insn.operands[2].imm * (-1 if mnemonic == "sub" else 1)
                    reg_values[insn.operands[0].reg] = base_pc + displacement

            # Direct calls add a new function root and execution continues at LR.
            if is_call:
                register_target = target is None and len(insn.operands) and insn.operands[-1].type == ARM_OP_REG
                if register_target:
                    target = reg_values.get(insn.operands[-1].reg)
                if target is not None and BASE <= (target & ~1) < BASE + len(rom):
                    target_mode = (("thumb" if target & 1 else "arm") if register_target else
                                   (("thumb" if mode == "arm" else "arm") if mnemonic == "blx" else mode))
                    function_roots.add((target & ~1, target_mode))
                    queue.append((target & ~1, target_mode, True))
                    call_edges.append({"from": f"0x{pc:08X}", "from_mode": mode,
                                       "to": f"0x{target & ~1:08X}", "to_mode": target_mode,
                                       "instruction": mnemonic})
                else:
                    indirect_transfers.append({"address": f"0x{pc:08X}", "mode": mode,
                                               "instruction": insn.mnemonic + (" " + insn.op_str if insn.op_str else "")})
                    call_edges.append({"from": f"0x{pc:08X}", "from_mode": mode,
                                       "to": None, "to_mode": None, "instruction": mnemonic})
                # A called function can clobber caller-saved registers.
                for reg in list(reg_values):
                    if md.reg_name(reg) in {"r0", "r1", "r2", "r3", "r12", "lr"}:
                        reg_values.pop(reg, None)
                pc += insn.size
                continue

            if is_return:
                break

            # Thumb MOV PC does not exchange CPU state and does not fall through.
            # Capstone does not consistently classify it as a jump. Known tables
            # are supplied only where the ROM's preceding range check proves size.
            if (mode == "thumb" and mnemonic == "mov" and len(insn.operands) == 2
                    and insn.operands[0].type == ARM_OP_REG and insn.operands[0].reg == ARM_REG_PC):
                table = manual_jump_tables.get(pc)
                if table:
                    for destination in table["targets"]:
                        queue.append((destination, table["target_mode"], False))
                    followed_jump_tables.add(pc)
                else:
                    source = insn.operands[1]
                    destination = reg_values.get(source.reg) if source.type == ARM_OP_REG else None
                    if destination is not None and BASE <= destination < BASE + len(rom):
                        queue.append((destination & ~1, mode, False))
                    else:
                        indirect_transfers.append({"address": f"0x{pc:08X}", "mode": mode,
                                                   "instruction": insn.mnemonic + " " + insn.op_str})
                break

            # Branch targets are blocks. Conditional branches also fall through.
            is_branch = is_jump
            if is_branch:
                register_target = target is None and len(insn.operands) and insn.operands[0].type == ARM_OP_REG
                if register_target:
                    target = reg_values.get(insn.operands[0].reg)
                if target is not None and BASE <= (target & ~1) < BASE + len(rom):
                    target_mode = ("thumb" if target & 1 else "arm") if register_target else mode
                    if register_target:
                        function_roots.add((target & ~1, target_mode))
                    queue.append((target & ~1, target_mode, True))
                elif target is None:
                    indirect_transfers.append({"address": f"0x{pc:08X}", "mode": mode,
                                               "instruction": insn.mnemonic + (" " + insn.op_str if insn.op_str else "")})
                conditional = (getattr(insn, "cc", ARM_CC_AL) != ARM_CC_AL or
                               mnemonic in {"cbz", "cbnz"})
                if conditional:
                    pc += insn.size
                    continue
                break
            pc += insn.size

    args.out.mkdir(parents=True, exist_ok=True)
    lines = ["; Conservative GBA ARM/Thumb control-flow disassembly",
             f"; ROM: {args.rom.name}", f"; Entry: 0x{BASE + args.entry_offset:08X} ({initial_mode})",
             "; Includes reviewed function-table roots and jump tables; other indirect transfers remain unresolved.", ""]
    for (address, mode), (mnemonic, size, operands, _) in sorted(instructions.items()):
        if (address, mode) in function_roots:
            name = symbols.get((address, mode), {}).get("name", f"sub_{address:08X}_{mode}")
            lines.append(f"{name}:")
        elif (address, mode) in seen_blocks:
            lines.append(f"loc_{address:08X}_{mode}:")
        lines.append(f"{address:08X}  {mode:5s}  {mnemonic:<8s} {operands}")
    prefix = "expanded" if args.seed_candidates else "reachable"
    (args.out / f"{prefix}.asm").write_text("\n".join(lines) + "\n")
    candidates = []
    candidate_manifest = ROOT / "build" / "rom_report.json"
    if candidate_manifest.exists():
        candidates = json.loads(candidate_manifest.read_text()).get("lz77_candidates", [])
    pointer_rows = []
    asm_index = {line[:8]: i for i, line in enumerate(lines)
                 if len(line) >= 8 and all(c in "0123456789ABCDEF" for c in line[:8])}
    wrapper_calls = {
        "#0x8036928": ("BIOS CpuFastSet (SWI 0x0c)", "cpufastset"),
        "#0x803692c": ("BIOS CpuSet (SWI 0x0b)", "cpuset"),
        "#0x8036934": ("BIOS LZ77UnCompWram (SWI 0x11)", "lz77wram"),
    }
    for ref in resolved_literals:
        value = int(ref["value"], 16)
        offset = value - BASE
        if 0 <= offset < len(rom):
            match = next((c for c in candidates if c["rom_offset"] == offset), None)
            if match is None:
                match = next((c for c in candidates if c["rom_offset"] < offset <
                              c["rom_offset"] + c["compressed_size"]), None)
            asm_i = asm_index.get(ref["instruction"][2:].upper())
            lookahead = lines[asm_i:asm_i + 12] if asm_i is not None else []
            usage, usage_kind, copy_size = "", "", ""
            r2_value = None
            for line in lookahead:
                m = re.search(r"movs?\s+r2,\s*#(0x[0-9a-f]+|[0-9]+)", line.lower())
                if m:
                    r2_value = int(m.group(1), 0)
                m = re.search(r"lsls\s+r2,\s*r2,\s*#(0x[0-9a-f]+|[0-9]+)", line.lower())
                if m and r2_value is not None:
                    r2_value <<= int(m.group(1), 0)
                wrapper = next(((desc, kind) for needle, (desc, kind) in wrapper_calls.items()
                                if needle in line.lower()), None)
                if wrapper:
                    usage, usage_kind = wrapper
                    if usage_kind in {"cpuset", "cpufastset"} and r2_value is not None:
                        count = r2_value & 0x1FFFFF
                        unit = 4 if r2_value & (1 << 26) else 2
                        copy_size = str(count * unit)
                    break
            pointer_rows.append({"instruction": ref["instruction"],
                                 "literal_address": ref["literal_address"],
                                 "target_address": ref["value"],
                                 "target_offset": f"0x{offset:X}",
                                 "lz77_candidate_start": (f"0x{match['rom_offset']:X}" if match else ""),
                                 "lz77_delta": (f"0x{offset - match['rom_offset']:X}" if match else ""),
                                 "probable_use": usage, "copy_size_bytes": copy_size})
    with (args.out / f"{prefix}_rom_pointer_references.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["instruction", "literal_address", "target_address",
                                               "target_offset", "lz77_candidate_start", "lz77_delta",
                                               "probable_use", "copy_size_bytes"])
        writer.writeheader()
        writer.writerows(pointer_rows)
    report = {
        "rom": str(args.rom), "rom_size": len(rom), "base_address": f"0x{BASE:08X}",
        "disassembly_scope": "reset and reviewed table/entry roots plus heuristic candidates" if args.seed_candidates else "reset and reviewed table/entry roots",
        "entry": {"address": f"0x{BASE + args.entry_offset:08X}", "mode": initial_mode},
        "instruction_count": len(instructions),
        "arm_instruction_count": sum(k[1] == "arm" for k in instructions),
        "thumb_instruction_count": sum(k[1] == "thumb" for k in instructions),
        "basic_block_count": len(seen_blocks),
        "direct_function_roots": [{"address": f"0x{a:08X}", "mode": m}
                                   for a, m in sorted(function_roots)],
        "direct_call_edges": call_edges,
        "basic_block_starts": [{"address": f"0x{a:08X}", "mode": m}
                                for a, m in sorted(seen_blocks)],
        "indirect_transfers": indirect_transfers,
        "resolved_pc_relative_literals": resolved_literals,
        "rom_pointer_reference_count": len(pointer_rows),
        "manual_symbols": [{"address": f"0x{a:08X}", "mode": m,
                            "name": info["name"], "evidence": info["evidence"]}
                           for (a, m), info in sorted(symbols.items())],
        "heuristic_candidate_seeds": seeded_candidates,
        "manual_function_table_seeds": seeded_tables,
        "manual_function_entry_seeds": seeded_entries,
        "followed_manual_jump_tables": [manual_jump_tables[a] for a in sorted(followed_jump_tables)],
        "unclassified_rom_bytes": len(rom) - sum(value[1] for value in instructions.values()),
        "limitations": ["Unresolved indirect calls and register targets are not followed; documented MOV PC tables are expanded.",
                        "Data/code boundaries are not inferred outside reachable control flow.",
                        "Thumb/ARM state changes through register-indirect branches need manual analysis."],
    }
    (args.out / f"{prefix}_report.json").write_text(json.dumps(report, indent=2) + "\n")
    detail_fields = {"direct_function_roots", "direct_call_edges", "basic_block_starts",
                     "indirect_transfers", "resolved_pc_relative_literals", "limitations",
                     "heuristic_candidate_seeds"}
    print(json.dumps({k: v for k, v in report.items() if k not in detail_fields}, indent=2))
    print(f"Wrote {args.out / f'{prefix}.asm'} and {args.out / f'{prefix}_report.json'}")


if __name__ == "__main__":
    main()
