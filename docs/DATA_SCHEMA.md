# Card Data Schema

## Recommendation

**REUSE VIA ADAPTER.** The supplied records are complete and consistent enough to remain the source dataset, but their field names and sentinel values should be translated into runtime-facing `CardDefinition` fields. The runtime should not depend on filenames or source wiki links, and it should not treat the prose description as a structured effect implementation.

## Sources inspected

- `data/cards_json/` — 900 extracted JSON records.
- `data/raw/original_card_json_dump.zip` — 900 JSON records plus 900 macOS metadata entries under `__MACOSX/`.
- The extracted records and raw archive records have identical filenames and byte content across all 900 cards.
- Representative monster, magic, trap, and ritual records were inspected, including IDs 1, 301, 683, and 692.

## Record shape

Every record contains exactly these 13 keys. JSON types and observed meanings are summarized below.

| Source key | JSON type | Observed values / range | Runtime adapter note |
|---|---|---|---|
| `id` | integer | `1..900`; all 900 unique | Required stable `card_id`. |
| `card` | string | 895 unique display names | Map to `display_name`; do not use as an ID. |
| `link` | string | Relative source wiki paths | Preserve as optional source metadata; runtime should not fetch it. |
| `dc` | integer | `0..585`; 34 records are `0` | Preserve as `source_dc` until its Sacred Cards meaning is confirmed. |
| `card_type` | string | `Monster` 773, `Magic` 83, `Trap` 19, `Ritual` 25 | Map to a runtime card category. |
| `monsterType` | string or null | `Normal Monster`, `Effect Monster`, `Ritual Monster`; null for 127 non-monsters | Map to `monster_subtype`; retain the source spelling in the adapter. |
| `type` | string or null | 20 monster types including Dragon, Fiend, Warrior, and Zombie; null for 127 non-monsters | Treat as source monster type/race metadata, not as the broad card category. |
| `alignment` | string or null | 11 values: Dark, Divine, Dreams, Earth, Fiend, Fire, Forest, Light, Thunder, Water, Wind; null for 127 non-monsters | Preserve as a Sacred Cards alignment enum/string. |
| `level` | integer | `0..12`; non-monsters use `0` | `0` is a source sentinel, not a missing JSON field. |
| `atk` | integer | `0..5000`; non-monsters use `0` | Map to attack; some monsters also legitimately have `0` attack in the source. |
| `def` | integer | `0..5000`; non-monsters use `0` | Map to defense; some monsters also legitimately have `0` defense in the source. |
| `password` | integer or null | 893 numeric values; 7 null values | Keep nullable; do not invent passwords for the seven null records. |
| `description` | string | Length `82..131`; 898 contain an actual line break | Preserve as source text. It is not a normalized effect schema. |

### Enumerated values

`monsterType` values are `Effect Monster`, `Normal Monster`, and `Ritual Monster`.

`type` values are `Aqua`, `Beast`, `Beast-Warrior`, `Dinosaur`, `Dragon`, `Fairy`, `Fiend`, `Fish`, `Insect`, `Machine`, `Plant`, `Pyro`, `Reptile`, `Rock`, `Sea Serpent`, `Spellcaster`, `Thunder`, `Warrior`, `Winged Beast`, and `Zombie`.

## Data quality findings

- All 900 files parse successfully. There are no missing required keys among `id`, `card`, `card_type`, and `description`.
- IDs are unique, cover `1..900`, and match the numeric prefix of every filename. No duplicate IDs were found.
- Five display names occur twice under different IDs: `Blue-Eyes White Dragon`, `Dark Magician`, `Blue-Eyes Ultimate Dragon`, `Red-Eyes Black Metal Dragon`, and `Red-Eyes B. Dragon`. Name-based lookups must therefore return or select by ID.
- Seven records have a null `password`: IDs `832`, `833`, `834`, `866`, `884`, `885`, and `887`. This appears to be source metadata absence, not a parse failure.
- Non-monster records use null `monsterType`, `type`, and `alignment`, plus zero `level`, `atk`, and `def`. These are source sentinels and should be represented explicitly by the adapter.
- Twelve monster records have a zero combat stat in the supplied data: IDs `72`, `96`, `97`, `98`, `362`, `366`, `730`, `731`, `733`, `734`, `768`, and `828`. Do not convert zero to null without a rules decision.
- Descriptions are prose rather than structured effects. Some contain compressed wording or typos, such as the description for `Turtle Oath`; effect behavior needs separate normalization and rule verification.
- The raw archive includes macOS resource-fork metadata. Only `cards_json/*.json` should be imported; `__MACOSX/` is not card data.

## Adapter guidance for SC-102

Keep the original JSON files unchanged and load them through a boundary that validates required keys and converts source names to typed runtime fields. A future `CardDefinition` should hold canonical, immutable card data; duel state such as current position, face-up state, damage, or temporary effects must live elsewhere. Preserve unresolved source fields such as `dc`, `link`, and the original description as metadata until later stories establish their exact game meaning.
