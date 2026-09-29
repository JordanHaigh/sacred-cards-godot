extends Node
class_name GameAudioDispatch

const CATALOG_SCRIPT := preload("res://scripts/systems/audio_sequence.gd")
const PLAYER_SCRIPT := preload("res://scripts/systems/audio_player.gd")
const MIXER_SCRIPT := preload("res://scripts/systems/audio_mixer.gd")
const CATALOG_PATH := "res://resources/audio_catalog.json"

var catalog: AudioSequenceCatalog
var player: GameAudioPlayer
var mixer: GodotAudioMixer
var load_error := ""

func _ready() -> void:
	load_default()

func load_default() -> bool:
	catalog = CATALOG_SCRIPT.new()
	if not catalog.load_default():
		load_error = catalog.load_error
		return false
	mixer = MIXER_SCRIPT.new()
	mixer.name = "GodotAudioMixer"
	add_child(mixer)
	player = PLAYER_SCRIPT.new()
	player.configure(catalog, mixer)
	load_error = ""
	return true

func audio_category(song_id: int) -> int:
	var slot := catalog.get_slot(song_id) if catalog != null else {}
	return int(slot.get("category", 0))

func play_game_audio(song_id: int) -> bool:
	var category := audio_category(song_id)
	if category in [1, 5]: return player.play(song_id, category, false)
	if category in [2, 3]: return player.play(song_id, category, true)
	if category == 4: return player.play(song_id, category, true)
	return false

func play_scene_music(scene_id: int, variant: int) -> int:
	if catalog == null: return -1
	var song_id := catalog.scene_song(scene_id, variant)
	play_game_audio(song_id)
	return song_id

func fade_game_music(step_interval: int) -> void:
	if mixer != null: mixer.fade_music(step_interval)

func play_psg_note(channel_id: int, key: int, fine: int = 0, volume: float = 1.0, waveform: StringName = &"square") -> bool:
	return mixer.play_psg_note(channel_id, key, fine, volume, waveform) if mixer != null else false

func play_psg_voice(channel_id: int, frequency_hz: float, left_volume: int, right_volume: int, waveform: StringName = &"square", wave_samples: PackedFloat32Array = PackedFloat32Array()) -> bool:
	return mixer.play_psg_voice(channel_id, frequency_hz, left_volume, right_volume, waveform, wave_samples) if mixer != null else false

func stop_psg_voice(channel_id: int) -> void:
	if mixer != null: mixer.stop_psg_voice(channel_id)

func release_psg_voice(channel_id: int) -> void:
	if mixer != null: mixer.release_psg_voice(channel_id)

func stop_effect_music_player() -> void:
	if player != null: player.stop_effect_music()

func stop_all() -> void:
	if mixer != null: mixer.stop_all()
