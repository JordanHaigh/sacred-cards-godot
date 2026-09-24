# Sacred Cards Effect Mapping

The runtime keeps effect handlers reusable and stores card-specific IDs and values in [`resources/card_effect_mappings.json`](../resources/card_effect_mappings.json). The supplied card JSON files remain unchanged.

The initial mappings below use effects whose action and numeric value are explicit in the supplied GameFAQs card-list reference (pages 44, 45, and 101). They do not claim that the full original game's timing and targeting rules are implemented.

| Card ID | Card | Effect ID | Parameters |
|---:|---|---|---|
| 338 | Mooyan Curry | `lp_heal` | Heal self by 200 LP |
| 339 | Red Medicine | `lp_heal` | Heal self by 500 LP |
| 340 | Goblin's Secret Remedy | `lp_heal` | Heal self by 1,000 LP |
| 341 | Soul of the Pure | `lp_heal` | Heal self by 2,000 LP |
| 342 | Dian Keto the Cure Master | `lp_heal` | Heal self by 5,000 LP |
| 343 | Sparks | `lp_damage` | Deal 50 LP damage to opponent |
| 344 | Hinotama | `lp_damage` | Deal 100 LP damage to opponent |
| 345 | Final Flame | `lp_damage` | Deal 200 LP damage to opponent |
| 346 | Oozaki | `lp_damage` | Deal 500 LP damage to opponent |
| 347 | Tremendous Fire | `lp_damage` | Deal 1,000 LP damage to opponent |
| 789 | Pot of Greed | `draw_cards` | Draw up to two cards |

The draw primitive draws up to the requested count and succeeds when at least one card is drawn. If the deck is empty it returns a visible failure. Healing is currently uncapped because the project's rule resource does not define a maximum LP value.

## Unmapped Cards

These 91 Magic and Trap cards in the supplied dataset do not yet have runtime effect mappings:

| IDs | Cards |
|---|---|
| 301-319 | Legendary Sword, Sword of Dark Destruction, Dark Energy, Axe of Despair, Laser Cannon Armor, Insect Armor with Laser Cannon, Elf's Light, Beast Fangs, Steel Shell, Vile Germs, Black Pendant, Silver Bow and Arrow, Horn of Light, Horn of the Unicorn, Dragon Treasure, Electro-Whip, Cyber Shield, Elegant Egotist, Mystical Moon |
| 320-337 | Stop Defense, Malevolent Nuzzler, Violet Crystal, Book of Secret Arts, Invigoration, Machine Conversion Factory, Raise Body Heat, Follow Wind, Power of Kaishin, Dragon Capture Jar, Forest, Wasteland, Mountain, Sogen, Umi, Yami, Dark Hole, Raigeki |
| 348-350 | Swords of Revealing Light, Spellbinding Circle, Dark-Piercing Light |
| 583-587 | Destiny Board, Spirit Message "I", Spirit Message "N", Spirit Message "A", Spirit Message "L" |
| 651-664 | Kunai with Chain, Magical Labyrinth, Warrior Elimination, Salamandra, Cursebreaker, Eternal Rest, Megamorph, Metalmorph, Winged Trumpeter, Stain Storm, Crush Card, Eradicating Aerosol, Breath of Light, Eternal Drought |
| 668-690 | Bright Castle, Shadow Spell, Harpie's Feather Duster, House of Adhesive Tape, Eatgaboon, Bear Trap, Invisible Wire, Acid Trap Hole, Widespread Ruin, Goblin Fan, Bad Reaction to Simochi, Reverse Trap, Fake Trap |
| 781-790 | Brain Control, Anti Raigeki, Change of Heart, Multiply, Exile of the Wicked, Last Day of Witch, Restructer Revolution, The Inexperienced Spy |
| 870, 891-900 | Amazon Archers, Messenger of Peace, Darkness Approaches, Final Destiny, Heavy Storm, Monster Reborn, Gravedigger Ghoul, Torrential Tribute, Beckon to Darkness, Infinite Dismissal, 7 Completed |

Most unmapped descriptions depend on a target filter, field-wide operation, duration, trigger, control change, hidden information, ritual, or unique multi-card condition. They remain unmapped rather than being approximated by a superficially similar primitive.

## Verification

`tests/test_card_effect_mappings.gd` checks that every sidecar card ID exists in the supplied database, each effect is registered, and the number of mapped cards matches this report. Run it with the project's Godot 4.x executable when available.
