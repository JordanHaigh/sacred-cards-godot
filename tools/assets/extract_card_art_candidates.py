#!/usr/bin/env python3
"""Export card illustration Texture2D candidates without changing the source dump."""

from __future__ import annotations

import argparse
import csv
import os
from pathlib import Path, PurePosixPath
from typing import Any

try:
    import UnityPy
except ImportError as exc:
    raise SystemExit(
        "UnityPy is required for this one-off inspection. Install it in an isolated "
        "environment and run this script with that environment's Python."
    ) from exc


FIELDS = (
    "source_asset_path",
    "bundle",
    "bundle_object_name",
    "object_type",
    "object_name",
    "path_id",
    "serialized_size",
    "width",
    "height",
    "export_path",
    "status",
    "notes",
)


def export_relative_path(asset_path: str) -> Path:
    normalized = asset_path.replace("\\", "/")
    marker = "card/images/illust/"
    start = normalized.casefold().find(marker)
    if start < 0:
        raise ValueError(f"Unexpected illustration path: {asset_path}")
    relative = PurePosixPath(normalized[start + len(marker) :])
    if not relative.parts or any(part in {".", ".."} for part in relative.parts):
        raise ValueError(f"Unsafe illustration path: {asset_path}")
    return Path(*relative.with_suffix(".png").parts)


def parsed_name(obj: Any) -> str:
    try:
        return str(obj.peek_name() or "")
    except Exception:
        return ""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Root directory of the untouched asset dump")
    parser.add_argument(
        "--inventory",
        type=Path,
        default=Path("manifests/unity_objects.csv"),
        help="CSV created by inventory_unity_objects.py",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("local_assets/card_art/candidates"),
        help="Directory for candidate PNGs, relative to the current working directory",
    )
    parser.add_argument(
        "--manifest",
        type=Path,
        default=Path("manifests/card_art_candidates.csv"),
        help="Candidate provenance CSV",
    )
    parser.add_argument("--limit", type=int, help="Optional maximum number of candidate bundles to process")
    args = parser.parse_args()

    source = args.source.expanduser().resolve(strict=True)
    if not source.is_dir():
        parser.error(f"source is not a directory: {source}")

    candidates: list[tuple[str, str]] = []
    with args.inventory.expanduser().open(newline="", encoding="utf-8") as stream:
        for row in csv.DictReader(stream):
            if row.get("object_type") == "AssetBundle" and "card/images/illust/" in row.get("object_name", "").casefold():
                candidates.append((row["bundle"], row["object_name"]))
    candidates.sort()
    if args.limit is not None:
        if args.limit < 0:
            parser.error("--limit must be non-negative")
        candidates = candidates[: args.limit]

    output_dir = args.output_dir.expanduser()
    manifest_path = args.manifest.expanduser()
    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / ".gdignore").touch(exist_ok=True)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_partial = manifest_path.with_suffix(manifest_path.suffix + ".partial")
    count = 0
    failed = 0
    try:
        with manifest_partial.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=FIELDS)
            writer.writeheader()
            for bundle, bundle_name in candidates:
                bundle_path = (source / bundle).resolve()
                if not bundle_path.is_relative_to(source):
                    raise ValueError(f"Bundle path escapes source root: {bundle}")
                row: dict[str, object] = {
                    "source_asset_path": "",
                    "bundle": bundle,
                    "bundle_object_name": bundle_name,
                    "object_type": "Texture2D",
                    "object_name": "",
                    "path_id": "",
                    "serialized_size": "",
                    "width": "",
                    "height": "",
                    "export_path": "",
                    "status": "failed",
                    "notes": "",
                }
                try:
                    environment = UnityPy.load(str(bundle_path))
                    asset_bundle = next(
                        obj for obj in environment.objects
                        if obj.type.name == "AssetBundle" and parsed_name(obj) == bundle_name
                    )
                    data = asset_bundle.read()
                    entries = getattr(data, "m_Container", [])
                    if not entries:
                        raise ValueError("AssetBundle has no container entries")
                    asset_path, asset_info = entries[0]
                    asset_object = next(
                        obj for obj in environment.objects
                        if obj.path_id == asset_info.asset.m_PathID and obj.type.name == "Texture2D"
                    )
                    texture = asset_object.read()
                    image = texture.image
                    relative_output = export_relative_path(asset_path)
                    destination = output_dir / relative_output
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    image.save(destination, format="PNG", optimize=True)
                    row.update(
                        {
                            "source_asset_path": asset_path,
                            "object_name": str(getattr(texture, "m_Name", "") or ""),
                            "path_id": asset_object.path_id,
                            "serialized_size": getattr(asset_object, "byte_size", ""),
                            "width": getattr(texture, "m_Width", image.width),
                            "height": getattr(texture, "m_Height", image.height),
                            "export_path": relative_output.as_posix(),
                            "status": "exported",
                        }
                    )
                    count += 1
                except Exception as exc:
                    failed += 1
                    row["notes"] = f"{type(exc).__name__}: {str(exc).replace(chr(10), ' ')}"
                writer.writerow(row)
                if (count + failed) % 500 == 0:
                    print(f"Processed {count + failed}/{len(candidates)} candidates; exported {count}; failed {failed}", flush=True)

        os.replace(manifest_partial, manifest_path)
    except BaseException:
        manifest_partial.unlink(missing_ok=True)
        raise

    print(f"UnityPy version: {getattr(UnityPy, '__version__', 'unknown')}")
    print(f"Candidates: {len(candidates)}")
    print(f"Exported: {count}")
    print(f"Failed: {failed}")
    print(f"Wrote manifest: {manifest_path}")
    print(f"Image directory: {output_dir}")


if __name__ == "__main__":
    main()
