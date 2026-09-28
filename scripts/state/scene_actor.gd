extends RefCounted
class_name SceneActor

## Data-only scene actor. Script references are resource paths or IDs, never ROM pointers.
var actor_id := -1
var sprite_id := -1
var orientation := 0
var position := Vector2i.ZERO
var height_offset := 0
var animation_state := 0
var palette_index := 0
var script_a: StringName = &""
var script_b: StringName = &""
var flags := 0

static func from_dictionary(data: Dictionary) -> SceneActor:
	var actor := SceneActor.new()
	actor.actor_id = int(data.get("actor_id", -1))
	actor.sprite_id = int(data.get("sprite_id", actor.actor_id))
	actor.orientation = int(data.get("orientation", 0))
	actor.position = Vector2i(int(data.get("x", 0)), int(data.get("y", 0)))
	actor.height_offset = int(data.get("height_offset", 0))
	actor.animation_state = int(data.get("animation_state", 0))
	actor.palette_index = int(data.get("palette_index", 0))
	actor.script_a = StringName(data.get("script_a", ""))
	actor.script_b = StringName(data.get("script_b", ""))
	actor.flags = int(data.get("flags", 0))
	return actor

func make_node(animation_database: ActorAnimationDatabase) -> Node2D:
	var node := Node2D.new()
	node.position = Vector2(position)
	var frame_index := animation_database.walking_frame_index(orientation, animation_state) if orientation < 4 else animation_database.special_frame_index(orientation)
	var sprite := animation_database.make_sprite(sprite_id, frame_index, palette_index)
	node.add_child(sprite)
	return node
