#!/usr/bin/env python3
"""Join extracted illustration IDs to Sacred Cards records through Master Duel tables."""

from __future__ import annotations

import argparse
import csv
import json
import struct
import unicodedata
import zlib
from collections import defaultdict
from pathlib import Path
from typing import Any

try:
    import UnityPy
except ImportError as exc:
    raise SystemExit(
        "UnityPy is required for this one-off inspection. Install it in an isolated "
        "environment and run this script with that environment's Python."
    ) from exc


TABLE_NAMES = {"CARD_Name", "CARD_Indx", "CARD_Prop"}
FIELDS = (
    "sacred_cards_id",
    "sacred_cards_name",
    "sacred_cards_password",
    "master_duel_card_id",
    "master_duel_name",
    "market",
    "illustration_path",
    "source_asset_path",
    "source_bundle",
    "match_status",
    "confidence",
    "evidence",
)


def textasset_bytes(obj: Any) -> bytes:
    value = obj.read().m_Script
    if isinstance(value, str):
        # UnityPy exposes non-UTF-8 encrypted bytes as surrogate escapes.
        return value.encode("utf-8", "surrogateescape")
    return bytes(value)


def decrypt_zlib(data: bytes) -> tuple[int, bytes]:
    for key in range(0x10000):
        decoded = bytearray(data)
        for index in range(len(decoded)):
            value = (index + key + 0x23D) * key
            value ^= index % 7
            decoded[index] ^= value & 0xFF
        try:
            return key, zlib.decompress(decoded)
        except zlib.error:
            continue
    raise ValueError("Could not find a CARD table decryption key")


def normal_name(value: str) -> str:
    return " ".join(unicodedata.normalize("NFKC", value).casefold().split())


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Root directory of the untouched asset dump")
    parser.add_argument("--inventory", type=Path, default=Path("manifests/unity_objects.csv"))
    parser.add_argument("--art-manifest", type=Path, default=Path("manifests/card_art_candidates.csv"))
    parser.add_argument("--cards-dir", type=Path, default=Path("data/cards_json"))
    parser.add_argument("--output-dir", type=Path, default=Path("manifests"))
    args = parser.parse_args()

    source = args.source.expanduser().resolve(strict=True)
    if not source.is_dir():
        parser.error(f"source is not a directory: {source}")

    table_rows: dict[str, list[dict[str, str]]] = defaultdict(list)
    with args.inventory.expanduser().open(newline="", encoding="utf-8") as stream:
        for row in csv.DictReader(stream):
            if row.get("object_type") == "TextAsset" and row.get("object_name") in TABLE_NAMES:
                table_rows[row["object_name"]].append(row)

    decoded_tables: dict[str, bytes] = {}
    keys: dict[str, int] = {}
    for name in TABLE_NAMES:
        # The current dump has a single downloaded table per name. Avoid picking
        # among the many older duplicate tables embedded in data.unity3d.
        local_rows = [row for row in table_rows[name] if row["bundle"].startswith("LocalData/")]
        if len(local_rows) != 1:
            raise ValueError(f"Expected one LocalData {name} TextAsset, found {len(local_rows)}")
        bundle_path = (source / local_rows[0]["bundle"]).resolve()
        if not bundle_path.is_relative_to(source):
            raise ValueError(f"Table bundle path escapes source root: {local_rows[0]['bundle']}")
        environment = UnityPy.load(str(bundle_path))
        table_object = next(
            obj for obj in environment.objects
            if obj.type.name == "TextAsset" and obj.path_id == int(local_rows[0]["path_id"])
        )
        keys[name], decoded_tables[name] = decrypt_zlib(textasset_bytes(table_object))

    name_data = decoded_tables["CARD_Name"]
    index_data = decoded_tables["CARD_Indx"]
    prop_data = decoded_tables["CARD_Prop"]
    if len(index_data) % 8:
        raise ValueError(f"Unexpected CARD_Indx length: {len(index_data)}")
    name_offsets = [struct.unpack_from("<I", index_data, offset)[0] for offset in range(0, len(index_data), 8)]
    names = [
        name_data[start:end].decode("utf-8").rstrip("\0")
        for start, end in zip(name_offsets[1:-1], name_offsets[2:])
    ]
    if not names or not any("Blue-Eyes White Dragon" == name for name in names):
        raise ValueError("Decoded CARD_Name table did not contain expected English names")
    if len(prop_data) < 8 or (len(prop_data) - 8) % 8:
        raise ValueError(f"Unexpected CARD_Prop length: {len(prop_data)}")
    card_ids = [struct.unpack_from("<H", prop_data, offset)[0] for offset in range(8, len(prop_data), 8)]
    if len(card_ids) != len(names):
        raise ValueError(f"CARD_Prop rows ({len(card_ids)}) do not align with CARD_Name rows ({len(names)})")
    if len(set(card_ids)) != len(card_ids):
        raise ValueError("CARD_Prop contains duplicate card IDs; refusing ambiguous name lookup")
    catalog_name_by_id = dict(zip(card_ids, names))

    sacred_cards: list[dict[str, Any]] = []
    for path in sorted(args.cards_dir.expanduser().glob("*.json")):
        sacred_cards.append(json.loads(path.read_text(encoding="utf-8")))
    if len(sacred_cards) != 900:
        raise ValueError(f"Expected 900 Sacred Cards JSON records, found {len(sacred_cards)}")
    sacred_cards.sort(key=lambda card: int(card["id"]))

    sacred_by_name: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for card in sacred_cards:
        sacred_by_name[normal_name(card["card"])].append(card)

    candidates_by_id: dict[int, list[dict[str, str]]] = defaultdict(list)
    with args.art_manifest.expanduser().open(newline="", encoding="utf-8") as stream:
        for asset in csv.DictReader(stream):
            try:
                card_id = int(Path(asset["bundle_object_name"]).name)
            except ValueError:
                continue
            if card_id in catalog_name_by_id:
                asset["master_duel_card_id"] = str(card_id)
                asset["master_duel_name"] = catalog_name_by_id[card_id]
                candidates_by_id[card_id].append(asset)

    catalog_ids_by_name: dict[str, list[int]] = defaultdict(list)
    for card_id, name in catalog_name_by_id.items():
        if name:
            catalog_ids_by_name[normal_name(name)].append(card_id)

    rows: list[dict[str, Any]] = []
    matched_sacred_ids: set[int] = set()
    for card in sacred_cards:
        canonical = normal_name(card["card"])
        master_ids = sorted(set(catalog_ids_by_name.get(canonical, [])))
        possible_sacred_cards = sacred_by_name[canonical]
        if not master_ids:
            rows.append(
                {
                    "sacred_cards_id": card["id"],
                    "sacred_cards_name": card["card"],
                    "sacred_cards_password": card.get("password") or "",
                    "master_duel_card_id": "",
                    "master_duel_name": "",
                    "market": "",
                    "illustration_path": "",
                    "source_asset_path": "",
                    "source_bundle": "",
                    "match_status": "unmatched",
                    "confidence": "unmatched",
                    "evidence": "No exact normalized English-name match found in the decoded Master Duel CARD_Name table.",
                }
            )
            continue
        matched_sacred_ids.add(int(card["id"]))
        duplicate_name = len(possible_sacred_cards) > 1
        multiple_master_ids = len(master_ids) > 1
        confidence = "medium" if duplicate_name or multiple_master_ids else "high"
        for master_id in master_ids:
            matches = candidates_by_id.get(master_id, [])
            for asset in matches or [None]:
                rows.append(
                    {
                        "sacred_cards_id": card["id"],
                        "sacred_cards_name": card["card"],
                        "sacred_cards_password": card.get("password") or "",
                        "master_duel_card_id": master_id,
                        "master_duel_name": catalog_name_by_id[master_id],
                        "market": Path(asset["export_path"]).parts[0] if asset else "",
                        "illustration_path": f"local_assets/card_art/candidates/{asset['export_path']}" if asset else "",
                        "source_asset_path": asset["source_asset_path"] if asset else "",
                        "source_bundle": asset["bundle"] if asset else "",
                        "match_status": "name_match_art_available" if asset else "name_match_art_not_in_candidate_dump",
                        "confidence": confidence,
                        "evidence": "CARD_Prop card ID at this row aligns with CARD_Name at the same CARD_Indx row; illustration AssetBundle path contains the same card ID; Sacred Cards name matches exactly after Unicode normalization, case-folding, and whitespace collapse.",
                    }
                )

    args.output_dir.expanduser().mkdir(parents=True, exist_ok=True)
    csv_path = args.output_dir.expanduser() / "card_asset_mapping.csv"
    json_path = args.output_dir.expanduser() / "card_asset_mapping.json"
    with csv_path.open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=FIELDS)
        writer.writeheader()
        writer.writerows(rows)
    with json_path.open("w", encoding="utf-8") as stream:
        json.dump(rows, stream, ensure_ascii=False, indent=2)
        stream.write("\n")

    print(f"UnityPy version: {getattr(UnityPy, '__version__', 'unknown')}")
    print(f"CARD table decryption keys: {', '.join(f'{name}={keys[name]:#x}' for name in sorted(keys))}")
    print(f"Sacred Cards with exact Master Duel name match: {len(matched_sacred_ids)}/900")
    print(f"Sacred Cards with matching exported illustration ID: {len({int(r['sacred_cards_id']) for r in rows if r['illustration_path']})}/900")
    print(f"Mapping rows (includes multiple matching artworks): {len(rows)}")
    print(f"Unmatched Sacred Cards: {900 - len(matched_sacred_ids)}")
    print(f"Wrote: {csv_path}")
    print(f"Wrote: {json_path}")


if __name__ == "__main__":
    main()
