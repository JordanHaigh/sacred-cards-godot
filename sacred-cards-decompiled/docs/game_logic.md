# Gameplay recovery — AY7E USA Rev. 00

The new C is a semantic reconstruction from local ROM instructions. It has not
been execution-compared, compiled to matching ARM code, or linked into a game.
Parameterized state replaces several RAM globals. It is intended for reading
and further recovery, not a claim of a complete gameplay implementation.

## Card metadata

`0x08006BE4` writes metadata at `0x02020B00`:

| Offset | Field | ROM source offset |
| --- | --- | --- |
| 00, 04 | Card-name pointer | D310E0, via 080073E4 |
| 08 | Description pointer | E94E78, or D30F40 when cost exceeds Duelist Level |
| 0C | Cost, u32 | 88DF0 |
| 10 | Card ID, u16 | argument |
| 12 | Attack, u16 | 886E6 |
| 14 | Defense, u16 | 87FDC |
| 16 | Type, byte | 8A30E |
| 17 | Summon attribute, byte | 89C04 |
| 18 | Level, byte | 89F89 |
| 19 | Frame, byte | 8A693 |
| 1A | Unnamed metadata | 8AD9D |
| 1B | Unnamed metadata | 8AA18 |
| 1C | Unnamed metadata | 8B122 |
| 1D | Lookup indexed by field 1A | 8B4A7 |

`tools/rip_game_data.py` exports all 901 records, source tables with hashes,
24 type labels through D4BC3C and 12 summon labels through D419E0. Labels come
from the English `$0` segment; markup in card names remains uninterpreted.
The cost-gated description explicitly refers to Duelist Level and deck eligibility.
Unknown metadata keeps neutral names rather than assumed effect meanings.

## Stat modifiers

`src/card_stats.c` recovers:

- **08006DA0:** truncate stat to u16, interpret stage as signed i8, add stage
  times 500, clamp to 0..65534.
- **08006DD4:** modifier 1 multiplies by binary64 0.7, modifier 3 by binary64
  1.3; other values leave the input unchanged. The result converts to an integer
  and then u16. The boost path applies its 65534 upper limit **after** the u16
  wrap; a simple saturating multiplication would not preserve this order.
- **08006CB4 / 08006D2C:** after loading card metadata, only field 1A equal to
  2 enters the modifier path. Terrain lookup uses `terrain * 24 + type` at
  ROM offset 8B533, then the stage adjustment is applied to attack and defense.
  The preview path reads terrain/stage at 0201CB30/31. The duel path reads
  terrain at 02023250 and stage from byte 2 of the supplied card reference.

Seven 24-byte terrain rows fit before the next resource; row names remain
untraced. The gameplay HTML includes an explorer implementing this ordering.
The floating-point helper interpretation is based on call patterns and binary64
constants; host/native equivalence still needs execution comparison.

## Progression and deck initialization

`src/progression.c` recovers these routines with explicit state parameters:

| Thumb entry | Behavior |
| --- | --- |
| 08014094 | Add capacity, maximum 99999, then update level |
| 080140C0 | Subtract capacity, minimum zero; does not lower level |
| 080140DC | Initialize capacity to 1600 |
| 080140EC | Increment level while the next threshold is met |
| 0801411C | Compare capacity with next threshold; set event flag bit 0 on success |
| 08014168 | Initialize Duelist Level to 72 |
| 08014424 | Copy 40 starting cards from EBAF0 to RAM 02020C5A |
| 08014174 | Copy a different 40-card preset from B4690 to RAM 020233E4 |

Capacity lives at RAM 02020C3C, Duelist Level at 02020C40, and the level-change
flag byte at 02020D5A. The threshold table at B3EC0 has 1000 u16 entries;
level is capped at 999. Initialization sequence 08006314 calls the capacity,
level, and starting-deck initializers. The 40 starting cards total 1229 cost,
with maximum individual cost 72. The B4690 preset has no direct caller in the
current listing and must not be confused with the player's starting deck.

## Remaining game logic

Metadata handler entry bodies, trap cases, save lifecycle and AI candidate
selection have semantic C. Shared helpers, duel/summon actions, AI presentation,
shop transactions and script-event bodies now have source in companion modules.
The source still needs runtime bindings and full-game behavior validation; see
[source recovery and contracts](source_recovery.md).

## Numerical battle resolution

`src/battle.c` reconstructs the arithmetic portion of 0802321C and its targets:
attack versus attack, attack versus defense, defense versus attack, direct
attacks, healing and direct damage. It preserves distinct result codes, clamps
life points at zero on damage and 9999 on healing, and emits destruction/defeat
flags. Board removal and animation remain separate. `src/battle_state.c` now adapts
the raw calculation/display records, commits life points and applies defeat flags.

The summon-attribute comparison at 08023A04 uses two 12-byte tables at D4BD30
and D4BD3C. Divine attribute 11 forces neutral; otherwise the first match gives
A an attribute win, the second gives B a win, and no match is neutral. Slot zero
is not special-cased in the native routine. Attribute wins can destroy a stronger
monster while numerical damage still depends on the relevant stat comparison.
These override paths are represented explicitly in the C.

`tools/rip_effects.py` exports the relationship tables and all 1,802 card-to-handler
links (two per card). ROM FB79C supplies the 85 indices referenced by metadata
1B; FB900 supplies 132 indices referenced by metadata 1A. Dispatchers 080285E8
and 0802B33C read card IDs at RAM 02023478 and 02023480 respectively. An additional
pointer after the 85 referenced entries is not assigned a card without evidence.
`src/effect_dispatch.c` reconstructs dispatch. All 217 entry bodies have separate
maintained C, with a registry and generated C tables. The gallery distinguishes
this from complete transitive helper recovery or matching C.

Seven reviewed callback tables now seed control-flow analysis. All currently
encountered MOV-PC switches have reviewed bounded tables in `jump_tables.csv`.
The remaining register branches include generic callback thunks and audio-driver
indirect transfers. This does not prove there are no further undiscovered roots.

## Script commands and event flags

`tools/script_commands.py` records all 27 #/@/^ command forms in dispatcher
08031E40, including operand byte counts. `tools/decode_scripts.py` produces
`build/assets/scripts/decoded.html` and `decoded.json`. All 1,288 current nodes
reach a NUL at a token boundary or the special terminal-Z node. This means the
current payloads are lexically decoded; it does not mean the full VM is rebuilt.
There are 25,646 command occurrences across all language segments, 474 audio
references and 527 flag references. Repeated language segments remain separate.

Notable commands are #6 set flag, #7 test flag into branch state, #8 duel and
branch on its result, #9 add one card (little-endian u16), @7 repeated update
cycles, and @8 audio ID. The @8 handler explicitly suppresses IDs 111, 122, 123.
Unknown syntax stops decoding and retains an explicit status rather than being
silently treated as dialogue. Raw bytes are retained for every token.

`src/event_flags.c` recovers the 50-byte bank at RAM 02023700. Setting a flag
checks ID <=399; clearing and querying have no native bounds check. The original
mask table is retained. These routines and the new battle C are assembly-derived,
compile to ARM objects, and have not been execution-compared or compiler-matched.

## Further semantic recovery

- Five effect modules cover all 217 metadata entry bodies; separate trap and
  duel-cell modules recover shared behavior. See [handler evidence](card_effects.md).
- `src/summon_rules.c`: type classification and tribute queries; tables exported.
- `src/currency.c`: RAM 02020DA0 holds unsigned 64-bit money. Initialization is
  500; addition saturates at 9,999,999,999,999 and subtraction at zero. Overflow
  room and affordability queries preserve native unsigned comparisons.
- `src/save_data.c`: checksum, packing and unpacking of thirteen descriptor
  regions from 080D1490. Payload is 0x80A bytes at 02018800; checksum is the low
  16 bits of the byte sum. The save contains only the first 32 bytes of the
  50-byte event bank. `build/assets/save/layout.json` retains each RAM range,
  payload offset, size and known identity. `src/save_storage.c` now recovers
  SRAM headers, copy selection, write retries, repair and lifecycle. New-game
  initialization and hardware timing remain dependencies.
- `src/script_runtime.c` / `.h`: native 32-bit script-state fields, node loading,
  NUL-triggered branch transition, terminal Z handling, five-state scheduler,
  and blink/mouth counter behavior. The native loop updates portrait counters,
  dispatches one state step, then waits/uploads graphics.
- `src/script_commands.c`: all 27 #/@/^ forms have semantic C dispatch, including
  operand consumption, event/audio operations, choice state, conditional branch
  flags and native helper calls. Seven actor-command bodies are now in `src/script_actors.c`; glyph rendering,
  duel integration and other native helpers remain dependencies; this is not a complete executing VM or linked game.

All new modules compile as ARM7TDMI Thumb objects. Compilation does not establish
execution equivalence. All 2,407 current function roots also have separate
[automatic drafts](decompilation.md), which must not be confused with reviewed C.

See [save, AI and actor recovery](save_ai_actors.md) for the new runtime evidence.
`src/ai_turn.c` implements candidate enumeration, snapshots, score storage and
selection; all five callback families and the card-specific scoring bodies are now recovered.
See [runtime recovery](runtime_recovery.md) for exact scope and remaining integration.

## Shared metadata and battle state

`src/card_metadata.c` reconstructs 08006BE4 and 08006CB4. It fills the raw
30-byte metadata record, preserving 32-bit ROM string addresses. Metadata 1D
indexes the 1A table, unlike the per-card fields. Description selection compares
Duelist Level with card cost. Preview stats apply terrain to both attack/defense,
then signed stage to each, only when metadata 1A equals 2.

`src/battle_state.c` reconstructs the four LP operation initializers at
08023974/998/9BC/9E0, the 0802321C adapter, 08023514 life-point writeback,
0802356C display-field copies and 08023614 defeat updates. Calculation state is
at 02023120; display state is at 02023140. Attribute fields are copied as bytes,
card IDs/stats as halfwords. LP writeback respects calculation owner indices.
Unchanged display fields/result codes remain intact for numerical operations
that do not overwrite them. Native global definitions and linker layout remain
unresolved; these adapters are not evidence of execution equivalence.
