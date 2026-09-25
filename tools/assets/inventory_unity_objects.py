#!/usr/bin/env python3
"""Enumerate Unity objects in bundles listed by a raw asset inventory."""

from __future__ import annotations

import argparse
import csv
import os
from pathlib import Path
from typing import Any

try:
    import UnityPy
except ImportError as exc:
    raise SystemExit(
        "UnityPy is required for this one-off inspection. Install it in an isolated "
        "environment and run this script with that environment's Python."
    ) from exc


OBJECT_FIELDS = ("bundle", "object_type", "object_name", "path_id", "size", "candidate_category")
ERROR_FIELDS = ("bundle", "error_type", "error")


def candidate_category(object_type: str, object_name: str) -> str:
    text = f"{object_type} {object_name}".casefold()
    if any(term in text for term in ("cardillust", "cardimage", "cardpicture", "cardthumb", "illust", "thumb", "picture")):
        return "card_art_candidate"
    if any(term in text for term in ("frame", "attribute", "star", "cardback", "selection")):
        return "card_ui_candidate"
    if object_type == "AudioClip" or any(term in text for term in ("bgm_", "se_")):
        return "audio_candidate"
    if any(
        term in text
        for term in ("animationclip", "animatorcontroller", "particlesystem", "summon", "attack", "fxs_", "cardcrack")
    ):
        return "animation_or_vfx_candidate"
    return "unknown"


def object_name(obj: Any) -> str:
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
        default=Path("manifests/raw_asset_inventory.csv"),
        help="CSV created by inventory_asset_dump.py",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("manifests"),
        help="Directory for unity_objects.csv and unity_object_errors.csv",
    )
    args = parser.parse_args()

    source = args.source.expanduser().resolve(strict=True)
    if not source.is_dir():
        parser.error(f"source is not a directory: {source}")

    inventory_path = args.inventory.expanduser().resolve(strict=True)
    output_dir = args.output_dir.expanduser()
    output_dir.mkdir(parents=True, exist_ok=True)
    object_path = output_dir / "unity_objects.csv"
    error_path = output_dir / "unity_object_errors.csv"
    object_partial = object_path.with_suffix(".csv.partial")
    error_partial = error_path.with_suffix(".csv.partial")

    bundle_count = 0
    object_count = 0
    errors = 0
    try:
        with inventory_path.open(newline="", encoding="utf-8") as inventory_stream, \
                object_partial.open("w", newline="", encoding="utf-8") as object_stream, \
                error_partial.open("w", newline="", encoding="utf-8") as error_stream:
            inventory_reader = csv.DictReader(inventory_stream)
            object_writer = csv.DictWriter(object_stream, fieldnames=OBJECT_FIELDS)
            error_writer = csv.DictWriter(error_stream, fieldnames=ERROR_FIELDS)
            object_writer.writeheader()
            error_writer.writeheader()

            for row in inventory_reader:
                if row.get("unity_bundle_status") not in {"likely", "possible"}:
                    continue
                relative_path = row["relative_path"]
                bundle_path = (source / relative_path).resolve()
                if not bundle_path.is_relative_to(source):
                    errors += 1
                    error_writer.writerow({"bundle": relative_path, "error_type": "InvalidPath", "error": "Path escapes source root"})
                    continue
                bundle_count += 1
                try:
                    environment = UnityPy.load(str(bundle_path))
                    for obj in environment.objects:
                        kind = obj.type.name
                        name = object_name(obj)
                        object_writer.writerow(
                            {
                                "bundle": relative_path,
                                "object_type": kind,
                                "object_name": name,
                                "path_id": obj.path_id,
                                "size": getattr(obj, "byte_size", ""),
                                "candidate_category": candidate_category(kind, name),
                            }
                        )
                        object_count += 1
                except Exception as exc:
                    errors += 1
                    error_writer.writerow(
                        {"bundle": relative_path, "error_type": type(exc).__name__, "error": str(exc).replace("\n", " ")}
                    )
                if bundle_count % 1000 == 0:
                    print(f"Scanned {bundle_count} bundles; indexed {object_count} objects; errors {errors}", flush=True)

        os.replace(object_partial, object_path)
        os.replace(error_partial, error_path)
    except BaseException:
        object_partial.unlink(missing_ok=True)
        error_partial.unlink(missing_ok=True)
        raise

    print(f"UnityPy version: {getattr(UnityPy, '__version__', 'unknown')}")
    print(f"Bundles scanned: {bundle_count}")
    print(f"Objects indexed: {object_count}")
    print(f"Bundle errors: {errors}")
    print(f"Wrote: {object_path}")
    print(f"Wrote: {error_path}")


if __name__ == "__main__":
    main()
