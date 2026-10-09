# Audio driver recovery

The local exports contain 134 rendered songs/effects, MIDI sequences, a SoundFont,
samples and the raw source tables. The driver C below is a separate semantic
reconstruction. It compiles for ARM7TDMI but is not linked into the game,
execution-compared, compiler-matched or demonstrated to have native timing.

## Maintained code

| Source | Native routines and scope |
|---|---|
| `src/audio_player.c` | 08037930 initialization, sound/player setup, start/stop, fades, mode/frequency, DMA and VBlank servicing |
| `src/audio_sequence.c` | 08037320 sequencer; 080375FC note allocation; 30 command slots B1..CE; 12 extended-command slots; memory operations; track volume/pitch; PCM pitch conversion |
| `src/audio_psg.c` | 08038388 pitch conversion; 08038430 oscillator stop; 08038480 envelope volume; 080384E8 four-channel register/envelope update |
| `src/audio_mixer.c` | 08036C80 wrapper and copied Thumb/ARM body 08036D04..080370A2: PCM envelopes, looping, interpolation, packed stereo addition and reverb |

The copied mixer uses inherited registers and stack slots. These become explicit
arguments in C. Its four samples per word use wrapping additions and byte
rotations, including partial-word termination; the reconstruction preserves that
arithmetic rather than introducing saturation. Native sample-count invariants
(at least16, divisible by4) and valid initialized sample/track records are required.
The scanline cutoff remains a hardware register read before each channel.

Sequencer details retained include three-deep pattern returns, byte repeat
counters with an untruncated comparison, running status, source-address filtering,
signed modulation and pan, and fade flags that decide whether paused tracks are
preserved. A channel is selected by availability, release state, priority and
native owner-address ordering. Invalid extended-command indices beyond11 are
outside the recovered command domain; native code would index beyond its table.

PSG behavior includes a second envelope step every15 frames, signed byte
countdown comparisons, wave RAM replacement, sound-bias pitch rounding and the
repeated channel1 trigger write. All hardware writes remain unexecuted here.

`function_tables.csv` now includes the 36-entry main callback table at089DF52C
and 12-entry extended table at089DF7D4. `function_entries.csv` includes the mixer,
sequencer and installed PSG callbacks. The disassembler follows PC-relative
ADR/ADD/SUB followed by BX, exposing the mixer's ARM/Thumb transitions.
`build/assets/runtime/manifest.json` includes the driver tables and binary files.

## Integration still required

SoundInfo, players, tracks, callback RAM and shared memory need their native
layout. Generated song/player table definitions contain original ROM/RAM
addresses. The initializer retains the original1024-byte mixer copy to03000000;
the recovered C mixer has not replaced that code in a running ROM. Interrupt and
frame scheduling, execution comparisons, compiler matching and hardware timing
remain unfinished. Entry-body recovery does not establish complete playback
equivalence.

## Audio-use annotations

The use map retains640 direct callsites:630 same-block constant IDs and10 dynamic
calls. Each dynamic call now has a reviewed source and possible-ID annotation:
opponent music records, shop/menu input, PlayGameAudio routing, scene music
selection, or script operands. These are static domains, not observed runtime
coverage; indirect and untraced uses can still exist.
