#!/usr/bin/env python3
"""Export one complete Unity duel-field hierarchy as a textured static GLB."""

from __future__ import annotations

import argparse
import csv
import io
import json
import re
from pathlib import Path
from typing import Any

try:
    import UnityPy
    from UnityPy.helpers.MeshHelper import MeshHandler
except ImportError as exc:
    raise SystemExit("Run with the isolated UnityPy environment on PYTHONPATH.") from exc

from export_unity_animation_glb import GlbBuilder

UNRESOLVED_REFERENCES: list[str] = []


def read_pointer(pointer: Any) -> Any:
    if not pointer:
        return None
    try:
        return pointer.deref().read()
    except FileNotFoundError:
        UNRESOLVED_REFERENCES.append(f"file_id={pointer.m_FileID} path_id={pointer.m_PathID}")
        return None


def unity_vec3(value: Any) -> list[float]:
    return [-float(value.x), float(value.y), float(value.z)]


def unity_quat(value: Any) -> list[float]:
    return [float(value.x), -float(value.y), -float(value.z), float(value.w)]


def unity_color(value: Any) -> list[float]:
    return [float(value.r), float(value.g), float(value.b), float(value.a)]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path, help="Root directory of the untouched Master Duel dump")
    parser.add_argument("--arena", default="036", help="Unity field material number, such as 036 or 011")
    parser.add_argument("--variant", choices=("near", "far"), default="near")
    parser.add_argument("--inventory", type=Path, default=Path("manifests/unity_objects.csv"))
    parser.add_argument("--output-dir", type=Path, default=Path("local_assets/arenas"))
    parser.add_argument("--include-root", action="append", default=[], help="Export only this named direct child of the arena root; repeat for more")
    parser.add_argument("--omit-damage-meshes", action="store_true", help="Skip alternate destroyed field meshes")
    parser.add_argument("--omit-leaf-shadows", action="store_true", help="Skip custom shader leaf-shadow planes that do not have an albedo texture")
    args = parser.parse_args()
    if not re.fullmatch(r"\d{3}", args.arena):
        parser.error("--arena must be a three-digit field material id")

    root_name = f"Mat_{args.arena}_{args.variant}"
    source = args.source.expanduser().resolve(strict=True)
    with args.inventory.open(newline="", encoding="utf-8") as stream:
        inventory = list(csv.DictReader(stream))
    root_rows = [r for r in inventory if r["object_type"] == "GameObject" and r["object_name"] == root_name]
    bundles = {r["bundle"] for r in root_rows}
    if len(bundles) != 1:
        parser.error(f"Expected one bundle for {root_name}; found {len(bundles)}")
    bundle_rel = next(iter(bundles))
    bundle_path = (source / bundle_rel).resolve(strict=True)
    if not bundle_path.is_relative_to(source):
        parser.error("Bundle path escapes source root")

    env = UnityPy.load(str(bundle_path))
    game_objects: dict[int, Any] = {}
    transforms: dict[int, Any] = {}
    for reader in env.objects:
        if reader.type.name == "GameObject":
            game_objects[int(reader.path_id)] = reader.read()
        elif reader.type.name == "Transform":
            transforms[int(reader.path_id)] = reader.read()

    root_go = next((go for go in game_objects.values() if go.m_Name == root_name), None)
    if root_go is None:
        raise RuntimeError(f"Could not read GameObject {root_name}")
    root_transform_ptr = next((p for p in root_go.m_Components if p.deref().type.name == "Transform"), None)
    if root_transform_ptr is None:
        raise RuntimeError(f"{root_name} has no Transform")
    root_transform_id = int(root_transform_ptr.path_id)

    builder = GlbBuilder()
    document: dict[str, Any] = {
        "asset": {"version": "2.0", "generator": "Sacred Cards Unity arena exporter"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [],
        "meshes": [],
        "materials": [],
        "images": [],
        "textures": [],
        "samplers": [{"magFilter": 9729, "minFilter": 9987, "wrapS": 10497, "wrapT": 10497}],
    }
    material_by_id: dict[int, int] = {}
    texture_by_id: dict[int, int] = {}
    texture_has_cutout: dict[int, bool] = {}
    visited_meshes = 0
    skipped_inactive = 0
    skipped_skinned = 0
    skipped_damage = 0
    skipped_leaf_shadows = 0

    def gltf_texture(pointer: Any) -> int | None:
        texture = read_pointer(pointer)
        if texture is None:
            return None
        texture_id = int(pointer.path_id)
        if texture_id in texture_by_id:
            return texture_by_id[texture_id]
        image = texture.image
        if image is None:
            return None
        encoded = io.BytesIO()
        if "A" in image.getbands():
            alpha_histogram = image.getchannel("A").histogram()
            texture_has_cutout[texture_id] = alpha_histogram[0] >= sum(alpha_histogram) * 0.02
        else:
            texture_has_cutout[texture_id] = False
        image.save(encoded, format="PNG")
        payload = encoded.getvalue()
        while len(builder.binary) % 4:
            builder.binary.append(0)
        view_index = len(builder.views)
        builder.views.append({"buffer": 0, "byteOffset": len(builder.binary), "byteLength": len(payload)})
        builder.binary.extend(payload)
        image_index = len(document["images"])
        document["images"].append({"name": str(texture.m_Name), "bufferView": view_index, "mimeType": "image/png"})
        texture_index = len(document["textures"])
        document["textures"].append({"sampler": 0, "source": image_index})
        texture_by_id[texture_id] = texture_index
        return texture_index

    def gltf_material(pointer: Any) -> int:
        if not pointer:
            return -1
        material_id = int(pointer.path_id)
        if material_id in material_by_id:
            return material_by_id[material_id]
        material = read_pointer(pointer)
        if material is None:
            return -1
        props = material.m_SavedProperties
        colors = {str(name): value for name, value in props.m_Colors}
        base_color = next((unity_color(colors[key]) for key in ("_BaseColor", "_Color") if key in colors), [1.0, 1.0, 1.0, 1.0])
        texture_envs = {str(name): value for name, value in props.m_TexEnvs}
        texture_index = None
        for name in ("_BaseMap", "_MainTex", "_Texture2D", "_BaseColorMap"):
            if name in texture_envs:
                texture_index = gltf_texture(texture_envs[name].m_Texture)
                if texture_index is not None:
                    break
        pbr: dict[str, Any] = {"baseColorFactor": base_color, "metallicFactor": 0.0, "roughnessFactor": 0.9}
        if texture_index is not None:
            pbr["baseColorTexture"] = {"index": texture_index}
        gltf_index = len(document["materials"])
        gltf_material_data: dict[str, Any] = {"name": str(material.m_Name), "pbrMetallicRoughness": pbr, "doubleSided": True}
        if texture_index is not None and any(texture_by_id.get(tex_id) == texture_index and has_cutout for tex_id, has_cutout in texture_has_cutout.items()):
            gltf_material_data["alphaMode"] = "MASK"
            gltf_material_data["alphaCutoff"] = 0.45
        document["materials"].append(gltf_material_data)
        material_by_id[material_id] = gltf_index
        return gltf_index

    def add_game_object(transform_id: int, parent_node: int | None = None) -> int | None:
        nonlocal visited_meshes, skipped_inactive, skipped_skinned, skipped_damage, skipped_leaf_shadows
        transform = transforms.get(transform_id)
        if transform is None:
            return None
        go = read_pointer(transform.m_GameObject)
        if go is None:
            return None
        if args.omit_damage_meshes and "destroy" in str(go.m_Name).lower():
            skipped_damage += 1
            return None
        if args.omit_leaf_shadows and "leafshadow" in str(go.m_Name).lower():
            skipped_leaf_shadows += 1
            return None
        if not bool(go.m_IsActive):
            skipped_inactive += 1
            return None
        node: dict[str, Any] = {
            "name": str(go.m_Name),
            "translation": unity_vec3(transform.m_LocalPosition),
            "rotation": unity_quat(transform.m_LocalRotation),
            "scale": [float(transform.m_LocalScale.x), float(transform.m_LocalScale.y), float(transform.m_LocalScale.z)],
        }
        node_index = len(document["nodes"])
        document["nodes"].append(node)
        if parent_node is not None:
            document["nodes"][parent_node].setdefault("children", []).append(node_index)
        mesh_filter = None
        mesh_renderer = None
        for component in go.m_Components:
            component_type = component.deref().type.name
            if component_type == "MeshFilter":
                mesh_filter = component.deref().read()
            elif component_type == "MeshRenderer":
                mesh_renderer = component.deref().read()
            elif component_type == "SkinnedMeshRenderer":
                skipped_skinned += 1
        if mesh_filter is not None and mesh_renderer is not None and bool(mesh_renderer.m_Enabled) and mesh_filter.m_Mesh:
            mesh = read_pointer(mesh_filter.m_Mesh)
            if mesh is not None:
                handler = MeshHandler(mesh)
                handler.process()
                positions = [(-v[0], v[1], v[2]) for v in handler.m_Vertices or []]
                if positions:
                    attributes = {"POSITION": builder.accessor(positions, 5126, "VEC3", target=34962)}
                    if handler.m_Normals:
                        attributes["NORMAL"] = builder.accessor([(-v[0], v[1], v[2]) for v in handler.m_Normals], 5126, "VEC3", target=34962)
                    if handler.m_UV0:
                        # Unity mesh UVs start at the image's bottom; glTF UVs start at its top.
                        attributes["TEXCOORD_0"] = builder.accessor([(v[0], 1.0 - v[1]) for v in handler.m_UV0], 5126, "VEC2", target=34962)
                    primitives = []
                    material_pointers = list(mesh_renderer.m_Materials)
                    for submesh_index, submesh in enumerate(mesh.m_SubMeshes):
                        index_size = 4 if int(mesh.m_IndexFormat or 0) != 0 else 2
                        start = int(submesh.firstByte) // index_size
                        raw_indices = (handler.m_IndexBuffer or [])[start:start + int(submesh.indexCount)]
                        triangles: list[int] = []
                        topology = int(submesh.topology or 0)
                        if topology == 0:
                            for i in range(0, len(raw_indices) - 2, 3):
                                triangles.extend((int(raw_indices[i]), int(raw_indices[i + 2]), int(raw_indices[i + 1])))
                        else:
                            # Unsupported line/strip surfaces are deliberately skipped.
                            continue
                        material_index = gltf_material(material_pointers[submesh_index]) if submesh_index < len(material_pointers) else -1
                        primitive: dict[str, Any] = {
                            "attributes": attributes,
                            "indices": builder.accessor(triangles, 5123 if len(positions) < 65536 else 5125, "SCALAR", target=34963),
                            "mode": 4,
                        }
                        if material_index >= 0:
                            primitive["material"] = material_index
                        primitives.append(primitive)
                    if primitives:
                        mesh_index = len(document["meshes"])
                        document["meshes"].append({"name": str(mesh.m_Name), "primitives": primitives})
                        node["mesh"] = mesh_index
                        visited_meshes += 1
        for child in transform.m_Children:
            if transform_id == root_transform_id and args.include_root:
                child_transform = transforms.get(int(child.path_id))
                child_go = read_pointer(child_transform.m_GameObject) if child_transform is not None else None
                if child_go is None or str(child_go.m_Name) not in args.include_root:
                    continue
            add_game_object(int(child.path_id), node_index)
        return node_index

    add_game_object(root_transform_id)
    document["scenes"][0]["nodes"] = [0]
    output = args.output_dir / f"mat_{args.arena}_{args.variant}.glb"
    builder.finish(document, output)
    manifest = {
        "arena": root_name,
        "source_bundle": bundle_rel,
        "output": output.name,
        "mesh_objects": visited_meshes,
        "gltf_meshes": len(document["meshes"]),
        "materials": len(document["materials"]),
        "embedded_textures": len(document["textures"]),
        "inactive_objects_skipped": skipped_inactive,
        "skinned_objects_skipped": skipped_skinned,
        "damage_objects_skipped": skipped_damage,
        "leaf_shadow_objects_skipped": skipped_leaf_shadows,
        "included_root_children": args.include_root,
        "unresolved_references": len(UNRESOLVED_REFERENCES),
        "unresolved_reference_examples": UNRESOLVED_REFERENCES[:10],
        "notes": "Static mesh hierarchy exported as GLB. Animated particle and skinned components are omitted; common base-color textures are embedded when available.",
    }
    output.with_suffix(".json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
