extends Node3D

## Frames the locally exported forest field for a visual import check.

const SOURCE_MODELS: Array[String] = [
	"res://local_assets/arenas/mat_029_near.glb",
	"res://local_assets/arenas/mat_029_far.glb",
]

@onready var _arena: Node3D = $ForestArena
@onready var _camera: Camera3D = $Camera3D
@onready var _status: Label = $Overlay/Status


func _ready() -> void:
	for model_path in SOURCE_MODELS:
		if not ResourceLoader.exists(model_path):
			_status.text = "Optional source model is missing: %s" % model_path
			return
		var model := load(model_path) as PackedScene
		if model == null:
			_status.text = "Source model could not be imported: %s" % model_path
			push_error(_status.text)
			return
		_arena.add_child(model.instantiate())
	var bounds := AABB()
	var found_geometry := false
	for candidate in _arena.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := candidate as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		var local_bounds := mesh_instance.get_aabb()
		for corner in range(8):
			var local_point := local_bounds.position + Vector3(
				local_bounds.size.x if (corner & 1) != 0 else 0.0,
				local_bounds.size.y if (corner & 2) != 0 else 0.0,
				local_bounds.size.z if (corner & 4) != 0 else 0.0,
			)
			var world_point := mesh_instance.global_transform * local_point
			if not found_geometry:
				bounds = AABB(world_point, Vector3.ZERO)
				found_geometry = true
			else:
				bounds = bounds.expand(world_point)
	if not found_geometry:
		_status.text = "Forest field GLB imported without visible meshes."
		push_error("Forest arena preview could not find imported MeshInstance3D nodes")
		return
	var center := bounds.get_center()
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect_ratio := maxf(viewport_size.x / maxf(viewport_size.y, 1.0), 0.01)
	var field_span := maxf(bounds.size.x, bounds.size.z)
	_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_camera.position = center + Vector3(0.0, field_span + 10.0, -field_span * 0.6)
	_camera.look_at(center, Vector3.UP)
	var frame_width := 0.0
	var frame_height := 0.0
	for corner in range(8):
		var point := bounds.position + Vector3(
			bounds.size.x if (corner & 1) != 0 else 0.0,
			bounds.size.y if (corner & 2) != 0 else 0.0,
			bounds.size.z if (corner & 4) != 0 else 0.0,
		)
		var from_center := point - center
		frame_width = maxf(frame_width, absf(from_center.dot(_camera.global_transform.basis.x)) * 2.0)
		frame_height = maxf(frame_height, absf(from_center.dot(_camera.global_transform.basis.y)) * 2.0)
	_camera.size = maxf(maxf(frame_height, frame_width / aspect_ratio) * 1.15, 10.0)
