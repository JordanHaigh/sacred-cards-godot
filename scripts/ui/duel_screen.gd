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
const CARD_HAND_SCENE: PackedScene = preload("res://ui/card_hand.tscn")

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
var _card_hand: Control
var _selection_label: Label
var _message_label: Label
var _card_preview: PanelContainer
var _preview_title: Label
var _preview_origin: Label
var _preview_type: Label
var _preview_details: Label
var _preview_description: Label
var _preview_stats: Label
var _preview_art: TextureRect
var _preview_art_fallback: Label
var _selected_card_id: int = -1
var _selected_hand_instance_id: int = 0
var _inspected_zone_kind: String = ""
var _inspected_zone_index: int = -1
var _selected_zone_kind: String = "player_monster"
var _selected_monster_zone: int = 0
var _selected_back_row_zone: int = 0
var _ai: Object
var _music_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _life_point_player: AudioStreamPlayer
var _duel_sfx: Dictionary = {}

const DUEL_MUSIC_PATH := "res://local_assets/audio/music/BGM_DUEL_NORMAL_09.wav"
const DUEL_SFX_PATHS := {
	"draw": "res://local_assets/audio/sfx/SE_CARD_DRAW_01.wav",
	"summon": "res://local_assets/audio/sfx/SE_SMN_CMN_CARD_01.wav",
	"attack": "res://local_assets/audio/sfx/SE_SOLO_ATTACK_01.wav",
	"life_points": "res://local_assets/audio/sfx/SE_LP_COUNT_PLAYER.wav",
}

const FIELD_ACCENT := Color("#a4dcb9")


func _ready() -> void:
	_build_screen()
	_setup_duel_audio()
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
	_refresh_placement_highlights(player)
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
	battlefield_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(battlefield_spacer)

	_add_heading(content, "YOUR HAND")
	_card_hand = CARD_HAND_SCENE.instantiate() as Control
	content.add_child(_card_hand)
	_card_hand.connect("card_selected", _select_hand_card)
	_card_hand.connect("card_hovered", _show_card_preview)
	_card_hand.connect("card_unhovered", _hide_card_preview)
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
	if _trap_system != null:
		show_message("Select a hand card to play it. Click a field card to inspect its details.")


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
	if zone_kind.begins_with("player_"):
		_selected_zone_kind = zone_kind
		if zone_kind == "player_monster":
			_selected_monster_zone = zone_index
		else:
			_selected_back_row_zone = zone_index
	var field_card := _card_in_zone(zone_kind, zone_index)
	if field_card != null:
		_inspected_zone_kind = zone_kind
		_inspected_zone_index = zone_index
		refresh_screen()
		return
	if zone_kind.begins_with("opponent_"):
		_inspected_zone_kind = ""
		_inspected_zone_index = -1
		refresh_screen()
		return
	if _selected_card_id < 0:
		_inspected_zone_kind = ""
		_inspected_zone_index = -1
		refresh_screen()
		return
	var action := _placement_action(zone_kind, zone_index)
	if action == null:
		refresh_screen()
		show_message("Choose one of the highlighted squares for this card.")
		return
	var definition := _selected_definition()
	if not _run_action(action):
		return
	if String(definition.get("card_type")) == "Monster":
		_play_duel_sfx("summon")
		show_message("Summoned %s in attack position." % definition.get("display_name"))
	else:
		show_message("Set %s face down." % definition.get("display_name"))
	_inspected_zone_kind = zone_kind
	_inspected_zone_index = zone_index
	_selected_card_id = -1
	_selected_hand_instance_id = 0
	refresh_screen()


func _card_in_zone(zone_kind: String, zone_index: int) -> RefCounted:
	if duel_state == null:
		return null
	var player_id := "player_one" if zone_kind.begins_with("player_") else "player_two"
	var player = duel_state.call("get_player", player_id)
	if player == null:
		return null
	if zone_kind.ends_with("monster"):
		return player.call("get_monster_zone", zone_index) as RefCounted
	return player.call("get_spell_trap_zone", zone_index) as RefCounted


func _refresh_placement_highlights(player: Object) -> void:
	var definition := _selected_definition()
	if definition == null:
		var no_zones: Array[int] = []
		_arena_3d.call("set_placement_zones", "", no_zones)
		return
	var zone_kind := "player_monster" if String(definition.get("card_type")) == "Monster" else "player_back"
	var zone_count: int = player.monster_zone_count() if zone_kind == "player_monster" else player.spell_trap_zone_count()
	var valid_zones: Array[int] = []
	for zone_index in range(zone_count):
		var action := _placement_action(zone_kind, zone_index)
		if action != null and bool(action.call("validate", duel_state)):
			valid_zones.append(zone_index)
	_arena_3d.call("set_placement_zones", zone_kind, valid_zones)


func _placement_action(zone_kind: String, zone_index: int) -> RefCounted:
	var definition := _selected_definition()
	if definition == null:
		return null
	var card_type := String(definition.get("card_type"))
	if zone_kind == "player_monster" and card_type == "Monster":
		return DUEL_ACTION_SCRIPT.summon("player_one", _selected_card_id, card_type, zone_index, _selected_hand_instance_id)
	if zone_kind == "player_back" and ["Magic", "Trap"].has(card_type):
		return DUEL_ACTION_SCRIPT.set_spell_trap("player_one", _selected_card_id, card_type, zone_index, _selected_hand_instance_id)
	return null


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
	_card_hand.call("show_hand", player.get_hand(), card_database, _selected_hand_instance_id)


func _build_card_preview() -> void:
	_card_preview = PanelContainer.new()
	_card_preview.name = "CardDetails"
	_card_preview.custom_minimum_size = Vector2(370, 510)
	_card_preview.visible = false
	_card_preview.z_index = 40
	_card_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_card_preview.add_theme_stylebox_override("panel", _preview_panel_style(Color("#829466")))
	add_child(_card_preview)
	_card_preview.anchor_top = 0.5
	_card_preview.anchor_bottom = 0.5
	_card_preview.offset_left = 24.0
	_card_preview.offset_top = -255.0
	_card_preview.offset_right = 394.0
	_card_preview.offset_bottom = 255.0
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_card_preview.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	margin.add_child(layout)
	_preview_origin = _new_label(layout, "CARD DETAILS", 15, Color("#a4dcb9"))
	_preview_title = _new_label(layout, "Card name", 27, Color("#f2d789"))
	_preview_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_type = _new_label(layout, "CARD TYPE", 16, Color("#b9c9af"))
	var art_frame := PanelContainer.new()
	art_frame.custom_minimum_size.y = 150.0
	art_frame.add_theme_stylebox_override("panel", _preview_art_style())
	layout.add_child(art_frame)
	var art_center := CenterContainer.new()
	art_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.add_child(art_center)
	_preview_art = TextureRect.new()
	_preview_art.custom_minimum_size = Vector2(145.0, 145.0)
	_preview_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_center.add_child(_preview_art)
	_preview_art_fallback = _new_label(art_center, "Illustration unavailable", 16, Color("#aab6a8"))
	_preview_details = _new_label(layout, "", 16, Color("#e0d8c2"))
	_preview_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var description_scroll := ScrollContainer.new()
	description_scroll.custom_minimum_size.y = 120.0
	description_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(description_scroll)
	_preview_description = _new_label(description_scroll, "", 17, Color("#f0ecdf"))
	_preview_description.custom_minimum_size.x = 314.0
	_preview_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_stats = _new_label(layout, "", 20, Color("#edcf79"))


func _show_card_preview(card_id: int, _source_button: Control) -> void:
	var definition = card_database.call("get_card", card_id) if card_database != null else null
	if definition == null:
		return
	_show_definition_preview(definition, null, "IN HAND")


func _show_definition_preview(definition: Object, card: Object, origin: String) -> void:
	var card_type := String(definition.get("card_type"))
	var accent := _card_accent(card_type)
	_preview_origin.text = origin
	_preview_title.text = String(definition.get("display_name"))
	_preview_type.text = card_type.to_upper()
	_preview_details.text = _card_preview_details(definition)
	_preview_description.text = _card_preview_text(definition)
	if card_type == "Monster":
		var attack := int(card.get("current_attack")) if card != null else int(definition.get("attack"))
		var defense := int(card.get("current_defense")) if card != null else int(definition.get("defense"))
		_preview_stats.text = "ATK  %d      DEF  %d" % [attack, defense]
	else:
		_preview_stats.text = ""
	_preview_art.texture = definition.call("load_illustration") as Texture2D
	_preview_art.visible = _preview_art.texture != null
	_preview_art_fallback.text = "Illustration unavailable"
	_preview_art_fallback.visible = _preview_art.texture == null
	_card_preview.add_theme_stylebox_override("panel", _preview_panel_style(accent))
	_card_preview.visible = true


func _show_field_card_preview(card: Object) -> void:
	var owner_id := String(card.get("owner_id"))
	if owner_id == "player_two" and String(card.get("face_state")) == "face_down":
		_preview_origin.text = "OPPONENT FIELD"
		_preview_title.text = "Face-down card"
		_preview_type.text = "HIDDEN"
		_preview_details.text = "This card has not been revealed."
		_preview_description.text = ""
		_preview_stats.text = ""
		_preview_art.texture = null
		_preview_art.visible = false
		_preview_art_fallback.text = "Card identity hidden"
		_preview_art_fallback.visible = true
		_card_preview.add_theme_stylebox_override("panel", _preview_panel_style(Color("#829466")))
		_card_preview.visible = true
		return
	var definition = card.call("resolve_definition", card_database)
	if definition == null:
		_card_preview.visible = false
		return
	var origin := "YOUR FIELD" if owner_id == "player_one" else "OPPONENT FIELD"
	origin += "  ·  %s" % String(card.get("face_state")).replace("_", " ").to_upper()
	if String(definition.get("card_type")) == "Monster":
		origin += "  ·  %s" % String(card.get("battle_position")).to_upper()
	_preview_art_fallback.text = "Illustration unavailable"
	_show_definition_preview(definition, card, origin)


func _hide_card_preview() -> void:
	if _card_preview == null:
		return
	var field_card: RefCounted = null
	if not _inspected_zone_kind.is_empty():
		field_card = _card_in_zone(_inspected_zone_kind, _inspected_zone_index)
	if field_card != null and card_database != null:
		_show_field_card_preview(field_card)
	elif _selected_card_id >= 0 and card_database != null:
		_show_card_preview(_selected_card_id, null)
	else:
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
	style.bg_color = Color("#0d1715")
	style.border_color = Color("#6b846c")
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
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
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 8)
	controls.add_theme_constant_override("v_separation", 8)
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


func _setup_duel_audio() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "DuelMusicPlayer"
	_music_player.volume_db = -12.0
	add_child(_music_player)
	var music := _load_local_audio(DUEL_MUSIC_PATH) as AudioStreamWAV
	if music != null:
		music.loop_mode = AudioStreamWAV.LOOP_FORWARD
		_music_player.stream = music
		_music_player.play()

	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.name = "DuelSfxPlayer"
	_sfx_player.volume_db = -4.0
	add_child(_sfx_player)
	_life_point_player = AudioStreamPlayer.new()
	_life_point_player.name = "LifePointSfxPlayer"
	_life_point_player.volume_db = -4.0
	add_child(_life_point_player)
	for cue_name in DUEL_SFX_PATHS:
		var stream := _load_local_audio(String(DUEL_SFX_PATHS[cue_name]))
		if stream != null:
			_duel_sfx[cue_name] = stream


func _load_local_audio(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as AudioStream


func _play_duel_sfx(cue_name: String) -> void:
	if not _duel_sfx.has(cue_name):
		return
	var player := _life_point_player if cue_name == "life_points" else _sfx_player
	player.stream = _duel_sfx[cue_name] as AudioStream
	player.play()


func _add_button(parent: Container, caption: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(145, 44)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)


func _select_hand_card(card_id: int, instance_id: int) -> void:
	_inspected_zone_kind = ""
	_inspected_zone_index = -1
	if _selected_hand_instance_id == instance_id:
		_selected_card_id = -1
		_selected_hand_instance_id = 0
		refresh_screen()
		show_message("Card selection cleared.")
		return
	_selected_card_id = card_id
	_selected_hand_instance_id = instance_id
	refresh_screen()
	var definition := _selected_definition()
	if definition != null and String(definition.get("card_type")) == "Ritual":
		show_message("Ritual placement is not available in this duel yet.")
	else:
		show_message("Selected %s. Click a highlighted square to play it." % _selected_card_name(duel_state.call("get_player", "player_one")))


func _on_draw() -> void:
	var action = DUEL_ACTION_SCRIPT.draw("player_one")
	if _run_action(action):
		_play_duel_sfx("draw")
		show_message("Drew a card.")


func _on_summon() -> void:
	var definition = _selected_definition()
	if definition == null:
		show_message("Select a card in your hand first.")
		return
	var action = DUEL_ACTION_SCRIPT.summon("player_one", _selected_card_id, String(definition.get("card_type")), _selected_monster_zone, _selected_hand_instance_id)
	if _run_action(action):
		_play_duel_sfx("summon")
		_inspected_zone_kind = "player_monster"
		_inspected_zone_index = _selected_monster_zone
		_selected_card_id = -1
		_selected_hand_instance_id = 0
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
		action = DUEL_ACTION_SCRIPT.set_monster("player_one", _selected_card_id, card_type, _selected_monster_zone, _selected_hand_instance_id)
	else:
		action = DUEL_ACTION_SCRIPT.set_spell_trap("player_one", _selected_card_id, card_type, _selected_back_row_zone, _selected_hand_instance_id)
	if _run_action(action):
		_inspected_zone_kind = "player_monster" if card_type == "Monster" else "player_back"
		_inspected_zone_index = _selected_monster_zone if card_type == "Monster" else _selected_back_row_zone
		_selected_card_id = -1
		_selected_hand_instance_id = 0
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
	_selected_hand_instance_id = 0
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
		_play_duel_sfx("attack")
		if result.life_point_damage > 0:
			_play_duel_sfx("life_points")
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
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label
