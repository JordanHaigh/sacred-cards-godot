# Deck builder recovery

The collection editor, current-deck editor, their parent menu and player-status
screen now have maintained C. The new source compiles for ARM7TDMI Thumb.
This completes the identified control/rendering entry bodies for the requested
screen scope. Runtime equivalence has not been established; this is not a
standalone application or a claim that all game code is recovered.

## Source map

| Native entry/family | Maintained implementation |
|---|---|
| `08001298`, `080013D8..0800181C` | `src/deck_management.c`: parent menu, errors, background and display callbacks |
| `0800315C..0800391A` | `src/deck_management.c`: player-status layout, values and callbacks |
| `08003C8C..080041B4` | `src/deck_builder_menu.c`: collection input/action loop |
| `080044A4..08004750` | `src/deck_builder_state.c`, `src/pre_duel_menu.c`: collection mutations and initialization |
| `080047D8..0800597C` | `src/pre_duel_graphics.c`, `src/pre_duel_display.c`, `src/deck_builder_state.c`: collection composition and eligibility colors |
| `08005998..08006054` | `src/pre_duel_graphics.c`, `src/deck_builder_menu.c`, `src/collection_display.c`: sprites, sorting and transfers |
| `08013B70..08014074` | `src/deck_builder_menu.c`: current-deck input/action loop |
| `0801421C..0801469C` | `src/deck_builder_state.c`: deck state, navigation, cost and sorting |
| `080146D0..080157B8` | `src/deck_builder_graphics.c`: current-deck composition |
| `08015810..08015868` | `src/deck_builder_state.c`: one/two/three-copy rules |
| `08015898..08015DD4` | `src/deck_builder_menu.c`, `src/collection_display.c`: deck sort popup and display callbacks |

`src/deck_builder.h` exposes the recovered entry points. Functions that are
identical to wager-list helpers share an implementation. The collection and
deck editors remain distinct where their native behavior differs.

## Preserved behavior

- The collection shows 900 card IDs, wraps navigation, and jumps 50 cards with
  R+up/down. The deck clamps navigation and jumps ten cards with R+up/down.
- L cycles extended name, ATK/DEF, type/attribute and cost views. SELECT cycles
  nine sorts; START opens the sort popup. Native key priority is retained.
- Collection right adds; left removes. Its three-option action popup shows card
  details, adds or removes. The two-option deck popup shows details or removes.
- Adding requires an owned copy, fewer than 40 deck cards, permission under the
  copy-limit lists, and card cost no greater than Duelist Level. Total deck
  capacity is checked when leaving the parent menu, not while adding.
- The parent menu allows exit only when all 40 slots are nonzero and cached
  deck cost is within capacity. It reports count and capacity errors separately.
- Eleven card IDs allow one copy, one ID allows two, and other IDs allow three.
  The exporter retains IDs and zero terminators rather than using modern rules.
- Collection-view removal increments its inventory byte without saturation;
  deck-view removal caps it at 250. Both compact the deck and adjust its cost.
- The deck auto-exits when emptied. Selection clamping can emit an additional
  navigation sound during removal, matching the native helper calls.
- Collection names use 18 selected-language glyphs; deck names use 22. The wager
  view keeps its separate raw 20-byte prefix rule. Temporary C buffers are sized
  to hold the documented glyph limits without relying on inferred stack overlap.
- Sort methods 36–44 handle the deck; 45–53 handle collection/wager lists.
  Sort acceptance resets selection. Native duplicate redraw calls are retained.
- Player status shows name, level, capacity, six-bit progress and money. Its
  level/capacity formatter truncates to 16 bits before division. Digits OR into
  preloaded tiles, as the native code does.
- Window/blend values, sprite masks, map positions, upload ordering and one-shot
  callbacks remain explicit. DMA map copies are expressed as BIOS copies of the
  same source/destination spans; cycle-level DMA timing is not reproduced.

## Entry contracts

`RunDeckManagement()` is the complete recovered hub entry. It fades music,
loads the hub, initializes collection state and cached deck state, then runs its
three choices. Changes affect the persistent deck/collection variables directly;
this function does not save SRAM on exit.

For direct editor entry, use the native setup order:

```c
InitializeCollectionList();
RefreshPlayerDeckState();
RunCollectionEditor(); /* or RunDeckEditor(); empty deck returns immediately */
```

The caller supplies a valid, compact deck of up to 40 IDs followed by zeroes.
Do not use `ShowPlayerStatus()` as a cold graphics initializer: the native
parent menu supplies its existing backdrop and buffers.

### State layout

| Native address | C view | Meaning |
|---|---|---|
| `0201FCC0` | `gCollectionMenu[12]` | selection u16 at 0, sort at 2, detail at 3, popup choice at 4 |
| `0201FCCC` | `gCollectionSortedCards[900]` | sorted u16 IDs |
| `020203E0` | `gCollectionTotals[901]` | byte counts of collection plus deck, captured on initialization |
| `02020770` | `gCardCollection[901]` | persistent collection counts |
| `02020C50` | `gPlayerDeckState[10]` | cost u32 at 0; signed selection at 4; sort/detail/popup/count at 5/6/7/8 |
| `02020C5A` | `gPlayerDeck[40]` | persistent u16 deck IDs |
| `0201CB48` | `gDeckActionChoice` | deck action popup selection |
| `02020AF8`, `02020AFA` | scroll position/limit | u16 scrollbar inputs |
| `02023040` | `gCardSortState[12]` | native pointer at 0, count u16 at 8, method at 10 |
| `02018800` | `gCardSortScratch[0x4314]` | sort records and range stack; overlaps other screen workspaces |

The totals snapshot stays unchanged during deck/collection transfers because
these transfers preserve combined ownership in normal game state. The native
byte arithmetic is retained, including wrap behavior outside normal counts.

## Assets

`build/assets/deck-builder/index.html` provides:

- Three static backdrop previews: collection, deck and parent menu.
- 101 exported files, including compressed originals, decoded tiles, maps,
  palettes, cursor/navigation tables, digit divisors and copy limits.
- 45 raw localized text records and readable candidate decodings.
- Additional shop popup/status maps, empty-card tiles and cursor assets.
- Links to shared card art, miniatures, icons, fonts, battle effects and audio.

The hub/status/popup maps reference runtime-rendered glyphs. They are exported
as raw maps; the PNGs deliberately describe static layers. Full composition is
specified by the C. Source offsets, lengths and SHA-256 hashes are recorded in
`manifest.json`; the input ROM hash is checked before extraction.

```sh
python3 tools/rip_deck_builder.py "Yu-Gi-Oh! - The Sacred Cards (USA).gba"
make semantic-objects
make recovery-status
```

No implementation tests were added or run. The recovered source was reviewed
against draft C and Thumb instructions where register types, callback bodies or
pointer scaling were ambiguous. That is not execution-equivalence evidence.
See [the three-screen reuse guide](screen_reuse.md) for shared dependencies and
remaining runtime contracts.
