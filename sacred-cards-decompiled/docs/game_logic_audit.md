# Duel, shop and deck-builder instruction audit

This is a static comparison of maintained C with AY7E USA Rev00 instructions.
It is not an emulator comparison or a claim that all recovered game code has
been independently audited. Native addresses below identify the evidence;
Ghidra drafts were used as navigation aids, with disputed types and branches
checked in the original instructions.

## Corrections made

- **`08026950`: restore the general immunity-aware counter.** The maintained
  implementation previously exposed only the `0802690C` empty-or-immune
  specialization. `CountDuelCardOrImmuneWindow(window, wanted)` now represents
  the original two-argument entry. At `0802696C..0802697A` the ROM checks
  immunity, replaces an immune card by zero, and then compares that result
  with the requested card in R7. The existing `CountEmptyOrImmuneCells`
  interface calls it with zero, preserving existing callers. The native byte
  count is sign-extended on return, although the five-slot result is always
  0 through 5.
- **`08018D68`: preserve the initial terminator check.** The immunity scan now
  tests the first list element before comparing it with the requested card,
  matching `08018D72..08018D78`. The fixed ROM list starts with a nonzero card,
  so this does not change ordinary gameplay with the supplied list.
- **`08021D74`: preserve pass narrowing order.** The dormant bubble-sort
  alternative increments a word-sized pass, uses it for signed loop limits,
  and narrows to 16 bits at `08021DF4..08021DF8`. The C now narrows at the same
  phase. This is a width/ordering correction; normal 900-card input cannot
  reach the wrap edge.

## Reviewed entries and conclusions

### Currency and shop

| Native entries | Maintained code | Instruction-level conclusions |
| --- | --- | --- |
| `08019B7C`, `08019BC4`, `08019BFC`, `08019C34`, `08019C58` | `src/currency.c` | Addition/receive checks use unsigned 64-bit `limit - money`, including subtraction wrap if money was already above the limit. Subtraction saturates at zero; affordability includes equality. Initial money is 500. |
| `08007414`, `08007470`, `08007404` | `src/shop.c` | Buy price is zero for stock outside 1..250, otherwise `base*(251-stock)/250` with a minimum of one. Sell price uses `base*(250-stock)/500` below 250 stock, and `base/500` at or above 250, also minimum one. Multiplication truncates to the native 64-bit width before division. |
| `0801B6B0`, `0801B6F0`, `0801B730`, `0801B758` | `src/shop.c` | Working collection mutations skip card zero. Space uses signed `250 - current`, rather than byte wrap, and saturates at 250. Removal saturates at zero. |
| `0801B334`, `0801BD20` | `src/shop.c` transaction cores | Sell order is remove owned card, add money, add stock, success audio. Buy predicates are stock, collection space, then money; successful order is remove stock, subtract money, add owned card, audio. C core return values are adapter results; the native routines also reprice and redraw through the separate shop modules. |
| `0801B85C` | `src/shop.c` | Commit copies both working inventories to persistent inventories, including card zero, for all 901 slots. |

### Deck mutation and navigation

| Native entries | Maintained code | Instruction-level conclusions |
| --- | --- | --- |
| `08004558`, `080045C4`, `080045E4` | `src/deck_builder_state.c` | Adding a card checks its cost against **Duelist Level**. Returning a card from the deck view saturates collection at 250; returning it from the collection view increments the byte without saturation. This native distinction is intentional. |
| `0801421C`, `0801425C`, `08014294` | `src/deck_builder_state.c` | Selection is a signed byte. Deck navigation clamps instead of wrapping, and emits error audio when already at the requested boundary. Detail mode increments as a byte and wraps after 3. |
| `080142B8`, `08014318`, `08014370`, `08014554`, `080145B0` | `src/deck_builder_state.c` | Removal shifts later cards left, clears the last occupied slot, decrements count, clamps selection, and saturates cost subtraction at zero. Collection-view removal loads metadata before searching. The native removal helper requires a nonempty deck. |
| `080143EC`, `08014448`, `0801449C`, `080144E8`, `08014570`, `0801457C`, `080145E8`, `08014610` | `src/deck_builder_state.c` | Refresh counts all 40 nonzero slots, then recalculates cost over the first `count` slots. It does not compact an invalid gapped deck. Card lookup accepts visible row offsets; fullness scans all slots independently of the count. |
| `08014630`, `0801469C` | `src/deck_builder_state.c` | ROM `08D35BE0` is exactly bytes 36..44, matching the factored C's `36 + method` for valid methods 0..8. One entry resets selection after sorting; the other preserves it. |

### Sort implementation

| Native entries | Maintained code | Instruction-level conclusions |
| --- | --- | --- |
| `0801FB74`, `0801FCF4`, `0801FD18`, `0801FD4C`, `0801FD5C` | `src/card_sort.c` | Descending unsigned 64-bit comparison; middle pivot; stop partitioning when left >= right; swap all 12 record bytes; push upper partition before lower partition. Equal-key order depends on this algorithm and is not stable. Stack capacity is 32 ranges; overflow loops forever in the ROM and C. Counts below two skip stack reset and sorting. |
| `0801FDE8`, `0801FE3C`, `0801FEC4`, `08020448`, `08020BC0`, `08020F40` | `src/card_sort.c` | Number method 1 writes IDs from a fixed ROM list but builds keys from the input IDs. Fixed-list methods 3..6 give all records zero keys before the ordinary partition pass; avoiding that pass would change their order. Collection number ranking adds 900 for owned cards; shop number ranking uses bit 60. |
| `08020098`, `08020110`, `080201C0`, `08020320` | `src/card_sort.c` | Names use a language-specific 901-halfword rank table. Inventory name ranking adds 900; it does not set the bit-60 presence flag used by several other keys. |
| `08020E08`, `08020F84`, `08021038`, `080211A0`, `080212E8`, `08021738`, `080217E0`, `080218B4`, `08021C64` | `src/card_sort.c` | Type inversion, byte-masked attribute inversion, shifted cost, buy/sell price keys, level and deck-quantity logic match the factored builders. Buy price sorting writes global shop price state and uses stock; sell sorting prices by stock but prioritizes nonzero owned quantity. |
| `08021D74` | `src/card_sort.c` | Dormant bubble alternative compares unsigned 64-bit keys, swaps only strictly out-of-order adjacent records, and performs at least one pass. Pass truncation corrected above. |

The table lists the key-builder variants actually examined. It does not label
all 54 native builders independently instruction-reviewed.

### Player duel controls and cells

| Native entries | Maintained code | Instruction-level conclusions |
| --- | --- | --- |
| `0802478C`, `08024810` | `src/duel_player.c` | Repeated directions outrank A, L, R and B. Start/Select produce no command. The turn processes an input before checking termination; duel-ended check precedes turn-done check. |
| `08025818`, `08025870`, `080258E8` | `src/duel_player.c` | Viewport transitions compare unsigned current halfwords with signed targets as full integers, step by 256, then snap to the target. Composition, frame wait and HUD upload call ordering is retained. |
| `08025C2C` | `src/duel_player.c` | Context-menu direction priority and ROM navigation tables match. Details require visibility and nonzero category; end-turn sets the flag then restores display; discard uses the absolute side record. |
| `08023644`, `08023684`, `08023734`, `08023854` | `src/duel_player.c` | Combatant setup distinguishes direct attack, attack-position target and defense-position target. Stage is signed. Direct attack records saved cursor coordinates as in the ROM, and does not initialize unrelated combatant fields. |
| `08027684`, `08027694`, `080276C8`, `08027704`, `080277E0` | `src/duel_player.c` | Saved cursor and mode dispatch match. Placement starts on the first empty appropriate row. The player selection uses visible pointers; effect logic uses relative pointers. |
| `08027854`, `08027A70`, `08027BC8` | `src/duel_player.c` | Monster menu defense, tribute and flip-effect paths preserve flags and call order. Attack restriction marks the selected card used. Trap activation precedes direct/target attack selection. Spells retain their three target classes. |
| `08027C80`, `08027D08`, `08027D50`, `08027DE4`, `08027EB0`, `08027EEC`, `08027EFC`, `08027F28`, `08027F54` | `src/duel_player.c` | Placement deliberately lacks an occupied-destination guard. Spell targeting rejects the used flag and dispatches only category-one targets. Attack confirmation turns both cards face up, locks the attacker, resolves numbers/destruction, restores cursor, and presents. Cancellation restores saved cursor before transitioning. |
| `08023FD4`, `080242A0`, `0802432C`, `08024350`, `0802436C`, `080243A0`, `080243A8`, `080243BC`, `080243D4`, `080243F8`, `0802441C`, `08024450`, `08024484`, `080244A4`, `08024548`, `08024560`, `0802457C` | `src/duel_cells.c` and called side helpers | Clearing a cell preserves flag bits 6..7 and bytes 5..7. Stage saturates at signed -128/127. Physical and relative side/cell access remain distinct. Status-bit changes affect byte 3, not flag byte 4. |
| `080268FC`, `0802690C`, `0802691C`, `08026950`, `080269A0`, `08026A20`, `08026A40`, `08026A64`, `08026A94`, `08026C04`, `08026EA4`, `08027174` | `src/duel_cells.c` and local duel searches | Five-pointer windows need not start at row boundaries. Backward searches receive the last pointer. Last-monster fallback is four; last-empty fallback is zero. Strongest face-up ties choose the last qualifying card, including zero attack. Face-up/used predicates match the bit tests. |

## Reuse constraints and uncertainty

- These routines assume the original valid card IDs, array extents, mode
  ranges, nonempty removal preconditions and initialized pointer views. A
  host API may validate its inputs before invoking a faithful core, but such
  validation is not part of the original behavior.
- A Rust translation must choose native wrapping operations where present:
  64-bit shop multiplication, unsigned money remainder, byte inventory
  increments and key assembly. Other operations deliberately saturate.
- Shop transaction cores are factored prefixes. Complete shop flow also needs
  its menu, graphics, panel, display and audio routines. The recovery adapters
  do not promise the original register-return ABI.
- Attack-trigger trap calls retain the existing explicit amount adapter of
  zero. The native caller passes the audio routine's return register; current
  attack-trigger validators select handlers that ignore that amount. This
  audit does not infer a meaningful amount from that register.
- Full card effects, battle numerical resolution, screen rendering, animation
  scheduling, BIOS/hardware behavior and save integration are dependencies,
  not all independently audited by this pass.
- No implementation tests or emulator runs were performed. Static compilation
  checks syntax and type consistency; it does not establish gameplay parity.
