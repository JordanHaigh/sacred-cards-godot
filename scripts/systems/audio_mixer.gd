extends Node
class_name GodotAudioMixer

## Godot's audio server performs mixing, resampling, stereo routing and output.
## This service only manages native players and a small reusable effect pool.
const PSG_RULES_SCRIPT := preload("res://scripts/systems/audio_psg.gd")
const PSG_SAMPLE_RATE := 44100
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
var psg_pitch_rules: PsgPitchRules
var psg_channels: Array[PsgChannelState] = []
var _psg_stream: AudioStreamGenerator
var _psg_player: AudioStreamPlayer
var _psg_playback: AudioStreamGeneratorPlayback
var _psg_envelope_frame := 0

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
	psg_pitch_rules = PSG_RULES_SCRIPT.new()
	if not psg_pitch_rules.load_tables():
		push_error("Could not load recovered PSG pitch tables.")
	for channel_id in range(1, 5):
		var channel := PsgChannelState.new()
		channel.channel_id = channel_id
		psg_channels.append(channel)
	_psg_stream = AudioStreamGenerator.new()
	_psg_stream.mix_rate = PSG_SAMPLE_RATE
	_psg_stream.buffer_length = 0.12
	_psg_player = _make_player("PsgOscillators", "Music")
	_psg_player.stream = _psg_stream
	_psg_player.play()
	_psg_playback = _psg_player.get_stream_playback() as AudioStreamGeneratorPlayback
	set_physics_process(true)
	set_process(true)

func play_psg_voice(channel_id: int, frequency_hz: float, left_volume: int, right_volume: int, waveform: StringName = &"square", wave_samples: PackedFloat32Array = PackedFloat32Array()) -> bool:
	if channel_id < 1 or channel_id > psg_channels.size() or frequency_hz <= 0.0 or frequency_hz >= PSG_SAMPLE_RATE / 2.0:
		return false
	var channel := psg_channels[channel_id - 1]
	channel.frequency_hz = frequency_hz
	channel.waveform = waveform
	channel.wave_samples = wave_samples.duplicate()
	channel.left_volume = clampi(left_volume, 0, 255)
	channel.right_volume = clampi(right_volume, 0, 255)
	psg_pitch_rules.calculate_envelope_volume(channel)
	channel.gain = 0.0
	channel.phase = 0.0
	channel.noise_lfsr = 0x7FFF
	channel.status_flags = 0x80
	channel.rate_countdown = 0
	channel.release_countdown = 0
	channel.current_envelope_level = 0
	channel.active = true
	return true

func play_psg_note(channel_id: int, key: int, fine: int = 0, volume: float = 1.0, waveform: StringName = &"square") -> bool:
	if psg_pitch_rules == null:
		return false
	if channel_id == 3:
		return false
	var bounded_volume := clampf(volume, 0.0, 1.0)
	var level := roundi(bounded_volume * 255.0)
	var frequency_hz := 440.0 * pow(2.0, float(key - 69) / 12.0)
	var resolved_waveform := &"noise" if channel_id == 4 and waveform == &"square" else waveform
	if channel_id >= 1 and channel_id <= 3:
		var period := psg_pitch_rules.midi_key_frequency(channel_id, key, fine)
		if period < 2048:
			frequency_hz = 131072.0 / float(2048 - period)
	return play_psg_voice(channel_id, frequency_hz, level, level, resolved_waveform)

func stop_psg_voice(channel_id: int) -> void:
	if channel_id < 1 or channel_id > psg_channels.size():
		return
	var channel := psg_channels[channel_id - 1]
	channel.active = false
	channel.status_flags = 0
	channel.gain = 0.0

func release_psg_voice(channel_id: int) -> void:
	if channel_id < 1 or channel_id > psg_channels.size():
		return
	psg_channels[channel_id - 1].status_flags |= 0x40

func _process(_delta: float) -> void:
	if _psg_player == null or not _psg_player.playing:
		return
	if _psg_playback == null:
		_psg_playback = _psg_player.get_stream_playback() as AudioStreamGeneratorPlayback
	if _psg_playback == null:
		return
	var available := _psg_playback.get_frames_available()
	if available <= 0:
		return
	var frames := PackedVector2Array()
	frames.resize(available)
	for frame_index in range(available):
		var left_sample := 0.0
		var right_sample := 0.0
		for channel in psg_channels:
			if not channel.active:
				continue
			var advanced_phase := channel.phase + channel.frequency_hz / float(PSG_SAMPLE_RATE)
			var cycles := int(floor(advanced_phase))
			channel.phase = fposmod(advanced_phase, 1.0)
			var sample := _psg_sample(channel, cycles)
			var amplitude := sample * channel.gain * 0.25
			if (channel.output_mask & 0xF0) != 0:
				left_sample += amplitude
			if (channel.output_mask & 0x0F) != 0:
				right_sample += amplitude
		frames[frame_index] = Vector2(clampf(left_sample, -1.0, 1.0), clampf(right_sample, -1.0, 1.0))
	_psg_playback.push_buffer(frames)

func _psg_sample(channel: PsgChannelState, cycles: int) -> float:
	match channel.waveform:
		&"triangle": return 1.0 - 4.0 * absf(channel.phase - 0.5)
		&"saw": return channel.phase * 2.0 - 1.0
		&"noise":
			for _cycle in range(cycles):
				var feedback := (channel.noise_lfsr ^ (channel.noise_lfsr >> 1)) & 1
				channel.noise_lfsr = (channel.noise_lfsr >> 1) | (feedback << 14)
			return 1.0 if (channel.noise_lfsr & 1) != 0 else -1.0
		&"wave":
			if channel.wave_samples.is_empty(): return 0.0
			var sample_index := mini(int(channel.phase * channel.wave_samples.size()), channel.wave_samples.size() - 1)
			return clampf(channel.wave_samples[sample_index], -1.0, 1.0)
		_: return 1.0 if channel.phase < 0.5 else -1.0

func _physics_process(_delta: float) -> void:
	_psg_envelope_frame = 14 if _psg_envelope_frame == 0 else _psg_envelope_frame - 1
	for channel in psg_channels:
		psg_pitch_rules.tick_channel_envelope(channel, _psg_envelope_frame == 0)
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
