#!/usr/bin/env python3
"""Convert one Unity skinned model and streamed Transform clip into a Godot-importable GLB.

This intentionally targets the generic Transform bindings used by the Sacred Cards
animation probe. It does not attempt to convert Unity humanoid muscle curves.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import struct
from pathlib import Path
from typing import Any

try:
    import UnityPy
    from UnityPy.helpers.MeshHelper import MeshHandler
except ImportError as exc:
    raise SystemExit("Run with the isolated UnityPy environment on PYTHONPATH.") from exc


class GlbBuilder:
    def __init__(self) -> None:
        self.binary = bytearray()
        self.views: list[dict[str, Any]] = []
        self.accessors: list[dict[str, Any]] = []

    def accessor(self, values: list[Any], component_type: int, kind: str, *, target: int | None = None, normalized: bool = False) -> int:
        if kind == "SCALAR":
            width = 1
            flat = values
        else:
            width = {"VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}[kind]
            flat = [component for value in values for component in value]
        formats = {5121: "B", 5123: "H", 5125: "I", 5126: "f"}
        payload = struct.pack("<" + formats[component_type] * len(flat), *flat)
        while len(self.binary) % 4:
            self.binary.append(0)
        view: dict[str, Any] = {"buffer": 0, "byteOffset": len(self.binary), "byteLength": len(payload)}
        if target is not None:
            view["target"] = target
        view_index = len(self.views)
        self.views.append(view)
        self.binary.extend(payload)
        accessor: dict[str, Any] = {
            "bufferView": view_index,
            "componentType": component_type,
            "count": len(flat) // width,
            "type": kind,
        }
        if normalized:
            accessor["normalized"] = True
        if component_type == 5126 and values and kind in {"SCALAR", "VEC2", "VEC3", "VEC4"}:
            columns = [[float(v)] if width == 1 else [float(c) for c in v] for v in values]
            accessor["min"] = [min(row[i] for row in columns) for i in range(width)]
            accessor["max"] = [max(row[i] for row in columns) for i in range(width)]
        self.accessors.append(accessor)
        return len(self.accessors) - 1

    def finish(self, document: dict[str, Any], output: Path) -> None:
        document["buffers"] = [{"byteLength": len(self.binary)}]
        document["bufferViews"] = self.views
        document["accessors"] = self.accessors
        json_bytes = json.dumps(document, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        json_bytes += b" " * ((4 - len(json_bytes) % 4) % 4)
        self.binary.extend(b"\0" * ((4 - len(self.binary) % 4) % 4))
        total_length = 12 + 8 + len(json_bytes) + 8 + len(self.binary)
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("wb") as stream:
            stream.write(struct.pack("<4sII", b"glTF", 2, total_length))
            stream.write(struct.pack("<I4s", len(json_bytes), b"JSON"))
            stream.write(json_bytes)
            stream.write(struct.pack("<I4s", len(self.binary), b"BIN\0"))
            stream.write(self.binary)


def ptr_read(pointer: Any) -> Any:
    return pointer.deref().read()


def quat(value: Any) -> list[float]:
    # Unity to Godot/glTF basis conversion matching AssetStudio's X reflection.
    return [float(value.x), -float(value.y), -float(value.z), float(value.w)]


def vec3(value: Any) -> list[float]:
    return [-float(value.x), float(value.y), float(value.z)]


def streamed_frames(clip: Any) -> list[tuple[float, list[tuple[int, float]]]]:
    words = clip.m_MuscleClip.m_Clip.data.m_StreamedClip.data
    payload = struct.pack("<" + "I" * len(words), *words)
    offset = 0
    frames = []
    while offset < len(payload):
        if offset + 8 > len(payload):
            raise ValueError("Truncated streamed animation frame header")
        time, count = struct.unpack_from("<fi", payload, offset)
        offset += 8
        if count < 0 or offset + count * 20 > len(payload):
            raise ValueError(f"Invalid streamed key count {count} at byte {offset - 4}")
        keys = []
        for _ in range(count):
            index, _a, _b, _out_slope, value = struct.unpack_from("<i4f", payload, offset)
            offset += 20
            keys.append((index, value))
        frames.append((float(time), keys))
    return frames


def decode_tracks(clip: Any, avatar_paths: dict[int, str]) -> tuple[dict[str, Any], float]:
    bindings = clip.m_ClipBindingConstant.genericBindings
    frames = streamed_frames(clip)
    clip_data = clip.m_MuscleClip.m_Clip.data
    stream_count = int(clip_data.m_StreamedClip.curveCount)
    dense_count = int(clip_data.m_DenseClip.m_CurveCount)
    constant_values = [float(value) for value in clip_data.m_ConstantClip.data]
    transforms: dict[str, dict[str, list[list[float]]]] = {}
    position = 0
    for binding in bindings:
        attr = int(binding.attribute)
        width = 4 if attr == 2 else 3 if attr in (1, 3, 4) else 1
        path = avatar_paths.get(int(binding.path), "")
        channel = {1: "translation", 2: "rotation", 3: "scale", 4: "rotation"}.get(attr)
        if path and channel:
            transforms.setdefault(path, {"translation": [], "rotation": [], "scale": []})
        position += width
    curve_count = stream_count + dense_count + len(constant_values)
    if position != curve_count:
        raise ValueError(f"Stream/dense/constant data has {curve_count} curves but bindings describe {position}")

    for time, keys in frames[1:-1]:
        if not math.isfinite(time):
            continue
        values: list[float | None] = [None] * stream_count
        for index, value in keys:
            if 0 <= index < stream_count:
                values[index] = value
        values.extend([None] * dense_count)
        values.extend(constant_values)
        index = 0
        for binding in bindings:
            attr = int(binding.attribute)
            width = 4 if attr == 2 else 3 if attr in (1, 3, 4) else 1
            path = avatar_paths.get(int(binding.path), "")
            channel = {1: "translation", 2: "rotation", 3: "scale", 4: "rotation"}.get(attr)
            components = values[index:index + width]
            index += width
            if not path or not channel or len(components) != width or any(v is None for v in components):
                continue
            packed = [float(value) for value in components]
            if attr == 1:
                packed[0] = -packed[0]
            elif attr == 2:
                packed = [packed[0], -packed[1], -packed[2], packed[3]]
            elif attr == 4:
                packed = [packed[0], -packed[1], -packed[2]]
            transforms[path][channel].append([time, *packed])

    duration = float(clip.m_MuscleClip.m_StopTime - clip.m_MuscleClip.m_StartTime)
    return transforms, duration


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Root directory of the untouched Master Duel dump")
    parser.add_argument("--clip", default="M13144_c")
    parser.add_argument("--inventory", type=Path, default=Path("manifests/unity_objects.csv"))
    parser.add_argument("--output", type=Path, default=Path("local_assets/animation_probe/godot_preview/M13144_attack.glb"))
    args = parser.parse_args()
    if not args.clip.startswith("M13144_"):
        parser.error("This first converter is limited to the M13144 probe rig")

    source = args.source.expanduser().resolve(strict=True)
    with args.inventory.open(newline="", encoding="utf-8") as stream:
        inventory = list(csv.DictReader(stream))
    rows = [r for r in inventory if r["object_type"] == "AnimationClip" and r["object_name"] == args.clip]
    if len(rows) != 1:
        parser.error(f"Expected one inventory row for {args.clip}; found {len(rows)}")
    bundle = (source / rows[0]["bundle"]).resolve(strict=True)
    if not bundle.is_relative_to(source):
        parser.error("Bundle path escapes source root")

    env = UnityPy.load(str(bundle))
    by_kind_name: dict[tuple[str, str], list[Any]] = {}
    for reader in env.objects:
        name = str(reader.peek_name() or "")
        by_kind_name.setdefault((reader.type.name, name), []).append(reader)
    def one(kind: str, name: str) -> Any:
        matches = by_kind_name.get((kind, name), [])
        if len(matches) != 1:
            raise RuntimeError(f"Expected one {kind} named {name!r}, got {len(matches)}")
        return matches[0].read()

    clip = one("AnimationClip", args.clip)
    avatar = one("Avatar", "M13144_ModelAvatar")
    avatar_paths = {int(path_hash): str(path) for path_hash, path in avatar.m_TOS}
    tracks, duration = decode_tracks(clip, avatar_paths)

    # Select the model root referenced by the renderer's root-bone parent.
    transform_readers = {int(r.path_id): r.read() for r in env.objects if r.type.name == "Transform"}
    renderers = [r.read() for r in env.objects if r.type.name == "SkinnedMeshRenderer"]
    renderer = next(r for r in renderers if r.m_Mesh and ptr_read(r.m_Mesh).m_Name == "body")
    root_transform_id = int(renderer.m_RootBone.path_id)
    root_transform = transform_readers[root_transform_id]
    root_parent = int(root_transform.m_Father.path_id)
    root_node = transform_readers[root_parent]

    # Build only the model root and renderer bone tree, excluding unrelated effects.
    bone_readers = [ptr_read(pointer) for pointer in renderer.m_Bones]
    bone_ids = {int(b.object_reader.path_id) if getattr(b, "object_reader", None) else int(pointer.path_id) for b, pointer in zip(bone_readers, renderer.m_Bones)}
    node_specs: list[dict[str, Any]] = []
    node_by_transform: dict[int, int] = {}
    path_by_transform: dict[int, str] = {}
    root_game_object = ptr_read(root_node.m_GameObject)
    model_root_index = 0
    node_specs.append({"name": str(root_game_object.m_Name), "translation": vec3(root_node.m_LocalPosition), "rotation": quat(root_node.m_LocalRotation), "scale": [float(root_node.m_LocalScale.x), float(root_node.m_LocalScale.y), float(root_node.m_LocalScale.z)], "children": []})

    def add_bone(transform_id: int, parent_index: int, parent_path: str = "") -> None:
        t = transform_readers[transform_id]
        go = ptr_read(t.m_GameObject)
        index = len(node_specs)
        node_by_transform[transform_id] = index
        path_by_transform[transform_id] = f"{parent_path}/{go.m_Name}" if parent_path else str(go.m_Name)
        node_specs.append({"name": str(go.m_Name), "translation": vec3(t.m_LocalPosition), "rotation": quat(t.m_LocalRotation), "scale": [float(t.m_LocalScale.x), float(t.m_LocalScale.y), float(t.m_LocalScale.z)], "children": []})
        node_specs[parent_index]["children"].append(index)
        child_ids = [int(p.path_id) for p in t.m_Children]
        for child_id in child_ids:
            if child_id in bone_ids:
                add_bone(child_id, index, path_by_transform[transform_id])

    add_bone(root_transform_id, model_root_index)
    if len(node_by_transform) != len(bone_readers):
        missing = len(bone_readers) - len(node_by_transform)
        raise RuntimeError(f"Could not place {missing} renderer bones in the root hierarchy")

    builder = GlbBuilder()
    meshes = []
    skins = []
    materials = []
    for renderer_name, color in (("body", [0.66, 0.68, 0.72, 1.0]), ("Aura", [0.22, 0.65, 0.95, 0.55])):
        renderer_obj = next(r for r in renderers if r.m_Mesh and ptr_read(r.m_Mesh).m_Name == renderer_name)
        mesh = ptr_read(renderer_obj.m_Mesh)
        handler = MeshHandler(mesh)
        handler.process()
        positions = [(-v[0], v[1], v[2]) for v in handler.m_Vertices]
        normals = [(-n[0], n[1], n[2]) for n in handler.m_Normals]
        uvs = [tuple(uv[:2]) for uv in handler.m_UV0]
        joints, weights = [], []
        for ids, ws in zip(handler.m_BoneIndices, handler.m_BoneWeights):
            id_values, weight_values = list(ids), list(ws)
            joints.append(tuple((id_values + [0] * 4)[:4]))
            weights.append(tuple((weight_values + [0.0] * 4)[:4]))
        pos_accessor = builder.accessor(positions, 5126, "VEC3", target=34962)
        normal_accessor = builder.accessor(normals, 5126, "VEC3", target=34962)
        uv_accessor = builder.accessor(uvs, 5126, "VEC2", target=34962)
        joints_accessor = builder.accessor(joints, 5123, "VEC4", target=34962)
        weights_accessor = builder.accessor(weights, 5126, "VEC4", target=34962)
        primitives = []
        for submesh in mesh.m_SubMeshes:
            start = int(submesh.firstByte) // (4 if mesh.m_IndexFormat else 2)
            count = int(submesh.indexCount)
            raw = handler.m_IndexBuffer[start:start + count]
            triangles = []
            for i in range(0, len(raw) - 2, 3):
                triangles.extend((int(raw[i]), int(raw[i + 2]), int(raw[i + 1])))
            index_accessor = builder.accessor(triangles, 5123 if len(positions) < 65536 else 5125, "SCALAR", target=34963)
            primitives.append({"attributes": {"POSITION": pos_accessor, "NORMAL": normal_accessor, "TEXCOORD_0": uv_accessor, "JOINTS_0": joints_accessor, "WEIGHTS_0": weights_accessor}, "indices": index_accessor, "material": len(materials)})
        materials.append({"name": renderer_name, "pbrMetallicRoughness": {"baseColorFactor": color, "metallicFactor": 0.0, "roughnessFactor": 0.8}, "alphaMode": "BLEND" if color[3] < 1 else "OPAQUE", "doubleSided": True})
        mesh_index = len(meshes)
        meshes.append({"name": renderer_name, "primitives": primitives})
        node_specs.append({"name": renderer_name, "mesh": mesh_index, "skin": len(skins)})
        node_specs[model_root_index]["children"].append(len(node_specs) - 1)
        joint_ids = [int(p.path_id) for p in renderer_obj.m_Bones]
        inverse_matrices = []
        for matrix in mesh.m_BindPose:
            # Convert Unity column-major transform matrix through the same X reflection.
            m = [[float(getattr(matrix, f"e{r}{c}")) for c in range(4)] for r in range(4)]
            reflect = [-1.0, 1.0, 1.0, 1.0]
            converted = [[reflect[r] * m[r][c] * reflect[c] for c in range(4)] for r in range(4)]
            inverse_matrices.append([converted[r][c] for c in range(4) for r in range(4)])
        inverse_accessor = builder.accessor(inverse_matrices, 5126, "MAT4")
        skins.append({"name": f"{renderer_name} Skin", "joints": [node_by_transform[i] for i in joint_ids], "skeleton": node_by_transform[root_transform_id], "inverseBindMatrices": inverse_accessor})

    animations = []
    samplers, channels = [], []
    input_cache: dict[tuple[float, ...], int] = {}
    for path, properties in tracks.items():
        transform_id = next((i for i, node_path in path_by_transform.items() if node_path == path), None)
        if transform_id is None:
            continue
        for property_name, samples in properties.items():
            if len(samples) < 2:
                continue
            samples.sort(key=lambda row: row[0])
            times = tuple(max(0.0, min(duration, sample[0])) for sample in samples)
            if times not in input_cache:
                input_cache[times] = builder.accessor(list(times), 5126, "SCALAR")
            output_values = [sample[1:] for sample in samples]
            width = len(output_values[0])
            output_accessor = builder.accessor(output_values, 5126, {3: "VEC3", 4: "VEC4"}[width])
            sampler_index = len(samplers)
            samplers.append({"input": input_cache[times], "output": output_accessor, "interpolation": "LINEAR"})
            channels.append({"sampler": sampler_index, "target": {"node": node_by_transform[transform_id], "path": property_name}})
    animations.append({"name": args.clip, "samplers": samplers, "channels": channels})

    document = {
        "asset": {"version": "2.0", "generator": "Sacred Cards Unity animation probe exporter"},
        "scene": 0,
        "scenes": [{"nodes": [model_root_index]}],
        "nodes": node_specs,
        "meshes": meshes,
        "skins": skins,
        "materials": materials,
        "animations": animations,
    }
    builder.finish(document, args.output)
    print(f"Wrote {args.output} ({args.output.stat().st_size:,} bytes)")
    print(f"Rig bones: {len(node_by_transform)}; meshes: {len(meshes)}; animation channels: {len(channels)}; duration: {duration:.3f}s")


if __name__ == "__main__":
    main()
