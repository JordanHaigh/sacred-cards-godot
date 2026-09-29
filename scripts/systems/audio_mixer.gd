extends Node
class_name GodotAudioMixer

## Godot's audio server performs mixing, resampling, stereo routing and output.
## This service only manages native players and a small reusable effect pool.
const EFFECT_PLAYER_COUNT := 12

var music_player: AudioStreamPlayer
var effect_music_player: AudioStreamPlayer
var effect_players: Array[AudioStreamPlayer] = []
var _effect_started_at: Array[int] = []
var _music_fade_interval := 0
var _music_fade_countdown := 0
var _music_fade_volume := 256
var _music_fade_base_db := 0.0
var _music_fade_song_id := -1

func _ready() -> void:
	_ensure_bus("Music")
	_ensure_bus("SFX")
	if music_player == null:
		music_player = _make_player("SceneMusic", "Music")
	if effect_music_player == null:
		effect_music_player = _make_player("EffectMusic", "Music")
	while effect_players.size() < EFFECT_PLAYER_COUNT:
		effect_players.append(_make_player("Effect_%02d" % effect_players.size(), "SFX"))
		_effect_started_at.append(0)
	set_physics_process(true)

func _physics_process(_delta: float) -> void:
	if _music_fade_interval <= 0:
		return
	if music_player == null or not music_player.playing or int(music_player.get_meta("song_id", -1)) != _music_fade_song_id:
		_cancel_music_fade(true)
		return
	_music_fade_countdown -= 1
	if _music_fade_countdown > 0:
		return
	_music_fade_countdown = _music_fade_interval
	_music_fade_volume -= 16
	if _music_fade_volume <= 0:
		music_player.stop()
		_cancel_music_fade(true)
		return
	music_player.volume_db = _music_fade_base_db + linear_to_db(float(_music_fade_volume) / 256.0)

func play_music(stream: AudioStream, song_id: int, restart: bool = false) -> void:
	if stream == null or music_player == null: return
	if not restart and music_player.playing and music_player.stream == stream: return
	_cancel_music_fade(true)
	music_player.stream = stream
	music_player.set_meta("song_id", song_id)
	music_player.play()

func play_effect_music(stream: AudioStream, song_id: int, restart: bool = false) -> void:
	if stream == null or effect_music_player == null: return
	if not restart and effect_music_player.playing and effect_music_player.stream == stream: return
	effect_music_player.stream = stream
	effect_music_player.set_meta("song_id", song_id)
	effect_music_player.play()

func play_effect(stream: AudioStream, priority: int = 0) -> void:
	if stream == null or effect_players.is_empty(): return
	var chosen: AudioStreamPlayer
	for index in range(effect_players.size()):
		if not effect_players[index].playing:
			chosen = effect_players[index]
			_effect_started_at[index] = Time.get_ticks_msec()
			break
	if chosen == null:
		var oldest_index := 0
		for index in range(1, _effect_started_at.size()):
			if _effect_started_at[index] < _effect_started_at[oldest_index]: oldest_index = index
		oldest_index = posmod(oldest_index + (1 if priority > 0 else 0), effect_players.size())
		chosen = effect_players[oldest_index]
		_effect_started_at[oldest_index] = Time.get_ticks_msec()
	chosen.stream = stream
	chosen.play()

func fade_music(step_interval: int) -> void:
	if step_interval <= 0 or music_player == null or not music_player.playing: return
	if _music_fade_interval <= 0:
		_music_fade_base_db = music_player.volume_db
	_music_fade_interval = step_interval
	_music_fade_countdown = step_interval
	_music_fade_volume = 256
	_music_fade_song_id = int(music_player.get_meta("song_id", -1))
	music_player.volume_db = _music_fade_base_db

func _cancel_music_fade(restore_volume: bool) -> void:
	if restore_volume and music_player != null and _music_fade_interval > 0:
		music_player.volume_db = _music_fade_base_db
	_music_fade_interval = 0
	_music_fade_countdown = 0
	_music_fade_volume = 256
	_music_fade_song_id = -1

func stop_effect_music() -> void:
	if effect_music_player != null: effect_music_player.stop()

func stop_all() -> void:
	if music_player != null: music_player.stop()
	_cancel_music_fade(true)
	stop_effect_music()
	for player in effect_players: player.stop()

func _make_player(player_name: String, preferred_bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = player_name
	if AudioServer.get_bus_index(preferred_bus) >= 0: player.bus = preferred_bus
	add_child(player)
	return player

func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) >= 0: return
	AudioServer.add_bus()
	var index := AudioServer.get_bus_count() - 1
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")
