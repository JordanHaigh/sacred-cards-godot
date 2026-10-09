# AI, dialogue, graphics and audio runtime recovery

These are maintained semantic C bodies, compiled for ARM7TDMI Thumb. They are
not linked into the ROM, compiler matched or execution compared. The original
ROM and existing audio/image exports are unchanged.

## AI callbacks

`semantic_ai_callbacks.json` maps all 125 slots in five 25-entry tables to
94 distinct entry bodies. Actions, validation and scoring are in
`src/ai_actions.c`, `src/ai_validation.c` and `src/ai_scoring.c`.

The four card-scoring views contain 434 slots and 432 distinct functions.
`src/ai_card_scoring.c` maintains 140 bodies. `tools/build_ai_scorers.py`
now inventories 350 exact constant-store templates, 118 immediate returns and
126 call wrappers, including dormant bodies outside the original four views.
Together with maintained routines, the expanded inventory has 734 bodies. Unsupported templates remain explicit dependencies; currently
there are none in these four views. The generated manifest records every body,
source, wrapper target and table index. Spell indices 130/131 overlap the next
physical table; the native views are retained without invented guards.

Recovered details include:

- Trapped attacks simulate normal damage, but execute trap activation.
- Unsigned score priorities and arithmetic; first strictly positive best score wins.
- The discard duplicate scan begins at the selected pointer and reads five
  entries, even across a logical row boundary.
- The three-tribute scorer checks only its first two material predicates before
  comparing all three attacks. Validation separately checks all three.
- Ritual score comparisons differ between recipes; strict and inclusive
  comparisons remain distinct.
- `0800F134` tests empty cells with a face-up flag. The native branch confirms
  this unusual condition. `0800C918` also retains its unusual life/damage comparison.
- Metadata and preview calls retain their observable global side effects.

`src/battle_setup.c` supplies native attack setup and destruction writeback.
The side-zero attack-versus-attack initializer assigns owners 1/0; other cases
assign 0/1. Display clearing preserves the two padding bytes. `src/duel_deck.c`
adds physical-hand draws, deck exhaustion and attack restriction flags.
`src/random.c` recovers the shift-register random generator and byte range query.

Browse `build/assets/gameplay/ai.html`; JSON includes all callback mappings,
card-scoring manifests, target classifications and named action kinds.

## Dialogue and scene graphics

`src/text.c` recovers language selection, glyph-index arithmetic, small/large
font rasterization, shadowing and bold rendering. Mode 0500 deliberately clears
its output, matching the native instructions. Bold widens only seven rows.

`src/script_dialogue.c` implements ordinary supported glyphs, wait prompts,
choices, player names and card names. Input choice tests are independent, so
simultaneous direction keys preserve their native order. The prompt tests the
pre-increment timer. Ordinary unsupported ASCII uses the low 16 bits of the script-state pointer,
inherited in native R4, and does not advance its cursor or set dirty. This path
is explicit in `ScriptWriteGlyph`; it does not invent a fallback glyph.

`src/scene_graphics.c` adds:

- Actor height sampling, Y sorting, sprite/shadow OAM composition and palette/frame upload.
- Portrait part placement, animation-frame selection, optional fourth part,
  Huffman/cumulative-byte decoding and actor restoration.
- Dialogue display registers, exit behavior, OAM/palette/VRAM transfers.

OAM writes preserve the fourth halfword. Part offsets use each previous part's
first-frame object count. Actor OAM loops both advance eight bytes; ambiguous
Ghidra pointer types were resolved from instructions. Actor sort retains the
native valid-coordinate precondition above sentinel -32767.

BIOS calls in `src/gba_bios.h` are Thumb SWIs, requiring an actual GBA BIOS/runtime
when executed. `src/frame_input.c` recovers frame waits and key repeat polling;
interrupt initialization is recovered in `hardware.c`/`startup.s`; execution timing is unverified.

## Audio and initialization

`src/audio_player.c` adds song/player routing, priority-aware song start,
track/channel stop, fade setup, sound mode, DMA suspension/resumption, frequency
and timer configuration. The channel-stop callback argument comes from native
R0; it was absent in the draft. Native mixing, sequencing and PSG handling are recovered in companion modules;
IRQ/VBlank service is recovered in `hardware.c` and `startup.s`. These additions do not change
the existing 134 rendered audio entries or establish exact hardware timing.

`src/audio_dispatch.c` now includes effect-player stop and fade wrappers. The
native stop wrapper calls the same player twice; that behavior is preserved.

`src/new_game.c` recovers the initialization chain at 08006314: name, collection,
deck, capacity, level, duel records, progression rank, shop stock, money, random
state and flags. Save scripts call the recovered storage API through a native
address adapter. Original SRAM code-copy sizes are retained in `save_storage.c`; timing is unverified.

## Build and remaining integration

`make semantic-objects` compiles maintained and generated C. `make recovery-status`
reads their symbol tables without running the code. The resulting
`build/research/semantic-linkage.json` lists unresolved data/function/compiler
symbols and duplicate definitions; `native-dependencies.csv` is only the explicit
address-named subset. More globals becoming explicit can increase the symbol
count while native routine dependencies decrease.

The identified subsystem bodies now have source. Runtime bindings, timing and
execution comparisons remain separate work. Compiler matching and native linker
placement are outside the user target. Compilation does not prove behavior.


## Event subcommands and additional graphics

`src/script_events.c` recovers all 58 ^2 event bodies and both ^0 conditions.
`semantic_script_events.json` maps native entries to cases. Effects include
progression flags, scene transitions, scripted actor motion and calls into menus.
`08031954` walks 196 event-flag rules in order; replacements can cascade.
Event 1 uses event 0's X table to terminate its motion, so its short coordinate
arrays read into adjacent ROM data. This behavior is explicitly retained.

`build/assets/runtime/` contains the 196 rules, ten native motion sequences,
ten AI attack tags, initial inventories, glyph traversal and audio-frequency
words. The HTML catalog and JSON/binary exports accompany the C bodies.

`src/scene_graphics.c` also restores scene backgrounds, foreground and dialogue
buffers, offset registers and all VRAM/palette/OAM transfers at 080302E8.
`src/duel_graphics.c` recovers terrain loading at 08024980. Seven terrain layers
and fourteen viewport previews are exported to `build/assets/duel/`.
Native terrain copies forty rows of 32 halfwords with a source stride of31
halfwords. Reads beyond the physical map boundary are retained in binary output;
previews use only traced viewports with available tile and palette data.

`tools/build_runtime_tables.py` now emits 96 immutable table definitions,
including fonts, card metadata, AI candidates, transition rules and motion data.
The table manifest distinguishes literal index views from physical boundaries.
Definitions containing native ROM addresses still require the original ROM data
layout. All generated tables compile as an additional object.

## Shop, rewards and audio-driver bodies

`src/shop.c` recovers inventory/price rules and the purchase/sale mutation cores.
`src/duel_rewards.c` recovers player drops, fifty shop-restock rolls and money
rewards; the16-bit random helper retains its native consumption order. Exports
include200 opponent records,8000 deck slots,52 reward tables and901 base prices.
See [shop and reward evidence](shop_rewards.md) and the recovered shop menu/display modules.

The audio C now includes sequencer/command dispatch, note allocation, player and
driver setup, PSG envelopes/register writes, and PCM/reverb mixing with native
packed-word arithmetic. These are unexecuted semantic reconstructions. The
original mixer copy, RAM layout, hardware scheduling and compiler matching remain
integration work. See [audio-driver evidence](audio_driver.md).
