# Source recovery and handoff

## Scope

The final pass recovers the remaining identified native bodies into maintained C
and the small assembly boundaries required for CPU mode/register transfers.
All 89 C modules, two assembly modules and generated table/scorer modules compile.
This is source for understanding and reuse; direct execution still requires GBA
services or equivalent adapters. It does not select Godot or another engine.

Byte-identical output, original compiler matching and native RAM/linker placement
are excluded from the user's completion criteria. No new implementation tests
were added or run. Compilation and static inventories are the final checks.

## Source map

| System | Maintained sources under `src/` |
|---|---|
| Entry, IRQ, hardware, input | `game.c`, `startup.s`, `hardware.c`, `frame_input.c`, `gba_bios.h` |
| Intro, title and name entry | `intro.c`, `title_screen.c`, `name_entry.c` |
| Credits and city map | `credits.c`, `city_map.c` |
| Overworld lifecycle/movement | `overworld.c`, `overworld_movement.c`, `overworld.h`, `scene_data.c` |
| Actors, portraits and text | `actor_graphics.c`, `scene_graphics.c`, `script_actors.c`, `text.c` |
| Script interpreter | `script_runtime.c`, `script_commands.c`, `script_dialogue.c`, `script_events.c` |
| Duel lifecycle/actions/presentation | `duel_flow.c`, `duel_player.c`, `duel_menus.c`, `duel_ui.c`, `duel_graphics.c`, `duel_text.c`, `battle_animation.c` |
| Battle/state/rules | `battle.c`, `battle_state.c`, `battle_setup.c`, `duel_cells.c`, `duel_deck.c`, `duel_special_wins.c`, `summon_rules.c` |
| Card effects | `effect_dispatch.c`, `card_effects.c`, `effect_families.c`, `spell_effects.c`, `monster_effects.c`, `trap_effects.c`, `effect_noops.c` |
| AI | `ai_turn.c`, `ai_actions.c`, `ai_validation.c`, `ai_scoring.c`, `ai_card_scoring.c` |
| Card data and rendering | `card_metadata.c`, `card_stats.c`, `card_art.c`, `card_presentation.c`, `card_sort.c` |
| Collection/deck/status | `deck_builder_menu.c`, `deck_builder_state.c`, `deck_builder_graphics.c`, `deck_management.c`, `collection_display.c` |
| Shop/wagers/rewards | `shop.c`, `shop_menu.c`, `shop_graphics.c`, `shop_panel.c`, `shop_display.c`, `shop_legacy_display.c`, `pre_duel_menu.c`, `pre_duel_graphics.c`, `pre_duel_display.c`, `duel_rewards.c` |
| Audio | `audio_dispatch.c`, `audio_player.c`, `audio_controls.c`, `audio_sequence.c`, `audio_psg.c`, `audio_mixer.c` |
| Records/password/link/diagnostics | `duel_records.c`, `duel_record_menu.c`, `password.c`, `link_transport.c`, `link_protocol.c`, `link_menu.c`, `diagnostic_screen.c` |
| Save, initialization and utilities | `save_data.c`, `save_storage.c`, `new_game.c`, `progression.c`, `currency.c`, `event_flags.c`, `random.c`, `menu_graphics.c`, `unused_helpers.c` |
| Cartridge compiler library | `compiler_runtime.c`, `compiler_float.c`, `compiler_thunks.s` and corresponding headers |

Address comments identify native entries. `semantic_function_families.json`
records reviewed native entries factored into shared implementations. Per-root
locators are in `build/research/function-coverage.json`.

## Final additions and native ranges

| Recovery | Original entry/range examples |
|---|---|
| Credits | `08000224..08000934` |
| City map | `08000938..080012BC` |
| Reset/IRQ and hardware | `080000C0..08000218`, `08003958..08003B94` |
| Main game entry | `08016928` |
| Intro logos | `0801950C..08019B7C` |
| Duel records/viewer | `0801679C..08016924`, `08019D64..0801A640` |
| Link transport/protocol/menu | `0801EFEC..0801FB14`, `08022014..08022184`, `08022984..08022EDC` |
| Overworld and collision | `0802FD18..08031238`; individual entry comments in the modules |
| Extra audio controls | `080378F4`, `08037A2C..08037BEC`, `08037F64`, `08038934..08038BA8` |
| Integer/float/string library | `08038E24..0803B61C` |

Dormant code remains dormant. Several link-menu handlers and unused effect
entries are no-ops in the original. The source preserves those bodies rather
than inventing behavior. The link stress diagnostic can wait indefinitely under
native conditions, and credits intentionally do not return.

## Generated data and AI templates

- `build/semantic/effect_tables.c`: both metadata dispatch tables.
- `build/semantic/ai_card_scorers.c`: 734 distinct bodies, including 140 maintained
  routines, 350 exact constant stores, 126 call wrappers and 118 returns.
  The generator includes dormant setters found outside the four active views;
  the four original views still have 434 slots and 432 distinct functions.
- `build/semantic/runtime_tables.c`: 96 immutable ROM views, including the actor,
  scene, portrait and save-region tables added in the final pass.

The generating scripts and JSON manifests preserve table addresses, dimensions,
wrapper targets and overlaps. Pointer-valued data still contains native addresses.

## Runtime contracts retained explicitly

### State and addresses

Source uses named global state and original buffer aliases. The symbol inventory
has no missing game-function definitions; 190 data symbols remain unbound.
Aliased views must remain consistent when integrating them. Several structure
fields hold 32-bit native addresses, so compiling for a 64-bit host is not by
itself a usable port. Direct `ROM(address)` casts require address translation or
an appropriate runtime mapping.

The [rebuild contract handoff](rebuild_contracts.md) now documents all 190 views,
their native addresses and extents, 145 RAM storage groups, 84 physical
intersections and 31 ARM record layouts. `src/native_state.h` supplies fixed-width
byte-layout records; `build/assets/runtime/resources.json` translates native ROM
references to original files or the retained archive. These are explicit
contracts, not installed RAM bindings.

Clang also emits ten `__aeabi_*` support symbols for the ARM object build.
These are the selected compiler's ABI support, separate from the recovered
cartridge compiler routines. Supply the toolchain runtime when linking ARM
objects; do not redirect them to functions with incompatible calling conventions.

### BIOS, IO and scheduling

`gba_bios.h` preserves BIOS operations as SWIs. Display, audio, DMA, timer and
serial operations preserve their register effects. `startup.s` retains ARM
mode/SPSR/stack handling; `hardware.c` also expresses IRQ dispatch in C.
These are alternative representations of the same hardware boundary, not two
handlers to install simultaneously. VBlank callbacks and frame waits depend on
interrupt service. No hardware timing equivalence has been established.

The original initializer copies mixer/IRQ/SRAM instructions to RAM. Their copy
sizes and control flow remain documented; the maintained C is not installed as
a replacement in a running cartridge image.

### Text register inputs

Unsupported ordinary scene-script ASCII uses the low 16 bits of the incoming
script-state pointer, inherited through native R4. It neither consumes the byte
nor marks the text dirty. This unusual path is explicit in `ScriptWriteGlyph`.

German card names 325 and 771 can enter a wrap path using inherited R8.
`WriteDuelCardNameWithContext`, `RunDuelTextWithContext` and
`PresentDuelTextWithContext` expose the input. The compatibility wrapper reads
`gDuelTextInheritedR8`, which an integration must supply. The original callers'
R8 values have not been established across every call chain. English names do
not take this identified path. No invented wrap value is supplied.

`build/assets/runtime/duel-text-register-context.json` records conservative local
R8 provenance at 242 native call sites. German is segment `$2`. Most sites
preserve entry R8; the Factory spell handler also preserves it. This narrows the
input contract without claiming to have solved every dynamic/indirect caller.

### Arithmetic library

`compiler_float.h` exposes float/double bit patterns rather than relying on host
floating point. The native double ABI passes its high word first; the C value API
is deliberately independent of that register order. Kind/sign/exponent/mantissa
parts retain original NaN, rounding, underflow and comparison behavior reviewed
from instructions. Invalid-operation parts refer to native RAM views
`gRomDoubleInvalidParts` / `gRomFloatInvalidParts`; no host NaN substitute is used.
Integer/string APIs retain wrapping, forward copying and NUL padding. Their
factored algorithms are not instruction-for-instruction recreations.

### Valid input domains

Native routines generally assume valid card IDs, indices, initialized records
and sufficient storage. Shared window helpers can scan across logical duel-row
boundaries; terminated lists can include adjacent table views. No new range
checks have been added to alter those contracts.

## Assets and raw data

Use the decoded family directories under `build/assets/`. Each manifest records
source offsets and interpretation. `remaining-screens/` adds the credits/map/logo
resources. `rom-data/original-data.bin` preserves all bytes after the reviewed
executable interval, including uninterpreted data and padding. Native data address
`A` is file offset `A - 0x0803B61C` in that archive.

Complete retention is established by extraction and hashing; complete semantic
classification of every data byte or animation context is not claimed. Rebuilding
an animation requires its recovered state machine and original frame/OAM/palette/
timing data, not only the exported PNG preview.

`build/assets/animations/manifest.json` exports descriptor/OAM/affine files and
playback rules for battles, portraits, actor walking/running, name/title UI and
the remaining screen sequences. See [the playback handoff](rebuild_contracts.md).

## Evidence and limits

Run `make semantic-objects` and `make recovery-status`. The latter inventories
source references, code bytes and object symbols without executing the recovered
game. All 2,806 known roots have a locator or reviewed shared mapping. There are
zero unclassified spans inside `08000000..0803B61C`, zero missing objects and zero
duplicate definitions.

An address locator, a successful compile and a zero-gap byte inventory are not
proofs of semantic equivalence. Full-game execution comparison, all original
inherited-register values, exhaustive code discovery and semantic interpretation
of every cartridge data byte remain unestablished. The automatic drafts remain
labelled as inferred output. No complete-game correctness percentage is claimed.
