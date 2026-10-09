# Shop and duel reward recovery

`src/shop.c` recovers the native inventory arithmetic and price rules.
`src/duel_rewards.c` recovers card selection, shop restocking and money rewards.
These compile as semantic C but are not linked, execution-compared or matched.

## Shop

Prices use901 unsigned64-bit base values at08D32D08. For stock1..250, buying costs
`max(1, base * (251-stock) / 250)`; other byte stock values produce zero. Selling
uses `max(1, base * (250-stock) / 500)` below250 stock and
`max(1, base / 500)` at250 or higher. Multiplication retains unsigned64-bit wrap.

The shop works on copied collection/stock arrays at02021CC0/02021140;0801B85C
commits them to persistent arrays. Additions saturate at250 using the native
signed remaining-space comparison; removals saturate atzero. Working-array
mutations skip cardzero, while persistent shop additions accept only IDs1..900.

The transaction cores from0801B334/0801BD20 preserve validation and mutation order,
currency changes and sound55/57. The sell core does not reject when shop stock
is already full; its addition saturates. Buying requires stock, collection space
and sufficient money. These cores explicitly exclude the native menu redraw and
repricing tails. Those tails, controls, graphics and shared sorting are now
recovered in the companion shop modules; see [player/menu recovery](player_menus.md).
Runtime equivalence remains unverified.

## Rewards

200 opponent records at080B4B5C, selected through08D35C28, contain40-card decks,
music, capacity/money fields and three reward-table pointers. The exporter keeps
all200 records and8000 deck slots plus52 distinct cumulative reward tables
(1916 entries including terminators) under `build/assets/opponents/`.

The normal/special player tables use rolls0..2047. The49-card list at080BA280
selects the special table using the wagered card. Up toten player rewards are
stored and added to the collection; a zero result is still passed through the
native collection updater. Fifty separate rolls0..29999 select shop additions.
Entries are scanned until the first threshold strictly above the roll or the
cardzero sentinel. Exports preserve thresholds and ordering, not inferred weights.

Money uses the opponent's inclusive16-bit minimum/maximum and a decimal scale
of10^1..10^15, with all other scale bytes selecting1. The PRNG consumes two bytes
even for equal bounds, unlike the byte-range helper. Its first byte becomes the
high byte of the16-bit result. Signed remainder and final16-bit truncation are
retained. Capacity changes, duel-outcome presentation and full caller integration
remain separate work.
