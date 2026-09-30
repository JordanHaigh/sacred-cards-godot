extends RefCounted
class_name AiTurn

## Candidate simulation and execution loop from ai_turn.c. GDScript data copies
## replace the scratch-RAM snapshot and restoration routines.

signal candidate_selected(candidate_id: int, action_kind: int, score: int)
signal action_starting(candidate_id: int, action_kind: int)
signal action_completed(candidate_id: int, action_kind: int, result: Dictionary)
signal action_presentation_requested(candidate_id: int, action_kind: int, result: Dictionary)
signal action_presentation_finished
signal turn_completed(report: Dictionary)

var candidates: AiCandidateDatabase
var validation: AiValidation
var scoring: AiScoring
var actions: AiActions
var special_wins: DuelSpecialWins
var attack_tags: AiAttackTagDatabase
var _presentation_pending := false

func _init(candidate_database: AiCandidateDatabase = null, validator: AiValidation = null, scorer: AiScoring = null, executor: AiActions = null, wins: DuelSpecialWins = null, tag_database: AiAttackTagDatabase = null) -> void:
	candidates = candidate_database
	validation = validator
	scoring = scorer
	actions = executor
	special_wins = wins if wins != null else DuelSpecialWins.new()
	attack_tags = tag_database

func complete_action_presentation() -> void:
	if not _presentation_pending:
		return
	_presentation_pending = false
	action_presentation_finished.emit()

## Evaluates the full candidate table on independent state copies, then executes
## the top result. Like the C controller, it keeps selecting actions until no
## positive candidate remains or the duel ends. Callers may supply a limit for
## bounded simulations; the default preserves the native unbounded loop.
func run_opponent_turn(state: SacredDuelState, acting_side: int, random_service: SacredRandom = null, max_actions: int = -1, opponent_id: int = -1) -> Dictionary:
	if state == null or acting_side < 0 or acting_side > 1 or state.active_side != acting_side:
		return {"completed": false, "reason": "invalid_context", "actions": []}
	if candidates == null or validation == null or scoring == null or actions == null:
		return {"completed": false, "reason": "ai_services_missing", "actions": []}
	actions.set_random_service(random_service)
	var report := {"completed": false, "actions": [], "candidate_scans": 0, "unsupported_scores": 0, "stop_reason": "no_candidate"}
	var stopped_early := false
	var action_index := 0
	while max_actions < 0 or action_index < max_actions:
		if state.has_ended():
			report.stop_reason = "duel_ended"
			stopped_early = true
			break
		var scored: Array[Dictionary] = []
		for candidate in candidates.get_candidates():
			report.candidate_scans = int(report.candidate_scans) + 1
			var valid := validation.validate_candidate(state, acting_side, candidate)
			if not bool(valid.get("valid", false)):
				continue
			var before := scoring.score_before(state, acting_side, candidate)
			if not bool(before.get("resolved", false)):
				report.unsupported_scores = int(report.unsupported_scores) + 1
				continue
			var simulation := state.duplicate_state()
			var simulated_action := actions.execute(simulation, acting_side, candidate, true)
			if not bool(simulated_action.get("resolved", false)):
				continue
			var after := scoring.score_after(simulation, acting_side, candidate, int(before.get("score", 0)))
			if not bool(after.get("resolved", false)):
				report.unsupported_scores = int(report.unsupported_scores) + 1
				continue
			var score_entry := candidate.duplicate(true)
			score_entry["score"] = int(after.get("score", 0))
			scored.append(score_entry)
		var selected := scoring.best_candidate(scored)
		if selected.is_empty():
			report.stop_reason = "no_candidate"
			stopped_early = true
			break
		_before_action_presentation(state, acting_side, selected, opponent_id)
		candidate_selected.emit(int(selected.id), int(selected.kind), int(selected.score))
		action_starting.emit(int(selected.id), int(selected.kind))
		var execution := actions.execute(state, acting_side, selected, false)
		if not bool(execution.get("resolved", false)):
			report.stop_reason = "execution_failed"
			report["failure"] = execution
			stopped_early = true
			break
		var action_record := {
			"candidate_id": int(selected.id),
			"action_kind": int(selected.kind),
			"score": int(selected.score),
			"result": execution,
		}
		var completed_actions: Array = report.actions
		completed_actions.append(action_record)
		report.actions = completed_actions
		action_completed.emit(int(selected.id), int(selected.kind), execution)
		if not action_presentation_requested.get_connections().is_empty():
			_presentation_pending = true
			action_presentation_requested.emit(int(selected.id), int(selected.kind), execution)
			await action_presentation_finished
		if special_wins != null:
			special_wins.check_destiny_board(state, acting_side)
			special_wins.check_exodia(state, acting_side)
		action_index += 1
		if state.has_ended():
			report.stop_reason = "duel_ended"
			stopped_early = true
			break
	if not stopped_early:
		report.stop_reason = "action_limit"
	# ai_turn.c waits one frame 30 times after the final candidate/action. Keep
	# this cadence in Godot so the opponent turn does not transition early.
	var scene_tree := Engine.get_main_loop() as SceneTree
	if scene_tree != null:
		report["tail_frames"] = 30
		for _frame in range(30):
			await scene_tree.process_frame
	report.completed = true
	turn_completed.emit(report)
	return report

func _before_action_presentation(state: SacredDuelState, acting_side: int, candidate: Dictionary, opponent_id: int) -> void:
	var action_kind := int(candidate.get("kind", -1))
	if action_kind not in [7, 8, 9, 10, 12, 13] or attack_tags == null:
		return
	var operands: Array = candidate.get("operands", [])
	if operands.is_empty():
		return
	var attacker: DuelCardSlot = actions._slot(state, acting_side, int(operands[0]))
	if attacker != null:
		# The native lookup stores this tag in a local record that is not consumed.
		attack_tags.find_attack_tag(opponent_id, attacker.card_id)
