#!/usr/bin/env python3
"""Inspect Unity animation clips and write a conversion-planning catalog."""

from __future__ import annotations

import argparse
import csv
import os
from collections import defaultdict
from pathlib import Path

try:
    import UnityPy
except ImportError as exc:
    raise SystemExit(
        "UnityPy is required. Install it in an isolated environment and run this script with that environment's Python."
    ) from exc


FIELDS = (
    "clip_name", "bundle", "path_id", "serialized_size", "sample_rate", "duration_seconds",
    "legacy", "compressed", "animation_type", "binding_count", "muscle_curve_count",
    "streamed_curve_count", "dense_curve_count", "dense_frame_count", "float_curve_count",
    "position_curve_count", "rotation_curve_count", "euler_curve_count", "scale_curve_count",
    "object_reference_curve_count", "event_count", "event_functions", "status", "notes",
)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Root of the untouched Master Duel dump")
    parser.add_argument("--inventory", type=Path, default=Path("manifests/unity_objects.csv"))
    parser.add_argument("--output", type=Path, default=Path("manifests/animation_catalog.csv"))
    parser.add_argument("--limit", type=int, help="Optional maximum number of animation clips to inspect")
    args = parser.parse_args()

    source = args.source.expanduser().resolve(strict=True)
    inventory = args.inventory.expanduser().resolve(strict=True)
    if args.limit is not None and args.limit < 0:
        parser.error("--limit must be non-negative")

    by_bundle: dict[str, list[dict[str, str]]] = defaultdict(list)
    with inventory.open(newline="", encoding="utf-8") as stream:
        for row in csv.DictReader(stream):
            if row.get("object_type") == "AnimationClip":
                by_bundle[row["bundle"]].append(row)
    candidates = [row for bundle_rows in by_bundle.values() for row in bundle_rows]
    candidates.sort(key=lambda row: (row["bundle"], int(row["path_id"]), row["object_name"]))
    if args.limit is not None:
        candidates = candidates[: args.limit]
    wanted = {(r["bundle"], r["path_id"], r["object_name"]): r for r in candidates}

    output = args.output.expanduser()
    output.parent.mkdir(parents=True, exist_ok=True)
    partial = output.with_suffix(output.suffix + ".partial")
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
                try:
                    environment = UnityPy.load(str(bundle_path))
                except Exception as exc:
                    for row in selected:
                        writer.writerow(_failure_row(row, f"{type(exc).__name__}: {exc}"))
                        counts["failed"] += 1
                        processed += 1
                    continue
                for row in selected:
                    try:
                        matches = [
                            obj for obj in environment.objects
                            if obj.type.name == "AnimationClip"
                            and int(obj.path_id) == int(row["path_id"])
                            and str(obj.peek_name() or "") == row["object_name"]
                        ]
                        if len(matches) != 1:
                            raise ValueError(f"Expected one matching AnimationClip object; found {len(matches)}")
                        clip = matches[0].read()
                        unity_clip = clip.m_MuscleClip.m_Clip.data
                        dense = unity_clip.m_DenseClip
                        streamed = unity_clip.m_StreamedClip
                        rate = float(clip.m_SampleRate or 0.0)
                        start_time = float(getattr(clip.m_MuscleClip, "m_StartTime", 0.0))
                        stop_time = float(getattr(clip.m_MuscleClip, "m_StopTime", 0.0))
                        duration = max(0.0, stop_time - start_time)
                        if duration == 0.0 and dense is not None and rate > 0:
                            duration = float(dense.m_FrameCount) / rate
                        events = getattr(clip, "m_Events", []) or []
                        counts_for_clip = {
                            "clip_name": row["object_name"], "bundle": bundle, "path_id": row["path_id"],
                            "serialized_size": row["size"], "sample_rate": rate,
                            "duration_seconds": f"{duration:.4f}", "legacy": bool(clip.m_Legacy),
                            "compressed": bool(clip.m_Compressed), "animation_type": str(clip.m_AnimationType),
                            "binding_count": len(getattr(clip.m_ClipBindingConstant, "genericBindings", []) or []),
                            "muscle_curve_count": len(getattr(clip.m_MuscleClip, "m_IndexArray", []) or []),
                            "streamed_curve_count": int(getattr(streamed, "curveCount", 0) or 0),
                            "dense_curve_count": int(getattr(dense, "m_CurveCount", 0) or 0),
                            "dense_frame_count": int(getattr(dense, "m_FrameCount", 0) or 0),
                            "float_curve_count": len(getattr(clip, "m_FloatCurves", []) or []),
                            "position_curve_count": len(getattr(clip, "m_PositionCurves", []) or []),
                            "rotation_curve_count": len(getattr(clip, "m_RotationCurves", []) or []),
                            "euler_curve_count": len(getattr(clip, "m_EulerCurves", []) or []),
                            "scale_curve_count": len(getattr(clip, "m_ScaleCurves", []) or []),
                            "object_reference_curve_count": len(getattr(clip, "m_PPtrCurves", []) or []),
                            "event_count": len(events),
                            "event_functions": "|".join(sorted({str(getattr(event, "functionName", "")) for event in events if getattr(event, "functionName", "")})),
                            "status": "cataloged", "notes": "",
                        }
                        writer.writerow(counts_for_clip)
                        counts["cataloged"] += 1
                    except Exception as exc:
                        writer.writerow(_failure_row(row, f"{type(exc).__name__}: {str(exc).replace(chr(10), ' ')}"))
                        counts["failed"] += 1
                    finally:
                        processed += 1
                del environment
                if processed and processed % 500 < len(selected):
                    print(f"Inspected {processed}/{len(candidates)} AnimationClips; failed {counts['failed']}", flush=True)
        os.replace(partial, output)
    except BaseException:
        partial.unlink(missing_ok=True)
        raise

    print(f"AnimationClip objects inspected: {processed}")
    print(f"Cataloged: {counts['cataloged']}")
    print(f"Failed: {counts['failed']}")
    print(f"Wrote: {output}")


def _failure_row(row: dict[str, str], note: str) -> dict[str, str]:
    result = {field: "" for field in FIELDS}
    result.update({
        "clip_name": row["object_name"], "bundle": row["bundle"], "path_id": row["path_id"],
        "serialized_size": row["size"], "status": "failed", "notes": note,
    })
    return result


if __name__ == "__main__":
    main()
