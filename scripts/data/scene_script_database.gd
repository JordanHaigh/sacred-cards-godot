extends RefCounted
class_name SceneScriptDatabase

const RESOURCE_PATH := "res://resources/scene_scripts.json"
var nodes: Dictionary[StringName, SceneScriptNode] = {}
var scene_roots: Dictionary[StringName, Dictionary] = {}
var load_error := ""

func load_default() -> bool:
	return load_json(RESOURCE_PATH)

func load_json(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_error = "Unable to open scene script database: %s" % path
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("nodes", []) is Array:
		load_error = "Scene script database has an invalid root structure."
		return false
	nodes.clear()
	scene_roots.clear()
	for raw_node: Variant in parsed.nodes:
		if raw_node is Dictionary:
			var node := SceneScriptNode.from_dictionary(raw_node)
			if node.node_id != &"":
				nodes[node.node_id] = node
	for raw_root: Variant in parsed.get("scene_roots", []):
		if raw_root is Dictionary:
			var key := StringName("%d:%d" % [int(raw_root.get("scene", -1)), int(raw_root.get("variant", -1))])
			var roots: Dictionary = scene_roots.get(key, {})
			roots[StringName(raw_root.get("role", ""))] = StringName(raw_root.get("node", ""))
			scene_roots[key] = roots
	load_error = ""
	return not nodes.is_empty()

func get_node(node_id: StringName) -> SceneScriptNode:
	return nodes.get(node_id) as SceneScriptNode

func roots_for_scene(scene_id: int, variant: int) -> Dictionary:
	return scene_roots.get(StringName("%d:%d" % [scene_id, variant]), {}).duplicate()
