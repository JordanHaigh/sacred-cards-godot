# Player controls, battle animations and menu recovery

The subsequent [deck-builder recovery](deck_builder.md) adds the actual
collection/deck editors, parent hub and player status. The consolidated
[reuse guide](screen_reuse.md) covers duel, shop and deck-builder dependencies.

## Scope of this checkpoint

The requested control and rendering bodies now have maintained C, including
shared card sorting. These bodies compile as ARM7TDMI Thumb objects. They have
**not been execution-compared**, and the entire game is still not decompiled.
ROM-backed tables, shared RAM aliases and GBA display/BIOS operations remain
explicit in the source. No Godot adaptation or compiler matching was introduced.

| Area | Maintained source | Native entries |
|---|---|---|
| Player duel input, placement, spell targeting and attacks | `src/duel_player.c` | `0802478C`, `08024810`, `080274EC..08027FBC`, `08023644..08023854` |
| Monster/context menus, statistics and opponent hand | `src/duel_menus.c` | `08025DE0..08028230` |
| Card staging, hits, destruction, attribute effects and LP countdown | `src/battle_animation.c` | `08012358..08013B6C` |
| Name editing, keyboard pages, sprite animation and confirmation | `src/name_entry.c` | `0800181C..08003118` |
| Title, continue/new game, overwrite confirmation and fade | `src/title_screen.c` | `08022184..08022984` |
| Buy/sell loops, action popup, navigation and sort choices | `src/shop_menu.c` | `0801A644..0801C5A4`, `0801E608` |
| Shop maps, miniature grid, status panel, sprites and transfers | `src/shop_graphics.c`, `src/shop_panel.c`, `src/shop_display.c` | `0801C5E4..0801EDC8`, `080351A4`, `080351EC` |
| Wager selection, special/no-wager prompts and sort popup | `src/pre_duel_menu.c`, `src/pre_duel_display.c` | `080074DC..08007D94`, `08008BD0..08008E48` |
| Wager list detail modes, thumbnails, deck counters and scrollbar | `src/pre_duel_graphics.c` | `08007D94..08008B74`, shared collection helpers |
| Shared menu buffer clearing and display callbacks | `src/menu_graphics.c`, `src/collection_display.c` | `08022EE0..08023040`, `08005DCC..08006054` |
| Shared sorter and all 54 key-builder slots | `src/card_sort.c` | `0801FB74..08021E18`, table `08D41A50` |

Existing duel, AI and script callers now invoke the recovered player turn,
battle presentation, name entry, shop and wager routines. The title exposes
`RunTitleScreen` using the existing save-storage view and `RunTitleMenu` for
its screen loop. Reconstructing the complete boot/interrupt path is separate.

## Behaviors retained

### Player duel

- Direction and button priority follows the native repeated/pressed checks.
  Cursor columns wrap across five slots; rows are clamped to the visible grid.
- Placement, spell targeting and attack targeting have distinct modes and
  saved cursor coordinates. The normal display reload does not reset those modes.
- Attack/defense menu previews modify the live pose before confirmation;
  cancelling does not restore the earlier pose.
- Occupied placement destinations, used-monster selection, trap dispatch,
  first-turn restrictions and Swords checks retain the native branch behavior.
- Direct attacks retain the saved-coordinate contract rather than substituting
  the AI battle setup. Exodia/FINAL checks and turn completion remain in order.
- Context options, held-L statistics and the opponent-hand view retain their
  original frame waits, uploads and input rules.

### Battle animation

- Seventeen nonzero battle-result cases select the original presentation flags.
- Full cards are staged on separate backgrounds; the second card's pixels
  retain the native palette-index adjustment.
- Hit descriptors advance every two frames. Destruction uses 12 particle
  records, five sprites per record and two OAM planes over 18 steps.
- Destruction consumes one global random draw, uses a selected local seed and
  restores the saved post-draw RNG state.
- LP decreases by 72 per frame, with the native initial/final waits and
  alternating sound calls. Attribute effects retain their affine-table updates.

### Title and name entry

- The actual title begins at `08022184`. `08000224`, previously described as
  title-like, is the separate credits screen, now recovered in `src/credits.c`.
- SELECT toggles the saved-game title choice; the overwrite prompt has its own
  up/down/confirm/cancel behavior. The title loop also consumes native RNG draws.
- Name entry preserves eight saved glyphs, a ninth working slot for combining
  marks, keyboard scrolling, page selection, dakuten/handakuten rules, trimming,
  sprite pulse and fade timing. B deletes; it is not a general screen cancel.
- The name screen's literal text path and bounded `strncpy` behavior are kept
  distinct from the ordinary language-selecting bitmap text renderer.

### Shop and pre-duel

- Shop rows use the original five-row ring over 129 logical rows, seven cards
  per row, working stock/collection filtering and R+direction page jumps.
- Buy/sell transaction mutation cores now have their repricing and redraw tails.
  Redraw also occurs after failure. The sell popup's exit deliberately calls the
  buy-panel presentation helper, as in the ROM.
- Original tile/palette writes, miniature overlays, cursor placement, sorting
  choices and money/insufficient-funds previews are retained.
- The cost display at `0801DDE0` first reads byte `02020C05`, just beyond the
  five formatted decimal digits. This is represented by the explicit
  `gDecimalDigitLookahead` alias, not an invented initial value.
- Wager navigation, 50-card jumps, forbidden cards, owned-card requirements,
  special-card confirmation and no-wager confirmation are recovered.
- Pre-duel details cycle through extended names, ATK/DEF, type/attribute and cost.
  Combined type icons retain their four-tile layout.
- All 54 sorting modes retain the original unsigned 64-bit keys and descending
  quicksort partition. Ownership/stock priorities, language name ranks,
  quantity, price side effects and tie behavior remain explicit. The native
  32-range stack and its overflow trap are retained.

## Assets and reproducibility

Run:

```sh
python3 tools/rip_player_menus.py "Yu-Gi-Oh! - The Sacred Cards (USA).gba"
make semantic-objects
make recovery-status
```

`rip_player_menus.py` is also included in `make rip-assets`. Its gallery is
`build/assets/player-menus/index.html`: eight background/atlas PNGs, 44 raw
files and nine hit/attribute frame descriptors, with ROM offsets and hashes.
These are source previews, not emulator captures or a claim of exhaustive
animation asset coverage. The previously exported name-entry background and
fonts remain in `build/assets/ui/`.

The refreshed Ghidra catalog has 2,806 roots: 2,739 drafts without explicit
warnings and 67 with warnings. Automatic drafts remain separate from reviewed
source. There are now 89 maintained C modules, two assembly modules and generated tables.
No implementation tests were added or run for this checkpoint.

## Runtime limits

The final recovery pass supplies credits, overworld/collision and the remaining
identified helper bodies. The object inventory has no missing game-function
symbols. GBA state, BIOS/IO operations and native pointer fields still need
runtime bindings; execution equivalence remains unverified. The inherited-R8
duel-name edge is exposed as an explicit context input. See
[source recovery and contracts](source_recovery.md) for the current scope.
