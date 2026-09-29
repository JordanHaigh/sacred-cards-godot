extends RefCounted
class_name AudioSequenceCatalog

## The recovered M4A bytecode and instrument banks are converted during the
## asset pipeline to complete Godot streams. Runtime playback never follows
## bank pointers or decodes addresses; it resolves a stable song/effect ID.
const RESOURCE_PATH := "res://resources/audio_catalog.json"
const PLAYER_ROUTING_PATH := "res://resources/audio_player_routing.json"
var slots: Array[Dictionary] = []
var scene_music: Array[int] = []
var scene_overrides: Array[Dictionary] = []
var song_players: Array[int] = []
var player_track_capacities: Array[int] = []
var player_priority_enabled: Array[bool] = []
var load_error := ""

func load_default() -> bool:
	return load_json(RESOURCE_PATH)

func load_json(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		load_error = "Unable to open audio catalog: %s" % path
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not parsed.get("slots", []) is Array:
		load_error = "Audio catalog has an invalid structure."
		return false
	slots.clear()
	scene_music.clear()
	scene_overrides.clear()
	for raw_slot: Variant in parsed.slots:
		if raw_slot is Dictionary: slots.append(raw_slot)
	for song_id: Variant in parsed.get("scene_music", []): scene_music.append(int(song_id))
	for row: Variant in parsed.get("scene_music_overrides", []):
		if row is Dictionary: scene_overrides.append(row)
	if not _load_player_routing():
		return false
	load_error = ""
	return slots.size() == 225 and scene_music.size() == 58

func get_slot(song_id: int) -> Dictionary:
	if song_id < 0 or song_id >= slots.size(): return {}
	if song_id >= song_players.size(): return {}
	var slot := slots[song_id].duplicate()
	var player_index := song_players[song_id]
	if player_index < 0 or player_index >= player_track_capacities.size(): return {}
	slot["native_player"] = player_index
	slot["player_track_capacity"] = player_track_capacities[player_index]
	slot["priority_enabled"] = player_priority_enabled[player_index]
	return slot

func _load_player_routing() -> bool:
	var file := FileAccess.open(PLAYER_ROUTING_PATH, FileAccess.READ)
	if file == null:
		load_error = "Unable to open audio player routing: %s" % PLAYER_ROUTING_PATH
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		load_error = "Audio player routing has an invalid structure."
		return false
	var raw_song_players: Variant = parsed.get("song_players", [])
	var raw_capacities: Variant = parsed.get("player_track_capacities", [])
	var raw_priority: Variant = parsed.get("player_priority_enabled", [])
	if not raw_song_players is Array or not raw_capacities is Array or not raw_priority is Array:
		load_error = "Audio player routing is missing its player tables."
		return false
	song_players.clear()
	player_track_capacities.clear()
	player_priority_enabled.clear()
	for player_index: Variant in raw_song_players: song_players.append(int(player_index))
	for capacity: Variant in raw_capacities: player_track_capacities.append(int(capacity))
	for enabled: Variant in raw_priority: player_priority_enabled.append(bool(enabled))
	if song_players.size() != 225 or player_track_capacities.size() != 11 or player_priority_enabled.size() != 11:
		load_error = "Audio player routing table sizes do not match recovered M4A data."
		return false
	return true

func scene_song(scene_id: int, variant: int) -> int:
	for row in scene_overrides:
		if int(row.get("scene", -1)) == scene_id and int(row.get("variant", -1)) == variant:
			return int(row.get("song_id", 0))
	return scene_music[scene_id] if scene_id >= 0 and scene_id < scene_music.size() else -1
