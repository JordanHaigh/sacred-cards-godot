extends RefCounted
class_name SaveStorage

## Portable dual-copy save storage. This keeps the recovered primary/backup
## intent while using atomic user:// files instead of SRAM addresses.

const PRIMARY_PATH := "user://sacred_cards_primary.json"
const BACKUP_PATH := "user://sacred_cards_backup.json"
const TEMP_PATH := "user://sacred_cards_write.tmp"

func save_game(save_data: PlayerSaveData) -> Error:
	var record := _make_record(save_data)
	var encoded := JSON.stringify(record)
	var primary_error := _write_atomic(PRIMARY_PATH, encoded)
	if primary_error != OK:
		return primary_error
	return _write_atomic(BACKUP_PATH, encoded)

func load_game() -> Dictionary:
	var primary := _read_record(PRIMARY_PATH)
	if primary.get("valid", false):
		return {"found": true, "recovered": false, "data": PlayerSaveData.from_dictionary(primary.data)}
	var backup := _read_record(BACKUP_PATH)
	if backup.get("valid", false):
		var repaired_data := PlayerSaveData.from_dictionary(backup.data)
		_write_atomic(PRIMARY_PATH, JSON.stringify(_make_record(repaired_data)))
		return {"found": true, "recovered": true, "data": repaired_data}
	return {"found": false, "recovered": false, "data": null}

func clear_saves() -> void:
	for path in [PRIMARY_PATH, BACKUP_PATH, TEMP_PATH]:
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
	return {"valid": true, "data": data}

func _write_atomic(path: String, content: String) -> Error:
	var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(content)
	file.flush()
	file.close()
	var absolute_temp := ProjectSettings.globalize_path(TEMP_PATH)
	var absolute_target := ProjectSettings.globalize_path(path)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(absolute_target)
	return DirAccess.rename_absolute(absolute_temp, absolute_target)

func _checksum(value: String) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(value.to_utf8_buffer())
	return context.finish().hex_encode()
