extends RefCounted
class_name PsgChannelState

## Value state for one recovered PSG voice. GBA register bytes are represented
## as named envelope and routing values so audio backends can consume them.
var channel_id := 1
var active := false
var left_volume := 0
var right_volume := 0
var sustain_level := 0
var envelope_volume := 0
var sustain_volume := 0
var stereo_mask := 0xFF
var channel_mask := 0xFF
var output_mask := 0xFF
