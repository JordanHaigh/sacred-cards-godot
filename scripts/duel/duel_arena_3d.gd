class_name DuelArena3D
extends Node3D

## Procedural 3D forest arena. DuelState remains authoritative; this node only
## draws the current field and reports which player zone was clicked.

signal slot_selected(zone_kind: String, zone_index: int)

const COLUMN_POSITIONS: Array[float] = [-5.2, -2.6, 0.0, 2.6, 5.2]
const CARD_VIEW_SCENE = preload("res://scenes/card_view_3d.tscn")
const FIELD_GLOW := Color("#3c8e68")
const PLACEMENT_GLOW := Color("#62e7a4")
const ZONE_ROWS: Array[Dictionary] = [
	{"key": "opponent_back", "z": -4.9, "kind": "Spell / Trap"},
	{"key": "opponent_monster", "z": -2.65, "kind": "Monster"},
	{"key": "player_monster", "z": 2.65, "kind": "Monster"},
	{"key": "player_back", "z": 4.9, "kind": "Spell / Trap"},
]

var _slots: Dictionary = {}
var _card_database: Object
var _selected_zone_kind: String = "player_monster"
var _selected_zone_index: int = 0
var _valid_placement_keys: Array[String] = []

var _stone_material: StandardMaterial3D
var _trim_material: StandardMaterial3D
var _forest_materials: Array[StandardMaterial3D] = []
var _blossom_materials: Array[StandardMaterial3D] = []
var _path_materials: Array[StandardMaterial3D] = []
var _rock_materials: Array[StandardMaterial3D] = []
var _ambient_time: float = 0.0
var _lanterns: Array[Dictionary] = []
var _canopy_pivots: Array[Node3D] = []
var _canopy_phases: Array[float] = []


func _ready() -> void:
	_build_materials()
	_build_lighting_and_camera()
	_build_environment()
	_build_field()
	_build_forest()
	_build_shrine()
	_build_lanterns()
	_build_card_zones()


func _process(delta: float) -> void:
	_ambient_time += delta
	_update_lantern_flicker()
	_update_tree_sway()


func _update_lantern_flicker() -> void:
	for lantern_data in _lanterns:
		var light: OmniLight3D = lantern_data["light"]
		var glow_material: StandardMaterial3D = lantern_data["glow_material"]
		var base_energy: float = lantern_data["base_energy"]
		var phase: float = lantern_data["phase"]
		var soft_pulse := sin(_ambient_time * 2.2 + phase) * 0.065
		var quick_flicker := sin(_ambient_time * 5.3 + phase * 2.1) * 0.04
		var tiny_flicker := sin(_ambient_time * 11.9 + phase * 0.67) * 0.015
		var brightness := 0.9 + soft_pulse + quick_flicker + tiny_flicker
		light.light_energy = base_energy * brightness
		glow_material.emission_energy_multiplier = 2.0 * brightness


func _update_tree_sway() -> void:
	for canopy_index in range(_canopy_pivots.size()):
		var pivot := _canopy_pivots[canopy_index]
		var phase := _canopy_phases[canopy_index]
		pivot.rotation.z = sin(_ambient_time * 0.38 + phase) * 0.026
		pivot.rotation.x = sin(_ambient_time * 0.29 + phase * 1.4) * 0.014


func refresh_from_duel(duel_state: Object, card_database: Object) -> void:
	_card_database = card_database
	if duel_state == null or not duel_state.has_method("get_player"):
		return
	var player = duel_state.call("get_player", "player_one")
	var opponent = duel_state.call("get_player", "player_two")
	for zone_key in _slots:
		var slot_data: Dictionary = _slots[zone_key]
		var owner = player if String(slot_data["owner_id"]) == "player_one" else opponent
		var card = owner.call("get_monster_zone", int(slot_data["zone_index"])) if slot_data["zone_type"] == "monster" else owner.call("get_spell_trap_zone", int(slot_data["zone_index"]))
		_update_slot(slot_data, card)


func select_zone(zone_kind: String, zone_index: int) -> void:
	_selected_zone_kind = zone_kind
	_selected_zone_index = zone_index
	_update_zone_highlights()


func set_placement_zones(zone_kind: String, zone_indices: Array[int]) -> void:
	_valid_placement_keys.clear()
	for zone_index in zone_indices:
		_valid_placement_keys.append("%s_%d" % [zone_kind, zone_index])
	_update_zone_highlights()


func _update_zone_highlights() -> void:
	for zone_key in _slots:
		var slot_data: Dictionary = _slots[zone_key]
		var is_selected: bool = String(slot_data["zone_kind"]) == _selected_zone_kind and int(slot_data["zone_index"]) == _selected_zone_index
		var is_valid: bool = _valid_placement_keys.has(String(zone_key))
		var pad_material: StandardMaterial3D = slot_data["pad_material"]
		var inset_material: StandardMaterial3D = slot_data["inset_material"]
		pad_material.albedo_color = Color("#b3f2bf") if is_valid else (Color("#91a477") if is_selected else Color("#778261"))
		pad_material.emission_enabled = is_valid or is_selected
		pad_material.emission = PLACEMENT_GLOW if is_valid else (FIELD_GLOW if is_selected else Color.BLACK)
		inset_material.albedo_color = Color("#9bdcb5") if is_valid else Color("#a7a987")
		inset_material.emission_enabled = is_valid
		inset_material.emission = PLACEMENT_GLOW if is_valid else Color.BLACK


func _build_materials() -> void:
	_stone_material = _material(Color("#9b9d86"), 0.96)
	_trim_material = _material(Color("#bd9c61"), 0.56, 0.18)
	_forest_materials = [
		_material(Color("#31594b"), 0.94),
		_material(Color("#3f6b55"), 0.94),
		_material(Color("#527d5b"), 0.94),
		_material(Color("#638d65"), 0.94),
		_material(Color("#7a9c6e"), 0.94),
	]
	_blossom_materials = [
		_material(Color("#f0b8c8"), 0.95),
		_material(Color("#f7cfda"), 0.95),
		_material(Color("#e6a5bc"), 0.95),
		_material(Color("#d68fae"), 0.95),
		_material(Color("#ffe0e3"), 0.95),
	]
	_path_materials = [
		_material(Color("#737766"), 0.98),
		_material(Color("#858b76"), 0.98),
		_material(Color("#626d60"), 0.98),
		_material(Color("#a1a18a"), 0.98),
	]
	_rock_materials = [
		_material(Color("#343b38"), 0.98),
		_material(Color("#465049"), 0.98),
		_material(Color("#596253"), 0.98),
	]


func _build_lighting_and_camera() -> void:
	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#111b21")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#aab5ac")
	environment.ambient_light_energy = 0.78
	environment_node.environment = environment
	add_child(environment_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("#ffe7d4")
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	add_child(sun)

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 20.0
	camera.position = Vector3(0.0, 30.0, 0.0)
	add_child(camera)
	# look_at() and make_current() use the camera's scene-tree transform, so
	# configure them after the camera has entered this SubViewport's world.
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	camera.make_current()


func _build_environment() -> void:
	var ground_material := _material(Color("#456b57"), 1.0)
	_add_box("Forest Clearing Floor", Vector3(80.0, 0.5, 40.0), Vector3(0.0, -0.76, 0.0), ground_material)
	_build_approach_paths()
	_build_grass_edges()


func _build_approach_paths() -> void:
	for step_index in range(4):
		var z_offset := 7.65 + float(step_index) * 0.72
		for side in [-1.0, 1.0]:
			var z_position: float = side * z_offset
			var stone_size := Vector3(3.0 + float(step_index % 2) * 0.45, 0.1, 0.74)
			_add_box("Forest Shrine Walkway", stone_size, Vector3(0.0, -0.43, z_position), _path_materials[step_index % _path_materials.size()])
			_add_box("Walkway Border Stone", Vector3(0.62, 0.12, 0.58), Vector3(side * 1.9, -0.4, z_position), _path_materials[(step_index + 1) % _path_materials.size()])


func _build_grass_edges() -> void:
	for side in [-1.0, 1.0]:
		for clump_index in range(14):
			var z_position := -10.4 + float(clump_index) * 1.58
			var x_position: float = side * (8.9 + float(clump_index % 3) * 0.42)
			_add_shrub_cluster(Vector3(x_position, -0.34, z_position), clump_index)
	for side in [-1.0, 1.0]:
		for clump_index in range(13):
			var x_position := -9.1 + float(clump_index) * 1.52
			_add_shrub_cluster(Vector3(x_position, -0.34, side * 8.1), clump_index + 17)


func _add_shrub_cluster(center: Vector3, clump_index: int) -> void:
	var base_material: StandardMaterial3D = _forest_materials[clump_index % _forest_materials.size()]
	for leaf_index in range(5):
		var angle := TAU * float(leaf_index) / 5.0 + float(clump_index % 4) * 0.23
		var offset := Vector3(cos(angle) * 0.48, float(leaf_index % 2) * 0.12, sin(angle) * 0.48)
		var leaf := _add_sphere("Low-poly Forest Shrub", 0.62 + float(leaf_index % 3) * 0.08, center + offset, _forest_materials[(clump_index + leaf_index) % _forest_materials.size()])
		leaf.scale = Vector3(1.1, 0.56, 0.9)
	var heart := _add_sphere("Shrub Crown", 0.54, center + Vector3(0.0, 0.2, 0.0), base_material)
	heart.scale = Vector3(1.0, 0.64, 0.92)


func _build_field() -> void:
	var board_material := _material(Color("#596959"), 0.92)
	var inlay_material := _emissive_material(Color("#887143"))
	_add_box("Carved Arena Plinth", Vector3(17.4, 0.72, 14.0), Vector3(0.0, -0.31, 0.0), board_material)
	_add_box("Paved Duel Court", Vector3(16.6, 0.12, 13.2), Vector3(0.0, 0.11, 0.0), _stone_material)
	_add_box("Arena Outer Gold Inlay", Vector3(16.4, 0.035, 13.0), Vector3(0.0, 0.188, 0.0), inlay_material)
	_add_box("Arena Inset Field", Vector3(16.18, 0.045, 12.78), Vector3(0.0, 0.21, 0.0), _stone_material)
	_add_box("Center Duel Line", Vector3(15.9, 0.025, 0.08), Vector3(0.0, 0.245, 0.0), _trim_material)
	_add_court_sigil(Vector3(0.0, 0.25, 0.0))
	_build_court_paving()
	_build_fallen_petals()


func _build_fallen_petals() -> void:
	# Small, fixed accents keep the board readable and need no texture files.
	for side in [-1.0, 1.0]:
		for petal_index in range(28):
			var z_position := -5.5 + float(petal_index) * 0.4
			var x_position: float = side * (7.45 + float((petal_index * 7) % 9) * 0.08)
			var petal := _add_box("Fallen Blossom Petal", Vector3(0.14, 0.012, 0.08), Vector3(x_position, 0.254, z_position), _blossom_materials[petal_index % _blossom_materials.size()])
			petal.rotation.y = float((petal_index * 13) % 9) * 0.32


func _build_court_paving() -> void:
	# Narrow runs of worn flagstones make the open margins feel like a courtyard.
	for side in [-1.0, 1.0]:
		for stone_index in range(13):
			var z_position := -5.8 + float(stone_index) * 0.96
			var x_position: float = side * (7.15 + float(stone_index % 2) * 0.16)
			var tile := _add_box("Court Perimeter Flagstone", Vector3(0.58, 0.055, 0.76), Vector3(x_position, 0.214, z_position), _path_materials[stone_index % _path_materials.size()])
			tile.rotation.y = float(stone_index % 3 - 1) * 0.035
	for z_side in [-1.0, 1.0]:
		for stone_index in range(9):
			var x_position := -6.85 + float(stone_index) * 1.7
			_add_box("Court Perimeter Flagstone", Vector3(1.2, 0.055, 0.62), Vector3(x_position, 0.214, z_side * 5.95), _path_materials[(stone_index + 2) % _path_materials.size()])


func _add_court_sigil(position: Vector3) -> void:
	var gold := _emissive_material(Color("#b3985e"))
	_add_box("Duel Sigil Line", Vector3(1.2, 0.025, 0.055), position, gold)
	_add_box("Duel Sigil Line", Vector3(0.055, 0.025, 1.2), position, gold)
	for diagonal in [-1.0, 1.0]:
		var ray := _add_box("Duel Sigil Ray", Vector3(0.055, 0.025, 0.72), position, gold)
		ray.rotation.y = diagonal * PI / 4.0
	var center := _add_cylinder("Duel Sigil Center", 0.25, 0.045, position + Vector3(0.0, 0.015, 0.0), gold)
	center.rotation.x = 0.0


func _build_forest() -> void:
	var tree_positions: Array[Vector3] = [
		Vector3(-10.3, 0.0, -9.0), Vector3(-12.3, 0.0, -6.2), Vector3(-13.1, 0.0, -2.5),
		Vector3(-12.2, 0.0, 1.8), Vector3(-12.5, 0.0, 5.6), Vector3(-10.2, 0.0, 9.0),
		Vector3(10.3, 0.0, -9.0), Vector3(12.3, 0.0, -6.2), Vector3(13.1, 0.0, -2.5),
		Vector3(12.2, 0.0, 1.8), Vector3(12.5, 0.0, 5.6), Vector3(10.2, 0.0, 9.0),
		Vector3(-8.0, 0.0, -10.1), Vector3(-4.2, 0.0, -10.4), Vector3(4.2, 0.0, -10.4), Vector3(8.0, 0.0, -10.1),
		Vector3(-8.0, 0.0, 10.1), Vector3(-4.2, 0.0, 10.4), Vector3(4.2, 0.0, 10.4), Vector3(8.0, 0.0, 10.1),
	]
	for tree_index in range(tree_positions.size()):
		_add_tree(tree_positions[tree_index], tree_index)
	for bank_index in range(4):
		var bank_z: float = -7.5 + bank_index * 5.0
		_add_rock(Vector3(-9.7, -0.42, bank_z), 0.72 + float(bank_index % 2) * 0.2, bank_index)
		_add_rock(Vector3(9.7, -0.42, bank_z + 1.3), 0.7 + float((bank_index + 1) % 2) * 0.22, bank_index + 1)


func _build_shrine() -> void:
	var path_stone := _material(Color("#aaa887"), 0.96)
	var gate_wood := _material(Color("#744a43"), 0.9)
	var gate_trim := _material(Color("#bc8662"), 0.78)
	for side in [-1.0, 1.0]:
		for step_index in range(3):
			var z_position: float = side * (7.15 + float(step_index) * 0.54)
			var step_width := 4.1 + float(step_index) * 0.8
			_add_box("Forest Gate Path Stone", Vector3(step_width, 0.12, 0.42), Vector3(0.0, -0.1, z_position), path_stone)
		for post_side in [-1.0, 1.0]:
			_add_box("Forest Gate Marker", Vector3(0.46, 0.5, 0.46), Vector3(post_side * 3.25, 0.28, side * 7.2), _path_materials[1])
			_add_box("Forest Gate Post", Vector3(0.32, 2.5, 0.32), Vector3(post_side * 2.2, 0.92, side * 9.0), gate_wood)
		_add_box("Forest Gate Beam", Vector3(5.2, 0.3, 0.48), Vector3(0.0, 2.3, side * 9.0), gate_wood)
		_add_box("Forest Gate Roof", Vector3(5.8, 0.18, 0.68), Vector3(0.0, 2.55, side * 9.0), gate_trim)


func _build_lanterns() -> void:
	var lantern_positions: Array[Vector3] = [Vector3(-7.55, 0.0, -4.8), Vector3(7.55, 0.0, -4.8), Vector3(-7.55, 0.0, 4.8), Vector3(7.55, 0.0, 4.8)]
	for lantern_index in range(lantern_positions.size()):
		var lantern_position: Vector3 = lantern_positions[lantern_index]
		var ground_position: Vector3 = lantern_position + Vector3(0.0, -0.5, 0.0)
		var base_material := _material(Color("#383a32"), 0.72, 0.2)
		_add_box("Lantern Pedestal", Vector3(0.55, 0.85, 0.55), ground_position + Vector3(0.0, 0.42, 0.0), base_material)
		var glow_material := _emissive_material(Color("#ffc879"))
		var lantern := _add_sphere("Lantern Glow", 0.24, ground_position + Vector3(0.0, 1.02, 0.0), glow_material)
		lantern.scale = Vector3(1.0, 0.75, 1.0)
		var light := OmniLight3D.new()
		light.position = ground_position + Vector3(0.0, 1.2, 0.0)
		light.light_color = Color("#ffc879")
		light.light_energy = 0.65
		light.omni_range = 4.5
		add_child(light)
		_lanterns.append({
			"light": light,
			"glow_material": glow_material,
			"base_energy": 0.65,
			"phase": float(lantern_index) * 1.71,
		})


func _build_card_zones() -> void:
	for row in ZONE_ROWS:
		for zone_index in range(COLUMN_POSITIONS.size()):
			var zone_kind := String(row["key"])
			var zone_type := "monster" if zone_kind.ends_with("monster") else "spell_trap"
			var owner_id := "player_one" if zone_kind.begins_with("player_") else "player_two"
			_create_zone(
				zone_kind,
				zone_type,
				owner_id,
				zone_index,
				Vector3(COLUMN_POSITIONS[zone_index], 0.0, float(row["z"])),
				String(row["kind"]),
			)
	select_zone(_selected_zone_kind, _selected_zone_index)


func _create_zone(zone_kind: String, zone_type: String, owner_id: String, zone_index: int, zone_position: Vector3, empty_text: String) -> void:
	var key := "%s_%d" % [zone_kind, zone_index]
	var zone := Area3D.new()
	zone.name = key
	zone.position = zone_position
	zone.input_ray_pickable = true
	zone.collision_layer = 1
	zone.collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.95, 0.7, 2.12)
	collision.shape = shape
	collision.position.y = 0.27
	zone.add_child(collision)
	zone.input_event.connect(_on_zone_input.bind(zone_kind, zone_index, owner_id))

	var pad_material := _material(Color("#778261"), 0.88, 0.08)
	var pad := MeshInstance3D.new()
	var pad_mesh := CylinderMesh.new()
	pad_mesh.top_radius = 1.0
	pad_mesh.bottom_radius = 1.04
	pad_mesh.height = 0.12
	pad_mesh.radial_segments = 6
	pad.mesh = pad_mesh
	pad.position.y = 0.2
	pad.material_override = pad_material
	zone.add_child(pad)
	var inset := MeshInstance3D.new()
	var inset_material := _material(Color("#a7a987"), 0.9)
	var inset_mesh := CylinderMesh.new()
	inset_mesh.top_radius = 0.89
	inset_mesh.bottom_radius = 0.89
	inset_mesh.height = 0.018
	inset_mesh.radial_segments = 6
	inset.mesh = inset_mesh
	inset.position.y = 0.267
	inset.material_override = inset_material
	zone.add_child(inset)

	var empty_label := _make_label(empty_text, Color("#e3dfbd"), 27, 0.0055)
	empty_label.position.y = 0.286
	zone.add_child(empty_label)
	var card_root := CARD_VIEW_SCENE.instantiate() as Node3D
	card_root.position.y = 0.31
	zone.add_child(card_root)
	card_root.visible = false
	add_child(zone)
	_slots[key] = {
		"node": zone,
		"pad_material": pad_material,
		"inset_material": inset_material,
		"empty_label": empty_label,
		"card_root": card_root,
		"card_view": card_root,
		"owner_id": owner_id,
		"zone_type": zone_type,
		"zone_kind": zone_kind,
		"zone_index": zone_index,
	}


func _update_slot(slot_data: Dictionary, card: Object) -> void:
	var empty_label: Label3D = slot_data["empty_label"]
	var card_view: Node3D = slot_data["card_view"]
	if card == null:
		_cancel_card_entry(slot_data)
		slot_data["card_instance_id"] = 0
		card_view.visible = false
		empty_label.visible = true
		return
	empty_label.visible = false
	var card_instance_id := card.get_instance_id()
	var is_new_card := int(slot_data.get("card_instance_id", 0)) != card_instance_id
	slot_data["card_instance_id"] = card_instance_id
	card_view.visible = true
	card_view.call("set_card", card, _card_database)
	var target_rotation := Vector3(
		0.0,
		PI / 2.0 if String(card.get("battle_position")) == "defense" else 0.0,
		0.0,
	)
	if is_new_card:
		_animate_card_entry(slot_data, card_view, target_rotation)
	elif not _card_entry_is_running(slot_data):
		card_view.rotation = target_rotation


func _animate_card_entry(slot_data: Dictionary, card_view: Node3D, target_rotation: Vector3) -> void:
	_cancel_card_entry(slot_data)
	var resting_position := Vector3(0.0, 0.31, 0.0)
	card_view.position = resting_position + Vector3(0.0, 2.5, 0.0)
	card_view.rotation = Vector3(-PI * 0.42, target_rotation.y, 0.0)
	card_view.scale = Vector3.ONE * 0.72
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(card_view, "position", resting_position, 0.46).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_view, "rotation", target_rotation, 0.42).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(card_view, "scale", Vector3.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(card_view, "position", resting_position + Vector3(0.0, 0.12, 0.0), 0.08).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(card_view, "position", resting_position, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	slot_data["card_entry_tween"] = tween


func _card_entry_is_running(slot_data: Dictionary) -> bool:
	var tween: Tween = slot_data.get("card_entry_tween")
	return tween != null and tween.is_running()


func _cancel_card_entry(slot_data: Dictionary) -> void:
	var tween: Tween = slot_data.get("card_entry_tween")
	if tween != null and tween.is_running():
		tween.kill()
	slot_data.erase("card_entry_tween")


func _on_zone_input(_camera: Camera3D, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_index: int, zone_kind: String, zone_index: int, _owner_id: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
			return
		slot_selected.emit(zone_kind, zone_index)


func _add_tree(position: Vector3, tree_index: int) -> void:
	var ground_position := position + Vector3(0.0, -0.5, 0.0)
	var trunk_material := _material(Color("#564442"), 0.98)
	var trunk := _add_cylinder("Forest Tree Trunk", 0.3, 3.4 + float(tree_index % 3) * 0.35, ground_position + Vector3(0.0, 1.7, 0.0), trunk_material)
	trunk.rotation.z = float(tree_index % 3 - 1) * 0.07
	var canopy_pivot := Node3D.new()
	canopy_pivot.name = "Swaying Canopy"
	canopy_pivot.position = ground_position + Vector3(0.0, 2.75, 0.0)
	add_child(canopy_pivot)
	_canopy_pivots.append(canopy_pivot)
	_canopy_phases.append(float(tree_index) * 1.37)
	for branch_side in [-1.0, 1.0]:
		var branch := _add_cylinder("Forest Branch", 0.11, 1.75, Vector3(branch_side * 0.48, -0.55, 0.0), trunk_material, canopy_pivot)
		branch.rotation.z = branch_side * -0.58
		var branch_crown := _add_sphere("Blossom Canopy", 0.82, Vector3(branch_side * 0.95, 0.1, 0.0), _blossom_materials[(tree_index + 2) % _blossom_materials.size()], canopy_pivot)
		branch_crown.scale = Vector3(1.05, 0.9, 1.0)
	for canopy_index in range(7):
		var angle := TAU * float(canopy_index) / 7.0 + float(tree_index % 5) * 0.27
		var canopy_position := Vector3(cos(angle) * 0.62, 0.35 + float(canopy_index % 3) * 0.28, sin(angle) * 0.62)
		var canopy_radius := 0.82 + float((tree_index + canopy_index) % 3) * 0.12
		var crown := _add_sphere("Layered Blossom Canopy", canopy_radius, canopy_position, _blossom_materials[(tree_index + canopy_index) % _blossom_materials.size()], canopy_pivot)
		crown.scale = Vector3(1.18, 0.78 + float(canopy_index % 2) * 0.12, 1.08)
	var canopy_top := _add_sphere("Canopy Highlight", 0.95, Vector3(0.0, 1.05, 0.0), _blossom_materials[(tree_index + 3) % _blossom_materials.size()], canopy_pivot)
	canopy_top.scale = Vector3(1.05, 0.72, 1.0)


func _add_rock(position: Vector3, size: float, rock_index: int) -> void:
	var boulder := _add_sphere("Riverbank Boulder", size, position, _rock_materials[rock_index % _rock_materials.size()])
	boulder.scale = Vector3(1.2, 0.7 + float(rock_index % 2) * 0.12, 0.9)
	boulder.rotation.y = float(rock_index) * 0.72
	if rock_index % 2 == 0:
		var moss := _add_sphere("Boulder Moss", size * 0.28, position + Vector3(0.16, size * 0.44, -0.08), _forest_materials[rock_index % _forest_materials.size()])
		moss.scale = Vector3(1.5, 0.25, 1.1)


func _add_cylinder(label: String, radius: float, height: float, position: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.78
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	if parent == null:
		add_child(instance)
	else:
		parent.add_child(instance)
	return instance


func _add_box(label: String, dimensions: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	add_child(instance)
	return instance


func _add_sphere(label: String, radius: float, position: Vector3, material: Material, parent: Node3D = null) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	if parent == null:
		add_child(instance)
	else:
		parent.add_child(instance)
	return instance


func _make_label(label_text: String, color: Color, text_size: int, text_scale: float) -> Label3D:
	var label := Label3D.new()
	label.text = label_text
	label.font_size = text_size
	label.pixel_size = text_scale
	label.modulate = color
	label.outline_size = 8
	label.outline_modulate = Color("#101614")
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.rotation_degrees.x = -90.0
	label.no_depth_test = true
	return label


func _material(color: Color, roughness_value: float, metallic_value: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness_value
	material.metallic = metallic_value
	return material


func _emissive_material(color: Color) -> StandardMaterial3D:
	var material := _material(color, 0.25)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 2.0
	return material
