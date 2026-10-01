extends RefCounted
class_name EffectFamilyRules

## Shared data-driven port of effect_families.c. Eligibility and ritual recipes
## are recovered source data; all duel mutations address owned slots by coordinate.

const TABLE_PATH := "res://resources/effect_family_rules.json"

var traps: TrapEffectRules
var _equipment: Dictionary[int, Dictionary] = {}
var _rituals: Dictionary[int, Dictionary] = {}
var _metadata_indices: Array[int] = []

func _init(trap_rules: TrapEffectRules = null) -> void:
	traps = trap_rules
	_load_tables()

func equipment_accepts_card(equipment_card_id: int, target_card_id: int) -> bool:
	var rule: Dictionary = _equipment.get(equipment_card_id, {})
	return bool(rule.get("eligible", {}).get(target_card_id, false))

func supported_metadata_1a() -> Array[int]:
	return _metadata_indices.duplicate()

func handles(effect_card_id: int) -> bool:
	return _equipment.has(effect_card_id) or _rituals.has(effect_card_id)

func resolve_equipment(state: SacredDuelState, acting_side: int, equipment_card_id: int, source_row: int, source_column: int, target_row: int, target_column: int, presentation_suppressed: bool = false) -> Dictionary:
	var target := _slot(state, acting_side, target_row, target_column)
	var source := _slot(state, acting_side, source_row, source_column)
	if target == null or source == null or source.is_empty() or not equipment_accepts_card(equipment_card_id, target.card_id):
		return {"resolved": false, "reason": "incompatible_target"}
	if traps != null:
		var found := traps.find_activating_trap(state, 1 - acting_side, acting_side, source_row, source_column)
		if bool(found.found) and not presentation_suppressed:
			var amount := _lower_stage_register_result(target)
			var trap_result := traps.activate(state, 1 - acting_side, int(found.slot), acting_side, source_row, source_column, int(found.kind), amount)
			return {"resolved": true, "redirected_by_trap": true, "trap": trap_result, "stage": target.stage}
	target.stage = mini(127, target.stage + 1)
	state.discard_slot(acting_side, source_row, source_column, 0)
	return {"resolved": true, "kind": "equipment", "target_card_id": target.card_id, "stage": target.stage, "presentation": [] if presentation_suppressed else [65, equipment_card_id, 73]}

func resolve_ritual(state: SacredDuelState, acting_side: int, ritual_card_id: int, ritual_row: int, ritual_column: int, presentation_suppressed: bool = false) -> Dictionary:
	var recipe: Dictionary = _rituals.get(ritual_card_id, {})
	if recipe.is_empty():
		return {"resolved": false, "reason": "unknown_ritual"}
	var side := state.side(acting_side)
	if side == null:
		return {"resolved": false, "reason": "invalid_side"}
	var material_slot: DuelCardSlot = null
	var material_column := -1
	for index in range(side.monster_zones.size()):
		if side.monster_zones[index].card_id == int(recipe.material):
			material_slot = side.monster_zones[index]
			material_column = index
			break
	if material_slot == null:
		return {"resolved": false, "reason": "material_missing"}
	if _slot(state, acting_side, ritual_row, ritual_column) == null:
		return {"resolved": false, "reason": "ritual_slot_missing"}
	state.discard_slot(acting_side, ritual_row, ritual_column, 0)
	material_slot.card_id = int(recipe.result)
	material_slot.stage = 0
	material_slot.zone_mode = 0
	material_slot.persistent_flags &= 0xC8
	state.tributes_committed = 0
	return {"resolved": true, "kind": "ritual", "material_column": material_column, "result_card_id": material_slot.card_id, "reset_tributes": true, "presentation": [] if presentation_suppressed else [65, ritual_card_id, material_slot.card_id, 83]}

func resolve(state: SacredDuelState, acting_side: int, effect_card_id: int, row: int, column: int, source_row: int = -1, source_column: int = -1, presentation_suppressed: bool = false) -> Dictionary:
	if _equipment.has(effect_card_id):
		if source_row < 0 or source_column < 0:
			return {"resolved": false, "reason": "equipment_source_missing"}
		return resolve_equipment(state, acting_side, effect_card_id, source_row, source_column, row, column, presentation_suppressed)
	if _rituals.has(effect_card_id):
		return resolve_ritual(state, acting_side, effect_card_id, row, column, presentation_suppressed)
	return {"resolved": false, "reason": "unsupported_effect_family"}

func _load_tables() -> void:
	if not FileAccess.file_exists(TABLE_PATH):
		push_error("Missing recovered effect family table: %s" % TABLE_PATH)
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if not parsed is Dictionary:
		push_error("Invalid recovered effect family table: %s" % TABLE_PATH)
		return
	for record: Variant in parsed.get("equipment", []):
		if not record is Dictionary:
			continue
		var eligible: Dictionary[int, bool] = {}
		for card_id: Variant in record.get("eligible_card_ids", []):
			eligible[int(card_id)] = true
		var equipment_card_id := int(record.get("card_id", 0))
		_equipment[equipment_card_id] = {"eligible": eligible, "metadata_1a": int(record.get("metadata_1a", -1))}
		_register_metadata_index(int(record.get("metadata_1a", -1)))
	for recipe: Variant in parsed.get("simple_rituals", []):
		if recipe is Dictionary:
			var ritual_card_id := int(recipe.get("card_id", 0))
			_rituals[ritual_card_id] = recipe
			_register_metadata_index(int(recipe.get("metadata_1a", -1)))

func _register_metadata_index(index: int) -> void:
	if index >= 0 and index not in _metadata_indices:
		_metadata_indices.append(index)

func _lower_stage_register_result(slot: DuelCardSlot) -> int:
	var old_byte := slot.stage & 0xFF
	var next_byte := old_byte if old_byte == 128 else (old_byte - 1) & 0xFF
	slot.stage = next_byte if next_byte < 128 else next_byte - 256
	return 0xFF80 if old_byte == 128 else (old_byte - 1) & 0xFFFF

func _slot(state: SacredDuelState, side_id: int, row: int, column: int) -> DuelCardSlot:
	return state.relative_board_slot(side_id, row, column) if state != null else null
