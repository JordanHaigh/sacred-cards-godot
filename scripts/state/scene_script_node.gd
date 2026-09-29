extends RefCounted
class_name SceneScriptNode

## One recovered scene-script node. Links use stable database keys rather than
## ROM addresses, and tokens contain decoded operands instead of byte pointers.
var node_id: StringName
var next_if_zero: StringName
var next_if_nonzero: StringName
var tokens: Array[Dictionary] = []
var terminal := false

static func from_dictionary(data: Dictionary) -> SceneScriptNode:
	var node := SceneScriptNode.new()
	node.node_id = StringName(data.get("id", ""))
	node.next_if_zero = StringName(data.get("zero", ""))
	node.next_if_nonzero = StringName(data.get("nonzero", ""))
	node.terminal = bool(data.get("terminal", false))
	for raw_token: Variant in data.get("tokens", []):
		if raw_token is Dictionary:
			node.tokens.append(raw_token)
	return node
