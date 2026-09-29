extends RefCounted
class_name TrapEffectRules

## Typed rules port of trap_effects.c. Inputs identify value-owned duel slots
## by side and coordinates; no byte offsets or cell pointers are exposed.

const DAMAGE_SPELLS := [14, 15, 16, 17, 18]
const HEALING_SPELLS := [9, 10, 11, 12, 13]
const EQUIPMENT_SPELLS := [21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 77, 78, 79, 80, 98, 100, 118]
const RAIGEKI_SPELLS := [20]
const ATTACK_LIMITS := {2: 500, 3: 1000, 4: 1500, 5: 2000, 6: 3000}
const IMMUNE_FLAG := 0x10
const LOCK_FLAG := 0x01
const PRESENTATION_FLAG := 0x10

var card_database: CardDatabase
var stat_rules: CardStatRules
var battle_state: SacredBattleState

func _init(database: CardDatabase = null, stats: CardStatRules = null) -> void:
	card_database = database
	stat_rules = stats if stats != null else CardStatRules.new()
	battle_state = SacredBattleState.new()

func can_activate(trap_card_id: int, trigger_card_id: int, trigger_slot: DuelCardSlot, terrain: int) -> Dictionary:
	var trap := _card(trap_card_id)
	var trigger := _card(trigger_card_id)
	if trap == null or trigger == null or trigger_slot == null:
		return {"can_activate": false, "kind": 0}
	var kind := trap.metadata_1c
	var is_monster := trigger.frame_type <= 2
	if kind == 1 or kind in [12, 13, 14]:
		return {"can_activate": is_monster, "kind": kind if is_monster else 0}
	if ATTACK_LIMITS.has(kind):
		if not is_monster:
			return {"can_activate": false, "kind": 0}
		var stats := stat_rules.apply_card_modifiers(trigger.attack, trigger.defense, trigger.metadata_1a, trigger.card_type, terrain, trigger_slot.stage)
		return {"can_activate": int(stats.attack) <= int(ATTACK_LIMITS[kind]), "kind": kind if int(stats.attack) <= int(ATTACK_LIMITS[kind]) else 0}
	var accepted: Array = []
	var require_spell := true
	match kind:
		7: accepted = DAMAGE_SPELLS
		8: accepted = HEALING_SPELLS
		9:
			accepted = EQUIPMENT_SPELLS
			require_spell = false
		11: accepted = RAIGEKI_SPELLS
		_: return {"can_activate": false, "kind": 0}
	if require_spell and trigger.frame_type != 3:
		return {"can_activate": false, "kind": 0}
	var matched := trigger.metadata_1a in accepted
	return {"can_activate": matched, "kind": kind if matched else 0}

## Finds the first eligible trap from left to right, matching the native priority.
## trap_side and trigger coordinates are explicit because Godot state has no global board pointer.
func find_activating_trap(state: SacredDuelState, trap_side: int, trigger_side: int, trigger_row: int, trigger_column: int) -> Dictionary:
	var trigger_slot := _slot(state, trigger_side, trigger_row, trigger_column)
	if trigger_slot == null or trigger_slot.is_empty():
		return {"found": false, "slot": 4, "kind": 0}
	for slot_index in range(5):
		var trap_slot := _slot(state, trap_side, 3, slot_index)
		if trap_slot == null or trap_slot.is_empty():
			continue
		var outcome := can_activate(trap_slot.card_id, trigger_slot.card_id, trigger_slot, state.terrain)
		if outcome.can_activate:
			return {"found": true, "slot": slot_index, "kind": int(outcome.kind), "trap_card_id": trap_slot.card_id}
	return {"found": false, "slot": 4, "kind": 0}

## Value-state portion of trap activation. The caller can connect presentation and
## battle-number services through the returned result without changing rule behavior.
func activate(state: SacredDuelState, trap_side: int, trap_column: int, trigger_side: int, trigger_row: int, trigger_column: int, kind: int, amount: int = 0) -> Dictionary:
	var trap_slot := _slot(state, trap_side, 3, trap_column)
	var trigger_slot := _slot(state, trigger_side, trigger_row, trigger_column)
	if trap_slot == null or trigger_slot == null or trap_slot.is_empty():
		return {"activated": false}
	var trap_id := trap_slot.card_id
	var trigger_id := trigger_slot.card_id
	var result := {"activated": true, "trap_card_id": trap_id, "trigger_card_id": trigger_id, "kind": kind, "presentation": []}
	match kind:
		1, 2, 3, 4, 5, 6:
			_discard(state, trap_side, 3, trap_column)
			if not state.is_effect_immune(trigger_id):
				_discard(state, trigger_side, trigger_row, trigger_column, true)
				result.presentation = [trap_id, trigger_id, 76]
			else:
				trigger_slot.persistent_flags |= IMMUNE_FLAG
				result.presentation = [trap_id, trigger_id, "immune"]
		7, 8:
			var acting := state.active_side
			result["battle"] = _reflect_life_points(state, acting, amount)
			_discard(state, trap_side, 3, trap_column)
			_discard(state, trigger_side, trigger_row, trigger_column)
			result.presentation = [trap_id, trigger_id, 77]
		9:
			_discard(state, trap_side, 3, trap_column)
			_discard(state, trigger_side, trigger_row, trigger_column)
			result.presentation = [trap_id, trigger_id, 74]
		11:
			_destroy_row(state, state.active_side, 2)
			_discard(state, trap_side, 3, trap_column)
			_discard(state, trigger_side, trigger_row, trigger_column)
			result.presentation = [782, 75]
		12:
			var fixed_target := _slot(state, trigger_side, 2, trigger_column)
			if fixed_target != null:
				fixed_target.persistent_flags |= LOCK_FLAG | PRESENTATION_FLAG
			_discard(state, trap_side, 3, trap_column)
			result.presentation = [899, fixed_target.card_id if fixed_target != null else 0, 80]
		13:
			_destroy_row(state, state.active_side, 2)
			_discard(state, trap_side, 3, trap_column)
			result.presentation = [897, 75]
		14:
			var fixed_target := _slot(state, trigger_side, 2, trigger_column)
			if fixed_target != null:
				fixed_target.stage = maxi(-128, fixed_target.stage - 1)
				fixed_target.persistent_flags |= LOCK_FLAG | PRESENTATION_FLAG
			_discard(state, trap_side, 3, trap_column)
			result.presentation = [870, trigger_id, 74]
		_:
			result.activated = false
	return result

func _reflect_life_points(state: SacredDuelState, acting_side: int, amount: int) -> Dictionary:
	var side_a := {"owner": 0, "attack": amount if acting_side == 0 else 0}
	var side_b := {"owner": 1, "attack": amount if acting_side == 1 else 0}
	if acting_side == 0: battle_state.prepare_damage_side_a(amount)
	else: battle_state.prepare_damage_side_b(amount)
	battle_state.resolve(state, side_a, side_b)
	if (battle_state.last_result_flags & 4) != 0: state.auxiliary_flags[0] = 2
	if (battle_state.last_result_flags & 16) != 0: state.auxiliary_flags[1] = 2
	return {"code": battle_state.last_result_code, "flags": battle_state.last_result_flags}

func _destroy_row(state: SacredDuelState, side_id: int, row: int) -> void:
	var side := state.side(side_id)
	if side == null:
		return
	var slots: Array[DuelCardSlot] = side.monster_zones if row == 2 else side.back_row_zones
	for index in range(slots.size()):
		if not slots[index].is_empty() and not state.is_effect_immune(slots[index].card_id):
			state.discard_slot(side_id, row, index, true)

func _discard(state: SacredDuelState, side_id: int, row: int, column: int, is_monster: bool = false) -> void:
	state.discard_slot(side_id, row, column, is_monster)

func _slot(state: SacredDuelState, side_id: int, row: int, column: int) -> DuelCardSlot:
	var side := state.side(side_id)
	if side == null or column < 0 or column >= 5:
		return null
	if row == 2:
		return side.monster_zones[column]
	if row == 3:
		return side.back_row_zones[column]
	return null

func _card(card_id: int) -> CardDefinition:
	return card_database.get_card(card_id) if card_database != null else null
