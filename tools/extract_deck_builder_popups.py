#!/usr/bin/env python3
"""Render recovered collection action and sort popup tile maps for Godot."""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "decompiled/build/assets/deck-builder"
TILE_FILE = ASSET_DIR / "collection-deck.tiles4.bin"
PALETTE_FILE = ASSET_DIR / "list-enabled.pal"
FRAME_TILE_INDICES_FILE = ASSET_DIR / "glyph-tile-indices.bin"
WIDTH_TILES, HEIGHT_TILES = 30, 20


def _chunk(kind: bytes, payload: bytes) -> bytes:
    return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)


def _bgr555(value: int) -> tuple[int, int, int, int]:
    return ((value & 31) * 255 // 31, ((value >> 5) & 31) * 255 // 31, ((value >> 10) & 31) * 255 // 31, 255)


def _apply_action_frame(tile_map: list[int], frame_indices: bytes) -> None:
    palette_flags = tile_map[2 * WIDTH_TILES + 2] & 0xFF00
    for index in range(20):
        tile = frame_indices[index]
        for row, offset in ((11, 0x15), (12, 0x17), (13, 0x3D), (14, 0x3F)):
            tile_map[row * WIDTH_TILES + index + 9] = ((tile + offset) & 0x03FF) | palette_flags


def _apply_sort_frame(tile_map: list[int], frame_indices: bytes) -> None:
    palette_flags = tile_map[2 * WIDTH_TILES + 2] & 0xFF00

    def write_tile(x: int, y: int, tile: int) -> None:
        tile_map[y * WIDTH_TILES + x] = (tile & 0x03FF) | palette_flags

    for index in range(6):
        for row in range(5):
            tile = frame_indices[index] + 0x1D + row * 32
            write_tile(index + 4, 6 + row * 2, tile)
            write_tile(index + 4, 7 + row * 2, tile + 2)
    blank = tile_map[2 * WIDTH_TILES]
    for x in range(10, 14):
        for y in range(6, 16):
            tile_map[y * WIDTH_TILES + x] = blank
    for index in range(10):
        for row in range(4):
            tile = frame_indices[index] + 0x29 + row * 32
            write_tile(index + 16, 6 + row * 2, tile)
            write_tile(index + 16, 7 + row * 2, tile + 2)
    for index in range(12):
        tile = frame_indices[index]
        write_tile(index + 4, 17, tile + 0xA9)
        write_tile(index + 4, 18, tile + 0xAB)


def render(map_file: Path, output: Path, kind: str) -> None:
    tiles = TILE_FILE.read_bytes()
    map_data = map_file.read_bytes()
    palette_data = PALETTE_FILE.read_bytes()
    frame_indices = FRAME_TILE_INDICES_FILE.read_bytes()
    if len(map_data) != WIDTH_TILES * HEIGHT_TILES * 2:
        raise ValueError(f"Expected 30x20 map: {map_file}")
    if len(tiles) % 32 or len(palette_data) != 32 or len(frame_indices) < 20:
        raise ValueError("Recovered popup tile, palette, or frame-index data has an unexpected size")
    tile_map = list(struct.unpack("<%dH" % (len(map_data) // 2), map_data))
    if kind == "action":
        _apply_action_frame(tile_map, frame_indices)
    elif kind == "sort":
        _apply_sort_frame(tile_map, frame_indices)
    else:
        raise ValueError(f"Unknown popup kind: {kind}")
    palette = [_bgr555(struct.unpack_from("<H", palette_data, index * 2)[0]) for index in range(16)]

    pixels: list[bytes] = []
    for y in range(HEIGHT_TILES * 8):
        row = bytearray([0])
        for x in range(WIDTH_TILES * 8):
            entry = tile_map[(y // 8) * WIDTH_TILES + x // 8]
            tile = entry & 0x3FF
            sx = 7 - x % 8 if entry & 0x400 else x % 8
            sy = 7 - y % 8 if entry & 0x800 else y % 8
            offset = tile * 32 + sy * 4 + sx // 2
            if offset >= len(tiles):
                raise ValueError(f"Map tile {tile:#x} exceeds {TILE_FILE}")
            packed = tiles[offset]
            color_index = (packed >> 4) & 0xF if sx & 1 else packed & 0xF
            if ((entry >> 12) & 0xF) != 5:
                raise ValueError("Popup map uses a non-native palette bank")
            row.extend(palette[color_index])
        pixels.append(bytes(row))

    png = (b"\x89PNG\r\n\x1a\n"
           + _chunk(b"IHDR", struct.pack(">IIBBBBB", 240, 160, 8, 6, 0, 0, 0))
           + _chunk(b"IDAT", zlib.compress(b"".join(pixels), 9))
           + _chunk(b"IEND", b""))
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(png)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--action-output", type=Path, default=ROOT / "art/ui/deck-builder/collection-action-popup.png")
    parser.add_argument("--sort-output", type=Path, default=ROOT / "art/ui/deck-builder/collection-sort-popup.png")
    args = parser.parse_args()
    render(ASSET_DIR / "collection-actions.map.u16", args.action_output, "action")
    render(ASSET_DIR / "collection-sort.map.u16", args.sort_output, "sort")


if __name__ == "__main__":
    main()
