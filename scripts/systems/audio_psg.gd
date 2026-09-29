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
	if channel == 4:
		return int(noise[clampi(key - 21, 0, 59)])
	var adjusted_key := key
	var interpolation := fine
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
	channel.sustain_volume = (volume * clampi(channel.sustain_level, 0, 255) + 15) >> 4
	channel.output_mask = channel.stereo_mask & clampi(channel.channel_mask, 0, 255)
