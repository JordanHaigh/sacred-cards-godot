extends Control

## Presentation for the demo duel. DuelState and DuelPlayerState remain the source
## of truth; this script only reads them and redraws labels.

const CARD_DATABASE_SCRIPT = preload("res://scripts/cards/card_database.gd")
const CARD_INSTANCE_SCRIPT = preload("res://scripts/cards/card_instance.gd")
const DUEL_ACTION_SCRIPT = preload("res://scripts/duel/duel_action.gd")
const DUEL_STATE_SCRIPT = preload("res://scripts/duel/duel_state.gd")
const DUEL_AI_SCRIPT = preload("res://scripts/duel/basic_duel_ai.gd")
const BATTLE_RESOLVER_SCRIPT = preload("res://scripts/duel/battle_resolver.gd")
const EFFECT_REGISTRY_SCRIPT = preload("res://scripts/duel/card_effect_registry.gd")
const BASIC_EFFECTS_SCRIPT = preload("res://scripts/duel/basic_card_effects.gd")
const TRAP_TRIGGER_SCRIPT = preload("res://scripts/duel/trap_trigger_system.gd")
const EVENT_BUS_SCRIPT = preload("res://scripts/duel/duel_event_bus.gd")
const ARENA_3D_SCENE = preload("res://scenes/duel_arena_3d.tscn")

var duel_state: Object
var card_database: Object
var effect_registry: Object
var _basic_effects: Object
var _trap_system: Object
var _last_trap_message: String = ""

var _turn_label: Label
var _player_summary: Label
var _opponent_summary: Label
var _arena_3d: Node3D
var _hand_container: HBoxContainer
var _selection_label: Label
var _message_label: Label
var _card_preview: PanelContainer
var _preview_title: Label
var _preview_type: Label
var _preview_details: Label
var _preview_description: Label
var _preview_stats: Label
var _selected_card_id: int = -1
var _selected_zone_kind: String = "player_monster"
var _selected_monster_zone: int = 0
var _selected_back_row_zone: int = 0
var _ai: Object

const FIELD_ACCENT := Color("#a4dcb9")


func _ready() -> void:
	_build_screen()
	_start_demo_duel()
	refresh_screen()


func _exit_tree() -> void:
	if _trap_system != null:
		_trap_system.call("unbind")


func refresh_screen() -> void:
	if duel_state == null:
		return
	var player = duel_state.call("get_player", "player_one")
	var opponent = duel_state.call("get_player", "player_two")
	_turn_label.text = "Turn %d  |  %s phase  |  Active: %s" % [duel_state.get("turn_number"), String(duel_state.get("phase")).capitalize(), String(duel_state.get("active_player_id")).capitalize()]
	_player_summary.text = _summary_text("You", player)
	_opponent_summary.text = _summary_text("Opponent", opponent)
	_arena_3d.call("refresh_from_duel", duel_state, card_database)
	var active_zone_index := _selected_monster_zone if _selected_zone_kind == "player_monster" else _selected_back_row_zone
	_arena_3d.call("select_zone", _selected_zone_kind, active_zone_index)
	_render_hand(player)
	_selection_label.text = "Selected card: %s   ·   Monster slot %d   ·   Spell / Trap slot %d" % [
		_selected_card_name(player), _selected_monster_zone + 1, _selected_back_row_zone + 1,
	]
	if duel_state.get("status") == "finished":
		_message_label.text = "Duel finished. Winner: %s" % String(duel_state.get("winner_id")).capitalize()


func show_message(message: String) -> void:
	_message_label.text = message


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	match key_event.keycode:
		KEY_D:
			_on_draw()
		KEY_S:
			_on_summon()
		KEY_F:
			_on_set()
		KEY_P:
			_on_change_position()
		KEY_B:
			_on_enter_battle()
		KEY_A:
			_on_attack()
		KEY_E:
			_on_end_turn()


func _build_screen() -> void:
	var arena_container := SubViewportContainer.new()
	arena_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	arena_container.stretch = true
	arena_container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(arena_container)
	var arena_viewport := SubViewport.new()
	arena_viewport.size = Vector2i(1920, 1080)
	arena_viewport.physics_object_picking = true
	arena_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	arena_container.add_child(arena_viewport)
	_arena_3d = ARENA_3D_SCENE.instantiate()
	arena_viewport.add_child(_arena_3d)
	_arena_3d.connect("slot_selected", _on_zone_selected)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 16)
	add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(content)

	var title := Label.new()
	title.text = "SACRED CARDS  /  DUEL"
	title.add_theme_color_override("font_color", Color("#f0cf68"))
	title.add_theme_font_size_override("font_size", 40)
	content.add_child(title)

	_turn_label = _new_label(content, "Loading duel...", 24, Color("#d8e2ef"))

	var summaries := HBoxContainer.new()
	summaries.add_theme_constant_override("separation", 64)
	content.add_child(summaries)
	_player_summary = _new_label(summaries, "You", 23, Color("#e8edf5"))
	_opponent_summary = _new_label(summaries, "Opponent", 23, Color("#e8edf5"))
	_new_label(content, "FOREST SHRINE  /  DUEL FIELD", 18, FIELD_ACCENT)

	var battlefield_spacer := Control.new()
	battlefield_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(battlefield_spacer)

	_add_heading(content, "YOUR HAND")
	var hand_scroll := ScrollContainer.new()
	hand_scroll.custom_minimum_size.y = 118
	hand_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	hand_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(hand_scroll)
	_hand_container = HBoxContainer.new()
	_hand_container.add_theme_constant_override("separation", 14)
	hand_scroll.add_child(_hand_container)
	_selection_label = _new_label(content, "", 16, Color("#c2cfdf"))
	_add_controls(content)

	var spacer := Control.new()
	spacer.custom_minimum_size.y = 2
	content.add_child(spacer)
	_message_label = _new_label(content, "", 18, Color("#f0cf68"))
	_build_card_preview()


func _start_demo_duel() -> void:
	card_database = CARD_DATABASE_SCRIPT.new()
	var diagnostics: PackedStringArray = card_database.call("load_from_directory", "res://data/cards_json")
	if not diagnostics.is_empty():
		show_message("Card data could not load: %s" % diagnostics[0])
		return
	effect_registry = EFFECT_REGISTRY_SCRIPT.new()
	_basic_effects = BASIC_EFFECTS_SCRIPT.new()
	var effect_diagnostics: PackedStringArray = _basic_effects.call("register_primitives", effect_registry)
	if not effect_diagnostics.is_empty():
		show_message("Card effects could not register: %s" % effect_diagnostics[0])
		return

	duel_state = DUEL_STATE_SCRIPT.new(load("res://resources/sacred_cards_rules.tres"), "player_one", "player_two")
	var definitions: Array[Resource] = card_database.call("get_all_cards")
	for definition in definitions:
		for effect_id in definition.get("effect_ids"):
			if not bool(effect_registry.call("map_card_effect", int(definition.get("card_id")), String(effect_id))):
				show_message("Card %d effect mapping failed: %s" % [definition.get("card_id"), effect_registry.get("last_error")])
				duel_state = null
				return
	var mapping_file := FileAccess.open("res://resources/card_effect_mappings.json", FileAccess.READ)
	if mapping_file == null:
		show_message("Card effect mapping data could not be opened.")
		duel_state = null
		return
	var mapping_data = JSON.parse_string(mapping_file.get_as_text())
	if not mapping_data is Array:
		show_message("Card effect mapping data must be a JSON array.")
		duel_state = null
		return
	var mapping_diagnostics: PackedStringArray = effect_registry.call("load_mapping_records", mapping_data)
	if not mapping_diagnostics.is_empty():
		show_message("Card effect mapping failed: %s" % mapping_diagnostics[0])
		duel_state = null
		return
	var player_deck: Array[RefCounted] = []
	var opponent_deck: Array[RefCounted] = []
	for definition in definitions:
		if definition.get("card_type") != "Monster":
			continue
		if player_deck.size() < 20:
			player_deck.append(_new_demo_card(definition, "player_one"))
		elif opponent_deck.size() < 20:
			opponent_deck.append(_new_demo_card(definition, "player_two"))
		if player_deck.size() == 20 and opponent_deck.size() == 20:
			break
	var effect_card_ids: Array[int] = [338, 343, 789]
	for effect_index in range(effect_card_ids.size()):
		var effect_definition = card_database.call("get_card", effect_card_ids[effect_index])
		if effect_definition == null:
			continue
		player_deck.insert(5 + effect_index, _new_demo_card(effect_definition, "player_one"))
		opponent_deck.append(_new_demo_card(effect_definition, "player_two"))
	var trap_definition = card_database.call("get_card", 685)
	if trap_definition != null:
		player_deck.insert(8, _new_demo_card(trap_definition, "player_one"))
		opponent_deck.insert(8, _new_demo_card(trap_definition, "player_two"))
	if player_deck.is_empty() or opponent_deck.is_empty():
		show_message("The card database needs at least two monster cards to start the demo.")
		duel_state = null
		return

	duel_state.call("get_player", "player_one").load_deck(player_deck)
	duel_state.call("get_player", "player_two").load_deck(opponent_deck)
	_ai = DUEL_AI_SCRIPT.new()
	if not bool(duel_state.call("start")):
		show_message("The demo duel could not start.")
		duel_state = null
		return
	var ruleset = duel_state.get("ruleset")
	var opening_hand_size := int(ruleset.get("opening_hand_size"))
	duel_state.call("get_player", "player_one").draw_cards(opening_hand_size)
	duel_state.call("get_player", "player_two").draw_cards(opening_hand_size)
	if not bool(duel_state.call("set_phase", "main")):
		show_message("The demo duel could not enter its first main phase.")
		return
	_setup_trap_system()


func _setup_trap_system() -> void:
	var mapping_file := FileAccess.open("res://resources/card_trap_mappings.json", FileAccess.READ)
	if mapping_file == null:
		show_message("Trap mapping data could not be opened.")
		return
	var mapping_data = JSON.parse_string(mapping_file.get_as_text())
	if not mapping_data is Array:
		show_message("Trap mapping data must be a JSON array.")
		return
	_trap_system = TRAP_TRIGGER_SCRIPT.new()
	var diagnostics: PackedStringArray = _trap_system.call("load_trigger_mappings", mapping_data)
	if not diagnostics.is_empty():
		show_message("Trap mapping failed: %s" % diagnostics[0])
		_trap_system = null
		return
	if not bool(_trap_system.call("bind", duel_state, effect_registry)):
		show_message("Trap system could not bind: %s" % _trap_system.get("last_error"))
		_trap_system = null
		return
	duel_state.get("event_bus").call("subscribe", EVENT_BUS_SCRIPT.EVENT_TRAP_ACTIVATED, Callable(self, "_on_trap_activated"))


func _on_trap_activated(event: Dictionary) -> void:
	var card_id := int(event.get("payload", {}).get("card_id", 0))
	var definition = card_database.call("get_card", card_id)
	var card_name := "Trap %d" % card_id if definition == null else String(definition.get("display_name"))
	_last_trap_message = "%s activated and destroyed the attacking monster." % card_name
func _on_zone_selected(zone_kind: String, zone_index: int) -> void:
	_selected_zone_kind = zone_kind
	if zone_kind == "player_monster":
		_selected_monster_zone = zone_index
	elif zone_kind == "player_back":
		_selected_back_row_zone = zone_index
	_arena_3d.call("select_zone", zone_kind, zone_index)
	refresh_screen()


func _new_demo_card(definition: Resource, owner_id: String) -> RefCounted:
	var card = CARD_INSTANCE_SCRIPT.new(int(definition.get("card_id")), owner_id)
	card.call("initialize_from_database", card_database)
	return card


func _summary_text(caption: String, player: Object) -> String:
	return "%s   LP %d   Deck %d   Hand %d   Graveyard %d" % [
		caption,
		player.life_points,
		player.deck_size(),
		player.hand_size(),
		player.graveyard_size(),
	]


func _render_hand(player: Object) -> void:
	_hide_card_preview()
	for child in _hand_container.get_children():
		child.queue_free()
	for card in player.get_hand():
		var definition = card.call("resolve_definition", card_database)
		var button := Button.new()
		button.text = _card_name(card)
		if definition != null and definition.get("card_type") == "Monster":
			button.text += "\nATK %d / DEF %d" % [definition.get("attack"), definition.get("defense")]
		button.custom_minimum_size = Vector2(190, 104)
		button.add_theme_font_size_override("font_size", 17)
		button.add_theme_color_override("font_color", Color("#eee7d3"))
		button.add_theme_color_override("font_hover_color", Color("#fff4c8"))
		button.add_theme_stylebox_override("normal", _hand_card_style(definition, false))
		button.add_theme_stylebox_override("hover", _hand_card_style(definition, true))
		var card_id := int(card.get("definition_id"))
		button.toggle_mode = true
		button.button_pressed = card_id == _selected_card_id
		button.pressed.connect(_select_hand_card.bind(card_id))
		button.mouse_entered.connect(_show_card_preview.bind(card_id, button))
		button.mouse_exited.connect(_hide_card_preview)
		_hand_container.add_child(button)
	if _hand_container.get_child_count() == 0:
		var empty_label := Label.new()
		empty_label.text = "(empty)"
		empty_label.add_theme_font_size_override("font_size", 20)
		_hand_container.add_child(empty_label)


func _build_card_preview() -> void:
	_card_preview = PanelContainer.new()
	_card_preview.name = "HoveredCardPreview"
	_card_preview.custom_minimum_size = Vector2(330, 430)
	_card_preview.size = _card_preview.custom_minimum_size
	_card_preview.visible = false
	_card_preview.z_index = 40
	_card_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_preview.add_theme_stylebox_override("panel", _preview_panel_style(Color("#829466")))
	add_child(_card_preview)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 22)
	margin.add_theme_constant_override("margin_right", 22)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	_card_preview.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	_preview_title = _new_label(layout, "Card name", 29, Color("#f2d789"))
	_preview_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_type = _new_label(layout, "CARD TYPE", 16, Color("#b9c9af"))
	var art_window := PanelContainer.new()
	art_window.custom_minimum_size.y = 116
	art_window.add_theme_stylebox_override("panel", _preview_art_style())
	layout.add_child(art_window)
	var art_label := Label.new()
	art_label.text = "✦"
	art_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	art_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	art_label.add_theme_color_override("font_color", Color("#dec98f"))
	art_label.add_theme_font_size_override("font_size", 62)
	art_window.add_child(art_label)
	_preview_details = _new_label(layout, "", 15, Color("#e0d8c2"))
	_preview_description = _new_label(layout, "", 17, Color("#f0ecdf"))
	_preview_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_description.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_preview_stats = _new_label(layout, "", 18, Color("#edcf79"))


func _show_card_preview(card_id: int, source_button: Control) -> void:
	var definition = card_database.call("get_card", card_id) if card_database != null else null
	if definition == null:
		return
	var card_type := String(definition.get("card_type"))
	var accent := _card_accent(card_type)
	_preview_title.text = String(definition.get("display_name"))
	_preview_type.text = card_type.to_upper()
	_preview_details.text = _card_preview_details(definition)
	_preview_description.text = _card_preview_text(definition)
	_preview_stats.text = "ATK  %d      DEF  %d" % [int(definition.get("attack")), int(definition.get("defense"))] if card_type == "Monster" else ""
	_card_preview.add_theme_stylebox_override("panel", _preview_panel_style(accent))
	_card_preview.visible = true
	_card_preview.reset_size()
	var source_rect := source_button.get_global_rect()
	var preview_x := source_rect.position.x + source_rect.size.x * 0.5 - _card_preview.size.x * 0.5
	var preview_y := source_rect.position.y - _card_preview.size.y - 18.0
	if preview_y < 18.0:
		preview_y = source_rect.end.y + 18.0
	_card_preview.position = Vector2(
		clampf(preview_x, 18.0, size.x - _card_preview.size.x - 18.0),
		clampf(preview_y, 18.0, size.y - _card_preview.size.y - 18.0),
	)
	_card_preview.scale = Vector2(0.96, 0.96)
	var tween := create_tween()
	tween.tween_property(_card_preview, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _hide_card_preview() -> void:
	if _card_preview != null:
		_card_preview.visible = false


func _card_preview_details(definition: Object) -> String:
	var card_type := String(definition.get("card_type"))
	if card_type != "Monster":
		return card_type
	var detail_parts := PackedStringArray()
	var family: Variant = definition.get("monster_type")
	var subtype: Variant = definition.get("monster_subtype")
	var alignment: Variant = definition.get("alignment")
	if family != null and not String(family).strip_edges().is_empty():
		detail_parts.append(String(family))
	if subtype != null and not String(subtype).strip_edges().is_empty():
		detail_parts.append(String(subtype))
	if alignment != null and not String(alignment).strip_edges().is_empty():
		detail_parts.append(String(alignment))
	detail_parts.append("Level %d" % int(definition.get("level")))
	return "  ·  ".join(detail_parts)


func _card_preview_text(definition: Object) -> String:
	var text := String(definition.get("description"))
	if effect_registry == null:
		return text
	var card_id := int(definition.get("card_id"))
	var effect_ids: PackedStringArray = effect_registry.call("effects_for_card", card_id)
	if effect_ids.is_empty():
		return text
	var effect_id := String(effect_ids[0])
	var parameters: Dictionary = effect_registry.call("parameters_for_card_effect", card_id, effect_id)
	var target := "your opponent" if String(parameters.get("target", "self")) == "opponent" else "you"
	var effect_text := ""
	match effect_id:
		"lp_damage":
			effect_text = "Deal %d damage to %s." % [int(parameters.get("amount", 0)), target]
		"lp_heal":
			effect_text = "Restore %d LP to %s." % [int(parameters.get("amount", 0)), target]
		"draw_cards":
			effect_text = "%s draw %d card(s)." % ["You" if target == "you" else "Your opponent", int(parameters.get("count", 1))]
		"modify_monster_stats":
			effect_text = "Change a monster's ATK by %d and DEF by %d." % [int(parameters.get("attack_delta", 0)), int(parameters.get("defense_delta", 0))]
		"destroy_monster":
			effect_text = "Destroy an opposing monster that meets this card's conditions."
		"revive_monster":
			effect_text = "Return a monster from your Graveyard to the field."
		"change_monster_position":
			effect_text = "Change a monster's battle position."
		_:
			effect_text = effect_id.replace("_", " ").capitalize()
	return "%s\n\nEffect\n%s" % [text, effect_text]


func _hand_card_style(definition: Object, highlighted: bool) -> StyleBoxFlat:
	var card_type := String(definition.get("card_type")) if definition != null else "Monster"
	var accent := _card_accent(card_type)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#192421") if not highlighted else Color("#28392f")
	style.border_color = accent.lightened(0.18) if highlighted else accent.darkened(0.25)
	style.set_border_width_all(2 if highlighted else 1)
	style.set_corner_radius_all(10)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	return style


func _preview_panel_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#15211e")
	style.border_color = accent
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.72)
	style.shadow_size = 16
	style.content_margin_left = 4.0
	style.content_margin_right = 4.0
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	return style


func _preview_art_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#28372e")
	style.border_color = Color("#6e805d")
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	return style


func _card_accent(card_type: String) -> Color:
	match card_type:
		"Magic":
			return Color("#83b9a0")
		"Trap":
			return Color("#c2899a")
		"Ritual":
			return Color("#b8a0d2")
		_:
			return Color("#c3a963")


func _add_controls(parent: VBoxContainer) -> void:
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 8)
	parent.add_child(controls)
	_add_button(controls, "Draw", _on_draw)
	_add_button(controls, "Summon", _on_summon)
	_add_button(controls, "Set", _on_set)
	_add_button(controls, "Activate Effect", _on_activate_effect)
	_add_button(controls, "Previous Zone", _on_previous_zone)
	_add_button(controls, "Next Zone", _on_next_zone)
	_add_button(controls, "Change Position", _on_change_position)
	_add_button(controls, "Enter Battle", _on_enter_battle)
	_add_button(controls, "Attack", _on_attack)
	_add_button(controls, "End Turn", _on_end_turn)


func _add_button(parent: HBoxContainer, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(145, 44)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)


func _select_hand_card(card_id: int) -> void:
	_selected_card_id = card_id
	refresh_screen()
	show_message("Selected %s." % _selected_card_name(duel_state.call("get_player", "player_one")))


func _on_draw() -> void:
	var action = DUEL_ACTION_SCRIPT.draw("player_one")
	if _run_action(action):
		show_message("Drew a card.")


func _on_summon() -> void:
	var definition = _selected_definition()
	if definition == null:
		show_message("Select a card in your hand first.")
		return
	var action = DUEL_ACTION_SCRIPT.summon("player_one", _selected_card_id, String(definition.get("card_type")), _selected_monster_zone)
	if _run_action(action):
		_selected_card_id = -1
		refresh_screen()
		show_message("Summoned %s in attack position." % definition.get("display_name"))


func _on_set() -> void:
	var definition = _selected_definition()
	if definition == null:
		show_message("Select a card in your hand first.")
		return
	var card_type := String(definition.get("card_type"))
	var action: Object
	if card_type == "Monster":
		action = DUEL_ACTION_SCRIPT.set_monster("player_one", _selected_card_id, card_type, _selected_monster_zone)
	else:
		action = DUEL_ACTION_SCRIPT.set_spell_trap("player_one", _selected_card_id, card_type, _selected_back_row_zone)
	if _run_action(action):
		_selected_card_id = -1
		refresh_screen()
		show_message("Set %s face down." % definition.get("display_name"))


func _on_activate_effect() -> void:
	var definition = _selected_definition()
	if definition == null:
		show_message("Select a Magic or Trap card in your hand first.")
		return
	var effect_ids: PackedStringArray = definition.get("effect_ids")
	if effect_ids.is_empty():
		effect_ids = effect_registry.call("effects_for_card", _selected_card_id)
	if effect_ids.is_empty():
		effect_ids = effect_registry.call("effects_for_card", _selected_card_id)
	if effect_ids.is_empty():
		show_message("This card does not have a mapped effect yet.")
		return
	var effect_id := String(effect_ids[0])
	var parameters: Dictionary = effect_registry.call("parameters_for_card_effect", _selected_card_id, effect_id)
	var default_target := "opponent" if effect_id == "lp_damage" or effect_id == "destroy_monster" else "self"
	var target_side := String(parameters.get("target", default_target))
	parameters.erase("target")
	parameters["target_player_id"] = "player_two" if target_side == "opponent" else "player_one"
	parameters["card_database"] = card_database
	if effect_id in ["modify_monster_stats", "change_monster_position", "destroy_monster"]:
		parameters["zone_index"] = int(parameters.get("zone_index", _selected_monster_zone))
	if effect_id == "change_monster_position" and not parameters.has("position"):
		var target = duel_state.call("get_player", parameters["target_player_id"])
		var target_card = target.call("get_monster_zone", parameters["zone_index"])
		if target_card != null:
			parameters["position"] = "defense" if target_card.get("battle_position") == "attack" else "attack"
	var action = DUEL_ACTION_SCRIPT.activate_effect(
		"player_one",
		_selected_card_id,
		String(definition.get("card_type")),
		effect_id,
		parameters,
	)
	if not bool(action.call("execute", duel_state, effect_registry)):
		show_message(String(action.get("last_error")))
		return
	_selected_card_id = -1
	refresh_screen()
	show_message("Activated %s." % effect_id.replace("_", " "))


func _on_previous_zone() -> void:
	var zone_count: int = duel_state.call("get_player", "player_one").monster_zone_count()
	if zone_count <= 0:
		return
	_selected_zone_kind = "player_monster"
	_selected_monster_zone = posmod(_selected_monster_zone - 1, zone_count)
	refresh_screen()


func _on_next_zone() -> void:
	var zone_count: int = duel_state.call("get_player", "player_one").monster_zone_count()
	if zone_count <= 0:
		return
	_selected_zone_kind = "player_monster"
	_selected_monster_zone = (_selected_monster_zone + 1) % zone_count
	refresh_screen()


func _on_change_position() -> void:
	var player = duel_state.call("get_player", "player_one")
	var card = player.get_monster_zone(_selected_monster_zone)
	if card == null:
		show_message("There is no monster in that zone.")
		return
	var position := "defense" if card.get("battle_position") == "attack" else "attack"
	var action = DUEL_ACTION_SCRIPT.change_position("player_one", _selected_monster_zone, position)
	if _run_action(action):
		show_message("Changed the monster to %s position." % position)


func _on_enter_battle() -> void:
	if bool(duel_state.call("set_phase", "battle")):
		refresh_screen()
		show_message("Choose Attack to attack the opposing field.")
	else:
		show_message(String(duel_state.get("last_transition_error")))


func _on_attack() -> void:
	var opponent = duel_state.call("get_player", "player_two")
	var defender_zone := _first_occupied_zone(opponent)
	var action = DUEL_ACTION_SCRIPT.attack("player_one", _selected_monster_zone, "player_two", defender_zone)
	_last_trap_message = ""
	if not _run_action(action):
		return
	duel_state.call("pop_pending_action")
	if not _last_trap_message.is_empty():
		refresh_screen()
		show_message(_last_trap_message)
		return
	var resolver = BATTLE_RESOLVER_SCRIPT.new(card_database, load("res://resources/sacred_cards_matchups.tres"))
	var result = resolver.resolve(duel_state, "player_one", _selected_monster_zone, "player_two", defender_zone)
	if not result.success:
		show_message(result.error)
	else:
		show_message("Battle result: %s. LP damage: %d." % [result.outcome.replace("_", " ").capitalize(), result.life_point_damage])
	refresh_screen()


func _on_end_turn() -> void:
	var action = DUEL_ACTION_SCRIPT.end_turn("player_one")
	if not _run_action(action):
		return
	if duel_state.get("status") == "in_progress" and duel_state.get("active_player_id") == "player_two":
		var resolver = BATTLE_RESOLVER_SCRIPT.new(card_database, load("res://resources/sacred_cards_matchups.tres"))
		_last_trap_message = ""
		if not bool(_ai.call("take_turn", duel_state, card_database, resolver)):
			var failure_message := String(_ai.get("last_error"))
			if not _last_trap_message.is_empty():
				failure_message = _last_trap_message
			show_message("Opponent turn failed: %s" % failure_message)
			refresh_screen()
			return
		show_message(_last_trap_message if not _last_trap_message.is_empty() else "Opponent completed its turn.")
	refresh_screen()


func _run_action(action: Object) -> bool:
	if not bool(action.call("execute", duel_state)):
		show_message(String(action.get("last_error")))
		return false
	refresh_screen()
	return true


func _selected_definition() -> Resource:
	if _selected_card_id < 0:
		return null
	return card_database.call("get_card", _selected_card_id) as Resource


func _selected_card_name(player: Object) -> String:
	for card in player.get_hand():
		if int(card.get("definition_id")) == _selected_card_id:
			return _card_name(card)
	return "none"


func _first_occupied_zone(player: Object) -> int:
	for zone_index in range(player.monster_zone_count()):
		if player.get_monster_zone(zone_index) != null:
			return zone_index
	return -1


func _card_name(card: Object) -> String:
	if card == null:
		return "Empty"
	var definition = card.call("resolve_definition", card_database)
	if definition == null:
		return "Unknown card"
	return String(definition.get("display_name"))


func _field_card_name(card: Object, viewer_id: String, show_stats: bool = false) -> String:
	if card == null:
		return "Empty"
	if card.get("face_state") == "face_down" and card.get("owner_id") != viewer_id:
		return "Face-down"
	var name := _card_name(card)
	if show_stats:
		return "%s (%d / %d)" % [name, card.get("current_attack"), card.get("current_defense")]
	return name


func _add_heading(parent: VBoxContainer, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_color_override("font_color", Color("#f0cf68"))
	heading.add_theme_font_size_override("font_size", 20)
	parent.add_child(heading)


func _new_label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
