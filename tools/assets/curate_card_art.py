#!/usr/bin/env python3
"""Copy only unambiguous high-confidence matches into the game's card asset tree."""

from __future__ import annotations

import argparse
import csv
import hashlib
import os
import shutil
from collections import defaultdict
from pathlib import Path


FIELDS = (
    "sacred_cards_id",
    "sacred_cards_name",
    "master_duel_card_id",
    "master_duel_name",
    "confidence",
    "status",
    "curated_path",
    "candidate_path",
    "sha256",
    "source_asset_path",
    "source_bundle",
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mapping", type=Path, default=Path("manifests/card_asset_mapping.csv"))
    parser.add_argument("--repo-root", type=Path, default=Path("."))
    parser.add_argument("--manifest", type=Path, default=Path("manifests/curated_card_art.csv"))
    args = parser.parse_args()

    root = args.repo_root.expanduser().resolve(strict=True)
    mapping_path = args.mapping.expanduser().resolve(strict=True)
    if not root.is_dir():
        parser.error(f"repo root is not a directory: {root}")

    by_card: dict[str, list[dict[str, str]]] = defaultdict(list)
    with mapping_path.open(newline="", encoding="utf-8") as stream:
        for row in csv.DictReader(stream):
            by_card[row["sacred_cards_id"]].append(row)

    output_rows: list[dict[str, str]] = []
    pending_copies: list[tuple[Path, Path, dict[str, str]]] = []
    for sacred_id in sorted(by_card, key=int):
        rows = by_card[sacred_id]
        art_rows = [row for row in rows if row.get("illustration_path")]
        representative = art_rows[0] if art_rows else rows[0]
        confidence = representative.get("confidence", "unmatched")
        status = "unmatched_name"
        curated_path = ""
        candidate_path = ""
        digest = ""

        if not art_rows:
            if any(row["match_status"] == "exact_name_illustration_unlinked" for row in rows):
                status = "exact_name_art_not_found"
            elif any(row["match_status"] == "name_match_art_not_in_candidate_dump" for row in rows):
                status = "exact_name_art_not_found"
        elif len(rows) > 1 or len(art_rows) > 1:
            status = "multiple_card_or_art_candidates"
            confidence = "medium"
        elif confidence != "high":
            status = "medium_confidence"
        else:
            source_rel = Path(art_rows[0]["illustration_path"])
            source_path = (root / source_rel).resolve(strict=True)
            if not source_path.is_relative_to(root):
                raise ValueError(f"Candidate path escapes repository root: {source_rel}")
            destination_rel = Path("local_assets/card_art/cards") / f"{int(sacred_id):03d}" / "illustration.png"
            destination = root / destination_rel
            pending_copies.append((source_path, destination, art_rows[0]))
            candidate_path = source_rel.as_posix()
            curated_path = destination_rel.as_posix()
            digest = sha256(source_path)
            status = "curated"

        output_rows.append(
            {
                "sacred_cards_id": sacred_id,
                "sacred_cards_name": representative["sacred_cards_name"],
                "master_duel_card_id": representative.get("master_duel_card_id", ""),
                "master_duel_name": representative.get("master_duel_name", ""),
                "confidence": confidence,
                "status": status,
                "curated_path": curated_path,
                "candidate_path": candidate_path,
                "sha256": digest,
                "source_asset_path": representative.get("source_asset_path", ""),
                "source_bundle": representative.get("source_bundle", ""),
            }
        )

    # Check every destination before writing any image. Existing different files
    # are preserved and cause a clear stop instead of being overwritten.
    for source, destination, _row in pending_copies:
        if destination.exists() and sha256(destination) != sha256(source):
            raise FileExistsError(f"Refusing to overwrite a different file: {destination}")

    for source, destination, _row in pending_copies:
        if destination.exists():
            continue
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, destination)

    manifest = args.manifest.expanduser()
    manifest.parent.mkdir(parents=True, exist_ok=True)
    partial = manifest.with_suffix(manifest.suffix + ".partial")
    try:
        with partial.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=FIELDS)
            writer.writeheader()
            writer.writerows(output_rows)
        os.replace(partial, manifest)
    except BaseException:
        partial.unlink(missing_ok=True)
        raise

    counts: dict[str, int] = defaultdict(int)
    for row in output_rows:
        counts[row["status"]] += 1
    print(f"Curated images: {counts['curated']}")
    print(f"Multiple candidate cards/artworks: {counts['multiple_card_or_art_candidates']}")
    print(f"Medium confidence: {counts['medium_confidence']}")
    print(f"Exact name, no exported image: {counts['exact_name_art_not_found']}")
    print(f"Unmatched name: {counts['unmatched_name']}")
    print(f"Wrote: {manifest}")


if __name__ == "__main__":
    main()
