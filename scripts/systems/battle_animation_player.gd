extends Control
class_name BattleAnimationPlayer

## Godot Tween choreography for battle_animation.c's semantic result phases.
signal phase_started(side_id: int, phase: StringName)
signal phase_finished(side_id: int, phase: StringName)

const RESULT_FLAGS := [
	[0, 0], [9, 0x4f], [0x4f, 0x4f], [0x4f, 9], [9, 0x57], [9, 0x11],
	[0x4b, 0x11], [0x11, 0x4b], [0x11, 9], [0x57, 9], [9, 0xc2], [9, 0],
	[0xcf, 0], [0, 0xcf], [0, 9], [0xc2, 9], [0x21, 0x67], [0x67, 0x21],
]
const FRAME_TIME := 1.0 / 60.0

@export var hit_distance := 5.0
@export var life_points_step := 72
@export var life_points_step_frames := 2

var card_nodes: Array[CanvasItem] = []
var life_point_labels: Array[CanvasItem] = []
var is_presenting := false
var _presentation_root: Control

## Stages the combatants with their recovered full-card art, then runs the
## result-code phases. Combat-side ordering follows the battle record; life
## values are remapped from physical duel sides using the supplied owners.
func play_duel_result(result_code: int, card_ids: Array[int], owners: Array[int], old_life_points: Array[int], new_life_points: Array[int], database: CardDatabase) -> void:
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
	if animation_flags(result_code) == [0, 0]:
		_presentation_root.queue_free()
		return
	is_presenting = true
	await present_result(result_code, combat_old, combat_new)
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

func present_result(result_code: int, old_life_points: Array[int], new_life_points: Array[int]) -> void:
	var flags := animation_flags(result_code)
	if flags[0] == 0 and flags[1] == 0:
		return
	for side_id in [1, 0]:
		var side_flags := flags[side_id]
		if (side_flags & 6) != 0:
			await _animate_card_impact(side_id, (side_flags & 128) != 0)
			await get_tree().create_timer(6 * FRAME_TIME).timeout
		if (side_flags & 4) != 0:
			await _animate_card_destruction(side_id)
		if (side_flags & 64) != 0 and side_id < old_life_points.size() and side_id < new_life_points.size():
			await _animate_life_points(side_id, old_life_points[side_id], new_life_points[side_id])
		if side_id == 1 and (flags[0] & 6) != 0:
			await get_tree().create_timer(30 * FRAME_TIME).timeout
	if result_code == 5 or result_code == 8:
		await get_tree().create_timer(30 * FRAME_TIME).timeout

func _on_battle_resolved(result_code: int, _flags: int, old_life_points: Array[int], new_life_points: Array[int]) -> void:
	present_result(result_code, old_life_points, new_life_points)

func _animate_card_impact(side_id: int, attribute_hit: bool) -> void:
	if side_id >= card_nodes.size() or card_nodes[side_id] == null:
		return
	var card := card_nodes[side_id]
	phase_started.emit(side_id, &"attribute_hit" if attribute_hit else &"hit")
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

func _animate_card_destruction(side_id: int) -> void:
	if side_id >= card_nodes.size() or card_nodes[side_id] == null:
		return
	var card := card_nodes[side_id]
	phase_started.emit(side_id, &"destruction")
	var tween := create_tween()
	tween.tween_property(card, "modulate:a", 0.0, 12 * FRAME_TIME)
	await tween.finished
	phase_finished.emit(side_id, &"destruction")

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
		await get_tree().create_timer(life_points_step_frames * FRAME_TIME).timeout
		frames += life_points_step_frames
	await get_tree().create_timer(30 * FRAME_TIME).timeout
	phase_finished.emit(side_id, &"life_points")
