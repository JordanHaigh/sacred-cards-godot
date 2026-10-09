#!/usr/bin/env python3
"""Report GBA ROM metadata and extract candidate BIOS LZ77 streams."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path


def lz77(data: bytes, pos: int, max_output: int = 32 * 1024 * 1024):
    """Decode a GBA 0x10 LZ77 stream, returning bytes or None if invalid."""
    if pos + 4 > len(data) or data[pos] != 0x10:
        return None
    size = int.from_bytes(data[pos + 1:pos + 4], "little")
    if size < 8 or size > max_output:
        return None
    out = bytearray()
    i = pos + 4
    while len(out) < size:
        if i >= len(data):
            return None
        flags = data[i]
        i += 1
        for bit in range(7, -1, -1):
            if len(out) >= size:
                break
            if flags & (1 << bit):
                if i + 2 > len(data):
                    return None
                a, b = data[i], data[i + 1]
                i += 2
                length = (a >> 4) + 3
                distance = (((a & 0x0F) << 8) | b) + 1
                if distance > len(out):
                    return None
                # The BIOS stops as soon as the declared output length is
                # reached, even if the final back-reference would be longer.
                for _ in range(min(length, size - len(out))):
                    out.append(out[-distance])
            else:
                if i >= len(data):
                    return None
                out.append(data[i])
                i += 1
    return bytes(out), i - pos


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("rom", type=Path)
    ap.add_argument("--out", type=Path, default=Path("build"))
    ap.add_argument("--min-size", type=int, default=32)
    args = ap.parse_args()
    data = args.rom.read_bytes()
    if len(data) < 0xC0:
        raise SystemExit("File is too short to contain a GBA header")
    h = data[0xA0:0xB0].split(b"\0", 1)[0].decode("ascii", "replace")
    game = data[0xAC:0xB0].decode("ascii", "replace")
    maker = data[0xB0:0xB2].decode("ascii", "replace")
    report = {
        "file": str(args.rom), "size": len(data), "sha256": hashlib.sha256(data).hexdigest(),
        "title": h, "game_code": game, "maker_code": maker,
        "fixed_value": f"0x{data[0xB2]:02X}", "unit_code": f"0x{data[0xB3]:02X}",
        "software_version": data[0xBC], "entry_instruction": data[:4].hex(),
    }
    args.out.mkdir(parents=True, exist_ok=True)
    asset_dir = args.out / "lz77"
    asset_dir.mkdir(parents=True, exist_ok=True)
    candidates = []
    for pos, byte in enumerate(data):
        if byte != 0x10:
            continue
        decoded = lz77(data, pos)
        if not decoded:
            continue
        raw, consumed = decoded
        if len(raw) < args.min_size:
            continue
        candidates.append({"rom_offset": pos, "rom_address": f"0x{0x08000000 + pos:08X}",
                           "compressed_size": consumed, "decompressed_size": len(raw),
                           "file": f"lz77/{pos:08X}.bin"})
        (args.out / candidates[-1]["file"]).write_bytes(raw)
    report["lz77_candidates"] = candidates
    (args.out / "rom_report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k: v for k, v in report.items() if k != "lz77_candidates"}, indent=2))
    print(f"Found {len(candidates)} candidate LZ77 streams; see {args.out / 'rom_report.json'}")


if __name__ == "__main__":
    main()
