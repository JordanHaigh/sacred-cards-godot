extends RefCounted
class_name SaveStorage

## Portable dual-copy save storage. This keeps the recovered primary/backup
## intent while using atomic user:// files instead of SRAM addresses.

const PRIMARY_PATH := "user://sacred_cards_primary.json"
const BACKUP_PATH := "user://sacred_cards_backup.json"
const TEMP_PATH := "user://sacred_cards_write.tmp"
const COMMIT_STATE_PATH := "user://sacred_cards_commit_state.txt"
const RECOVERY_OUTCOMES := [0, 3, 2, 1, 0, 3, 0, 3, 0, 0, 2, 2]

func save_game(save_data: PlayerSaveData) -> Error:
	var record := _make_record(save_data)
	var encoded := JSON.stringify(record)
	var error := _write_commit_state(1)
	if error != OK: return error
	error = _write_atomic(PRIMARY_PATH, encoded)
	if error != OK: return error
	error = _write_commit_state(2)
	if error != OK: return error
	error = _write_atomic(BACKUP_PATH, encoded)
	if error != OK: return error
	return _write_commit_state(0)

func load_game() -> Dictionary:
	var primary := _read_record(PRIMARY_PATH)
	var backup := _read_record(BACKUP_PATH)
	var commit_state := _read_commit_state()
	if commit_state < 0 or commit_state >= 3:
		return {"found": false, "recovered": false, "data": null}
	var primary_valid := bool(primary.get("valid", false))
	var backup_valid := bool(backup.get("valid", false))
	var outcome_index := (commit_state << 2) | (int(primary_valid) << 1) | int(backup_valid)
	var recovery_state := int(RECOVERY_OUTCOMES[outcome_index])
	match recovery_state:
		1:
			return {"found": true, "recovered": false, "data": PlayerSaveData.from_dictionary(primary.data)}
		2:
			if not primary_valid: return {"found": false, "recovered": false, "data": null}
			_write_commit_state(2)
			_write_atomic(BACKUP_PATH, JSON.stringify(primary.envelope))
			_write_commit_state(0)
			return {"found": true, "recovered": true, "data": PlayerSaveData.from_dictionary(primary.data)}
		3:
			if not backup_valid: return {"found": false, "recovered": false, "data": null}
			_write_commit_state(1)
			_write_atomic(PRIMARY_PATH, JSON.stringify(backup.envelope))
			_write_commit_state(0)
			return {"found": true, "recovered": true, "data": PlayerSaveData.from_dictionary(backup.data)}
	return {"found": false, "recovered": false, "data": null}

func clear_saves() -> void:
	for path in [PRIMARY_PATH, BACKUP_PATH, TEMP_PATH, COMMIT_STATE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _make_record(save_data: PlayerSaveData) -> Dictionary:
	var payload := JSON.stringify(save_data.to_dictionary())
	return {"checksum": _checksum(payload), "payload": payload}

func _read_record(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"valid": false}
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not envelope is Dictionary or not envelope.get("payload", "") is String:
		return {"valid": false}
	var payload: String = envelope.payload
	if str(envelope.get("checksum", "")) != _checksum(payload):
		return {"valid": false}
	var data: Variant = JSON.parse_string(payload)
	if not data is Dictionary or int(data.get("version", 0)) != 1:
		return {"valid": false}
	return {"valid": true, "data": data, "envelope": envelope}

func _write_atomic(path: String, content: String) -> Error:
	var absolute_temp := ProjectSettings.globalize_path(TEMP_PATH)
	var absolute_target := ProjectSettings.globalize_path(path)
	var last_error: Error = ERR_CANT_CREATE
	for _attempt in range(3):
		var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
		if file == null:
			last_error = FileAccess.get_open_error()
			continue
		file.store_string(content)
		file.flush()
		last_error = file.get_error()
		file.close()
		if last_error != OK: continue
		if FileAccess.file_exists(path):
			last_error = DirAccess.remove_absolute(absolute_target)
			if last_error != OK: continue
		last_error = DirAccess.rename_absolute(absolute_temp, absolute_target)
		if last_error != OK: continue
		if FileAccess.file_exists(path) and FileAccess.get_file_as_string(path) == content:
			return OK
		last_error = ERR_FILE_CORRUPT
	return last_error

func _write_commit_state(state: int) -> Error:
	return _write_atomic(COMMIT_STATE_PATH, str(state))

func _read_commit_state() -> int:
	if not FileAccess.file_exists(COMMIT_STATE_PATH):
		return 0
	var value := FileAccess.get_file_as_string(COMMIT_STATE_PATH).strip_edges()
	if not value.is_valid_int():
		return -1
	return int(value)

func _checksum(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()
