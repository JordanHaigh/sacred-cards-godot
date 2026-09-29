extends RefCounted
class_name AiCandidateDatabase

## Typed-access wrapper for the recovered 616-entry AI action table.

const DATA_PATH := "res://resources/ai_candidates.json"
var _candidates: Array[Dictionary] = []

func load_recovered_data() -> Error:
	if not FileAccess.file_exists(DATA_PATH): return ERR_FILE_NOT_FOUND
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not parsed is Dictionary or not parsed.get("candidates", []) is Array: return ERR_PARSE_ERROR
	var rows: Array = parsed.candidates
	if rows.size() != 616: return ERR_INVALID_DATA
	_candidates.clear()
	for row: Variant in rows:
		if not row is Dictionary: return ERR_PARSE_ERROR
		var operands: Array[int] = []
		for packed: Variant in row.get("operands", []): operands.append(int(packed))
		if operands.size() != 6: return ERR_INVALID_DATA
		_candidates.append({
			"id": int(row.get("id", -1)),
			"kind": int(row.get("kind", -1)),
			"name": str(row.get("name", "")),
			"operands": operands,
		})
	return OK

func get_candidate(candidate_id: int) -> Dictionary:
	if candidate_id < 0 or candidate_id >= _candidates.size(): return {}
	return _candidates[candidate_id].duplicate(true)

func get_candidates() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in _candidates: result.append(candidate.duplicate(true))
	return result

func get_candidates_for_kind(action_kind: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for candidate in _candidates:
		if int(candidate.kind) == action_kind: result.append(candidate.duplicate(true))
	return result

func get_candidate_count() -> int:
	return _candidates.size()
