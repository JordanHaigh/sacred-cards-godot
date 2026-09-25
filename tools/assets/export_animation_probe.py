#!/usr/bin/env python3
"""Export one M13144 Unity animation and its rig references for conversion study."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
from pathlib import Path
from typing import Any

try:
    import UnityPy
except ImportError as exc:
    raise SystemExit(
        "UnityPy is required. Install it in an isolated environment and run this script with that environment's Python."
    ) from exc


def object_name(reader: Any) -> str:
    return str(reader.peek_name() or "")


def export_typetree(reader: Any, destination: Path) -> None:
    destination.write_text(
        json.dumps(reader.parse_as_dict(), indent=2, ensure_ascii=False, default=str) + "\n",
        encoding="utf-8",
    )


def pointer_name(pointer: Any) -> str:
    if not pointer:
        return ""
    target = pointer.deref().read()
    if hasattr(target, "m_Name"):
        return str(target.m_Name)
    game_object = getattr(target, "m_GameObject", None)
    return str(game_object.deref().read().m_Name) if game_object else ""


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Root of the untouched Master Duel dump")
    parser.add_argument("--clip", default="M13144_c", help="M13144 AnimationClip name to export")
    parser.add_argument("--inventory", type=Path, default=Path("manifests/unity_objects.csv"))
    parser.add_argument("--output-dir", type=Path, default=Path("local_assets/animation_probe"))
    args = parser.parse_args()
    if not args.clip.startswith("M13144_"):
        parser.error("--clip must name a clip from the M13144 model bundle")

    source = args.source.expanduser().resolve(strict=True)
    inventory_path = args.inventory.expanduser().resolve(strict=True)
    output_dir = args.output_dir.expanduser()
    with inventory_path.open(newline="", encoding="utf-8") as stream:
        inventory = list(csv.DictReader(stream))
    clip_rows = [r for r in inventory if r["object_type"] == "AnimationClip" and r["object_name"] == args.clip]
    if len(clip_rows) != 1:
        parser.error(f"Expected one inventory match for {args.clip!r}; found {len(clip_rows)}")
    clip_row = clip_rows[0]
    bundle = clip_row["bundle"]
    bundle_path = (source / bundle).resolve(strict=True)
    if not bundle_path.is_relative_to(source):
        parser.error(f"Bundle path escapes source root: {bundle}")

    environment = UnityPy.load(str(bundle_path))
    selected_clip_rows = [clip_row]
    effect_rows = [
        r for r in inventory
        if r["object_type"] == "AnimationClip"
        and r["object_name"] == f"{args.clip}_EFF"
        and r["bundle"] == bundle
    ]
    if len(effect_rows) == 1:
        selected_clip_rows.extend(effect_rows)

    wanted = {
        ("AnimationClip", int(row["path_id"])): (
            "animation_clip.json" if row is clip_row else "effect_clip.json"
        )
        for row in selected_clip_rows
    }
    for object_type, name, filename in (
        ("AnimatorController", "M13144 Controller", "animator_controller.json"),
        ("Avatar", "M13144_ModelAvatar", "avatar.json"),
        ("GameObject", "M13144_Model", "model_root.json"),
    ):
        matches = [o for o in environment.objects if o.type.name == object_type and object_name(o) == name]
        if len(matches) == 1:
            wanted[(object_type, int(matches[0].path_id))] = filename

    selected_readers = {
        (reader.type.name, int(reader.path_id)): reader
        for reader in environment.objects
        if (reader.type.name, int(reader.path_id)) in wanted
    }
    missing = set(wanted) - set(selected_readers)
    if missing:
        raise RuntimeError(f"Bundle is missing required Unity objects: {sorted(missing)}")

    output_dir.mkdir(parents=True, exist_ok=True)
    (output_dir / ".gdignore").touch(exist_ok=True)
    for object_key, filename in wanted.items():
        export_typetree(selected_readers[object_key], output_dir / filename)

    clips = {
        row["object_name"]: selected_readers[("AnimationClip", int(row["path_id"]))].read()
        for row in selected_clip_rows
    }
    clip = clips[args.clip]
    avatar_reader = next(
        (r for (kind, _), r in selected_readers.items() if kind == "Avatar"), None
    )
    avatar_tos: dict[int, str] = {}
    if avatar_reader is not None:
        avatar = avatar_reader.read()
        avatar_tos = {int(path_hash): str(path) for path_hash, path in avatar.m_TOS}

    bindings = []
    for index, binding in enumerate(clip.m_ClipBindingConstant.genericBindings):
        bindings.append({
            "index": index,
            "avatar_path": avatar_tos.get(int(binding.path), ""),
            "path_hash": int(binding.path),
            "attribute": int(binding.attribute),
            "type_id": int(binding.typeID or 0),
            "is_object_reference_curve": bool(binding.isPPtrCurve),
        })

    controller_reader = next(
        (r for (kind, _), r in selected_readers.items() if kind == "AnimatorController"), None
    )
    controller_clips: list[str] = []
    controller_state_clip_map: dict[str, list[str]] = {}
    if controller_reader is not None:
        controller = controller_reader.read()
        names_by_path_id = {
            int(r["path_id"]): r["object_name"]
            for r in inventory
            if r["bundle"] == bundle and r["object_type"] == "AnimationClip"
        }
        controller_clips = [
            names_by_path_id[path_id]
            for reference in controller.m_AnimationClips
            if (path_id := int(reference.m_PathID)) in names_by_path_id
        ]
        tos_names = {int(name_hash): str(name) for name_hash, name in controller.m_TOS}
        state_machine = controller.m_Controller.m_StateMachineArray[0].data
        for state_pointer in state_machine.m_StateConstantArray:
            state = state_pointer.data
            state_name = tos_names.get(int(state.m_NameID), str(state.m_NameID))
            clip_indexes = [
                int(node_pointer.data.m_ClipID)
                for tree_pointer in state.m_BlendTreeConstantArray
                for node_pointer in tree_pointer.data.m_NodeArray
            ]
            controller_state_clip_map[state_name] = [
                controller_clips[index]
                for index in clip_indexes
                if 0 <= index < len(controller_clips)
            ]

    renderers = []
    for reader in environment.objects:
        if reader.type.name != "SkinnedMeshRenderer":
            continue
        renderer = reader.read()
        try:
            mesh_reader = renderer.m_Mesh.deref()
            mesh = mesh_reader.read()
        except (AttributeError, FileNotFoundError, KeyError, ValueError):
            continue
        mesh_name = str(mesh.m_Name or f"mesh_{reader.path_id}")
        if mesh_name not in {"body", "Aura"}:
            continue
        mesh_stem = f"{mesh_name.lower()}_{reader.path_id}"
        export_typetree(mesh_reader, output_dir / f"{mesh_stem}.json")
        (output_dir / f"{mesh_stem}.obj").write_text(mesh.export(), encoding="utf-8")
        renderers.append({
            "renderer_path_id": int(reader.path_id),
            "mesh": mesh_name,
            "mesh_path_id": int(mesh_reader.path_id),
            "root_bone": pointer_name(renderer.m_RootBone),
            "bones": [pointer_name(bone) for bone in renderer.m_Bones],
            "mesh_json": f"{mesh_stem}.json",
            "mesh_obj": f"{mesh_stem}.obj",
        })

    bundle_digest = hashlib.sha256(bundle_path.read_bytes()).hexdigest()
    muscle_clip = clip.m_MuscleClip
    manifest = {
        "source_bundle": bundle,
        "source_bundle_sha256": bundle_digest,
        "clip": args.clip,
        "clip_path_id": int(clip_row["path_id"]),
        "sample_rate": float(clip.m_SampleRate or 0.0),
        "duration_seconds": round(float(muscle_clip.m_StopTime - muscle_clip.m_StartTime), 4),
        "binding_count": len(bindings),
        "avatar_path_bindings_resolved": sum(bool(binding["avatar_path"]) for binding in bindings),
        "bindings": bindings,
        "controller_clips": controller_clips,
        "controller_state_clip_map": controller_state_clip_map,
        "exported_clips": [
            {
                "name": row["object_name"],
                "path_id": int(row["path_id"]),
                "sample_rate": float(clips[row["object_name"]].m_SampleRate or 0.0),
                "duration_seconds": round(
                    float(
                        clips[row["object_name"]].m_MuscleClip.m_StopTime
                        - clips[row["object_name"]].m_MuscleClip.m_StartTime
                    ),
                    4,
                ),
                "binding_count": len(clips[row["object_name"]].m_ClipBindingConstant.genericBindings),
            }
            for row in selected_clip_rows
        ],
        "renderers": renderers,
        "exports": sorted(
            [path.name for path in output_dir.iterdir() if path.is_file()]
            + ["probe_manifest.json"]
        ),
        "note": "OBJ exports contain mesh surfaces but do not preserve skin weights or a Godot skeleton. Mesh JSON and Avatar JSON retain source data for a later converter.",
    }
    (output_dir / "probe_manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    print(f"Animation probe: {output_dir}")
    print(f"Clip: {args.clip} ({manifest['duration_seconds']:.3f}s, {len(bindings)} bindings)")
    print(f"Avatar paths resolved: {manifest['avatar_path_bindings_resolved']}/{len(bindings)}")
    print(f"Controller clips listed: {len(controller_clips)}")
    print(f"Skinned renderers exported: {len(renderers)}")


if __name__ == "__main__":
    main()
