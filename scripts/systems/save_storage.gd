extends RefCounted
class_name SaveStorage

## Portable dual-copy save storage. This keeps the recovered primary/backup
## intent while using atomic user:// files instead of SRAM addresses.

const PRIMARY_PATH := "user://sacred_cards_primary.json"
const BACKUP_PATH := "user://sacred_cards_backup.json"
const TEMP_PATH := "user://sacred_cards_write.tmp"
const COMMIT_STATE_PATH := "user://sacred_cards_commit_state.txt"
const SAVE_SIGNATURE := "020322_DM7_KCEJ"
const RECOVERY_OUTCOMES := [0, 3, 2, 1, 0, 3, 0, 3, 0, 0, 2, 2]
const NEW_GAME_SCRIPT := preload("res://scripts/systems/new_game_state.gd")

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

## Equivalent of DetectSaveState: 0 invalid/new, 1 ready, 2 repair backup,
## 3 repair primary. Validation reads both copies before selecting an outcome.
func detect_save_state() -> int:
	var primary := _read_record(PRIMARY_PATH)
	var backup := _read_record(BACKUP_PATH)
	var commit_state := _read_commit_state()
	if commit_state < 0 or commit_state >= 3:
		return 0
	var index := (commit_state << 2) | (int(bool(primary.get("valid", false))) << 1) | int(bool(backup.get("valid", false)))
	return int(RECOVERY_OUTCOMES[index])

## Equivalent of PrepareSaveState. Invalid storage is initialized from the
## caller's save model (or the recovered new-game defaults).
func prepare_save_state(state: int, save_data: PlayerSaveData = null) -> Error:
	match state & 0xFF:
		1:
			return OK
		2:
			return _repair_copy(true)
		3:
			return _repair_copy(false)
		_:
			return initialize_save_storage(save_data)

func repair_interrupted_save() -> Error:
	match detect_save_state():
		2:
			return _repair_copy(true)
		3:
			return _repair_copy(false)
	return OK

## The native initializer clears SRAM, initializes new-game state, writes both
## verified copies, and commits the signature last. Atomic files replace SRAM.
func initialize_save_storage(save_data: PlayerSaveData = null) -> Error:
	clear_saves()
	var initial_save := save_data if save_data != null else NEW_GAME_SCRIPT.initialize()
	return save_game(initial_save)

func clear_saves() -> void:
	for path in [PRIMARY_PATH, BACKUP_PATH, TEMP_PATH, COMMIT_STATE_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _make_record(save_data: PlayerSaveData) -> Dictionary:
	var payload := JSON.stringify(save_data.to_dictionary())
	var native_payload := SavePayloadAdapter.pack_save(save_data)
	return {
		"signature": SAVE_SIGNATURE,
		"checksum": _checksum(payload),
		"payload": payload,
		"native_payload": Array(native_payload),
		"native_checksum": SavePayloadCodec.checksum(native_payload),
	}

func _read_record(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"valid": false}
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not envelope is Dictionary or not envelope.get("payload", "") is String:
		return {"valid": false}
	if envelope.has("signature") and str(envelope.signature) != SAVE_SIGNATURE:
		return {"valid": false}
	var payload: String = envelope.payload
	if str(envelope.get("checksum", "")) != _checksum(payload):
		return {"valid": false}
	if envelope.has("native_payload") or envelope.has("native_checksum"):
		var native_bytes: Variant = envelope.get("native_payload", null)
		if not native_bytes is Array or native_bytes.size() != SavePayloadCodec.PAYLOAD_SIZE:
			return {"valid": false}
		var native_payload := PackedByteArray()
		native_payload.resize(native_bytes.size())
		for index in range(native_bytes.size()):
			var value := int(native_bytes[index])
			if value < 0 or value > 255:
				return {"valid": false}
			native_payload[index] = value
		if int(envelope.get("native_checksum", -1)) != SavePayloadCodec.checksum(native_payload):
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

func _repair_copy(repair_backup: bool) -> Error:
	var source_path := PRIMARY_PATH if repair_backup else BACKUP_PATH
	var target_path := BACKUP_PATH if repair_backup else PRIMARY_PATH
	var source := _read_record(source_path)
	if not bool(source.get("valid", false)):
		return ERR_FILE_CORRUPT
	var state := 2 if repair_backup else 1
	var error := _write_commit_state(state)
	if error != OK:
		return error
	error = _write_atomic(target_path, JSON.stringify(source.envelope))
	if error != OK:
		return error
	return _write_commit_state(0)

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
