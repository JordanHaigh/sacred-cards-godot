extends RefCounted
class_name PsgPitchRules

## Portable pitch conversion helpers retained for dynamic PSG tones. GBA
## oscillator/register writes are delegated to AudioStream generation/player.
const TABLE_PATH := "res://resources/audio_pitch_tables.json"
var tables: Dictionary = {}

func load_tables() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(TABLE_PATH))
	if not parsed is Dictionary: return false
	tables = parsed
	return true

func midi_key_frequency(channel: int, key: int, fine: int) -> int:
	if tables.is_empty() and not load_tables(): return 0
	var noise: Array = tables.gPsgNoiseFrequencies
	var key_scale: Array = tables.gPsgKeyScale
	var pitch_table: Array = tables.gPsgPitchTable
	var channel_byte := channel & 0xff
	var adjusted_key := key & 0xff
	var interpolation := fine & 0xff
	if channel_byte == 4:
		return int(noise[clampi(adjusted_key - 21, 0, 59)])
	if adjusted_key < 36:
		adjusted_key = 36
		interpolation = 0
	var index := adjusted_key - 36
	if index > 130:
		index = 130
		interpolation = 255
	var first := int(key_scale[index])
	var second := int(key_scale[index + 1])
	var low := int(pitch_table[first & 15]) >> (first >> 4)
	var high := int(pitch_table[second & 15]) >> (second >> 4)
	return low + (((high - low) * interpolation) >> 8) + 2048

func psg_noise_frequency(key: int) -> int:
	return midi_key_frequency(4, key, 0)

## Decodes the four little-endian words copied to the native 16-byte wave RAM.
## Each byte contains two unsigned four-bit samples, low nibble first.
func unpack_wave_words(words: Array[int]) -> PackedFloat32Array:
	if words.size() != 4:
		return PackedFloat32Array()
	var samples := PackedFloat32Array()
	samples.resize(32)
	var sample_index := 0
	for word in words:
		var packed_word := word & 0xffffffff
		for byte_index in range(4):
			var packed_byte := (packed_word >> (byte_index * 8)) & 0xff
			samples[sample_index] = (float(packed_byte & 0x0f) - 7.5) / 7.5
			samples[sample_index + 1] = (float((packed_byte >> 4) & 0x0f) - 7.5) / 7.5
			sample_index += 2
	return samples

## Value-state equivalent of StopPsgOscillator. The native code silences the
## channel through GBA registers; Godot stops its generated voice directly.
func stop_channel(channel: PsgChannelState) -> void:
	if channel == null:
		return
	_stop_channel(channel)

## Port of CalculatePsgEnvelopeVolume. It updates the envelope and routing
## values on typed voice state instead of writing mixer bytes/registers.
func calculate_envelope_volume(channel: PsgChannelState) -> void:
	if channel == null:
		return
	var left := clampi(channel.left_volume, 0, 255)
	var right := clampi(channel.right_volume, 0, 255)
	var volume := (left + right) >> 4
	if left < right and left <= (right >> 1):
		channel.stereo_mask = 0xF0
		volume = mini(volume, 15)
	elif left >= right and right <= (left >> 1):
		channel.stereo_mask = 15
		volume = mini(volume, 15)
	else:
		channel.stereo_mask = 255
	channel.envelope_volume = volume
	channel.sustain_volume = ((volume * clampi(channel.sustain_level, 0, 255) + 15) >> 4) & 0xff
	channel.output_mask = channel.stereo_mask & clampi(channel.channel_mask, 0, 255)

## One TickPsgSound envelope visit. frame_zero performs the source's extra
## envelope step that occurs once every fifteen sound ticks.
func tick_channel_envelope(channel: PsgChannelState, frame_zero: bool = false) -> bool:
	if channel == null or (channel.status_flags & 0xC7) == 0:
		return false
	if (channel.status_flags & 0x80) != 0:
		if (channel.status_flags & 0x40) != 0:
			_stop_channel(channel)
			return false
		channel.status_flags = 3
		channel.current_envelope_level = 0
		calculate_envelope_volume(channel)
		var attack_rate := channel.attack_rate & 0xff
		channel.rate_countdown = attack_rate
		if attack_rate == 0:
			if not _start_decay(channel):
				return false
			if (channel.status_flags & 4) != 0:
				_sync_channel_gain(channel)
				return channel.active
			_decrement_rate(channel, frame_zero)
			_sync_channel_gain(channel)
			return channel.active
		else:
			_decrement_rate(channel, frame_zero)
			_sync_channel_gain(channel)
			return channel.active
	if (channel.status_flags & 4) != 0:
		channel.release_countdown = (channel.release_countdown - 1) & 0xFF
		if channel.release_countdown == 0 or channel.release_countdown >= 0x80:
			_stop_channel(channel)
		return channel.active
	if (channel.status_flags & 0x40) != 0 and (channel.status_flags & 3) != 0:
		channel.status_flags &= 0xFC
		var release_rate := channel.release_rate & 0xff
		channel.rate_countdown = release_rate
		if release_rate == 0:
			if not _enter_echo(channel):
				return false
			_sync_channel_gain(channel)
			return channel.active
		else:
			_decrement_rate(channel, frame_zero)
			_sync_channel_gain(channel)
			return channel.active
	if channel.rate_countdown == 0 and not _envelope_step(channel):
		return false
	if (channel.status_flags & 4) != 0:
		_sync_channel_gain(channel)
		return channel.active
	_decrement_rate(channel, frame_zero)
	_sync_channel_gain(channel)
	return channel.active

func _decrement_rate(channel: PsgChannelState, frame_zero: bool) -> void:
	channel.rate_countdown = (channel.rate_countdown - 1) & 0xFF
	if frame_zero:
		_envelope_step(channel)

func _envelope_step(channel: PsgChannelState) -> bool:
	match channel.status_flags & 3:
		0:
			channel.current_envelope_level = (channel.current_envelope_level - 1) & 0xff
			if _signed_byte(channel.current_envelope_level) <= 0:
				return _enter_echo(channel)
			channel.rate_countdown = channel.release_rate & 0xff
		1:
			channel.current_envelope_level = channel.sustain_volume
			channel.rate_countdown = 7
		2:
			channel.current_envelope_level = (channel.current_envelope_level - 1) & 0xff
			if _signed_byte(channel.current_envelope_level) <= _signed_byte(channel.sustain_volume):
				return _enter_sustain(channel)
			channel.rate_countdown = channel.decay_rate & 0xff
		3:
			channel.current_envelope_level = (channel.current_envelope_level + 1) & 0xff
			if channel.current_envelope_level >= channel.envelope_volume:
				return _start_decay(channel)
			channel.rate_countdown = channel.attack_rate & 0xff
	return true

func _start_decay(channel: PsgChannelState) -> bool:
	channel.status_flags = (channel.status_flags - 1) & 0xFF
	var decay_rate := channel.decay_rate & 0xff
	channel.rate_countdown = decay_rate
	channel.current_envelope_level = channel.envelope_volume
	if decay_rate == 0:
		return _enter_sustain(channel)
	return true

func _enter_sustain(channel: PsgChannelState) -> bool:
	if channel.sustain_level == 0:
		channel.status_flags &= 0xFC
		return _enter_echo(channel)
	channel.status_flags = (channel.status_flags - 1) & 0xFF
	channel.current_envelope_level = channel.sustain_volume & 0xff
	channel.rate_countdown = 7
	return true

func _enter_echo(channel: PsgChannelState) -> bool:
	channel.current_envelope_level = ((channel.envelope_volume * channel.echo_level) + 255) >> 8
	if channel.current_envelope_level == 0:
		_stop_channel(channel)
		return false
	channel.status_flags |= 4
	return true

func _sync_channel_gain(channel: PsgChannelState) -> void:
	if channel.channel_id == 3:
		var wave_volumes: Array = tables.get("gPsgWaveVolumes", [])
		if wave_volumes.is_empty():
			channel.gain = 0.0
			return
		var level := clampi(channel.current_envelope_level, 0, wave_volumes.size() - 1)
		channel.gain = float(wave_volumes[level]) / 128.0
	else:
		# TickPsgSound writes c[9] into the high nibble of the native envelope
		# register; the byte store wraps its effective level to four bits.
		channel.output_volume_level = channel.current_envelope_level & 0x0F
		channel.gain = float(channel.output_volume_level) / 15.0

func _stop_channel(channel: PsgChannelState) -> void:
	channel.status_flags = 0
	channel.current_envelope_level = 0
	channel.output_volume_level = 0
	channel.gain = 0.0
	channel.active = false

func _signed_byte(value: int) -> int:
	var byte_value := value & 0xff
	return byte_value - 0x100 if byte_value >= 0x80 else byte_value
