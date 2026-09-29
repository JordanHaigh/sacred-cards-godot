extends RefCounted
class_name PsgChannelState

## Value state for one recovered PSG voice. GBA register bytes are represented
## as named envelope and routing values so audio backends can consume them.
var channel_id := 1
var active := false
var frequency_hz := 440.0
var waveform: StringName = &"square"
var gain := 0.25
var phase := 0.0
var noise_lfsr := 0x7FFF
var wave_samples := PackedFloat32Array()
var left_volume := 0
var right_volume := 0
var status_flags := 0
var attack_rate := 4
var decay_rate := 4
var sustain_level := 8
var release_rate := 4
var echo_level := 0
var rate_countdown := 0
var release_countdown := 0
var envelope_volume := 0
var current_envelope_level := 0
var sustain_volume := 0
var stereo_mask := 0xFF
var channel_mask := 0xFF
var output_mask := 0xFF
