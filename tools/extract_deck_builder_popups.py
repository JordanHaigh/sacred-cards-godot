#!/usr/bin/env python3
"""Render the recovered 30x20 collection-sort tile map as a Godot PNG."""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "decompiled/build/assets/deck-builder"
MAP_FILE = ASSET_DIR / "collection-sort.map.u16"
TILE_FILE = ASSET_DIR / "collection-deck.tiles4.bin"
PALETTE_FILE = ASSET_DIR / "list-enabled.pal"
FRAME_TILE_INDICES_FILE = ASSET_DIR / "glyph-tile-indices.bin"
WIDTH_TILES = 30
HEIGHT_TILES = 20


def _chunk(kind: bytes, payload: bytes) -> bytes:
    return (
        struct.pack(">I", len(payload))
        + kind
        + payload
        + struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
    )


def _bgr555(value: int) -> tuple[int, int, int, int]:
    return (
        (value & 0x1F) * 255 // 31,
        ((value >> 5) & 0x1F) * 255 // 31,
        ((value >> 10) & 0x1F) * 255 // 31,
        255,
    )


def render(output: Path) -> None:
    tile_data = TILE_FILE.read_bytes()
    map_data = MAP_FILE.read_bytes()
    palette_data = PALETTE_FILE.read_bytes()
    frame_indices = FRAME_TILE_INDICES_FILE.read_bytes()
    if len(map_data) != WIDTH_TILES * HEIGHT_TILES * 2:
        raise ValueError(f"Expected a 30x20 halfword tile map: {MAP_FILE}")
    if len(tile_data) % 32:
        raise ValueError(f"4bpp tile data is incomplete: {TILE_FILE}")
    if len(palette_data) != 32:
        raise ValueError(f"Expected one 16-color OBJ/BG palette: {PALETTE_FILE}")
    if len(frame_indices) < 20:
        raise ValueError(f"Expected at least 20 frame tile indices: {FRAME_TILE_INDICES_FILE}")

    tile_map = list(struct.unpack("<%dH" % (len(map_data) // 2), map_data))
    palette_flags = tile_map[2 * WIDTH_TILES + 2] & 0xFF00

    def write_tile(x: int, y: int, tile: int) -> None:
        tile_map[y * WIDTH_TILES + x] = (tile & 0x03FF) | palette_flags

    # DrawCardListSortPopup's recovered 6-column and 10-column framed rows.
    for index in range(6):
        for row_index in range(5):
            tile = frame_indices[index] + 0x1D + row_index * 32
            write_tile(index + 4, 6 + row_index * 2, tile)
            write_tile(index + 4, 7 + row_index * 2, tile + 2)
    blank_tile = tile_map[2 * WIDTH_TILES]
    for x in range(10, 14):
        for y in range(6, 16):
            tile_map[y * WIDTH_TILES + x] = blank_tile
    for index in range(10):
        for row_index in range(4):
            tile = frame_indices[index] + 0x29 + row_index * 32
            write_tile(index + 16, 6 + row_index * 2, tile)
            write_tile(index + 16, 7 + row_index * 2, tile + 2)
    for index in range(12):
        tile = frame_indices[index]
        write_tile(index + 4, 17, tile + 0xA9)
        write_tile(index + 4, 18, tile + 0xAB)

    palette = [_bgr555(struct.unpack_from("<H", palette_data, index * 2)[0]) for index in range(16)]
    pixels: list[bytes] = []
    for screen_y in range(HEIGHT_TILES * 8):
        row = bytearray([0])
        tile_y = screen_y // 8
        local_y = screen_y % 8
        for screen_x in range(WIDTH_TILES * 8):
            tile_x = screen_x // 8
            local_x = screen_x % 8
            entry = tile_map[tile_y * WIDTH_TILES + tile_x]
            tile_index = entry & 0x3FF
            source_x = 7 - local_x if entry & 0x400 else local_x
            source_y = 7 - local_y if entry & 0x800 else local_y
            offset = tile_index * 32 + source_y * 4 + source_x // 2
            if offset >= len(tile_data):
                raise ValueError(f"Map tile {tile_index:#x} exceeds {TILE_FILE}")
            packed = tile_data[offset]
            color_index = (packed >> 4) & 0xF if source_x & 1 else packed & 0xF
            palette_bank = (entry >> 12) & 0xF
            if palette_bank != 5:
                raise ValueError(f"Unexpected map palette bank {palette_bank}; expected native bank 5")
            row.extend(palette[color_index])
        pixels.append(bytes(row))

    width, height = WIDTH_TILES * 8, HEIGHT_TILES * 8
    png = (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
        + _chunk(b"IDAT", zlib.compress(b"".join(pixels), 9))
        + _chunk(b"IEND", b"")
    )
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(png)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "art/ui/pre-duel/sort-popup.png")
    render(parser.parse_args().output)


if __name__ == "__main__":
    main()
