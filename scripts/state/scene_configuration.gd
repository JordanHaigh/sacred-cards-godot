extends RefCounted
class_name SceneConfiguration

const ACTOR_RUNTIME_SCRIPT = preload("res://scripts/systems/scene_actor_runtime.gd")

## Typed replacement for the fixed-size scene struct; absent actors are omitted.
var actors: Array[SceneActor] = []
var scene_script_a: StringName = &""
var scene_script_b: StringName = &""
var player_spawns: Array[SceneActor] = []

static func from_dictionary(data: Dictionary) -> SceneConfiguration:
	var scene := SceneConfiguration.new()
	scene.scene_script_a = StringName(data.get("scene_script_a", ""))
	scene.scene_script_b = StringName(data.get("scene_script_b", ""))
	for value: Variant in data.get("actors", []):
		if value is Dictionary and scene.actors.size() < 16:
			var actor := SceneActor.from_dictionary(value)
			if actor.actor_id < 0:
				break
			scene.actors.append(actor)
	for value: Variant in data.get("player_spawns", []):
		if value is Dictionary and scene.player_spawns.size() < 5:
			scene.player_spawns.append(SceneActor.from_dictionary(value))
	return scene

func instantiate_actors(animation_database: ActorAnimationDatabase) -> Node2D:
	var runtime: SceneActorRuntime = ACTOR_RUNTIME_SCRIPT.new()
	runtime.load_scene(self, animation_database)
	return runtime
