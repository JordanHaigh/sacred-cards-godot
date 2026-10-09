# Rust port status

This repository contains a playable native Rust reconstruction using Macroquad
and the supplied AY7E decompilation and exported assets. It is a new host runtime.
It has not been execution-compared with the original game, and it does not yet
constitute a complete or timing-equivalent rebuild.

## Implemented systems

| System | Current implementation | Source evidence |
|---|---|---|
| Card database | All 901 numeric slots, including the empty sentinel; original names, descriptions, stats, costs, attributes, levels, effect metadata and artwork | `card_metadata.c`, `card_stats.c`, `tools/rip_game_data.py`, `build/assets/gameplay/cards.csv` |
| Opponent data | All 200 native records and forty-card decks, starting life points, terrain, music and reward tables; six empty native control slots remain empty | `duel_flow.c`, `duel_rewards.c`, `tools/rip_opponents.py` |
| Duel loop | Five-card hands and monster/spell rows, draw and deck-out, normal summons and native tribute requirements, position/action locks, battles, attribute overrides, terrain and 500-point stat stages | `duel_flow.c`, `duel_player.c`, `summon_rules.c`, `battle.c`, `card_stats.c` |
| Effects | Explicit spell, trap, equipment, ritual and monster activation branches; unsupported activations return an explanation and keep state intact; native equipment eligibility and immunity tables | `spell_effects.c`, `trap_effects.c`, `monster_effects.c`, `card_effects.c`, exported gameplay tables |
| Opponent decisions | Deterministic Rust heuristic using the same legal public actions as the player | `src/duel.rs`; the original callback/scoring AI is retained as source/data but is not emulated |
| Economy and deck editing | Native starting money/capacity/level, collection and stock; card-level admission and copy limits; stock-sensitive buy/sell arithmetic; ante, card/stock/money rewards and capacity progression | `new_game.c`, `currency.c`, `shop.c`, `deck_builder_state.c`, `duel_rewards.c`, `random.c` |
| Exploration | All 58 native scene grids and 237 variants load; collision, actor interaction, grid exits and ordered variant rules; native city-map destinations and milestone unlock masks | `overworld_movement.c`, `overworld.c`, `city_map.c`, exported world/runtime manifests |
| Story scripts | Decoded graph traversal, English dialogue, choices, flags, duel branches, item grants, actor/player placement and supported scene/menu events | `script_commands.c`, `script_events.c`, `script_actors.c`, `build/assets/scripts/decoded.json` |
| Desktop presentation | Title/hub, exploration, duel, deck/shop/card browsers, opponent selection and atlas; recovered raster assets with a new desktop layout; exported audio playback | `src/main.rs`, `src/ui.rs`, `build/assets/` |
| Persistence | Validated versioned JSON, synced temporary write and atomic rename; player deck, ownership, stock, progression flags and scene state | `src/save.rs`; native save-region export is retained for provenance |
| Passwords | Native card codes add shop stock; one-time money/capacity bonus codes | `password.c`, `build/assets/passwords/manifest.json` |

Opponent labels deliberately identify native record slots. The exported records
do not establish a complete verified mapping from slots to character names.
There are 900 nonempty card IDs plus slot zero, and 194 populated opponent decks.
The native starting shop stock is empty. Wins perform fifty native shop-reward
rolls; card passwords also add shop stock. Scene grids use 120 × 80 two-pixel
coordinate units. Scene PNGs are 256 × 256 exports, cropped to a 240 × 160 view.

## Verification

Verified on 10 October 2026: 48 tests pass; Clippy is clean with warnings denied.
The export audit decoded 9,011 PNGs and checked 119,248 file references. All 194
seeded duel simulations completed within the turn limit. The actual macOS window
was exercised through new game, hand selection, summoning, end turn, AI battle
resolution and returning to the hub. No player save was written by that check.

Run from the repository root:

```sh
cargo test
cargo run --bin audit
cargo run --bin audit -- --simulate 194
```

`SACRED_ASSETS` or `audit --assets DIRECTORY` selects another exported asset
directory. The audit parses every exported JSON document, checks referenced file
existence and declared byte sizes, decodes every PNG, loads each world variant,
compares opponent JSON decks with their native binary exports, checks initial
economy and money-reward ranges, and tests save roundtrip/corruption rejection in
a unique temporary directory. It does not touch the player's save.

Optional simulations cycle through populated opponent slots using fixed seeds.
The player policy alternates the native starting deck and native opponent decks,
uses public summon/spell/effect/attack actions, and calls the normal opponent AI.
The audit checks state invariants after turns and rejects panics, mutation after
rejected spell validation, and games that exceed 240 turns. It reports action
counts and the implemented activation coverage. These are regression checks of
the Rust runtime, not original-ROM equivalence tests.

The export audit verifies sizes and PNG decoding. It does **not** recompute every
SHA-256 digest, decode every audio/binary format, or establish the correctness of
the decompilation's semantic interpretation.

## Remaining gaps

- A complete, manually verified campaign playthrough and every script branch
  have not been established. Unsupported commands stop with an explanation;
  presentation-only timing commands are currently collapsed.
- The native callback/scoring AI, full GBA animation/OAM/palette scheduling,
  screen transitions, link duel protocol, IRQ/BIOS timing and native memory
  layout are not implemented by this desktop runtime.
- The desktop UI and audio playback use host facilities. Native menu/text
  composition, exact sound-driver mixing and hardware frame timing are not
  reproduced.
- The JSON save format is specific to this port. Native SRAM payload import,
  export and communication compatibility are not provided.
- Effect support is explicit in `Duel::spell_supported` and
  `Duel::monster_effect_supported`; a supported activation is still subject to
  testing of its individual board-state branches. Loading all cards or counting
  implemented handlers does not prove every card interaction is correct.

The upstream recovery's own limits remain relevant: see
[`sacred-cards-decompiled/README.md`](../sacred-cards-decompiled/README.md) and
[`docs/rebuild_contracts.md`](../sacred-cards-decompiled/docs/rebuild_contracts.md).
