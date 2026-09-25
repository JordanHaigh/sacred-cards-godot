#!/usr/bin/env python3
"""Create a read-only file inventory for a supplied asset dump directory."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from collections import Counter
from pathlib import Path


FIELDS = (
    "relative_path",
    "filename",
    "extension",
    "size",
    "sha256",
    "probable_format",
    "unity_bundle_status",
)


def identify(path: Path) -> tuple[str, str]:
    with path.open("rb") as stream:
        header = stream.read(32)

    signatures = (
        (b"UnityFS\x00", "UnityFS bundle", "likely"),
        (b"UnityRaw\x00", "UnityRaw bundle", "likely"),
        (b"UnityWeb\x00", "UnityWeb bundle", "likely"),
        (b"\x89PNG\r\n\x1a\n", "PNG image", "unlikely"),
        (b"\xff\xd8\xff", "JPEG image", "unlikely"),
        (b"OggS", "Ogg audio/container", "unlikely"),
        (b"PK\x03\x04", "ZIP archive", "unlikely"),
        (b"%PDF-", "PDF document", "unlikely"),
    )
    for signature, description, bundle_status in signatures:
        if header.startswith(signature):
            return description, bundle_status

    extension = path.suffix.lower()
    if extension in {".bundle", ".assets", ".unity3d"}:
        return f"unknown binary ({extension})", "possible"
    if not extension:
        return "unknown binary (no extension)", "unknown"
    return f"unknown ({extension})", "unknown"


def inventory(source: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for path in sorted(source.rglob("*")):
        if path.is_symlink() or not path.is_file():
            continue
        digest = hashlib.sha256()
        size = 0
        with path.open("rb") as stream:
            for block in iter(lambda: stream.read(1024 * 1024), b""):
                size += len(block)
                digest.update(block)
        probable_format, unity_status = identify(path)
        rows.append(
            {
                "relative_path": path.relative_to(source).as_posix(),
                "filename": path.name,
                "extension": path.suffix.lower(),
                "size": size,
                "sha256": digest.hexdigest(),
                "probable_format": probable_format,
                "unity_bundle_status": unity_status,
            }
        )
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Root directory of the untouched dump")
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("manifests"),
        help="Directory for raw_asset_inventory.csv and .json (default: ./manifests)",
    )
    args = parser.parse_args()

    source = args.source.expanduser().resolve(strict=True)
    if not source.is_dir():
        parser.error(f"source is not a directory: {source}")

    rows = inventory(source)
    output_dir = args.output_dir.expanduser()
    output_dir.mkdir(parents=True, exist_ok=True)
    csv_path = output_dir / "raw_asset_inventory.csv"
    json_path = output_dir / "raw_asset_inventory.json"

    with csv_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    with json_path.open("w", encoding="utf-8") as stream:
        json.dump(rows, stream, ensure_ascii=False, indent=2)
        stream.write("\n")

    duplicate_hashes = sum(count - 1 for count in Counter(row["sha256"] for row in rows).values())
    total_bytes = sum(int(row["size"]) for row in rows)
    probable_bundles = sum(row["unity_bundle_status"] in {"likely", "possible"} for row in rows)
    print(f"Files: {len(rows)}")
    print(f"Bytes: {total_bytes}")
    print(f"Likely/possible Unity bundles: {probable_bundles}")
    print(f"Duplicate files by SHA-256: {duplicate_hashes}")
    print(f"Wrote: {csv_path}")
    print(f"Wrote: {json_path}")


if __name__ == "__main__":
    main()
