# Recovery checkpoint — 10 October 2026

The remaining identified code has source implementations. The supplied ROM is
unchanged. This checkpoint describes static recovery, compilation and extraction;
**full-game execution equivalence has not been established**.

## Completed in the final recovery pass

- Credits sequence, text placement, scrolling/fades and display callbacks.
- Overworld input, actor/NPC interaction, movement/collision, followers,
  transitions and the city map.
- Reset/IRQ entry assembly, hardware initialization, VBlank service and intro logos.
- Duel record storage/menu, diagnostic screen and legacy shop display helpers.
- Link serial/timer transport, packet transfer/retry behavior and link menus.
- Additional song/player/track controls and mutable RAM callback dispatch.
- Software integer/floating-point library routines, strings/copies and call veneers.
- Dormant routines, leaf accessors and shared mappings discovered by a code-boundary audit.
- Credits/map/logo resources, remaining immutable ROM tables and a complete raw data archive.
- Corrections found during review: deck-editor repeat input, link-timer interrupt
  flag mask, mutable audio callbacks and independent palette-copy destination.

The maintained total is **89 C modules and two assembly modules**, plus generated
effect dispatch, AI scorers and **96 immutable ROM table definitions**.
`make semantic-objects` compiles these as ARM7TDMI objects. No implementation
tests were added or run for this pass.

## Static inventory

The latest [contract audit](rebuild_contracts.md) adds all 190 native data views,
145 RAM storage groups, 84 intersections and 31 target record layouts. It corrects
the full-card palette extent and aligns the `CopyDuelCell` source qualifier.
Maintained and generated C have no incompatible variable declarations, differing
function signatures or differing record layouts in the current compiler audit.

The resource catalog maps 27,640 referenced addresses to original assets/archive,
with 10,683 original file spans, 96 binary tables and 14,117 known pointer edges.
The animation catalog adds 68 original files and playback contracts. A native
R8 provenance catalog covers 242 duel-text/spell-dispatch call sites.

The delegated native reviews cover [state](state_audit.md),
[animation](animation_audit.md) and [duel/shop/deck logic](game_logic_audit.md).
They corrected the NPC wandering flag test, credits row width and starting-LP
address, restored the general immunity-aware card counter, and retained native
list/sort edge behavior. The [runtime contract review](runtime_contract_audit.md)
also records sampled input, fixed-point, random and save routines. These reviews
state their exact scope and do not establish full-game execution equivalence.

| Item | Result |
|---|---|
| Known native function roots | 2,806 |
| Reviewed shared implementation mappings | 433 |
| Other source locators | 2,373 |
| Roots without a source locator/mapping | 0 |
| Reviewed executable interval | `08000000..0803B61C` |
| Unclassified spans inside that interval | 0 |
| Reviewed switch / callback tables | 40 / 7 |
| Address-named / named missing game-function symbols | 0 / 0 |
| Duplicate object definitions / missing objects | 0 / 0 |
| Metadata effect bodies | 217 |
| Top-level AI callback slots / distinct bodies | 125 / 94 |
| AI scoring bodies including dormant templates | 734 |

A source locator is an address/name reference, **not an independent correctness
proof**. Reviewed family mappings explain where several native entries are
factored into one implementation. Static byte classification distinguishes code,
literals, tables and padding; it does not prove that code is absent everywhere
else in the cartridge.

`make recovery-status` refreshes the exact counts from existing artifacts.
See `build/research/function-coverage.json`, `code-coverage.json`,
`semantic-linkage.json` and `build/recovery-status.json`.

## Assets retained

The existing card, world, actor, portrait, UI, duel, menu, script, gameplay,
opponent, save and audio exports remain available. The final pass adds
`build/assets/remaining-screens/` (26 previews, 233 files and 169 text uses).
`build/assets/rom-data/original-data.bin` preserves every original byte from
`0803B61C` through the cartridge end, including unused data and padding.

There are 134 playable audio exports: 58 music entries and 76 effects, with MIDI,
SoundFont, samples and sequence/driver source data. Full original animation
behavior depends on recovered code plus its frame/OAM/palette/timing data.
Every contextual asset interpretation has not been independently confirmed.

## Explicit boundaries

- New C has not been run as a complete game or compared against native execution.
- Sources retain GBA BIOS, IO registers, 32-bit pointer fields and named global
  state. The object inventory has 190 unbound game-data symbols and ten Clang
  compiler-support symbols. These are runtime/binding contracts; there are no
  missing game-function symbols in the inventory.
- Two German duel names have inherited-R8 behavior. The input is exposed through
  context APIs; no guessed default has been substituted.
- Complete semantic classification of every data byte and proof of exhaustive
  executable discovery are not claimed.
- Original compiler matching, native RAM/linker placement and byte-identical
  recompilation were excluded by the user. The older instruction rebuild is a
  separate artifact that retains original bytes for gaps.

See [source recovery and contracts](source_recovery.md) for the handoff, and
[the screen reuse guide](screen_reuse.md) for duel/shop/deck-builder integration.
