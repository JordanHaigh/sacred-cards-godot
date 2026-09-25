#!/usr/bin/env python3
"""Extract Master Duel AudioClip samples as WAV files with source provenance."""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import os
import re
import wave
from collections import defaultdict
from pathlib import Path
from typing import Any, cast

try:
    import UnityPy
except ImportError as exc:
    raise SystemExit(
        "UnityPy is required. Install it in an isolated environment and run this script with that environment's Python."
    ) from exc


FIELDS = (
    "category", "clip_name", "sample_name", "bundle", "path_id", "serialized_size",
    "export_path", "file_bytes", "sha256", "channels", "sample_rate", "duration_seconds",
    "decoder", "status", "notes",
)


def category_for(name: str) -> str:
    prefix = name.split("_", 1)[0].upper()
    return {"BGM": "music", "SE": "sfx", "V": "voice"}.get(prefix, "other")


def safe_name(value: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]+", "_", value).strip("._-")
    return cleaned[:100] or "unnamed"


def wav_details(payload: bytes) -> tuple[str, str, str]:
    try:
        with wave.open(io.BytesIO(payload), "rb") as wav:
            duration = wav.getnframes() / wav.getframerate() if wav.getframerate() else 0.0
            return str(wav.getnchannels()), str(wav.getframerate()), f"{duration:.4f}"
    except (wave.Error, EOFError, ZeroDivisionError):
        return "", "", ""


def audio_extension(payload: bytes, sample_name: str) -> str:
    if payload[:4] == b"RIFF":
        return ".wav"
    if payload[:4] == b"OggS":
        return ".ogg"
    if payload[4:8] == b"ftyp":
        return ".m4a"
    if payload[:3] == b"ID3" or (len(payload) > 1 and payload[0] == 0xFF and payload[1] & 0xE0 == 0xE0):
        return ".mp3"
    extension = Path(sample_name).suffix.lower()
    return extension if extension in {".wav", ".ogg", ".m4a", ".mp3", ".aif", ".aiff"} else ".bin"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Root of the untouched Master Duel dump")
    parser.add_argument("--inventory", type=Path, default=Path("manifests/unity_objects.csv"))
    parser.add_argument("--output-dir", type=Path, default=Path("local_assets/audio/library"))
    parser.add_argument("--manifest", type=Path, default=Path("manifests/audio_assets.csv"))
    parser.add_argument("--limit", type=int, help="Optional maximum number of AudioClip objects to process")
    args = parser.parse_args()

    source = args.source.expanduser().resolve(strict=True)
    if not source.is_dir():
        parser.error(f"source is not a directory: {source}")
    inventory_path = args.inventory.expanduser().resolve(strict=True)
    output_dir = args.output_dir.expanduser()
    manifest_path = args.manifest.expanduser()
    if args.limit is not None and args.limit < 0:
        parser.error("--limit must be non-negative")

    by_bundle: dict[str, list[dict[str, str]]] = defaultdict(list)
    with inventory_path.open(newline="", encoding="utf-8") as stream:
        for row in csv.DictReader(stream):
            if row.get("object_type") == "AudioClip":
                by_bundle[row["bundle"]].append(row)
    candidates = [row for bundle_rows in by_bundle.values() for row in bundle_rows]
    candidates.sort(key=lambda row: (row["bundle"], int(row["path_id"]), row["object_name"]))
    if args.limit is not None:
        candidates = candidates[: args.limit]
    wanted = {(r["bundle"], r["path_id"], r["object_name"]): r for r in candidates}

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / ".gdignore").touch(exist_ok=True)
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    partial = manifest_path.with_suffix(manifest_path.suffix + ".partial")
    counts: dict[str, int] = defaultdict(int)
    processed = 0
    try:
        with partial.open("w", newline="", encoding="utf-8") as stream:
            writer = csv.DictWriter(stream, fieldnames=FIELDS, lineterminator="\n")
            writer.writeheader()
            for bundle, bundle_rows in sorted(by_bundle.items()):
                selected = [r for r in bundle_rows if (r["bundle"], r["path_id"], r["object_name"]) in wanted]
                if not selected:
                    continue
                bundle_path = (source / bundle).resolve()
                if not bundle_path.is_relative_to(source):
                    raise ValueError(f"Bundle path escapes source root: {bundle}")
                environment = None
                try:
                    environment = UnityPy.load(str(bundle_path))
                except Exception as exc:
                    for row in selected:
                        writer.writerow(_failure_row(row, "bundle_load_failed", f"{type(exc).__name__}: {exc}"))
                        counts["failed"] += 1
                        processed += 1
                    continue

                for row in selected:
                    category = category_for(row["object_name"])
                    base = f"{safe_name(row['object_name'])}__{hashlib.sha256(bundle.encode()).hexdigest()[:8]}_{row['path_id']}"
                    try:
                        matches = [
                            obj for obj in environment.objects
                            if obj.type.name == "AudioClip"
                            and int(obj.path_id) == int(row["path_id"])
                            and str(obj.peek_name() or "") == row["object_name"]
                        ]
                        if len(matches) != 1:
                            raise ValueError(f"Expected one matching AudioClip object; found {len(matches)}")
                        clip = matches[0].read()
                        try:
                            samples = clip.samples
                            decoder = "UnityPy AudioClip.samples"
                        except Exception as sample_error:
                            samples = _decode_external_resource(source, bundle_path, clip)
                            decoder = "external resource fallback (%s)" % type(sample_error).__name__
                        if not samples:
                            writer.writerow(_failure_row(row, "no_samples", "UnityPy returned no audio samples"))
                            counts["no_samples"] += 1
                            continue
                        sample_items = list(samples.items())
                        for sample_index, (sample_name, payload) in enumerate(sample_items):
                            suffix = f"_{sample_index + 1}" if len(sample_items) > 1 else ""
                            extension = audio_extension(payload, sample_name)
                            relative_path = Path(category) / f"{base}{suffix}{extension}"
                            destination = output_dir / relative_path
                            destination.parent.mkdir(parents=True, exist_ok=True)
                            digest = hashlib.sha256(payload).hexdigest()
                            if destination.exists():
                                existing_digest = hashlib.sha256(destination.read_bytes()).hexdigest()
                                if existing_digest != digest:
                                    raise FileExistsError(f"Refusing to replace different output: {destination}")
                            else:
                                temp_path = destination.with_suffix(destination.suffix + ".partial")
                                temp_path.write_bytes(payload)
                                os.replace(temp_path, destination)
                            channels, sample_rate, duration = wav_details(payload)
                            writer.writerow({
                                "category": category, "clip_name": row["object_name"], "sample_name": sample_name,
                                "bundle": bundle, "path_id": row["path_id"], "serialized_size": row["size"],
                                "export_path": relative_path.as_posix(), "file_bytes": len(payload), "sha256": digest,
                                "channels": channels, "sample_rate": sample_rate, "duration_seconds": duration,
                                "decoder": decoder, "status": "exported", "notes": "",
                            })
                            counts["exported"] += 1
                    except Exception as exc:
                        writer.writerow(_failure_row(row, "failed", f"{type(exc).__name__}: {str(exc).replace(chr(10), ' ')}"))
                        counts["failed"] += 1
                    finally:
                        processed += 1
                del environment
                if processed and processed % 250 < len(selected):
                    print(f"Processed {processed}/{len(candidates)} AudioClips; exported {counts['exported']}; failed {counts['failed']}", flush=True)
        os.replace(partial, manifest_path)
    except BaseException:
        partial.unlink(missing_ok=True)
        raise

    print(f"AudioClip objects processed: {processed}")
    for label in ("exported", "failed", "no_samples"):
        print(f"{label.capitalize()}: {counts[label]}")
    print(f"Wrote manifest: {manifest_path}")
    print(f"Audio output: {output_dir}")


def _failure_row(row: dict[str, str], status: str, note: str) -> dict[str, str]:
    return {
        "category": category_for(row["object_name"]), "clip_name": row["object_name"], "sample_name": "",
        "bundle": row["bundle"], "path_id": row["path_id"], "serialized_size": row["size"],
        "export_path": "", "file_bytes": "", "sha256": "", "channels": "", "sample_rate": "",
        "duration_seconds": "", "decoder": "", "status": status, "notes": note,
    }


def _decode_external_resource(source: Path, bundle_path: Path, clip: Any) -> dict[str, bytes]:
    """Read the Unity external resource sidecar directly when UnityPy mis-resolves it."""
    resource = getattr(clip, "m_Resource", None)
    if resource is None or not getattr(resource, "m_Source", ""):
        raise ValueError("AudioClip has no external resource to retry")

    relative_resource = Path(str(resource.m_Source).replace("\\", "/"))
    resource_path = relative_resource if relative_resource.is_absolute() else bundle_path.parent / relative_resource
    resource_path = resource_path.resolve(strict=True)
    if not resource_path.is_relative_to(source):
        raise ValueError(f"Audio resource path escapes source root: {resource.m_Source}")
    with resource_path.open("rb") as stream:
        stream.seek(int(resource.m_Offset))
        raw_audio = stream.read(int(resource.m_Size))
    if len(raw_audio) != int(resource.m_Size):
        raise ValueError(f"Audio resource was truncated: expected {resource.m_Size}, got {len(raw_audio)}")

    magic = raw_audio[:8]
    if magic[:4] == b"OggS":
        return {f"{clip.m_Name}.ogg": raw_audio}
    if magic[:4] == b"RIFF":
        return {f"{clip.m_Name}.wav": raw_audio}
    if magic[4:8] == b"ftyp":
        return {f"{clip.m_Name}.m4a": raw_audio}

    try:
        import fmod_toolkit
    except ImportError as exc:
        raise RuntimeError("fmod_toolkit is required to decode this external audio resource") from exc
    return cast(
        dict[str, bytes],
        fmod_toolkit.raw_to_wav(
            raw_audio,
            str(clip.m_Name),
            int(clip.m_Channels or 2),
            int(clip.m_Frequency or 44100),
        ),
    )


if __name__ == "__main__":
    main()
