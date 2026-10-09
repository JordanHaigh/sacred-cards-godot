# Card effects and tribute queries

All **217 metadata dispatch slots** now have maintained semantic C entry bodies:
132 metadata-1A and 85 metadata-1B. `semantic_handlers.json` is the explicit
address/function/source registry. It does not count transitive helper recovery.
The C compiles for ARM7TDMI; it has not been execution-compared, linked into the
ROM, or compiler-matched. Presentation and draw/action helpers now have maintained
source; ROM/RAM global views still require bindings. `card_metadata.c` now implements metadata/preview loading;
`battle_state.c` connects effects to numerical battle C and writes results back.

| Source | Entry bodies | Scope |
|---|---:|---|
| `src/card_effects.c` | 17 | Terrain, healing, damage, Fairy's Gift |
| `src/effect_families.c` | 55 | 33 equipment and 22 single-material rituals |
| `src/spell_effects.c` | 37 | Other nonempty metadata-1A bodies |
| `src/effect_noops.c` | 24 | Verified immediate-return metadata-1A entries |
| `src/monster_effects.c` | 84 | Remaining metadata-1B bodies, including two immediate returns |

`tools/build_effect_tables.py` generates both C function-pointer tables under
`build/semantic/`, compiled by `make semantic-objects`. The handler gallery at
`build/assets/gameplay/effects.html` links every slot to its maintained function
and separate automatic draft. These tables do not supply the game's linker/RAM
layout or native ABI. Companion modules supply the shared helper bodies.

## Preserved behavior

- Healing/damage/equipment spells perform trap detection even during suppressed
  presentation. A detected trap redirects resolution only when suppression is
  zero. Equipment preserves the stage-decrement helper's incidental R0 result
  passed as the trap amount; it is not replaced with an invented constant.
- Equipment eligibility comes from 33 exact 113-byte bitsets at 08175804.
  `effect-rules.html` and `equipment-compatibility.csv` expose every allowed card.
- Thirty ritual records at 08D36328 retain four raw u16 words. Handler-specific
  selection order determines which recipe succeeds. Multi-material recipes use
  distinct slots; simple rituals use exact card IDs.
- The immune list at 08D36678 contains three IDs. Individual effects differ in
  when they consult immunity; their behavior is not generalized from TCG rules.
- Strongest-target selectors choose the **last** equal-attack candidate. AI
  candidate selection uses the **first** equal positive score instead.
- Cell flags, permanent/temporary stages, and grave-card side effects are kept.
  `src/duel_cells.c` distinguishes physical side records from relative pointers.
  Only category-one monsters replace the remembered grave card.
- Unreferenced monster slots remain represented. Slot 57 checks Gate Guardian
  pieces but removes Blue-Eyes cards and presents Blue-Eyes Ultimate; the odd
  native behavior is retained. Dark Necrofear's two guard predicates both inspect
  the opposing row. Shared monster slot 68 does not contain a draw call.
- Some native presentation calls explicitly supply a second card argument;
  others leave R1 as incidental register state. The latter remains an unresolved
  ABI/presentation dependency, represented by a variadic external declaration.

## Separate trap engine

`src/trap_effects.c` recovers dispatchers 08035AFC / 08035BEC / 08035C30 and all
20 validation and activation cases through 080368F0. Empty cases are 0, 10,
15..19. Empty metadata-1A entries for trap cards do not mean they lack effects.

Trap search scans opposing slots 0..4 and uses the first eligible trap. Kinds
2..6 accept monster attack at most 500 / 1000 / 1500 / 2000 / 3000. Validation
loads preview stats and changes shared metadata. Four FFFF-terminated lists at
08D5113C / 148 / 154 / 198 match metadata-1A indices for damage, healing,
equipment and Raigeki triggers. Their exact lists and corresponding card IDs
are exported to `effect-rules.json` and individual binary files.

Destruction traps are consumed even when the trigger monster is immune; the
immune branch reveals it and uses a distinct presentation helper. Goblin Fan
and Bad Reaction to Simochi damage the acting side, then consume both cards.
Reverse Trap consumes its trigger; the equipment wrapper has already undone
its stage change. Infinite Dismissal and Amazon Archers use fixed monster row 2.

All ROM card records have trap kind 0..19. Invalid kinds in native 08035C30 return
caller-register residue; that behavior is outside the valid-input semantic API.
Timing, complete action integration and presentation are still unresolved.

## Tribute helpers

`src/summon_rules.c` reconstructs 08023C34, 08018150 and
08028378/08028384/08028394/080283DC/08028414.

- Type classification uses signed bytes at 08D4BD48; empty card ID returns 0.
- Category 1 uses the signed level table at 08D4C6D0: levels 0..4 require 0,
  5..6 require 1, 7..8 require 2, and 9..12 require 3.
- Remaining requirement subtracts the committed count at 02023448 and floors at 0.
- Category 4 uses a separate lookup at 080BA25C indexed by metadata byte 1D.
- The committed count increments as an unsigned byte, including wraparound.

The query tables are exported. AI summon actions and callback bodies are now
recovered; see [runtime recovery](runtime_recovery.md). Player board interaction
and duel presentation/sequencing remain separate recovery work.
