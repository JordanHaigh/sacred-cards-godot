#!/usr/bin/env python3
"""Extract the shop's 4bpp selector and scrollbar sprites as transparent PNGs."""

from __future__ import annotations

import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "decompiled/build/assets/deck-builder"
TILE_FILE = ASSET_DIR / "shop-selection.tiles4.bin"
PALETTE_FILE = ASSET_DIR / "shop-selection.pal"
SCROLLBAR_TILE_FILE = ASSET_DIR / "shop-scrollbar.tiles4.bin"
SCROLLBAR_PALETTE_FILE = ASSET_DIR / "shop-scrollbar.pal"


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
	return (
		struct.pack(">I", len(payload))
		+ kind
		+ payload
		+ struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
	)


def extract(output: Path, tile_file: Path, palette_file: Path, width: int, height: int) -> None:
	tiles = tile_file.read_bytes()
	palette_data = palette_file.read_bytes()
	if len(tiles) != (width // 8) * (height // 8) * 32:
		raise ValueError(f"Unexpected number of 4bpp tiles: {tile_file}")
	if len(palette_data) < 32:
		raise ValueError(f"Expected a 16-color palette: {palette_file}")

	palette: list[tuple[int, int, int, int]] = []
	for index in range(16):
		value = struct.unpack_from("<H", palette_data, index * 2)[0]
		red = (value & 0x1F) * 255 // 31
		green = ((value >> 5) & 0x1F) * 255 // 31
		blue = ((value >> 10) & 0x1F) * 255 // 31
		palette.append((red, green, blue, 0 if index == 0 else 255))

	rows: list[bytes] = []
	for y in range(height):
		line = bytearray([0])
		for x in range(width):
			tile = (y // 8) * (width // 8) + x // 8
			offset = tile * 32 + (y % 8) * 4 + (x % 8) // 2
			packed = tiles[offset]
			color_index = packed >> 4 if x & 1 else packed & 0x0F
			line.extend(palette[color_index])
		rows.append(bytes(line))

	ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
	png = (
		b"\x89PNG\r\n\x1a\n"
		+ _png_chunk(b"IHDR", ihdr)
		+ _png_chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
		+ _png_chunk(b"IEND", b"")
	)
	output.parent.mkdir(parents=True, exist_ok=True)
	output.write_bytes(png)


if __name__ == "__main__":
	import argparse

	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument(
		"--output",
		type=Path,
		default=ROOT / "art/ui/shop/selection-cursor.png",
	)
	parser.add_argument(
		"--scrollbar-output",
		type=Path,
		default=ROOT / "art/ui/shop/scrollbar-thumb.png",
	)
	args = parser.parse_args()
	extract(args.output, TILE_FILE, PALETTE_FILE, 32, 32)
	extract(args.scrollbar_output, SCROLLBAR_TILE_FILE, SCROLLBAR_PALETTE_FILE, 8, 16)
