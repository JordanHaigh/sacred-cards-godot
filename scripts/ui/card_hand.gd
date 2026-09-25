extends Control

## Fans hand cards across the available width and forwards their UI events.

signal card_selected(card_id: int, instance_id: int)
signal card_hovered(card_id: int, source: Control)
signal card_unhovered

const HAND_CARD_SCENE: PackedScene = preload("res://ui/hand_card.tscn")
const CARD_SIZE := Vector2(152.0, 220.0)
const MAX_CARD_STEP := 108.0
const HOVER_RISE := 18.0
const HOVER_TIME := 0.16

@onready var _cards: Control = $Cards

var _card_views: Array[Button] = []
var _rest_positions: Array[Vector2] = []
var _rest_angles: Array[float] = []
var _motion_tweens: Dictionary = {}
var _hovered_card: Button


func _ready() -> void:
	resized.connect(_layout_cards)


func show_hand(hand_cards: Array, card_database: Object, selected_instance_id: int) -> void:
	for motion in _motion_tweens.values():
		var tween := motion as Tween
		if tween != null and tween.is_running():
			tween.kill()
	_motion_tweens.clear()
	_hovered_card = null
	_card_views.clear()
	for child in _cards.get_children():
		_cards.remove_child(child)
		child.queue_free()
	for card in hand_cards:
		var definition = card.call("resolve_definition", card_database)
		if definition == null:
			push_error("CardHand could not resolve a card definition")
			continue
		var card_view := HAND_CARD_SCENE.instantiate() as Button
		_cards.add_child(card_view)
		var instance_id: int = int(card.get_instance_id())
		card_view.call("show_card", definition, instance_id, instance_id == selected_instance_id)
		card_view.connect("card_selected", _on_card_selected)
		card_view.connect("card_hovered", _on_card_hovered)
		card_view.connect("card_unhovered", _on_card_unhovered)
		_card_views.append(card_view)
	if _card_views.is_empty():
		var empty_label := Label.new()
		empty_label.text = "(empty)"
		empty_label.add_theme_font_size_override("font_size", 20)
		_cards.add_child(empty_label)
		return
	_layout_cards()


func _layout_cards() -> void:
	var count := _card_views.size()
	if count == 0:
		return
	_rest_positions.clear()
	_rest_angles.clear()
	var available_width := maxf(_cards.size.x - 24.0, CARD_SIZE.x)
	var step := minf(MAX_CARD_STEP, maxf(0.0, (available_width - CARD_SIZE.x) / float(maxi(count - 1, 1))))
	var fan_width := CARD_SIZE.x + step * float(count - 1)
	var left := (_cards.size.x - fan_width) * 0.5
	for card_index in range(count):
		var card_view := _card_views[card_index]
		var normalized := (float(card_index) - float(count - 1) * 0.5) / maxf(float(count - 1) * 0.5, 1.0)
		var resting_position := Vector2(left + step * float(card_index), 10.0 + absf(normalized) * 22.0)
		var resting_angle := normalized * 12.0
		_rest_positions.append(resting_position)
		_rest_angles.append(resting_angle)
		var motion := _motion_tweens.get(card_view) as Tween
		if motion != null and motion.is_running():
			motion.kill()
		card_view.size = CARD_SIZE
		card_view.pivot_offset = Vector2(CARD_SIZE.x * 0.5, CARD_SIZE.y * 0.82)
		card_view.position = resting_position
		card_view.rotation_degrees = resting_angle
		card_view.scale = Vector2.ONE
		card_view.z_index = card_index
	if _hovered_card != null and is_instance_valid(_hovered_card):
		_hovered_card.position.y -= HOVER_RISE
		_hovered_card.rotation_degrees = 0.0
		_hovered_card.scale = Vector2.ONE * 1.08
		_hovered_card.z_index = 30


func _animate_card(card_view: Button, raised: bool) -> void:
	var card_index := _card_views.find(card_view)
	if card_index < 0:
		return
	var prior := _motion_tweens.get(card_view) as Tween
	if prior != null and prior.is_running():
		prior.kill()
	var target_position := _rest_positions[card_index]
	if raised:
		target_position.y -= HOVER_RISE
	card_view.z_index = 30 if raised else card_index
	var motion := card_view.create_tween().set_parallel(true)
	motion.tween_property(card_view, "position", target_position, HOVER_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(card_view, "rotation_degrees", 0.0 if raised else _rest_angles[card_index], HOVER_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	motion.tween_property(card_view, "scale", Vector2.ONE * 1.08 if raised else Vector2.ONE, HOVER_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_motion_tweens[card_view] = motion


func _on_card_selected(card_id: int, instance_id: int) -> void:
	card_selected.emit(card_id, instance_id)


func _on_card_hovered(card_id: int, source: Control) -> void:
	var next_card := source as Button
	if next_card == null or _hovered_card == next_card:
		return
	if _hovered_card != null and is_instance_valid(_hovered_card):
		_animate_card(_hovered_card, false)
	_hovered_card = next_card
	_animate_card(next_card, true)
	card_hovered.emit(card_id, source)


func _on_card_unhovered(source: Control) -> void:
	call_deferred("_finish_unhover", source.get_instance_id())


func _finish_unhover(source_id: int) -> void:
	if _hovered_card == null or not is_instance_valid(_hovered_card) or _hovered_card.get_instance_id() != source_id:
		return
	_animate_card(_hovered_card, false)
	_hovered_card = null
	card_unhovered.emit()
