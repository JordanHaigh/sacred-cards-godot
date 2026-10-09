#!/usr/bin/env python3
"""Render large decompressed streams as tile-oriented indexed PNG previews.

GBA graphics often use 4bpp 8x8 tiles. Previews use a linear tile layout; raw
grayscale views and code-paired RGB555 palette variants are emitted. Tilemaps
and the exact palette-bank assignment still need to be identified.
"""
from __future__ import annotations

import json
import math
import struct
import zlib
import csv
from pathlib import Path

MAX_PREVIEW_BYTES = 512 * 1024


def png_indexed(path: Path, pixels: bytes, width: int, height: int, colors: int,
                palette_rgb: list[tuple[int, int, int]] | None = None,
                transparent_index: int | None = None):
    palette = bytearray()
    for i in range(colors):
        if palette_rgb and i < len(palette_rgb):
            palette.extend(palette_rgb[i])
        else:
            v = round(i * 255 / (colors - 1))
            palette.extend((v, v, v))

    def chunk(kind: bytes, payload: bytes) -> bytes:
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)

    rows = bytearray()
    for y in range(height):
        rows.append(0)
        row = pixels[y * width:(y + 1) * width]
        if colors == 16:
            rows.extend((row[x] << 4) | row[x + 1] for x in range(0, width, 2))
        else:
            rows.extend(row)
    bitdepth = 4 if colors == 16 else 8
    transparency = b""
    if transparent_index is not None:
        if not 0 <= transparent_index < colors:
            raise ValueError("Transparency index outside palette")
        transparency = chunk(b"tRNS", bytes(0 if i == transparent_index else 255 for i in range(colors)))
    out = (b"\x89PNG\r\n\x1a\n" +
           chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, bitdepth, 3, 0, 0, 0)) +
           chunk(b"PLTE", bytes(palette)) + transparency +
           chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b""))
    path.write_bytes(out)


def main():
    report = json.loads(Path("build/rom_report.json").read_text())
    notes_path = Path("asset_notes.csv")
    annotations = {}
    if notes_path.exists():
        with notes_path.open(newline="") as f:
            for row in csv.DictReader(f):
                annotations[int(row["rom_offset"], 16)] = row
    out = Path("build/previews")
    out.mkdir(parents=True, exist_ok=True)
    entries = []
    code_refs: dict[int, set[str]] = {}
    reset_code_refs: dict[int, set[str]] = {}
    expanded_code_refs: dict[int, set[str]] = {}
    code_usage: dict[int, set[str]] = {}
    copy_sizes_by_rom_offset: dict[int, int] = {}
    refs_paths = [(Path("build/disassembly/reachable_rom_pointer_references.csv"), "reset"),
                  (Path("build/disassembly/expanded_rom_pointer_references.csv"), "expanded")]
    rom = Path(report["file"]).read_bytes()

    for refs_path, origin in refs_paths:
        if refs_path.exists():
            with refs_path.open(newline="") as f:
                for ref in csv.DictReader(f):
                    if ref["lz77_candidate_start"]:
                        start = int(ref["lz77_candidate_start"], 16)
                        site = ref["instruction"]
                        code_refs.setdefault(start, set()).add(site)
                        origin_refs = reset_code_refs if origin == "reset" else expanded_code_refs
                        origin_refs.setdefault(start, set()).add(site)
                        if ref["probable_use"]:
                            code_usage.setdefault(start, set()).add(ref["probable_use"])
                    if "CpuSet" in ref["probable_use"] and ref["copy_size_bytes"]:
                        source = int(ref["target_offset"], 16)
                        copy_sizes_by_rom_offset[source] = max(
                            copy_sizes_by_rom_offset.get(source, 0), int(ref["copy_size_bytes"]))
    for item in report["lz77_candidates"]:
        has_lz77_use = any("LZ77UnCompWram" in use
                           for use in code_usage.get(item["rom_offset"], set()))
        if item["decompressed_size"] > MAX_PREVIEW_BYTES or (
                item["decompressed_size"] < 8192 and not has_lz77_use):
            continue
        src = Path("build") / item["file"]
        data = src.read_bytes()
        if not any(data):
            continue
        # Each 4bpp tile is 32 bytes; render successive tiles left-to-right.
        width4, tiles_per_row = 256, 32
        tile_count4 = math.ceil(len(data) / 32)
        height4 = math.ceil(tile_count4 / tiles_per_row) * 8
        px4 = bytearray(width4 * height4)
        for tile in range(tile_count4):
            tx, ty = (tile % tiles_per_row) * 8, (tile // tiles_per_row) * 8
            for j in range(32):
                source = tile * 32 + j
                value = data[source] if source < len(data) else 0
                x, y = tx + (j % 4) * 2, ty + j // 4
                px4[y * width4 + x] = value & 15
                px4[y * width4 + x + 1] = value >> 4
        name = Path(item["file"]).stem
        annotation = annotations.get(item["rom_offset"], {})
        manual_palette = (int(annotation["manual_palette_rom_offset"], 16)
                          if annotation.get("manual_palette_rom_offset") else None)
        file4 = f"{name}-4bpp.png"
        png_indexed(out / file4, bytes(px4), width4, height4, 16)
        file8 = f"{name}-8bpp.png"
        # 8bpp graphics store 64 bytes per tile.
        width8, tiles_per_row8 = 256, 32
        tile_count8 = math.ceil(len(data) / 64)
        height8 = math.ceil(tile_count8 / tiles_per_row8) * 8
        px8 = bytearray(width8 * height8)
        for tile in range(tile_count8):
            tx, ty = (tile % tiles_per_row8) * 8, (tile // tiles_per_row8) * 8
            block = data[tile * 64:(tile + 1) * 64].ljust(64, b"\0")
            for j, value in enumerate(block):
                x, y = tx + j % 8, ty + j // 8
                px8[y * width8 + x] = value
        png_indexed(out / file8, px8, width8, height8, 256)
        palette_variants = []
        if manual_palette is not None:
            palette_length = copy_sizes_by_rom_offset.get(manual_palette, 0)
            palette_data = rom[manual_palette:manual_palette + palette_length]
            for bank in range(len(palette_data) // 32):
                words = [int.from_bytes(palette_data[bank * 32 + i * 2:bank * 32 + i * 2 + 2], "little")
                         for i in range(16)]
                if any(v & 0x8000 for v in words) or len(set(words)) < 6:
                    continue
                rgb = [((v & 31) * 255 // 31,
                        ((v >> 5) & 31) * 255 // 31,
                        ((v >> 10) & 31) * 255 // 31) for v in words]
                pal_file = f"{name}-pal-{manual_palette:06X}-{bank:02d}.png"
                png_indexed(out / pal_file, bytes(px4), width4, height4, 16, rgb)
                palette_variants.append({"file": pal_file, "palette_rom_offset": manual_palette,
                                         "bank": bank, "manual_pairing": True})
        entries.append({"rom_offset": item["rom_offset"], "rom_address": item["rom_address"],
                        "source_size": len(data), "preview_4bpp": file4,
                        "preview_8bpp": file8,
                        "code_reference_sites": sorted(code_refs.get(item["rom_offset"], set())),
                        "reset_code_reference_sites": sorted(reset_code_refs.get(item["rom_offset"], set())),
                        "expanded_code_reference_sites": sorted(expanded_code_refs.get(item["rom_offset"], set()) - reset_code_refs.get(item["rom_offset"], set())),
                        "code_usage": sorted(code_usage.get(item["rom_offset"], set())),
                        "palette_variants": palette_variants,
                        "asset_annotation": annotation})
    html = ["<!doctype html><meta charset='utf-8'><title>Sacred Cards tile previews</title>",
            "<style>body{background:#202124;color:#eee;font:14px sans-serif}article{display:inline-block;vertical-align:top;margin:12px;padding:10px;background:#333;max-width:540px}img{image-rendering:pixelated;max-width:512px;border:1px solid #888}a{color:#9cf}</style>",
            "<h1>Candidate tile previews</h1><p>Linear tiled 4bpp and 8bpp grayscale sheets, plus RGB555 palette variants where code references suggest a pairing. Tilemap arrangement and exact palette-bank use still need confirmation.</p>"]
    for e in entries:
        refs = ", ".join(e["code_reference_sites"])
        exploratory_refs = ", ".join(e["expanded_code_reference_sites"])
        usage = "; ".join(e["code_usage"])
        evidence = (f"{usage}. Reset-reachable refs: {', '.join(e['reset_code_reference_sites'])}. Exploratory refs: {exploratory_refs}" if usage else
                    f"Reset-reachable refs: {', '.join(e['reset_code_reference_sites'])}. Exploratory refs: {exploratory_refs}" if refs else "No direct code pointer found")
        annotation = e["asset_annotation"]
        label = (f"<h2>{annotation['asset_label']} <small>({annotation['confidence']} confidence)</small></h2><p>{annotation['evidence']}</p>" if annotation else "")
        palette_images = "".join(f"<p>Annotated palette +0x{v['palette_rom_offset']:X}, bank {v['bank']}:<br><img src='{v['file']}'></p>" for v in e["palette_variants"])
        html.append(f"<article><b>{e['rom_address']} (ROM +0x{e['rom_offset']:X}), {e['source_size']} bytes</b>{label}<p>{evidence}</p><p>4bpp grayscale: <a href='{e['preview_4bpp']}'>{e['preview_4bpp']}</a><br><img src='{e['preview_4bpp']}'></p><p>8bpp grayscale: <a href='{e['preview_8bpp']}'>{e['preview_8bpp']}</a><br><img src='{e['preview_8bpp']}'></p>{palette_images}</article>")
    (out / "index.html").write_text("\n".join(html) + "\n")
    (out / "manifest.json").write_text(json.dumps(entries, indent=2) + "\n")
    with (out / "classifications.csv").open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["rom_address", "rom_offset", "compressed_size",
                                               "decompressed_size", "has_preview", "preview_4bpp",
                                               "preview_8bpp", "code_reference_sites", "reset_code_reference_sites",
                                               "expanded_code_reference_sites", "reference_confidence", "code_usage", "suspected_format",
                                               "palette_candidate_offsets", "manual_palette_rom_offset",
                                               "tilemap_rom_offset", "game_location", "asset_label", "asset_kind",
                                               "confidence", "evidence", "notes"])
        writer.writeheader()
        previews_by_offset = {e["rom_offset"]: e for e in entries}
        for item in report["lz77_candidates"]:
            e = previews_by_offset.get(item["rom_offset"], {})
            annotation = e.get("asset_annotation", annotations.get(item["rom_offset"], {}))
            writer.writerow({"rom_address": item["rom_address"], "rom_offset": f"0x{item['rom_offset']:X}",
                             "compressed_size": item["compressed_size"],
                             "decompressed_size": item["decompressed_size"],
                             "has_preview": bool(e), "preview_4bpp": e.get("preview_4bpp", ""),
                             "preview_8bpp": e.get("preview_8bpp", ""),
                             "code_reference_sites": ";".join(sorted(code_refs.get(item["rom_offset"], set()))),
                             "reset_code_reference_sites": ";".join(sorted(reset_code_refs.get(item["rom_offset"], set()))),
                             "expanded_code_reference_sites": ";".join(sorted(expanded_code_refs.get(item["rom_offset"], set()) - reset_code_refs.get(item["rom_offset"], set()))),
                             "reference_confidence": ("reset reachable" if reset_code_refs.get(item["rom_offset"]) else
                                                      "heuristic-seeded code" if expanded_code_refs.get(item["rom_offset"]) else "none"),
                             "code_usage": ";".join(sorted(code_usage.get(item["rom_offset"], set()))),
                             "suspected_format": "LZ77 signature candidate (0x10)",
                             "palette_candidate_offsets": ";".join(sorted({f"0x{v['palette_rom_offset']:X}"
                                                                              for v in e.get("palette_variants", [])})),
                             "manual_palette_rom_offset": annotation.get("manual_palette_rom_offset", ""),
                             "asset_label": annotation.get("asset_label", ""),
                             "asset_kind": annotation.get("asset_kind", ""),
                             "confidence": annotation.get("confidence", ""),
                             "evidence": annotation.get("evidence", "")})
    print(f"Rendered {len(entries)} candidate streams to {out}")


if __name__ == "__main__":
    main()
