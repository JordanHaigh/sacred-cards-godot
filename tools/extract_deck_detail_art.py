#!/usr/bin/env python3
"""Extract deck_builder_graphics.c's fixed mode-0 row tiles as a PNG atlas."""

from __future__ import annotations

import argparse
import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ASSET_DIR = ROOT / "decompiled/build/assets/deck-builder"
TILE_FILE = ASSET_DIR / "collection-deck.tiles4.bin"
PALETTE_FILE = ASSET_DIR / "list-enabled.pal"
WIDTH = 6 * 8
HEIGHT = 2 * 8
VISIBLE_ROWS = 5


def _png_chunk(kind: bytes, payload: bytes) -> bytes:
	return (
		struct.pack(">I", len(payload))
		+ kind
		+ payload
		+ struct.pack(">I", zlib.crc32(kind + payload) & 0xFFFFFFFF)
	)


def extract(output: Path) -> None:
	tiles = TILE_FILE.read_bytes()
	palette_data = PALETTE_FILE.read_bytes()
	if len(palette_data) < 32:
		raise ValueError(f"Expected a 16-color palette: {PALETTE_FILE}")
	if len(tiles) % 32:
		raise ValueError(f"4bpp tile data is not a whole number of tiles: {TILE_FILE}")

	palette: list[tuple[int, int, int, int]] = []
	for index in range(16):
		value = struct.unpack_from("<H", palette_data, index * 2)[0]
		red = (value & 0x1F) * 255 // 31
		green = ((value >> 5) & 0x1F) * 255 // 31
		blue = ((value >> 10) & 0x1F) * 255 // 31
		palette.append((red, green, blue, 255))

	width = WIDTH * VISIBLE_ROWS
	rows: list[bytes] = []	# PNG filter type 0 on each scanline.
	for pixel_y in range(HEIGHT):
		line = bytearray([0])
		for pixel_x in range(width):
			row = pixel_x // WIDTH
			local_x = pixel_x % WIDTH
			column = local_x // 8
			within_x = local_x % 8
			within_y = pixel_y % 8
			tile_id = 0xF4 + row * 48 + (column // 2) * 4 + column % 2
			if pixel_y >= 8:
				tile_id += 2
			byte_offset = tile_id * 32 + within_y * 4 + within_x // 2
			if byte_offset >= len(tiles):
				raise ValueError(f"Tile {tile_id:#x} exceeds {TILE_FILE}")
			packed = tiles[byte_offset]
			color_index = packed >> 4 if within_x & 1 else packed & 0x0F
			line.extend(palette[color_index])
		rows.append(bytes(line))

	ihdr = struct.pack(">IIBBBBB", width, HEIGHT, 8, 6, 0, 0, 0)
	png = (
		b"\x89PNG\r\n\x1a\n"
		+ _png_chunk(b"IHDR", ihdr)
		+ _png_chunk(b"IDAT", zlib.compress(b"".join(rows), 9))
		+ _png_chunk(b"IEND", b"")
	)
	output.parent.mkdir(parents=True, exist_ok=True)
	output.write_bytes(png)


def main() -> None:
	parser = argparse.ArgumentParser(description=__doc__)
	parser.add_argument(
		"--output",
		type=Path,
		default=ROOT / "art/ui/deck-builder/detail-mode-0.png",
	)
	args = parser.parse_args()
	extract(args.output)


if __name__ == "__main__":
	main()
