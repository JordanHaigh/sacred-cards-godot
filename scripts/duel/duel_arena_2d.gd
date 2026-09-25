class_name DuelArena2D
extends Control

## Flat forest field. DuelState owns the cards; this scene draws their slots.

signal slot_selected(zone_kind: String, zone_index: int)
signal slot_set_requested(zone_kind: String, zone_index: int)
signal slot_hovered(zone_kind: String, zone_index: int)
signal slot_unhovered(zone_kind: String, zone_index: int)

const FIELD_ZONE_SCENE: PackedScene = preload("res://ui/field_zone_2d.tscn")
const ZONE_ROWS: Array[String] = [
	"opponent_back",
	"opponent_monster",
	"player_monster",
	"player_back",
]
const BLOSSOM_COLORS: Array[Color] = [
	Color("#f4c5d5"),
	Color("#e9a8c0"),
	Color("#f9d9df"),
	Color("#d78fac"),
]

var _slots: Dictionary = {}
var _board_rect: Rect2 = Rect2()
var _selected_zone_kind: String = "player_monster"
var _selected_zone_index: int = 0
var _valid_placement_keys: Array[String] = []
var _tribute_keys: Array[String] = []
var _attack_target_keys: Array[String] = []
var _pile_views: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_slots()
	_build_piles()
	resized.connect(_layout_field)
	_layout_field()


func refresh_from_duel(duel_state: Object, card_database: Object) -> void:
	if duel_state == null or not duel_state.has_method("get_player"):
		return
	var player = duel_state.call("get_player", "player_one")
	var opponent = duel_state.call("get_player", "player_two")
	for zone_key in _slots:
		var zone: FieldZone2D = _slots[zone_key]
		var owner: Object = player if zone.zone_kind.begins_with("player_") else opponent
		var card: RefCounted = null
		if zone.zone_kind.ends_with("monster"):
			card = owner.call("get_monster_zone", zone.zone_index) as RefCounted
		else:
			card = owner.call("get_spell_trap_zone", zone.zone_index) as RefCounted
		zone.show_card(card, card_database)
	_update_pile("opponent_deck", opponent, card_database)
	_update_pile("opponent_graveyard", opponent, card_database)
	_update_pile("player_graveyard", player, card_database)
	_update_pile("player_deck", player, card_database)


func select_zone(zone_kind: String, zone_index: int) -> void:
	_selected_zone_kind = zone_kind
	_selected_zone_index = zone_index
	_update_highlights()


func set_placement_zones(zone_kind: String, zone_indices: Array[int]) -> void:
	_valid_placement_keys.clear()
	for zone_index in zone_indices:
		_valid_placement_keys.append("%s_%d" % [zone_kind, zone_index])
	_update_highlights()


func set_tribute_zones(zone_indices: Array[int]) -> void:
	_tribute_keys.clear()
	for zone_index in zone_indices:
		_tribute_keys.append("player_monster_%d" % zone_index)
	_update_highlights()


func set_attack_targets(zone_indices: Array[int]) -> void:
	_attack_target_keys.clear()
	for zone_index in zone_indices:
		_attack_target_keys.append("opponent_monster_%d" % zone_index)
	_update_highlights()


func _build_slots() -> void:
	for zone_kind in ZONE_ROWS:
		for zone_index in range(5):
			var zone := FIELD_ZONE_SCENE.instantiate() as FieldZone2D
			add_child(zone)
			zone.configure(zone_kind, zone_index)
			zone.slot_selected.connect(_on_slot_selected)
			zone.slot_set_requested.connect(_on_slot_set_requested)
			zone.slot_hovered.connect(_on_slot_hovered)
			zone.slot_unhovered.connect(_on_slot_unhovered)
			_slots["%s_%d" % [zone_kind, zone_index]] = zone
	_update_highlights()


func _build_piles() -> void:
	for pile_key in ["opponent_deck", "opponent_graveyard", "player_graveyard", "player_deck"]:
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color("#253c35") if pile_key.ends_with("deck") else Color("#4d3c39")
		style.border_color = Color("#c8b578")
		style.set_border_width_all(2)
		style.set_corner_radius_all(8)
		panel.add_theme_stylebox_override("panel", style)
		add_child(panel)
		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.add_theme_constant_override("margin_left", 10)
		margin.add_theme_constant_override("margin_right", 10)
		margin.add_theme_constant_override("margin_top", 6)
		margin.add_theme_constant_override("margin_bottom", 6)
		panel.add_child(margin)
		var column := VBoxContainer.new()
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_theme_constant_override("separation", 2)
		margin.add_child(column)
		var title := _pile_label(column, 14, Color("#f0d58b"))
		var count := _pile_label(column, 18, Color("#f5f0db"))
		var top_card := _pile_label(column, 11, Color("#c9d8cd"))
		title.text = ("OPPONENT" if pile_key.begins_with("opponent") else "YOUR") + (" DECK" if pile_key.ends_with("deck") else " GRAVEYARD")
		_pile_views[pile_key] = {"panel": panel, "count": count, "top": top_card}


func _pile_label(parent: VBoxContainer, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _update_pile(pile_key: String, player: Object, card_database: Object) -> void:
	var view: Dictionary = _pile_views[pile_key]
	var count: Label = view["count"]
	var top: Label = view["top"]
	if pile_key.ends_with("deck"):
		count.text = "%d cards" % player.deck_size()
		top.text = "Face-down draw pile"
		return
	var graveyard: Array = player.get_graveyard()
	count.text = "%d cards" % graveyard.size()
	if graveyard.is_empty():
		top.text = "Empty"
		return
	var definition = graveyard.back().call("resolve_definition", card_database)
	top.text = "Top: %s" % String(definition.get("display_name")) if definition != null else "Top card unavailable"


func _layout_field() -> void:
	if size.x < 100.0 or size.y < 100.0:
		_board_rect = Rect2()
		for zone_key in _slots:
			var hidden_zone: FieldZone2D = _slots[zone_key]
			hidden_zone.visible = false
		for pile_key in _pile_views:
			var hidden_pile: PanelContainer = _pile_views[pile_key]["panel"]
			hidden_pile.visible = false
		queue_redraw()
		return
	var board_width := minf(size.x * 0.72, 1400.0)
	var board_height := size.y * 0.96
	_board_rect = Rect2(Vector2((size.x - board_width) * 0.5, (size.y - board_height) * 0.5), Vector2(board_width, board_height))
	var inner := _board_rect.grow(-18.0)
	var cell_size := Vector2(inner.size.x / 5.0, inner.size.y / 4.0)
	var zone_size := Vector2(minf(cell_size.x * 0.76, cell_size.y), cell_size.y * 0.92)
	for row_index in range(ZONE_ROWS.size()):
		for zone_index in range(5):
			var zone: FieldZone2D = _slots["%s_%d" % [ZONE_ROWS[row_index], zone_index]]
			zone.visible = true
			zone.size = zone_size
			zone.position = inner.position + Vector2(
				cell_size.x * float(zone_index) + (cell_size.x - zone_size.x) * 0.5,
				cell_size.y * float(row_index) + (cell_size.y - zone_size.y) * 0.5,
			)
	_layout_piles()
	queue_redraw()


func _layout_piles() -> void:
	var pile_width := minf(212.0, maxf(130.0, size.x - _board_rect.end.x - 18.0))
	var pile_height := minf(95.0, maxf(72.0, (size.y - 48.0) / 4.0))
	var gap := maxf(4.0, (size.y - 24.0 - pile_height * 4.0) / 3.0)
	var pile_keys := ["opponent_deck", "opponent_graveyard", "player_graveyard", "player_deck"]
	for pile_index in range(pile_keys.size()):
		var panel: PanelContainer = _pile_views[pile_keys[pile_index]]["panel"]
		panel.visible = true
		panel.size = Vector2(pile_width, pile_height)
		panel.position = Vector2(_board_rect.end.x + 10.0, 12.0 + float(pile_index) * (pile_height + gap))


func _update_highlights() -> void:
	for zone_key in _slots:
		var zone: FieldZone2D = _slots[zone_key]
		var selected := zone.zone_kind == _selected_zone_kind and zone.zone_index == _selected_zone_index
		zone.set_highlight(
			selected,
			_valid_placement_keys.has(String(zone_key)),
			_tribute_keys.has(String(zone_key)),
			_attack_target_keys.has(String(zone_key)),
		)


func _on_slot_selected(zone_kind: String, zone_index: int) -> void:
	slot_selected.emit(zone_kind, zone_index)


func _on_slot_set_requested(zone_kind: String, zone_index: int) -> void:
	slot_set_requested.emit(zone_kind, zone_index)


func _on_slot_hovered(zone_kind: String, zone_index: int) -> void:
	slot_hovered.emit(zone_kind, zone_index)


func _on_slot_unhovered(zone_kind: String, zone_index: int) -> void:
	slot_unhovered.emit(zone_kind, zone_index)


func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	for band_index in range(12):
		var band_height := size.y / 12.0
		var band_color := Color("#1b3a32").lerp(Color("#10251f"), float(band_index) / 11.0)
		draw_rect(Rect2(0.0, band_height * float(band_index), size.x, band_height + 1.0), band_color)
	if _board_rect.size == Vector2.ZERO:
		return
	_draw_forest()
	_draw_board()


func _draw_forest() -> void:
	for side in [-1.0, 1.0]:
		for tree_index in range(7):
			var x_position: float = _board_rect.position.x - 86.0 if side < 0.0 else _board_rect.end.x + 86.0
			x_position += sin(float(tree_index) * 1.7) * 26.0
			var y_position := _board_rect.position.y + (float(tree_index) + 0.5) * _board_rect.size.y / 7.0
			_draw_tree(Vector2(x_position, y_position), tree_index + (0 if side < 0.0 else 7))
	for petal_index in range(42):
		var petal_position := Vector2(
			_board_rect.position.x + float((petal_index * 79) % 997) / 997.0 * _board_rect.size.x,
			_board_rect.position.y + float((petal_index * 43) % 503) / 503.0 * _board_rect.size.y,
		)
		draw_circle(petal_position, 2.0 + float(petal_index % 3), BLOSSOM_COLORS[petal_index % BLOSSOM_COLORS.size()])


func _draw_tree(center: Vector2, tree_index: int) -> void:
	var radius := 31.0 + float(tree_index % 3) * 5.0
	draw_circle(center + Vector2(7.0, 10.0), radius + 8.0, Color(0.02, 0.07, 0.06, 0.45))
	draw_rect(Rect2(center + Vector2(-5.0, 2.0), Vector2(10.0, 35.0)), Color("#594842"))
	draw_circle(center, radius, Color("#35634d"))
	for blossom_index in range(6):
		var angle := TAU * float(blossom_index) / 6.0 + float(tree_index) * 0.31
		var blossom_position := center + Vector2(cos(angle), sin(angle)) * radius * 0.48
		draw_circle(blossom_position, radius * 0.45, BLOSSOM_COLORS[(tree_index + blossom_index) % BLOSSOM_COLORS.size()])
	draw_circle(center + Vector2(-4.0, -5.0), radius * 0.44, BLOSSOM_COLORS[(tree_index + 2) % BLOSSOM_COLORS.size()])


func _draw_board() -> void:
	draw_rect(Rect2(_board_rect.position + Vector2(10.0, 12.0), _board_rect.size), Color(0.02, 0.06, 0.05, 0.45))
	draw_rect(_board_rect, Color("#d1c395"))
	draw_rect(_board_rect.grow(-7.0), Color("#806d48"), false, 5.0)
	draw_rect(_board_rect.grow(-15.0), Color("#efe1ad"), false, 2.0)
	var center_y := _board_rect.position.y + _board_rect.size.y * 0.5
	draw_line(Vector2(_board_rect.position.x + 20.0, center_y), Vector2(_board_rect.end.x - 20.0, center_y), Color("#90754b"), 3.0)
	draw_circle(Vector2(_board_rect.get_center().x, center_y), 17.0, Color("#a58e59"))
	draw_circle(Vector2(_board_rect.get_center().x, center_y), 10.0, Color("#e9dba9"))
	for corner_x in [_board_rect.position.x + 22.0, _board_rect.end.x - 22.0]:
		for corner_y in [_board_rect.position.y + 22.0, _board_rect.end.y - 22.0]:
			draw_circle(Vector2(corner_x, corner_y), 7.0, Color("#9b8052"))
