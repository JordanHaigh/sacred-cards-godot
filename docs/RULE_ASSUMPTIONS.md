# Sacred Cards Rule Assumptions

Use CONFIRMED / ASSUMED / NEEDS VERIFICATION labels for uncertain mechanics.

## SC-201 DuelRuleSet

- **ASSUMED:** Starting LP is 8,000, the opening hand is 5 cards, the configured starting deck size is 40, and each player has 5 monster zones, 5 spell/trap zones, and 1 field zone.
- **ASSUMED:** The first player does not draw on their first turn; later turns draw 1 card.
- **ASSUMED:** A player may perform 1 normal summon per turn. Level 5–6 monsters require 1 tribute and level 7+ monsters require 2 tributes.
- **ASSUMED:** A direct attack is legal only when the defending monster field is empty, and direct-attack damage uses the attacker's ATK.
- **ASSUMED:** A player loses when LP reaches 0 or below. Empty-deck defeat is disabled until the exact Sacred Cards draw/deck-out behavior is verified.
- **NEEDS VERIFICATION:** Sacred Cards-specific draw timing, summon/tribute edge cases, deck-out behavior, and exceptions to direct attacks.
- **CONFIRMED:** Type, attribute, and guardian-star matchup data live in the separate SC-202 matchup resource rather than inside the general DuelRuleSet.

## SC-202 Matchup Source

- **CONFIRMED FROM USER-SUPPLIED `Archive.zip`:** Dragon, Warrior, Beast-Warrior, Winged Beast, Fiend, Insect, Dinosaur, Fish, Sea Serpent, Thunder, Aqua, Rock, Plant, and Spellcaster have the listed environment advantages; Fairy, Machine, and Pyro have the listed environment disadvantages.
- **CONFIRMED FROM USER-SUPPLIED `Archive.zip`:** Guardian-star superiority follows `Fire > Forest > Wind > Earth > Thunder > Water > Fire` and `Dark > Light > Fiend > Dreams > Dark`. Divine has no configured superiority edge.
- **ASSUMED:** The source archive's `Magician` label maps to the dataset's `Spellcaster` type; `Pyro`, `Aqua`, and `Shadow` map to the dataset's `Fire`, `Water`, and `Dark` alignment labels.
- **ASSUMED:** An explicit type/environment advantage resolves as attacker advantage, an explicit disadvantage resolves as defender advantage, and unconfigured pairs are neutral.
- **NEEDS VERIFICATION:** Exact battle-stat scaling and the interaction order between environment effects and guardian-star superiority belong in later battle-resolution rules.
