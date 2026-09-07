# Sacred Cards Rules Reference

This document separates what the repository can currently support from what still needs verification against the original game. `CONFIRMED` means it is directly represented by supplied data, an existing project resource, or the supplied card-list reference. `ASSUMED` means the current implementation uses it as a configurable baseline. `NEEDS VERIFICATION` means no exact rule has been established here.

The supplied PDF is a 2003 card-list FAQ, not a complete mechanics manual. It confirms card fields, broad card categories, some progression/economy concepts, and effect descriptions; it must not be treated as proof of every duel rule.

## Duel and player state

- **ASSUMED:** A duel starts with two players, each represented by independent runtime state. `DuelState` owns turn/phase/winner state; `DuelPlayerState` owns deck, hand, graveyard, monster zones, spell/trap zones, and an optional field zone.
- **ASSUMED:** Starting life points are 8,000.
- **ASSUMED:** The configured baseline is a 40-card deck, five-card opening hand, five monster zones, five spell/trap zones, and one field zone.
- **ASSUMED:** The first player does not draw on turn one; later turns draw one card.
- **NEEDS VERIFICATION:** Mulligans, first-player choice, simultaneous setup, hand limits, deck-out timing, and whether the original game uses all of these modern concepts at all.

## Card categories and data

- **CONFIRMED:** The supplied 900-card dataset contains 773 `Monster`, 83 `Magic`, 19 `Trap`, and 25 `Ritual` records. These are source `card_type` values, not modern Yu-Gi-Oh! assumptions.
- **CONFIRMED:** Card records provide ID, name, ATK, DEF, source type, alignment/summon value, level, cost-like `dc`, password, and prose description. The card-list FAQ presents the same broad details as Card Number, Card Name, Attack, Defense, Type, Summon, Cost, and Stars on its card entries.
- **CONFIRMED:** Card IDs are the canonical runtime identity. Display names are not unique.
- **NEEDS VERIFICATION:** The exact relationship between dataset `dc`, the FAQ's `Cost`, deck capacity, and in-game card availability. The runtime preserves `source_dc` without assigning it a stronger meaning.
- **NEEDS VERIFICATION:** The exact mapping between source names and game labels. The adapter currently documents `Spellcaster`/`Magician`, `Beast-Warrior`/`Beast Warrior`, and `Sea Serpent`/`Sea Dragon` as terminology differences rather than silently changing source records.

## Drawing and summoning

- **ASSUMED:** Drawing removes the first card from the authoritative deck order and places it in the hand.
- **ASSUMED:** One normal summon is available per turn. Level 5–6 monsters require one tribute and level 7+ monsters require two tributes.
- **CONFIRMED:** The card-list FAQ uses tribute language for ritual and special-summon descriptions, including examples with one tribute and multiple tributes. This confirms that tribute concepts exist, but not the complete normal-summon procedure.
- **NEEDS VERIFICATION:** Exact tribute selection, whether level thresholds apply identically to all summon types, ritual requirements, summon limits, and whether the current level thresholds match the original game.

## Positions and card visibility

- **CONFIRMED:** Runtime state supports attack position, defense position, face-up state, and face-down state without modifying canonical card definitions.
- **ASSUMED:** A summoned monster enters face-up attack position; a set monster enters face-down defense position; a set spell/trap enters face-down.
- **NEEDS VERIFICATION:** Flip rules, position-change limits, whether a monster may attack after changing position, and the original game's exact face-up/face-down conventions.

## Combat and direct attacks

- **ASSUMED:** Only a face-up attack-position monster can attack.
- **ASSUMED:** In attack-vs-attack, the higher effective power destroys the lower monster and inflicts the difference as LP damage; equal power is a draw.
- **ASSUMED:** In attack-vs-defense, the attacker's ATK is compared with the defender's DEF. A winning attack destroys the defender and inflicts the difference; a losing attack destroys the attacker and inflicts the difference to the attacking player.
- **ASSUMED:** A direct attack is legal only when the defending monster field is empty and deals the attacker's effective ATK as LP damage.
- **ASSUMED:** `BattleResolver` applies one configurable +500 effective-power bonus to the side favored by the configured matchup result. This is an implementation baseline, not a confirmed original-game multiplier.
- **NEEDS VERIFICATION:** Exact damage rules, destruction timing, ties, attack-vs-defense LP damage, direct-attack exceptions, battle replay/order, and matchup scaling/order.

## Type, alignment, and matchup rules

- **CONFIRMED:** Matchup data is stored independently in `resources/sacred_cards_matchups.tres` and validated by `CardMatchupRules`.
- **CONFIRMED:** The current configured matrix contains 17 type/environment advantages, 3 type/environment disadvantages, and 10 guardian-star superiority edges.
- **CONFIRMED:** The configured guardian-star cycles are `Fire > Forest > Wind > Earth > Thunder > Water > Fire` and `Dark > Light > Fiend > Dreams > Dark`; Divine has no configured edge.
- **ASSUMED:** A type/environment advantage favors the attacker, a disadvantage favors the defender, and an unconfigured pair is neutral.
- **NEEDS VERIFICATION:** Whether environment is always active, whether guardian-star and type/environment advantages stack, and the exact numerical effect/order in the original game.

## Magic, trap, ritual, and field effects

- **CONFIRMED:** The dataset preserves Magic, Trap, and Ritual categories and prose descriptions. The reference card list includes ritual descriptions involving tributes, traps that trigger when attacked, and spells that affect monsters or fields.
- **ASSUMED:** Spell/trap cards can occupy the spell/trap zone and remain separate from monster combat state.
- **NEEDS VERIFICATION:** Effect timing, targeting, activation costs, chains/responses, ritual materials, field-card rules, continuous effects, and whether any modern chain/priority concept applies. No such modern behavior is implemented or implied here.

## Deck capacity, progression, and rewards

- **CONFIRMED:** The supplied card-list FAQ says dueling can earn Domino, Deck Capacity, Duelist Level, a Card Locator, and a card; it also describes Deck Capacity as affecting whether high-capacity cards can temporarily be played.
- **CONFIRMED:** The FAQ says Duelist Level indicates progression through dueling and that a Card Locator is obtained by fighting special duelists.
- **CONFIRMED:** The FAQ describes an ante choice where selecting one of the player's cards can yield a card from the opponent, with rarer ante cards potentially yielding rarer rewards.
- **NEEDS VERIFICATION:** Numeric deck-capacity formulas, progression thresholds, duelist rewards, card-locator behavior, ante legality, ante ownership transfer, rarity rules, and loss/win reward details.

## Victory, defeat, and special wins

- **ASSUMED:** A player is defeated when life points reach zero or below.
- **ASSUMED:** Empty-deck defeat is disabled until the original draw/deck-out behavior is verified.
- **CONFIRMED FROM CARD DATA:** Exodia component descriptions state that gathering all five cards in hand wins, so special-win effects exist in the source text.
- **NEEDS VERIFICATION:** Whether Exodia and other described effects are implemented as automatic victory conditions, how simultaneous victory/defeat resolves, and whether there are other story-specific victory conditions.

## Source cross-check

- `docs/DATA_SCHEMA.md` — repository analysis of all 900 JSON records and their sentinels.
- `docs/RULE_ASSUMPTIONS.md` — implementation assumptions currently represented by rules and battle code.
- `resources/sacred_cards_rules.tres` — configurable baseline LP, deck, zone, draw, summon, attack, and defeat settings.
- `resources/sacred_cards_matchups.tres` — editable type/environment and guardian-star relationships.
- `data/raw/type_matchup_rules_source.zip` — supplied matchup source used for SC-202.
- [`Yu-Gi-Oh! The Sacred Cards - Card List - Game Boy Advance - By Griffin_Knight - GameFAQs.pdf`](../reference/Yu-Gi-Oh!%20The%20Sacred%20Cards%20-%20Card%20List%20-%20Game%20Boy%20Advance%20-%20By%20Griffin_Knight%20-%20GameFAQs.pdf) — card-list FAQ, version 1.1 dated 2003-12-21; page 1 provides the progression/ante overview, and pages 2 onward provide card fields and descriptions.

No modern TCG rules are introduced here unless explicitly labeled `ASSUMED` and represented by a current configurable resource or implementation note.
