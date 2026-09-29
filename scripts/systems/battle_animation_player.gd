extends Control
class_name BattleAnimationPlayer

## Godot Tween choreography for battle_animation.c's semantic result phases.
signal phase_started(side_id: int, phase: StringName)
signal phase_finished(side_id: int, phase: StringName)
signal sound_requested(sound_id: int)

const RESULT_FLAGS := [
	[0, 0], [9, 0x4f], [0x4f, 0x4f], [0x4f, 9], [9, 0x57], [9, 0x11],
	[0x4b, 0x11], [0x11, 0x4b], [0x11, 9], [0x57, 9], [9, 0xc2], [9, 0],
	[0xcf, 0], [0, 0xcf], [0, 9], [0xc2, 9], [0x21, 0x67], [0x67, 0x21],
]
const PLAYER_MENU_ASSETS := "res://decompiled/build/assets/player-menus/"
const SACRED_RANDOM_SCRIPT = preload("res://scripts/systems/sacred_random.gd")
const DESTRUCTION_SEEDS := [0x99, 0x129, 0x1C9, 0x1FF]
const DESTRUCTION_PARTICLES := 12
const DESTRUCTION_FRAGMENTS := 5
const OAM_DIMENSIONS := {
	0: [[8, 8], [16, 16], [32, 32], [64, 64]],
	1: [[16, 8], [32, 8], [32, 16], [64, 32]],
	2: [[8, 16], [8, 32], [16, 32], [32, 64]],
}
const FRAME_TIME := 1.0 / 60.0

@export var hit_distance := 5.0
@export var life_points_step := 72
@export var life_points_step_frames := 1

var card_nodes: Array[CanvasItem] = []
var life_point_labels: Array[CanvasItem] = []
var is_presenting := false
var _presentation_root: Control
var _sprite_layer: Node2D
var _sprite_sheets: Dictionary[String, Texture2D] = {}
var _destruction_sheet: Texture2D
var _destruction_alpha_bytes: PackedByteArray

## Stages the combatants with their recovered full-card art, then runs the
## result-code phases. Combat-side ordering follows the battle record; life
## values are remapped from physical duel sides using the supplied owners.
func play_duel_result(result_code: int, card_ids: Array[int], owners: Array[int], old_life_points: Array[int], new_life_points: Array[int], database: CardDatabase, random_service: SacredRandom = null) -> void:
	if database == null or card_ids.size() < 2 or owners.size() < 2 or old_life_points.size() < 2 or new_life_points.size() < 2:
		return
	if is_instance_valid(_presentation_root):
		_presentation_root.queue_free()
	_presentation_root = Control.new()
	_presentation_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_presentation_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_presentation_root)
	var backdrop := ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.015, 0.025, 0.035, 0.94)
	_presentation_root.add_child(backdrop)
	_sprite_layer = Node2D.new()
	_sprite_layer.z_index = 5
	_presentation_root.add_child(_sprite_layer)
	card_nodes.clear()
	life_point_labels.clear()
	var combat_old: Array[int] = []
	var combat_new: Array[int] = []
	for combat_side in range(2):
		var owner := owners[combat_side]
		combat_old.append(old_life_points[owner])
		combat_new.append(new_life_points[owner])
		var card_node: TextureRect = null
		var card := database.get_card(card_ids[combat_side]) if card_ids[combat_side] > 0 else null
		if card != null:
			card_node = TextureRect.new()
			card_node.position = Vector2(24 + combat_side * 112, 32)
			card_node.size = Vector2(80, 108)
			card_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			card_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			var image_path := card.art_path if ResourceLoader.exists(card.art_path) else card.miniature_path
			if ResourceLoader.exists(image_path):
				card_node.texture = load(image_path) as Texture2D
			_presentation_root.add_child(card_node)
		card_nodes.append(card_node)
		var label := Label.new()
		label.position = Vector2(12 + combat_side * 112, 12)
		label.size = Vector2(104, 16)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 10)
		label.text = "%s  %04d" % ["YOU" if owner == 0 else "RIVAL", combat_old[combat_side]]
		_presentation_root.add_child(label)
		life_point_labels.append(label)
	var flags := animation_flags(result_code)
	if flags[0] == 0 and flags[1] == 0:
		_presentation_root.queue_free()
		return
	is_presenting = true
	await get_tree().create_timer(12 * FRAME_TIME).timeout
	await present_result(result_code, combat_old, combat_new, random_service)
	is_presenting = false
	if is_instance_valid(_presentation_root):
		_presentation_root.queue_free()
	_presentation_root = null

func bind_battle(state: SacredBattleState, cards: Array[CanvasItem], labels: Array[CanvasItem]) -> void:
	card_nodes = cards
	life_point_labels = labels
	if not state.battle_resolved.is_connected(_on_battle_resolved):
		state.battle_resolved.connect(_on_battle_resolved)

func animation_flags(result_code: int) -> Array[int]:
	if result_code < 0 or result_code >= RESULT_FLAGS.size():
		return [0, 0]
	return [int(RESULT_FLAGS[result_code][0]), int(RESULT_FLAGS[result_code][1])]

func present_result(result_code: int, old_life_points: Array[int], new_life_points: Array[int], random_service: SacredRandom = null) -> void:
	var flags := animation_flags(result_code)
	if flags[0] == 0 and flags[1] == 0:
		return
	for side_id in [1, 0]:
		var side_flags := flags[side_id]
		if (side_flags & 6) != 0:
			sound_requested.emit(69 if (side_flags & 128) != 0 else 68)
			await _animate_card_impact(side_id, (side_flags & 128) != 0)
			await get_tree().create_timer(6 * FRAME_TIME).timeout
		if (side_flags & 4) != 0:
			sound_requested.emit(70)
			await _animate_card_destruction(side_id, random_service)
		if (side_flags & 64) != 0 and side_id < old_life_points.size() and side_id < new_life_points.size():
			await _animate_life_points(side_id, old_life_points[side_id], new_life_points[side_id])
		if side_id == 1 and (flags[0] & 6) != 0:
			await get_tree().create_timer(30 * FRAME_TIME).timeout
	if result_code == 5 or result_code == 8:
		await get_tree().create_timer(30 * FRAME_TIME).timeout

func _on_battle_resolved(result_code: int, _flags: int, old_life_points: Array[int], new_life_points: Array[int]) -> void:
	present_result(result_code, old_life_points, new_life_points)

func _animate_card_impact(side_id: int, attribute_hit: bool) -> void:
	if side_id >= card_nodes.size():
		return
	phase_started.emit(side_id, &"attribute_hit" if attribute_hit else &"hit")
	await _animate_recovered_sprite_sequence("battle-attribute" if attribute_hit else "battle-hit", side_id, 5 if attribute_hit else 4)
	if card_nodes[side_id] == null:
		phase_finished.emit(side_id, &"attribute_hit" if attribute_hit else &"hit")
		return
	var card := card_nodes[side_id]
	var origin := card.position
	var tween := create_tween()
	tween.tween_property(card, "position", origin + Vector2(hit_distance, 0), FRAME_TIME)
	tween.tween_property(card, "position", origin - Vector2(hit_distance, 0), FRAME_TIME)
	tween.tween_property(card, "position", origin, FRAME_TIME)
	if attribute_hit:
		var original_modulate := card.modulate
		tween.parallel().tween_property(card, "modulate", Color(1.0, 0.45, 0.45, original_modulate.a), FRAME_TIME)
		tween.tween_property(card, "modulate", original_modulate, FRAME_TIME)
	await tween.finished
	phase_finished.emit(side_id, &"attribute_hit" if attribute_hit else &"hit")

func _animate_recovered_sprite_sequence(animation_name: String, side_id: int, frame_count: int) -> void:
	for frame_index in range(frame_count):
		_render_oam_frame(animation_name, frame_index, side_id)
		await get_tree().create_timer(2 * FRAME_TIME).timeout
	_clear_sprite_layer()

func _render_oam_frame(animation_name: String, frame_index: int, side_id: int) -> void:
	if _sprite_layer == null:
		return
	_clear_sprite_layer()
	var frame_path := PLAYER_MENU_ASSETS + "%s-frame-%02d.oam" % [animation_name, frame_index]
	var bytes := FileAccess.get_file_as_bytes(frame_path)
	if bytes.is_empty() or bytes.size() % 8 != 0:
		return
	var main_sheet := _sprite_sheet(animation_name)
	var extra_sheet := _sprite_sheet("battle-hit-extra") if animation_name in ["battle-hit", "battle-attribute"] else null
	var base_x := (124 if side_id == 1 else 4) if animation_name == "battle-hit" else (116 if side_id == 1 else -4)
	for record_offset in range(0, bytes.size(), 8):
		var attr0 := bytes.decode_u16(record_offset)
		var attr1 := bytes.decode_u16(record_offset + 2)
		var attr2 := bytes.decode_u16(record_offset + 4)
		var shape := (attr0 >> 14) & 3
		var object_size := (attr1 >> 14) & 3
		if shape >= 3:
			continue
		var dimensions: Array = OAM_DIMENSIONS[shape][object_size]
		var tiles_wide := int(dimensions[0]) >> 3
		var tiles_high := int(dimensions[1]) >> 3
		var base_tile := attr2 & 0x3FF
		var x := (attr1 & 0x1FF) + base_x
		if x < 0: x += 512
		if x >= 256: x -= 512
		var y := ((attr0 & 0xFF) + 4) & 0xFF
		if y >= 160: y -= 256
		var flip_h := (attr1 & 0x1000) != 0
		var flip_v := (attr1 & 0x2000) != 0
		for row in range(tiles_high):
			for column in range(tiles_wide):
				var source_row := tiles_high - row - 1 if flip_v else row
				var source_column := tiles_wide - column - 1 if flip_h else column
				var object_tile := base_tile + source_row * tiles_wide + source_column
				var tile_sheet := main_sheet
				var tile_offset := object_tile
				if object_tile >= 512:
					tile_sheet = extra_sheet
					tile_offset = object_tile - 512
				if tile_sheet == null:
					continue
				# Native transfer copies sixteen source tiles into each 32-tile
				# object-memory row; reconstruct the compact PNG tile index.
				var source_tile_index := ((tile_offset >> 5) << 4) + (tile_offset & 31)
				var atlas_row := source_tile_index >> 4
				var atlas_column := source_tile_index % 16
				var tile := Sprite2D.new()
				tile.centered = false
				tile.texture = tile_sheet
				tile.region_enabled = true
				tile.region_rect = Rect2(atlas_column * 8, atlas_row * 8, 8, 8)
				tile.flip_h = flip_h
				tile.flip_v = flip_v
				tile.position = Vector2(x + column * 8, y + row * 8)
				tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				_sprite_layer.add_child(tile)

func _sprite_sheet(sheet_name: String) -> Texture2D:
	if _sprite_sheets.has(sheet_name):
		return _sprite_sheets[sheet_name]
	var texture_path := PLAYER_MENU_ASSETS + sheet_name + ".png"
	var texture := load(texture_path) as Texture2D if ResourceLoader.exists(texture_path) else null
	_sprite_sheets[sheet_name] = texture
	return texture

func _clear_sprite_layer() -> void:
	if _sprite_layer == null:
		return
	for child in _sprite_layer.get_children():
		child.free()

func _animate_card_destruction(side_id: int, random_service: SacredRandom) -> void:
	if side_id >= card_nodes.size() or card_nodes[side_id] == null:
		return
	var card := card_nodes[side_id]
	phase_started.emit(side_id, &"destruction")
	if random_service != null:
		await _animate_destruction_particles(side_id, card, random_service)
	else:
		var tween := create_tween()
		tween.tween_property(card, "modulate:a", 0.0, 12 * FRAME_TIME)
		await tween.finished
	phase_finished.emit(side_id, &"destruction")

func _animate_destruction_particles(side_id: int, card: CanvasItem, random_service: SacredRandom) -> void:
	var seed_choice := random_service.byte_inclusive(0, 3)
	var local_random := SACRED_RANDOM_SCRIPT.new() as SacredRandom
	local_random.state = DESTRUCTION_SEEDS[seed_choice]
	var particles: Array[Dictionary] = []
	for column in range(3):
		for row in range(4):
			var delay := local_random.next_byte() % 4 if row == 0 else local_random.next_byte() % 2 + int(particles[particles.size() - 1].delay) + 1
			var particle := {
				"position": Vector2((122 if side_id == 1 else 4) + column * 40, posmod(94 - int(row * 112 / 3), 256)),
				"delay": delay, "hold": 4, "life": 3, "plane": 0, "flip": local_random.next_byte() % 2,
				"frame": 0, "counter": 0, "offsets": []
			}
			particles.append(particle)
	for particle in particles:
		for _fragment in range(DESTRUCTION_FRAGMENTS):
			particle.offsets.append(Vector2(16 - local_random.next_byte() % 32, 20 - local_random.next_byte() % 40))
	# The C animation restores the global stream after its one seed-selection draw.
	# Its local seeded particle stream has no effect on duel randomness.
	var fragments: Array[Sprite2D] = []
	for _particle_index in range(DESTRUCTION_PARTICLES):
		for _fragment_index in range(DESTRUCTION_FRAGMENTS):
			var fragment := Sprite2D.new()
			fragment.centered = false
			fragment.texture = _destruction_sprite_sheet()
			fragment.region_enabled = true
			fragment.region_rect = Rect2(0, 0, 8, 8)
			fragment.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			_sprite_layer.add_child(fragment)
			fragments.append(fragment)
	var original_modulate := card.modulate
	for step in range(1, 18):
		var blend_alpha := _destruction_alpha(step)
		if is_instance_valid(card):
			var darkening := float(step * 2) / 31.0
			card.modulate = Color(maxf(0.0, original_modulate.r - darkening), maxf(0.0, original_modulate.g - darkening), maxf(0.0, original_modulate.b - darkening), original_modulate.a)
		for particle_index in range(DESTRUCTION_PARTICLES):
			var particle: Dictionary = particles[particle_index]
			if int(particle.delay) > 0:
				particle.delay = int(particle.delay) - 1
			elif int(particle.life) > 0:
				if int(particle.hold) > 0:
					particle.hold = int(particle.hold) - 1
				elif step % 3 == 0 or int(particle.plane) == 1:
					if int(particle.plane) == 1:
						particle.life = int(particle.life) - 1
					else:
						particle.plane = 1
			if int(particle.life) > 0 and int(particle.delay) == 0:
				particle.counter = int(particle.counter) + 1
				if int(particle.counter) >= 2:
					particle.counter = 0
					particle.frame = (int(particle.frame) + 1) % 4
			particles[particle_index] = particle
			for fragment_index in range(DESTRUCTION_FRAGMENTS):
				var sprite := fragments[particle_index * DESTRUCTION_FRAGMENTS + fragment_index]
				var offset: Vector2 = particle.offsets[fragment_index]
				sprite.visible = int(particle.life) > 0 and int(particle.delay) == 0
				sprite.position = particle.position + offset
				var tile := (int(particle.frame) * 5 + fragment_index) % 128
				sprite.region_rect = Rect2((tile % 16) * 8, (tile / 16) * 8, 8, 8)
				sprite.modulate.a = float(blend_alpha) / 16.0
			sprite.flip_h = int(particle.flip) != 0
		# C advances one destruction step for every three uploaded display frames.
		await get_tree().create_timer(3 * FRAME_TIME).timeout
	if is_instance_valid(card):
		card.modulate = Color(original_modulate.r, original_modulate.g, original_modulate.b, 0.0)

func _destruction_sprite_sheet() -> Texture2D:
	if _destruction_sheet == null:
		_destruction_sheet = load(PLAYER_MENU_ASSETS + "battle-destruction.png") as Texture2D
	return _destruction_sheet

func _destruction_alpha(step: int) -> int:
	if _destruction_alpha_bytes.is_empty():
		_destruction_alpha_bytes = FileAccess.get_file_as_bytes(PLAYER_MENU_ASSETS + "battle-destruction.alpha.bin")
	return int(_destruction_alpha_bytes[step % 3]) if _destruction_alpha_bytes.size() >= 3 else 8

func _animate_life_points(side_id: int, old_value: int, new_value: int) -> void:
	if side_id >= life_point_labels.size() or life_point_labels[side_id] == null or new_value >= old_value:
		return
	var label := life_point_labels[side_id]
	phase_started.emit(side_id, &"life_points")
	await get_tree().create_timer(15 * FRAME_TIME).timeout
	var displayed := old_value
	var frames := 0
	while displayed > new_value and frames < 10000:
		displayed = maxi(new_value, displayed - life_points_step)
		label.set("text", str(displayed))
		if frames % 2 == 0:
			sound_requested.emit(71)
		await get_tree().create_timer(life_points_step_frames * FRAME_TIME).timeout
		frames += life_points_step_frames
	await get_tree().create_timer(30 * FRAME_TIME).timeout
	phase_finished.emit(side_id, &"life_points")
