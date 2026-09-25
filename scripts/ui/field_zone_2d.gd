class_name FieldZone2D
extends Control

## One clickable field square. Its card artwork and labels are presentation only.

signal slot_selected(zone_kind: String, zone_index: int)
signal slot_set_requested(zone_kind: String, zone_index: int)
signal slot_hovered(zone_kind: String, zone_index: int)
signal slot_unhovered(zone_kind: String, zone_index: int)

var zone_kind: String = ""
var zone_index: int = -1
var _card_instance_id: int = 0
var _has_card: bool = false
var _face_down: bool = false
var _selected: bool = false
var _valid_placement: bool = false
var _tribute: bool = false
var _attack_target: bool = false
var _hovered: bool = false
var _entry_tween: Tween

var _name_label: Label
var _art: TextureRect
var _center_label: Label
var _stats_label: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_build_content()
	resized.connect(_layout_content)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_layout_content()


func configure(kind: String, index: int) -> void:
	zone_kind = kind
	zone_index = index
	_update_content()
	queue_redraw()


func show_card(card: RefCounted, card_database: Object) -> void:
	var next_instance_id := 0
	if card != null:
		next_instance_id = int(card.get_instance_id())
	var is_new_card := next_instance_id != 0 and next_instance_id != _card_instance_id
	_card_instance_id = next_instance_id
	_has_card = card != null
	_face_down = card != null and String(card.get("face_state")) == "face_down"
	if card == null:
		_name_label.text = ""
		_stats_label.text = ""
		_art.texture = null
	elif _face_down:
		_name_label.text = "SET CARD"
		_stats_label.text = ""
		_art.texture = null
	else:
		var definition = card.call("resolve_definition", card_database)
		if definition == null:
			_name_label.text = "Unknown card"
			_stats_label.text = ""
			_art.texture = null
		else:
			_name_label.text = String(definition.get("display_name"))
			_art.texture = definition.call("load_illustration") as Texture2D
			if String(definition.get("card_type")) == "Monster":
				_stats_label.text = "%d / %d" % [int(card.get("current_attack")), int(card.get("current_defense"))]
			else:
				_stats_label.text = String(definition.get("card_type")).to_upper()
	_update_content()
	queue_redraw()
	if is_new_card:
		_animate_entry()


func set_highlight(selected: bool, valid_placement: bool, tribute: bool, attack_target: bool) -> void:
	_selected = selected
	_valid_placement = valid_placement
	_tribute = tribute
	_attack_target = attack_target
	queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			slot_selected.emit(zone_kind, zone_index)
			accept_event()
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
			slot_set_requested.emit(zone_kind, zone_index)
			accept_event()


func _draw() -> void:
	var background := Color("#53685d")
	if zone_kind.ends_with("back"):
		background = Color("#475b56")
	if _has_card:
		background = Color("#d5bd91") if not _face_down else Color("#263d3a")
	var border := Color("#a89365")
	if _selected:
		border = Color("#e7d47c")
	if _valid_placement:
		border = Color("#72f3ad")
	if _tribute:
		border = Color("#dd9eff")
	if _attack_target:
		border = Color("#ff9b71")
	if _hovered:
		border = border.lightened(0.22)
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.06, 0.11, 0.10, 0.55))
	draw_rect(Rect2(Vector2(3.0, 3.0), size - Vector2(6.0, 6.0)), background)
	draw_rect(Rect2(Vector2(2.0, 2.0), size - Vector2(4.0, 4.0)), border, false, 3.0 if _valid_placement else 2.0)
	if _valid_placement:
		draw_rect(Rect2(Vector2(7.0, 7.0), size - Vector2(14.0, 14.0)), Color(0.48, 1.0, 0.65, 0.13))
	if _face_down:
		draw_rect(Rect2(Vector2(12.0, 28.0), size - Vector2(24.0, 54.0)), Color("#7d6953"), false, 2.0)


func _build_content() -> void:
	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_color", Color("#2c261f"))
	add_child(_name_label)

	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art)

	_center_label = Label.new()
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_center_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_center_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_label.add_theme_font_size_override("font_size", 12)
	_center_label.add_theme_color_override("font_color", Color("#e5dec0"))
	add_child(_center_label)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_stats_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stats_label.add_theme_font_size_override("font_size", 11)
	_stats_label.add_theme_color_override("font_color", Color("#27251e"))
	add_child(_stats_label)


func _layout_content() -> void:
	if _name_label == null:
		return
	pivot_offset = size * 0.5
	_name_label.position = Vector2(7.0, 3.0)
	_name_label.size = Vector2(size.x - 14.0, 17.0)
	_art.position = Vector2(7.0, 20.0)
	_art.size = Vector2(size.x - 14.0, maxf(10.0, size.y - 38.0))
	_center_label.position = Vector2(7.0, 20.0)
	_center_label.size = Vector2(size.x - 14.0, maxf(10.0, size.y - 38.0))
	_stats_label.position = Vector2(7.0, size.y - 19.0)
	_stats_label.size = Vector2(size.x - 14.0, 16.0)
	queue_redraw()


func _update_content() -> void:
	if _name_label == null:
		return
	_name_label.visible = _has_card
	_stats_label.visible = _has_card and not _face_down
	_art.visible = _has_card and not _face_down and _art.texture != null
	_center_label.visible = not _art.visible
	if not _has_card:
		_center_label.text = "MONSTER" if zone_kind.ends_with("monster") else "SPELL/TRAP"
	elif _face_down:
		_center_label.text = "✦"
	else:
		_center_label.text = "NO ART"


func _animate_entry() -> void:
	if _entry_tween != null and _entry_tween.is_running():
		_entry_tween.kill()
	scale = Vector2.ONE * 0.84
	modulate.a = 0.55
	_entry_tween = create_tween().set_parallel(true)
	_entry_tween.tween_property(self, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_entry_tween.tween_property(self, "modulate:a", 1.0, 0.18)


func _on_mouse_entered() -> void:
	_hovered = true
	queue_redraw()
	if _has_card:
		slot_hovered.emit(zone_kind, zone_index)


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()
	slot_unhovered.emit(zone_kind, zone_index)
