extends RefCounted
class_name AiCardScoring

## Card-specific AI scorer table, translated from ai_card_scoring.c.
## The native scratch word is a local unsigned score; candidates and slots are
## ordinary Godot values. Source inputs that the typed model cannot represent
## report an explicit unresolved result rather than inventing a score.

const TABLE_PATH := "res://resources/ai_card_score_tables.json"
const RITUAL_PATH := "res://resources/spell_ritual_recipes.json"
const LOW := 0x7EE0ACE9
const MASK := 0xFFFFFFFF

var card_database: CardDatabase
var stat_rules: CardStatRules
var summon_rules: SummonRules
var score_tables: Dictionary = {}
var ritual_recipes: Array = []

func _init(database: CardDatabase = null, stats: CardStatRules = null) -> void:
	card_database = database
	stat_rules = stats if stats != null else CardStatRules.new()
	summon_rules = SummonRules.new()
	var file := FileAccess.open(TABLE_PATH, FileAccess.READ)
	if file != null:
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary: score_tables = parsed
	if FileAccess.file_exists(RITUAL_PATH):
		var recipes: Variant = JSON.parse_string(FileAccess.get_file_as_string(RITUAL_PATH))
		if recipes is Array: ritual_recipes = recipes

func score_spell_before(state: SacredDuelState, active: int, candidate: Dictionary, card: CardDefinition, score: int = 0) -> Dictionary:
	return _score("spell_before", state, active, candidate, card, score)

func score_spell_after(state: SacredDuelState, active: int, candidate: Dictionary, card: CardDefinition, score: int = 0) -> Dictionary:
	return _score("spell_after", state, active, candidate, card, score)

func score_monster_before(state: SacredDuelState, active: int, candidate: Dictionary, card: CardDefinition, score: int = 0) -> Dictionary:
	return _score("monster_before", state, active, candidate, card, score)

func score_monster_after(state: SacredDuelState, active: int, candidate: Dictionary, card: CardDefinition, score: int = 0) -> Dictionary:
	return _score("monster_after", state, active, candidate, card, score)

func _score(table_name: String, state: SacredDuelState, active: int, candidate: Dictionary, card: CardDefinition, base_score: int) -> Dictionary:
	if state == null or active not in [0, 1] or card == null:
		return {"resolved": false, "reason": "invalid_context"}
	var metadata_index := card.metadata_1a if table_name.begins_with("spell") else card.metadata_1b
	var table: Array = score_tables.get(table_name, [])
	if metadata_index < 0 or metadata_index >= table.size():
		return {"resolved": false, "reason": "metadata_index_out_of_range", "metadata_index": metadata_index}
	var entry: Dictionary = table[metadata_index]
	match str(entry.get("kind", "")):
		"constant": return {"resolved": true, "score": int(entry.get("score", LOW)) & MASK}
		"noop": return {"resolved": true, "score": base_score & MASK}
		"handler":
			var result := _run_handler(int(entry.get("handler_id", -1)), state, active, candidate, base_score)
			if result.has("score"):
				result["resolved"] = true
				result["metadata_index"] = metadata_index
				return result
			return {"resolved": false, "reason": "scorer_input_unavailable", "handler_id": int(entry.get("handler_id", -1)), "metadata_index": metadata_index}
	return {"resolved": false, "reason": "invalid_score_table_entry", "metadata_index": metadata_index}

func _run_handler(id: int, state: SacredDuelState, active: int, candidate: Dictionary, initial_score: int) -> Dictionary:
	var enemy := 1 - active
	var own_monsters := state.side(active).monster_zones
	var enemy_monsters := state.side(enemy).monster_zones
	var enemy_back := state.side(enemy).back_row_zones
	var own_back := state.side(active).back_row_zones
	var score := initial_score & MASK
	match id:
		0: return {"score": _stat_sum(own_monsters, state.terrain)}
		1: return {"score": state.side(active).life_points & MASK}
		2: return {"score": _damage_score(state, active, 50)}
		3: return {"score": _damage_score(state, active, 100)}
		4: return {"score": _damage_score(state, active, 200)}
		5: return {"score": _damage_score(state, active, 500)}
		6: return {"score": _damage_score(state, active, 1000)}
		7: return {"score": _choice(_empty(own_monsters) == 5 and _empty(enemy_monsters) != 5, 0x7FF99745)}
		8: return {"score": _choice(_empty(enemy_monsters) != 5, 0x7FF99744)}
		9:
			var target := _candidate_slot(state, active, candidate, 1)
			if target == null: return {}
			var target_stats := _stats(target, state.terrain)
			return {"score": int(target_stats.x + target_stats.y)}
		10: return {"score": _choice(_count_flag(enemy_monsters, 2) > 0, 0x7FB3184A)}
		11: return {"score": _choice(_count_type(enemy_monsters, 1) > 0, 0x7FF99742)}
		12: return {"score": _choice((state.side(enemy).duel_flags & 3) == 0, 0x7EEB5B5A)}
		13: return {"score": _hidden_row(enemy_monsters, 0x7FFFFFF7)}
		14: return {"score": _stat_sum(enemy_monsters, state.terrain, true) if _empty(enemy_monsters) != 5 else LOW}
		15:
			var marked := _candidate_slot(state, active, candidate, 1)
			return {"score": _choice(marked != null and marked.card_id in [62, 875], 0x7FF55173)}
		16:
			var ritual_spell := _candidate_slot(state, active, candidate, 0)
			var ritual_card := card_database.get_card(ritual_spell.card_id) if ritual_spell != null else null
			return _ritual_score(state, active, candidate, ritual_card.metadata_1d, false, false) if ritual_card != null else {}
		17: return {"score": _score_three_material_ritual(state, active)}
		18: return {"score": _choice(_empty(enemy_back) != 5, 0x7FF9974A)}
		19: return {"score": _choice(_count_attack(enemy_monsters, state.terrain, 1500) > 0, 0x7FF99742)}
		20:
			var ritual_spell_cell := _candidate_slot(state, active, candidate, 0)
			var ritual_spell_data := card_database.get_card(ritual_spell_cell.card_id) if ritual_spell_cell != null else null
			if ritual_spell_data == null or ritual_spell_data.metadata_1d >= ritual_recipes.size(): return {}
			var recipe: Dictionary = ritual_recipes[ritual_spell_data.metadata_1d]
			var ritual_a := _candidate_slot(state, active, candidate, 2)
			var ritual_b := _candidate_slot(state, active, candidate, 3)
			var materials: Array = recipe.get("other_materials", [])
			if ritual_a == null or ritual_b == null or materials.size() < 2: return {}
			if not ((ritual_a.card_id == int(materials[0]) and ritual_b.card_id == int(materials[1])) or (ritual_a.card_id == int(materials[1]) and ritual_b.card_id == int(materials[0]))): return {"score": LOW}
			return _ritual_score(state, active, candidate, ritual_spell_data.metadata_1d, true, true)
		21: return {"score": _choice(_count_type(enemy_monsters, 4) > 0, 0x7FF99742)}
		22: return {"score": _has_high_stage_flag(own_monsters)}
		23: return {"score": _choice(_count_type(enemy_monsters, 3) > 0, 0x7FF99742)}
		24:
			var selected := _candidate_slot(state, active, candidate, 1)
			if selected != null and selected.card_id in [391, 82, 885]:
				var selected_card_stats := _stats(selected, state.terrain)
				return {"score": int(selected_card_stats.x + selected_card_stats.y)}
			return {"score": LOW}
		25: return {"score": _choice(_count_type(enemy_monsters, 15) > 0, 0x7FF99742)}
		26: return {"score": _choice(_count_type(enemy_monsters, 10) > 0, 0x7FF99742)}
		27: return {"score": _choice(_count_type(enemy_monsters, 19) > 0, 0x7FF99742)}
		28: return {"score": _choice(_count_type(enemy_monsters, 13) > 0, 0x7FF99742)}
		29: return {"score": _hidden_hand(state.side(enemy).hand, state.side(enemy).hand_flags, 0x7FFFFFF6)}
		30:
			var ritual_spell_for_special := _candidate_slot(state, active, candidate, 0)
			var ritual_special_data := card_database.get_card(ritual_spell_for_special.card_id) if ritual_spell_for_special != null else null
			var ritual_target := _candidate_slot(state, active, candidate, 1)
			if ritual_special_data == null or ritual_target == null: return {}
			var recipe_id := 24 if ritual_special_data.metadata_1d < ritual_recipes.size() and ritual_target.card_id == int(ritual_recipes[ritual_special_data.metadata_1d].get("material", 0)) else 26
			return _ritual_score(state, active, candidate, recipe_id, false, false)
		31: return {"score": _choice(_empty_hand(state.side(enemy).hand) >= 2, 0x7EEB5B58)}
		32:
			var hand_size := state.side(enemy).hand_count()
			if hand_size == 0: return {"score": LOW}
			return {"score": 0x7FFFFFFF if hand_size * 200 < state.side(enemy).life_points else 0x7FFFFFF5}
		33: return {"score": _choice(_count_type(enemy_monsters, 2) > 0, 0x7FF99742)}
		34: return {"score": _choice(_count_type(enemy_monsters, 8) > 0, 0x7FF99742)}
		35: return {"score": _choice(_count_card(own_monsters, 58) > 0 and _empty(own_monsters) > 0, 0x7FF32E8B)}
		36, 37: return {"score": _choice(_empty(own_monsters) > 0 and _empty(enemy_monsters) != 5, 0x7FF9974B)}
		38: return {"score": _choice(state.side(enemy).graveyard_monster_id != 0 and _empty(own_monsters) > 0, 0x7FB31849)}
		39: return {"score": _choice(_empty(enemy_monsters) != 5, 0x7FF77462)}
		40: return {"score": _choice(state.side(active).graveyard_monster_id != 0, 0x7EEB5B59)}
		41: return {"score": _choice(_empty(own_monsters) == 5 and (_empty(enemy_monsters) != 5 or _empty(enemy_back) != 5), 0x7FFFFFFD)}
		42: return {"score": _choice(_empty(own_monsters) == 5 and (_empty(enemy_monsters) != 5 or _empty(enemy_back) != 5), 0x7FFFFFFE)}
		43: return {"score": _strong_enemy_attack(state, active)}
		44: return {"score": _own_effect_monster(state, active)}
		45:
			var total := _stat_sum(own_monsters, state.terrain)
			return {"score": _choice(score < total, total + 0x7FC8750B)}
		46: return {"score": _choice(score < state.side(active).life_points, 0x7FF99748)}
		47:
			var selected_stat_cell := _candidate_slot(state, active, candidate, 1)
			if selected_stat_cell == null: return {}
			var selected_stats := _stats(selected_stat_cell, state.terrain)
			return {"score": _choice(score < selected_stats.x + selected_stats.y, score + 0x7F083246)}
		48: return {"score": _choice(_stat_sum(enemy_monsters, state.terrain, true) < score, 0x7FF55178) if score != LOW else score}
		49:
			if score == LOW: return {"score": score}
			var selected_score_cell := _candidate_slot(state, active, candidate, 1)
			if selected_score_cell == null: return {}
			var selected_score_stats := _stats(selected_score_cell, state.terrain)
			return {"score": _choice(score < selected_score_stats.x + selected_score_stats.y, 0x7FF55173)}
		50: return {"score": _choice(_empty(enemy_back) != 5, 0x7FFFFFF8)}
		51: return {"score": _choice(9999 - state.side(active).life_points >= 1000, 0x7FFFFFEF)}
		52: return {"score": _choice(_empty(enemy_monsters) != 5, 0x7FFBBA2B)}
		53: return {"score": _choice(_empty(enemy_monsters) != 5, 0x7FFDDD0B)}
		54: return {"score": _choice(_empty_hand(state.side(enemy).hand) != 0, 0x7FB31848)}
		55, 56, 104: return {"score": _score_card_boost(own_monsters, state.terrain, 386)}
		57: return {"score": _choice(_count_cards(own_monsters, [4, 35, 865]) > 0, 0x7EF2D571)}
		58: return {"score": _score_terrain_six_case(state, own_monsters)}
		59: return {"score": _score_card_boost_any(own_monsters, state.terrain, [1, 887])}
		60, 88: return {"score": _score_terrain(state, active, 2 if id == 60 else 1)}
		61: return {"score": _choice(_count_type(enemy_monsters, 11) > 0, 0x7FF7745E)}
		62: return {"score": _score_terrain(state, active, 0)}
		63: return {"score": _choice(_count_visible_metadata(enemy_monsters, 0x17, 5) > 0, 0x7FF7745D)}
		64: return {"score": _score_card_boost(own_monsters, state.terrain, 375)}
		65: return {"score": _score_card_boost_any(own_monsters, state.terrain, [96, 97, 98])}
		66: return {"score": _choice(_empty(enemy_monsters) != 5, 0x7FF55177)}
		67: return {"score": _score_input_column_damage(state, active, candidate)}
		68: return {"score": _choice(_empty_hand(state.side(enemy).hand) != 0, 0x7FB31847)}
		69: return {"score": _score_terrain(state, active, 3)}
		77, 79, 81, 85, 90, 94, 96, 97, 99, 100, 101, 106, 107, 108, 109, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139:
			var priorities := {77: 0x7EF2D57B, 79: 0x7EED7E3E, 81: 0x7FFFFFEE, 85: 0x7FF32E8E, 90: 0x7FF32E91, 94: 0x7FF32E90, 96: 0x7EED7E3B, 97: 0x7EF2D57C, 99: 0x7FFFFFF1, 100: 0x7EF2D573, 101: 0x7FF99747, 106: 0x7FF32E92, 107: 0x7FF32E92, 108: 0x7FF32E92, 109: 0x7FF32E8C, 128: 0x7EFD83E4, 129: 0x7EF2D582, 130: 0x7FDDD1CB, 131: 0x7EF2D583, 132: 0x7FB3184B, 133: 0x7FB3184B, 134: 0x7EF2D581, 135: 0x7EF2D580, 136: 0x7FB3184B, 137: 0x7FB3184B, 138: 0x7FB3184B, 139: 0x7EF2D584}
			return {"score": _score_handler_family(id, priorities[id], state, active, candidate, score)}
		70, 116: return {"score": _choice(_count_type(enemy_monsters, 1) > 0, 0x7FF7745C if id == 70 else 0x7EF2D572)}
		71: return {"score": _choice(_empty(enemy_back) > 0, 0x7EF2D570)}
		72: return {"score": _choice(_empty(enemy_monsters) != 5, 0x7FF5517C)}
		73: return {"score": _choice(_empty(enemy_monsters) != 5, 0x7EED7E3B)}
		74: return {"score": _choice(_empty(enemy_monsters) != 5, 0x7EEB5B5B)}
		75: return {"score": _choice(_dragon_in_grave(state), 0x7EF2D57F)}
		76: return {"score": _choice(_count_metadata(own_monsters, 0x16, 20, true, false) > 0, 0x7EF2D57D)}
		78: return {"score": _choice(_count_card(own_monsters, 160) > 0, 0x7EF2D57A)}
		80, 120: return {"score": _choice(9999 - state.side(active).life_points >= 500, 0x7FFFFFEE if id == 80 else 0x7FFFFFED)}
		82: return {"score": 0x7FFFFFFF if state.side(enemy).life_points <= 50 else 0x7EEB5B57}
		83: return {"score": _choice(_count_attack_max(own_monsters, state.terrain, 500) > 0, 0x7EF2D579)}
		84: return {"score": _choice(state.side(enemy).hand_count() > 0, 0x7EED7E3F)}
		86: return {"score": _choice(_count_card(own_monsters, 554) > 0, 0x7EF2D578)}
		87: return {"score": _choice(_count_card(own_monsters, 12) > 0, 0x7EF2D577)}
		89: return {"score": _choice(_count_card(own_monsters, 366) > 0, 0x7EF2D577)}
		91: return {"score": _choice(_empty(own_monsters) != 5 and state.side(active).life_points > 1000, 0x7EF2D576)}
		92: return {"score": _choice(_empty(own_monsters) >= 4 and _empty(enemy_monsters) != 5, 0x7FF5517B)}
		93: return {"score": _choice(_empty(enemy_monsters) != 5 and _unlocked_count(own_monsters) == 1, 0x7EED7E3C)}
		95: return {"score": _score_attribute_change(own_monsters, 1, 2)}
		98: return {"score": _score_attack_damage(state, active, candidate, 0x7FFFFFF2)}
		102: return {"score": _choice(_count_metadata(state.side(enemy).hand, 0x1A, 2, false, false) > 0, 0x7F083244)}
		105: return {"score": _choice(_dragon_in_grave(state), 0x7EF2D57E)}
		110: return {"score": _choice(_empty(enemy_monsters) != 5, 0x7FF55176)}
		111: return {"score": _choice(_empty(own_monsters) > 0 and _count_empty_or_immune(enemy_monsters) < 5, 0x7FFFFFEB)}
		112, 113, 114, 117: return {"score": _score_opposing_target(state, enemy_monsters, {112: 0x7FF5517A, 113: 0x7FF99746, 114: 0x7FF99743, 117: 0x7FF7745F}[id])}
		115: return {"score": _choice(_empty(enemy_back) != 5, 0x7FFFFFF8)}
		118: return {"score": _score_strongest_fatal(state, active)}
		119: return {"score": _score_strongest_comparison(state, active, candidate)}
		121: return {"score": _score_strongest_selected(state, active, candidate)}
		122: return {"score": _choice(_empty(enemy_monsters) != 5, 0x7FF55175)}
		123: return {"score": _choice(_empty(own_monsters) > 0, 0x7FF32E8D)}
		124: return {"score": _choice(_count_metadata(own_monsters, 0x16, 1, true, false) > 0, 0x7EF2D57C)}
		125: return {"score": _choice(_empty(own_monsters) > 0, 0x7FF32E8F)}
		126: return {"score": _score_opp_damage_gate(state, active, enemy_monsters)}
		127: return {"score": _score_attack_damage(state, active, candidate, 0x7FFFFFF3)}
		103: return {"score": _score_life_comparison(state, active)}
	return {}

func _choice(condition: bool, priority: int) -> int:
	return priority & MASK if condition else LOW

func _damage_score(state: SacredDuelState, active: int, damage: int) -> int:
	return 0x7FFFFFFF if state.side(1 - active).life_points <= damage else 0x7FF99749

func _empty(row: Array) -> int:
	var total := 0
	for slot in row:
		if slot.is_empty(): total += 1
	return total

func _occupied(row: Array) -> int:
	return row.size() - _empty(row)

func _count_card(row: Array, card_id: int) -> int:
	var total := 0
	for slot in row:
		if slot.card_id == card_id: total += 1
	return total

func _count_flag(row: Array, flag: int) -> int:
	var total := 0
	for slot in row:
		if not slot.is_empty() and (slot.persistent_flags & flag) != 0: total += 1
	return total

func _unlocked_count(row: Array) -> int:
	var total := 0
	for slot in row:
		if not slot.is_empty() and (slot.persistent_flags & 1) == 0: total += 1
	return total

func _count_type(row: Array, type_id: int) -> int:
	var total := 0
	for slot in row:
		if slot.is_empty() or (slot.persistent_flags & 0x10) == 0: continue
		var card := card_database.get_card(slot.card_id)
		if card != null and card.card_type == type_id: total += 1
	return total

func _count_attack(row: Array, terrain: int, minimum: int) -> int:
	var total := 0
	for slot in row:
		if not slot.is_empty() and (slot.persistent_flags & 0x10) != 0 and _stats(slot, terrain).x >= minimum: total += 1
	return total

func _count_attack_max(row: Array, terrain: int, maximum: int) -> int:
	var total := 0
	for slot in row:
		if not slot.is_empty() and _stats(slot, terrain).x <= maximum: total += 1
	return total

func _count_cards(row: Array, card_ids: Array[int]) -> int:
	var total := 0
	for slot in row:
		if slot.card_id in card_ids: total += 1
	return total

func _count_metadata(row: Array, field: int, value: int, nonempty: bool, visible: bool) -> int:
	var total := 0
	for item in row:
		var card_id: int = item.card_id if item is DuelCardSlot else int(item)
		var flags: int = item.persistent_flags if item is DuelCardSlot else 0
		if nonempty and card_id == 0: continue
		if visible and (flags & 0x10) == 0: continue
		var card := card_database.get_card(card_id) if card_database != null else null
		if card == null: continue
		var metadata := card.card_type if field == 0x16 else card.attribute if field == 0x17 else card.metadata_1a if field == 0x1A else card.metadata_1d
		if metadata == value: total += 1
	return total

func _score_card_boost(row: Array, terrain: int, card_id: int) -> int:
	return _stat_sum(row, terrain) if _count_card(row, card_id) > 0 else LOW

func _score_card_boost_any(row: Array, terrain: int, card_ids: Array[int]) -> int:
	return _stat_sum(row, terrain) if _count_cards(row, card_ids) > 0 else LOW

func _score_terrain(state: SacredDuelState, active: int, excluded_terrain: int) -> int:
	return LOW if state.terrain == excluded_terrain else _stat_sum(state.side(active).monster_zones, state.terrain)

func _score_attribute_change(row: Array, required: int, excluded: int) -> int:
	var required_found := false
	for slot in row:
		var card := card_database.get_card(slot.card_id) if card_database != null else null
		if card == null: continue
		if card.attribute == excluded: return LOW
		required_found = required_found or card.attribute == required
	return _choice(required_found, 0x7EF2D575)

func _has_high_stage_flag(row: Array) -> int:
	for slot in row:
		if not slot.is_empty() and (slot.stage & 0x80) != 0: return 0x7FF55174
	return LOW

func _score_terrain_six_case(state: SacredDuelState, own_monsters: Array) -> int:
	if state.terrain == 6:
		var qualifying_empty := false
		for slot in own_monsters:
			if slot.is_empty() and (slot.persistent_flags & 0x10) != 0:
				qualifying_empty = true
				break
		if not qualifying_empty: return LOW
	return _stat_sum(own_monsters, state.terrain)

func _score_input_column_damage(state: SacredDuelState, active: int, candidate: Dictionary) -> int:
	var operands: Array = candidate.get("operands", [])
	if operands.size() < 2: return LOW
	var input_column := int(operands[1]) & 15
	var own := state.side(active).monster_zones
	var available := false
	for index in range(own.size()):
		var slot: DuelCardSlot = own[index]
		if index != input_column and not slot.is_empty() and slot.card_id != 89 and (slot.persistent_flags & 1) == 0:
			available = true
			break
	if not available: return LOW
	var damage := 0
	for slot in own:
		if not slot.is_empty() and slot.card_id != 89:
			damage = (damage + int(_stats(slot, state.terrain).x)) & MASK
	return 0x7FFFFFF4 if damage < state.side(1 - active).life_points else 0x7FFFFFFF

func _dragon_in_grave(state: SacredDuelState) -> bool:
	return state.relative_graveyard_ids.has(865) or state.relative_graveyard_ids.has(35)

func _score_opposing_target(state: SacredDuelState, opposing_row: Array, priority: int) -> int:
	return _choice(_count_empty_or_immune(opposing_row) != 5, priority)

func _count_empty_or_immune(row: Array) -> int:
	var total := 0
	for slot in row:
		if slot.is_empty() or slot.card_id in SacredDuelState.EFFECT_IMMUNE_CARD_IDS: total += 1
	return total

func _score_attack_damage(state: SacredDuelState, active: int, candidate: Dictionary, priority: int) -> int:
	var source := _candidate_slot(state, active, candidate, 0)
	if source == null: return LOW
	return priority if _stats(source, state.terrain).x < state.side(1 - active).life_points else 0x7FFFFFFF

func _score_handler_family(id: int, priority: int, state: SacredDuelState, active: int, candidate: Dictionary, score: int) -> int:
	var own := state.side(active).monster_zones
	var enemy := state.side(1 - active).monster_zones
	match id:
		77: return _choice(_count_card(own, 161) > 0, priority)
		79: return _choice(_empty(enemy) != 5, priority)
		81: return 0x7FFFFFFF if state.side(1 - active).life_points <= 50 else 0x7EEB5B57
		85, 90, 94: return _choice(_empty(own) > 0, priority)
		96: return _choice(_empty(enemy) != 5, priority)
		97: return _score_attribute_change(own, 2, 1)
		99: return _score_attack_damage(state, active, candidate, priority)
		100: return _choice(_count_metadata(own, 0x16, 10, true, false) + _count_type(enemy, 10) > 0, priority)
		101: return 0x7FFFFFFF if state.side(1 - active).life_points <= 4000 else 0x7FF99747
		106: return _choice(_count_card(own, 757) > 0 and _count_card(own, 850) > 0, priority)
		107: return _choice(_count_card(own, 738) > 0 and _count_card(own, 850) > 0, priority)
		108: return _choice(_count_card(own, 738) > 0 and _count_card(own, 757) > 0, priority)
		109: return _choice(_empty(own) >= 2, priority)
		_:
			if score == LOW: return LOW
			return _choice(score < _stat_sum(own, state.terrain), priority)
	return LOW

func _score_strongest_comparison(state: SacredDuelState, active: int, candidate: Dictionary) -> int:
	var row := state.side(1 - active).monster_zones
	if _count_empty_or_immune(row) == 5: return LOW
	var strongest: DuelCardSlot = row[0]
	var strongest_attack := -1
	for slot in row:
		if slot.is_empty() or state.is_effect_immune(slot.card_id): continue
		var attack := int(_stats(slot, state.terrain).x)
		if attack >= strongest_attack:
			strongest_attack = attack
			strongest = slot
	if (strongest.persistent_flags & 0x10) != 0:
		var source := _candidate_slot(state, active, candidate, 0)
		if source == null: return LOW
		if _stats(strongest, state.terrain).x <= _stats(source, state.terrain).x: return LOW
	return 0x7FF55179

func _score_strongest_fatal(state: SacredDuelState, active: int) -> int:
	var row := state.side(1 - active).monster_zones
	if _count_empty_or_immune(row) == 5: return LOW
	var best_attack := -1
	for slot in row:
		if slot.is_empty() or (slot.persistent_flags & 0x10) == 0: continue
		best_attack = maxi(best_attack, int(_stats(slot, state.terrain).x))
	if best_attack >= 0 and state.side(1 - active).life_points <= best_attack: return 0x7FFFFFFF
	return 0x7FFFFFF0

func _score_strongest_selected(state: SacredDuelState, active: int, candidate: Dictionary) -> int:
	var cards := state.side(1 - active).hand
	var strongest_id := 0
	var best_attack := -1
	for card_id in cards:
		var card := card_database.get_card(card_id)
		if card == null or card.card_type != 10: continue
		var slot := DuelCardSlot.new()
		slot.card_id = card_id
		var attack := int(_stats(slot, state.terrain).x)
		if attack >= best_attack:
			best_attack = attack
			strongest_id = card_id
	if strongest_id == 0: return LOW
	var source := _candidate_slot(state, active, candidate, 0)
	if source == null: return LOW
	return _choice(_stats(source, state.terrain).x < best_attack, 0x7FB31846)

func _score_opp_damage_gate(state: SacredDuelState, active: int, enemy: Array) -> int:
	if _count_empty_or_immune(enemy) == 5: return LOW
	return 0x7FFFFFFF if state.side(1 - active).life_points <= 500 else 0x7FF77460

func _score_life_comparison(state: SacredDuelState, active: int) -> int:
	var ours := state.side(active).life_points
	var theirs := state.side(1 - active).life_points
	if theirs < ours: return 0x7FFFFFFF
	return _choice(theirs == ours, 0x7FFFFFEC)

func _ritual_score(state: SacredDuelState, active: int, candidate: Dictionary, recipe_id: int, equality_first: bool, equality_second: bool) -> Dictionary:
	if recipe_id < 0 or recipe_id >= ritual_recipes.size(): return {}
	var recipe: Dictionary = ritual_recipes[recipe_id]
	var result_slot := DuelCardSlot.new()
	result_slot.card_id = int(recipe.get("result", 0))
	var result_attack := int(_stats(result_slot, state.terrain).x)
	var first := _candidate_slot(state, active, candidate, 2)
	var second := _candidate_slot(state, active, candidate, 3)
	if first == null or second == null: return {}
	var first_attack := int(_stats(first, state.terrain).x)
	var first_pass := first_attack <= result_attack if equality_first else first_attack < result_attack
	if not first_pass: return {"score": LOW}
	var next_score := (0xFFFE - first_attack) & MASK
	var second_attack := int(_stats(second, state.terrain).x)
	var second_pass := second_attack <= result_attack if equality_second else second_attack < result_attack
	if not second_pass: return {"score": LOW}
	return {"score": (next_score - second_attack + 0x7FF42E91) & MASK}

func _score_three_material_ritual(state: SacredDuelState, active: int) -> int:
	for recipe_id in [29, 28, 27, 5]:
		if recipe_id >= ritual_recipes.size(): continue
		var recipe: Dictionary = ritual_recipes[recipe_id]
		var required: Array[int] = [int(recipe.get("material", 0))]
		var extras: Array = recipe.get("other_materials", [])
		if extras.size() < 2: continue
		required.append(int(extras[0]))
		required.append(int(extras[1]))
		var picked := _pick_material_slots(state.side(active).monster_zones, required)
		if picked.size() != 3: continue
		var result := DuelCardSlot.new()
		result.card_id = int(recipe.get("result", 0))
		var result_attack := int(_stats(result, state.terrain).x)
		var first_attack := int(_stats(state.side(active).monster_zones[picked[1]], state.terrain).x)
		if first_attack >= result_attack: return LOW
		var current := (0xFFFE - first_attack) & MASK
		var second_attack := int(_stats(state.side(active).monster_zones[picked[2]], state.terrain).x)
		return (current - second_attack + 0x7FF42E91) & MASK if second_attack <= result_attack else LOW
	return LOW

func _pick_material_slots(row: Array, materials: Array[int]) -> Array[int]:
	var picked: Array[int] = []
	var used: Array[int] = []
	for required_id in materials:
		var found := -1
		for index in range(row.size()):
			if index in used: continue
			if row[index].card_id == required_id:
				found = index
				break
		if found < 0: return []
		picked.append(found)
		used.append(found)
	return picked

func _count_visible_metadata(row: Array, field: int, value: int) -> int:
	var total := 0
	for slot in row:
		if slot.is_empty() or (slot.persistent_flags & 0x10) == 0: continue
		var card := card_database.get_card(slot.card_id)
		if card == null: continue
		var meta := card.metadata_1a if field == 0x16 else card.attribute if field == 0x17 else card.metadata_1d
		if meta == value: total += 1
	return total

func _stat_sum(row: Array, terrain: int, visible_only: bool = false) -> int:
	var total := 0
	for slot in row:
		if slot.is_empty() or (visible_only and (slot.persistent_flags & 0x10) == 0): continue
		var card := card_database.get_card(slot.card_id)
		if card != null and summon_rules.classify_card(slot.card_id, card_database) == 1:
			var stats := _stats(slot, terrain)
			total = (total + int(stats.x) + int(stats.y)) & MASK
	return total

func _stats(slot: DuelCardSlot, terrain: int) -> Vector2i:
	var card := card_database.get_card(slot.card_id) if card_database != null else null
	if card == null: return Vector2i.ZERO
	var stats := stat_rules.apply_card_modifiers(card.attack, card.defense, card.metadata_1a, card.card_type, terrain, slot.stage)
	return Vector2i(stats.attack, stats.defense)

func _hidden_row(row: Array, priority: int) -> int:
	for slot in row:
		if not slot.is_empty() and (slot.persistent_flags & 0x10) == 0: return priority
	return LOW

func _empty_hand(hand: Array[int]) -> int:
	var occupied := 0
	for card_id in hand:
		if card_id != 0: occupied += 1
	return maxi(0, 5 - occupied)

func _hidden_hand(hand: Array[int], flags: Array[int], priority: int) -> int:
	for index in range(hand.size()):
		if hand[index] == 0: continue
		if index >= flags.size() or (flags[index] & 0x10) == 0: return priority
	return LOW

func _candidate_slot(state: SacredDuelState, active: int, candidate: Dictionary, operand_index: int) -> DuelCardSlot:
	var operands: Array = candidate.get("operands", [])
	if operand_index < 0 or operand_index >= operands.size(): return null
	var packed := int(operands[operand_index])
	var row_id := (packed >> 4) & 15
	var column := packed & 15
	if column >= 5: return null
	var side_id := active if row_id >= 2 else 1 - active
	var side := state.side(side_id)
	match row_id:
		0, 3: return side.back_row_zones[column]
		1, 2: return side.monster_zones[column]
		4:
			var hand_slot := DuelCardSlot.new()
			if column < side.hand.size():
				hand_slot.card_id = side.hand[column]
				if column < side.hand_flags.size(): hand_slot.persistent_flags = side.hand_flags[column]
			return hand_slot
	return null

func _strong_enemy_attack(state: SacredDuelState, active: int) -> int:
	for slot in state.side(1 - active).monster_zones:
		if slot.is_empty() or (slot.persistent_flags & 1) != 0: continue
		if _stats(slot, state.terrain).x >= 1500: return 0x7EED7E3D
	return LOW

func _own_effect_monster(state: SacredDuelState, active: int) -> int:
	for slot in state.side(active).monster_zones:
		if slot.is_empty() or (slot.persistent_flags & 0x10) == 0 or (slot.persistent_flags & 1) != 0: continue
		var card := card_database.get_card(slot.card_id)
		if card != null and card.metadata_1b != 0: return 0x7FFFFFF9
	return LOW

func _candidate_source(candidate: Dictionary) -> int:
	var operands: Array = candidate.get("operands", [])
	if operands.is_empty(): return 0
	var packed := int(operands[0])
	var column := packed & 15
	return column

func _find_slot(state: SacredDuelState, active: int, card_index: int) -> DuelCardSlot:
	if card_index < 0 or card_index >= state.side(active).monster_zones.size(): return null
	return state.side(active).monster_zones[card_index]
