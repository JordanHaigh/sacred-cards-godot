extends RefCounted
class_name GameAudioPlayer

## Routes recovered song IDs through the same fixed player slots as native M4A.
var catalog: AudioSequenceCatalog
var mixer: GodotAudioMixer
var resource_cache: Dictionary[int, AudioStream] = {}

func configure(sequence_catalog: AudioSequenceCatalog, godot_mixer: GodotAudioMixer) -> void:
	catalog = sequence_catalog
	mixer = godot_mixer

func play(song_id: int, category: int, restart: bool = false) -> bool:
	if catalog == null or mixer == null: return false
	var slot := catalog.get_slot(song_id)
	if slot.is_empty(): return false
	if category == 4:
		mixer.stop_native_music()
		return true
	var stream := _stream_for(song_id, slot)
	if stream == null: return false
	match category:
		1: mixer.play_music(stream, song_id, restart)
		2, 3, 5:
			var native_player := int(slot.get("native_player", -1))
			if native_player < 1 or native_player > 10: return false
			var restart_song := true if category == 2 or category == 3 else restart
			mixer.play_native_secondary(
				stream,
				song_id,
				category,
				int(slot.get("priority", 0)),
				native_player,
				int(slot.get("player_track_capacity", 1)),
				bool(slot.get("priority_enabled", false)),
				restart_song
			)
		_: return false
	return true

func stop_effect_music() -> void:
	if mixer != null: mixer.stop_effect_music()

func _stream_for(song_id: int, slot: Dictionary) -> AudioStream:
	if resource_cache.has(song_id): return resource_cache[song_id]
	var stream_path := String(slot.get("stream", ""))
	if stream_path.is_empty() or not ResourceLoader.exists(stream_path): return null
	var stream := load(stream_path) as AudioStream
	if stream != null: resource_cache[song_id] = stream
	return stream
