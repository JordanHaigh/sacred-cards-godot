# Native state, resources and animation contracts

This is the 10 October 2026 handoff for a faithful rebuild in another language.
The maintained C remains the behavioral reference. These catalogs explain the
original storage, pointers and playback inputs without requiring the original
RAM placement, linker or compiler.

## Files to use

| File or folder | Purpose |
|---|---|
| `src/` | Maintained C, headers and processor-specific assembly |
| `src/native_state.h` | Fixed-width byte-layout records; native addresses use `uint32_t` |
| `state_views.json` | Reviewed symbol-to-address registry and record associations |
| `build/assets/runtime/state-contracts.json` | All 190 unbound data views, sizes, users, overlaps and ARM record offsets |
| `build/assets/runtime/resources.json` | Native address translation, original file spans and pointer-table edges |
| `build/assets/runtime/tables/` | 96 immutable tables as little-endian binary files |
| `build/assets/animations/` | Playback contracts and 68 original descriptor/OAM/affine files |
| `build/assets/runtime/duel-text-register-context.json` | 242 original call sites and conservative R8 provenance |
| `build/assets/rom-data/` | Complete original data interval, including uninterpreted bytes |
| Other `build/assets/` families | Decoded graphics, audio, scripts, rules and raw source files |
| `build/research/source-contracts.json` | Clang declarations and target layouts, including generated definitions |
| `build/semantic/*.c` and `*.json` | Generated effect dispatch, AI scorers, immutable tables and provenance |

Paths inside the resource catalog are relative to `build/assets/`. Family
manifests use local files. `runtime/animations.json` mirrors the animation
manifest; its `asset_base` is `animations/`.

## State is a set of views

Instruction-review evidence and corrections are recorded in the
[state audit](state_audit.md), [animation audit](animation_audit.md),
[duel/shop/deck audit](game_logic_audit.md) and
[input/arithmetic/random/save review](runtime_contract_audit.md).

The 190 symbols describe 145 connected RAM storage groups, IO aliases, a ROM
pointer view and an explicit register input. They are not 190 independent
allocations. The catalog records 84 physical intersections. Some represent
fields of a larger structure; others represent scratch reused by separate
screens. A physical intersection does not itself establish object lifetime.

Important relationships:

- `gDuelStateBytes` is a 252-byte snapshot: 20 board cells, ten hand cells,
  terrain/padding and two side records. Hand and side symbols address its fields.
- `gDuelCursorColumn` and `gDuelViewport` are the first two bytes of
  `gDuelCursorState`. The second byte is the cursor row. `gDuelViewMode` is separate.
- `gOpponentRecord` contains the identifier and three reward pointer views.
  `gScriptOpponent` and `gCurrentOpponent` share another location.
- `gInitialDuelLifePoints` addresses the opponent record's two starting-LP
  halfwords at `02020D70/72`. Duel initialization copies this view into current LP.
- Title, name entry, password, records, credits, card sorting, full-card
  composition and battle animation reuse the workspace beginning at `02018800`.
- `gAiScratch` is a ROM pointer word at `08D41B28` pointing into that workspace.
- The full-card palette occupies 256 bytes at `0201C800`; the map starts at
  `0201C900`. It is not a 256-element RGB555 palette.
- The last two sound-command callback entries are also the named music
  callbacks. Replacing the callback table must update those views consistently.
- Several legacy flag banks alias password-use data. Native clear/copy extents
  remain relevant when implementing those dormant routines.

`native_state.h` defines records for duel cells/snapshots/decks/cursors,
card metadata, menus, opponents, actors/followers, battle calculation/display,
scripts, duel text, OAM and native descriptors. Size and selected field-offset
assertions are compiled. The JSON includes Clang's ARM offsets and alignments;
do not infer native layouts from 64-bit host pointers.

Read multi-byte fields as little endian. Preserve signed byte/halfword behavior,
reserved bytes, partial writes, wrapping counters and aliasing. A Rust rebuild
can use typed state and resource IDs, provided these observable relationships
remain consistent. Packed records describe byte layout; avoid taking potentially
unaligned references to their fields.

## Translating native resources

`resources.json` contains 10,683 byte-identical original file spans, 27,640
referenced ROM addresses, 96 table exports and 14,117 known pointer edges.
A span is labeled original only after its exported bytes were compared to that
ROM slice as static data. Decoded PNGs, decompressed tiles and rendered audio
have different representations.

Known edges include script branches, scene and actor configuration, opponent
decks/rewards, audio banks/tracks, portraits and gameplay callbacks. Code targets
also link to the maintained source-location inventory; this is a navigation aid,
not a certificate of behavioral equivalence.

For an address with `exported_spans`, use the named asset plus `file_offset`.
Otherwise its `archive` field locates the original bytes when they fall in the
retained data interval:

```text
archive offset = native address - 0x0803B61C
```

Use the lookup tool for any address, including addresses without an exact
reference entry:

```sh
python3 tools/resolve_resource.py 080AC2A0
```

Keep original addresses as provenance even after assigning new resource IDs.
Pointers can address the middle of a string, a table field or an overlapping
view. A base constant or code pointer is not automatically a separately
identified asset. Raw archive fallback retains data without inventing its
semantic type or boundary.

## Playback contracts

`animations/manifest.json` combines original descriptors with scheduler rules:

- Battle hits draw four descriptors for two ticks each. The duration byte is
  ignored. Adjacent repeated OAM pointers terminate the loop.
- Attribute hits draw five descriptors for two ticks each and update affine
  matrices separately. A zero-duration descriptor terminates this sequence.
- Destruction performs 17 steps at three ticks each: 51 draw ticks, with
  procedural particle delays, lifetimes, palette darkening and two OAM planes.
  It consumes one global seed-selection draw and restores that post-draw RNG.
- LP decreases by 72 per tick, clamped to its target, with the original 15-tick
  initial hold, 30-tick damage hold and alternating sound cadence. Setup/cleanup
  callback ticks are recorded separately.
- Opponent battle presentation precedes player presentation. Result flags gate
  effects, card visibility and conditional pauses. The dormant jitter helper
  is not called by the stock hit loop.
- Portrait blink and mouth tables run in reverse index order. Blink uses four
  times the duration value; speaking changes mouth timing. Silent mouth state
  settles on frame zero instead of cycling indefinitely.
- Ordinary walking draws before decrementing phase. Script walking decrements
  first and performs two frame/upload cycles per coordinate step. Running uses
  actor sheets 89/90 and a separate 26-entry phase table.
- Name-entry timers compare before incrementing; steady descriptor holds use
  duration plus one. Arrows share phase, focused labels share timer state, and
  affine scale has a distinct initial expansion.
- Title pulse, title/name fades, intro logos, credits scrolling, city fade and
  duel-text prompts have their own timing contracts.

The animation catalog references the recovered code for procedural and
input-dependent composition. OAM retains coordinates, wrapping, palette,
priority, blending and affine bits. These contracts are static recovery; they
are not emulator captures or execution-verified animation parity.

## Inherited text registers

German language segment `$2`, cards 325 and 771, has at least 26 glyphs without
an ASCII space before glyph 28. Native wrapping then consumes incoming R8.
Values 0..27 add `28-value` blanks; larger values add none. The original
no-space path also drops the first byte.

The context catalog covers 242 reviewed direct call sites; 228 locally preserve
the function-entry R8. Other sites carry constants or symbolic value origins.
The Machine Conversion Factory handler and message wrapper preserve their
incoming value. This analysis assumes APCS callee-saved behavior across calls;
it does not solve every indirect caller or dynamic register value.

The `WithContext` text APIs expose the input directly. Convenience wrappers
require `gDuelTextInheritedR8` to be supplied by the integration. A universal
zero/default value is not supported by the native evidence. English card names
do not take these two identified wrap paths. Unsupported scene ASCII has a
separate pointer-derived R4 input, expressed in its recovered C.

## Regenerate and evidence

```sh
make recovery-contracts
```

This compiles ARM objects, refreshes source/byte/symbol inventories, inventories
declarations and target layouts, exports state/animation/resource contracts and
reads existing Ghidra function bodies without changing the analysis project.
It requires existing extraction/decompilation artifacts. The lookup and export
tools do not execute recovered game code.

The current static audit reports no incompatible variable declarations,
function-signature differences or record-layout differences. All known function
roots have source locators or shared mappings; no game-function symbol is missing
from the object inventory. These results do not prove the correctness of all
2,806 implementations or exhaustive discovery of code/data. Full-game behavior,
hardware timing and every original register context remain unverified. No new
implementation tests or emulator comparisons were run in this pass.
