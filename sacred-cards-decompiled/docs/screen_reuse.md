# Reusing the duel, shop and deck builder

The identified screen control/rendering bodies and their original source assets
are now available for reconstruction. Start from the maintained C and the asset
galleries below. Automatic Ghidra drafts remain research material.

Use the [native rebuild contract handoff](rebuild_contracts.md) for state aliases,
fixed-width record layouts, resource address translation and original animation
playback rules. These catalogs complement the screen-specific sources below.

## Where to start

| Screen | Entry | Main sources | Assets |
|---|---|---|---|
| Duel | `RunDuel()` | `duel_flow.c`, `duel_player.c`, `duel_menus.c`, `duel_ui.c`, `duel_graphics.c`, `duel_text.c`, `battle_animation.c` | `build/assets/duel/`, `duel-text/`, `player-menus/`, `full-cards/`, `opponents/` |
| Shop | `RunBuyShop()`, `RunSellShop()` | `shop_menu.c`, `shop.c`, `shop_graphics.c`, `shop_panel.c`, `shop_display.c` | `build/assets/player-menus/`, `deck-builder/`, `cards/`, `ui/`, `gameplay/` |
| Deck builder | `RunDeckManagement()` | `deck_management.c`, `deck_builder_menu.c`, `deck_builder_state.c`, `deck_builder_graphics.c`, shared collection/pre-duel helpers | `build/assets/deck-builder/`, `cards/`, `ui/`, `gameplay/` |

All source names above are under `src/`. Shared helpers include `card_sort.c`,
`card_metadata.c`, `card_art.c`, `card_presentation.c`, `text.c`,
`collection_display.c`, `menu_graphics.c` and `frame_input.c`.
The duel additionally depends on battle rules, effects, AI, progression and
rewards. Those are present as maintained C/generated tables; compile-time
coverage does not establish game-level equivalence.

The machine-readable **`build/research/screen-dependencies.json`** lists each
screen's primary source files, asset families, conservative object dependency
closure and external symbols. Regenerate it with `make recovery-status` after
compiling. Shared modules and function-pointer tables pull in extra functions,
so this is an object dependency catalog, not a precise runtime call graph.

## Input and state contracts

### Duel

`RunDuel()` performs fade, initialization, alternating player/AI turns and
outcome/reward handling. Supply the persistent player deck, current opponent
record/index, wager/reward context, progression, collection and RNG state before
entry. `RunPlayerDuelTurn()` assumes an already initialized duel, correctly
oriented board pointers and display state; it is not an independent initializer.

The physical board, player-relative effect grid and visible grid are different
views of shared cells. Preserve that relationship when changing storage.
The recovered effect dispatch tables live in `build/semantic/effect_tables.c`;
AI scorers and ROM table definitions are alongside them. Do not replace these
with automatic drafts based on their larger apparent coverage.

### Shop

Each entry copies persistent stock and collection into working inventories,
initializes sorting and its five-row/seven-column view, handles transactions,
then commits inventory on exit. Money changes occur in the transaction cores.
Supply `gShopStock[901]`, `gCardCollection[901]`, `gPlayerDeck[40]`, `gMoney`,
language and metadata/price tables. Slot zero is a sentinel; the shop also rejects
IDs 832–834. The deck count shown in the panel reads the persistent deck.

The panel retains the original read of `gDecimalDigitLookahead` at `02020C05`,
adjacent to the five formatted digits. This is explicit source behavior; it is
not safe to assume that independent zero-initialized buffers preserve it.

### Deck builder

Use the parent entry or the documented direct-editor setup in
[deck_builder.md](deck_builder.md). Card copy limits, Duelist Level eligibility,
40-card requirements and capacity checks are separate rules. This is the actual
collection/deck editor, in addition to the already recovered wager selector.

## Display, text and audio

- Native backgrounds use tiled buffers, tilemaps and palette banks. OAM records
  supply sprite coordinates, shape, priority, palette and affine flags. Reuse
  PNGs for ready-made visual assets; use raw data and C for original composition.
- Font glyphs, ASCII mappings and raw multilingual strings are retained. Card
  names are truncated differently by each screen; use its recovered rule.
- `WaitForFrame()` waits for a VBlank flag, then resets the callback to idle and
  polls keys. Registered callbacks run once through the interrupt path. A host
  implementation must preserve those semantics and the distinct menu-repeat
  polling used by collection/deck popups.
- Audio IDs go through `PlayGameAudio()`. `build/assets/audio/index.html` contains
  134 playable entries: 58 music and 76 effects, plus MIDI/SoundFont/raw sources.
  `usage.html` maps native call sites and scripts to audio IDs. Conversions are
  not a claim of cycle-accurate native-driver playback.
- `gBackgroundBuffer` is a 64 KiB view, actor tiles are a 32 KiB view, palettes
  total 1 KiB and OAM totals 1 KiB. Other workspaces overlap in original RAM.
  Their addresses annotate identity and sharing; native linker placement is
  not required for a new implementation.

## What remains for a running rebuild

These are faithful recovery sources, not a portable engine library. A rebuild
must provide the host-facing frame/input/display/audio services, global storage
and aliases, BIOS operations and ROM-data access. Several pointer fields are
explicitly 32 bits; direct casts to ROM addresses cannot run unchanged on a
64-bit desktop. A new engine can supply equivalent services without recreating
the original memory map. This repository intentionally does not select an engine.

Two long German card names take a native text-wrap branch that reads incoming
R8 before initializing it. The `WithContext` APIs in `duel_text.h` expose the input;
the compatibility wrapper uses the integration-owned `gDuelTextInheritedR8`.
The original value has not been established across every caller chain. English
names do not take this identified branch. Scene-script unsupported ASCII is
recovered with its inherited script-state pointer, and credits now have C source.

All 89 C modules, two assembly modules and generated tables compile. There are
no duplicate definitions, missing objects or unresolved game-function symbols.
Shared state and compiler support still need runtime bindings. No implementation
tests or execution comparisons were run for the final recovery pass.

The source-and-asset recovery is available as reconstruction input, including
previously missing overworld/collision and credits code. See
[source recovery and contracts](source_recovery.md) and [PROGRESS.md](PROGRESS.md).
Source recovery, extraction and a playable rebuild are separate results.
