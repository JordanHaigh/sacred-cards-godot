//! Literal game data exported by the AY7E decompilation.
//!
//! This module translates the exported files into host data structures. It does
//! not treat a recovered table or semantic C listing as proof of full runtime
//! equivalence. Native addresses in comments refer to the supplied AY7E build.

use serde::Deserialize;
use std::collections::HashMap;
use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};

pub const CARD_COUNT: usize = 901;
pub const OPPONENT_COUNT: usize = 200;
pub const DECK_SIZE: usize = 40;

#[derive(Clone, Debug, Deserialize)]
pub struct Card {
    pub id: u16,
    pub name: String,
    pub attack: u16,
    pub defense: u16,
    pub cost: u32,
    #[serde(rename = "type")]
    pub type_id: u8,
    /// The exported `summon` column is the native attribute, not a summon rule.
    pub summon: u8,
    pub level: u8,
    pub frame: u8,
    pub metadata_1a: u8,
    pub metadata_1b: u8,
    pub metadata_1c: u8,
    pub metadata_1d: u8,
    pub type_name: String,
    pub summon_name: String,
    pub base_shop_price: u64,
    #[serde(default)]
    pub description: String,
    #[serde(default)]
    pub description_markup: String,
}

impl Card {
    /// card_metadata.c 08006CB4 only modifies stats for metadata 1A == 2.
    pub fn is_monster(&self) -> bool {
        self.id != 0 && self.metadata_1a == 2
    }

    /// gCardTypeClasses[22] == 3; types 21/23 are spell/ritual categories.
    pub fn is_trap(&self) -> bool {
        self.id != 0 && self.type_id == 22
    }

    /// shop.c 08007414: stock 1..=250; multiplication has native u64 wrap.
    pub fn buy_price(&self, stock: u8) -> u64 {
        if !(1..=250).contains(&stock) {
            return 0;
        }
        (self.base_shop_price.wrapping_mul(251 - u64::from(stock)) / 250).max(1)
    }

    /// shop.c 08007470 deliberately uses base / 500 for stock >= 250.
    pub fn sell_price(&self, stock: u8) -> u64 {
        let price = if stock < 250 {
            self.base_shop_price.wrapping_mul(250 - u64::from(stock))
        } else {
            self.base_shop_price
        };
        (price / 500).max(1)
    }
}

#[derive(Clone, Debug, Deserialize)]
pub struct RewardEntry {
    pub card_id: u16,
    pub threshold: u16,
}

#[derive(Clone, Debug)]
pub struct Opponent {
    pub id: usize,
    /// A slot label: the asset export does not establish character names.
    pub name: String,
    pub identifier: u32,
    pub terrain: u8,
    pub deck: Vec<u16>,
    pub starting_lp: [u32; 2],
    pub capacity_reward: u32,
    /// Minimum possible money award, retained for simple UI previews.
    pub money_reward: u64,
    pub money_min: u16,
    pub money_max: u16,
    pub money_scale: u8,
    pub music: u16,
    pub normal_rewards: Vec<RewardEntry>,
    pub shop_rewards: Vec<RewardEntry>,
    pub special_rewards: Vec<RewardEntry>,
}

impl Opponent {
    /// duel_rewards.c 080164EC: exponents outside 1..=15 mean a factor of 1.
    pub fn money_for_roll(&self, roll: u16) -> u64 {
        let factor = if (1..=15).contains(&self.money_scale) {
            10u64.pow(u32::from(self.money_scale))
        } else {
            1
        };
        u64::from(roll).wrapping_mul(factor)
    }
}

#[derive(Clone, Debug)]
pub struct Database {
    pub asset_root: PathBuf,
    pub cards: Vec<Card>,
    pub initial_deck: Vec<u16>,
    pub opponents: Vec<Opponent>,
    pub terrain: Vec<Vec<u8>>,
    pub attribute_beats: Vec<u8>,
    pub attribute_loses_to: Vec<u8>,
    pub initial_collection: Vec<u8>,
    pub initial_shop_stock: Vec<u8>,
    pub level_thresholds: Vec<u16>,
    pub special_wager_cards: Vec<u16>,
    tributes_by_level: Vec<u8>,
    effect_immune_cards: Vec<u16>,
    equipment_targets: HashMap<u16, Vec<u16>>,
    copy_limits: Vec<u8>,
}

#[derive(Deserialize)]
struct CardText {
    id: u16,
    description_markup: String,
}

#[derive(Deserialize)]
struct OpponentManifest {
    records: Vec<OpponentRecord>,
    reward_tables: HashMap<String, RewardTable>,
    special_wager_cards: Vec<u16>,
}

#[derive(Deserialize)]
struct OpponentRecord {
    index: usize,
    identifier: u32,
    record_file: String,
    deck: Vec<u16>,
    deck_capacity_reward: u32,
    money_roll_bounds: [u16; 2],
    money_decimal_scale: u8,
    duel_music: u16,
    reward_tables: HashMap<String, String>,
}

#[derive(Deserialize)]
struct RewardTable {
    entries: Vec<RewardEntry>,
}

#[derive(Deserialize)]
struct EffectRules {
    equipment: Vec<EquipmentRule>,
}

#[derive(Deserialize)]
struct EquipmentRule {
    card_id: u16,
    eligible_card_ids: Vec<u16>,
}

impl Database {
    pub fn load(asset_root: impl AsRef<Path>) -> Result<Self, String> {
        let asset_root = asset_root.as_ref().to_path_buf();
        let mut reader = csv::Reader::from_path(asset_root.join("gameplay/cards.csv"))
            .map_err(|e| format!("Cannot read gameplay/cards.csv: {e}"))?;
        let mut cards: Vec<Card> = reader
            .deserialize()
            .collect::<Result<_, _>>()
            .map_err(|e| format!("Invalid gameplay/cards.csv: {e}"))?;
        cards.sort_by_key(|card| card.id);
        if cards.len() != CARD_COUNT
            || cards
                .iter()
                .enumerate()
                .any(|(i, card)| usize::from(card.id) != i)
        {
            return Err("Card export must contain each numeric ID 0..=900 exactly once".into());
        }
        for card in &cards {
            if card.type_id >= 24 || card.summon >= 12 || card.level >= 13 {
                return Err(format!(
                    "Card {} has invalid type, attribute or level",
                    card.id
                ));
            }
        }
        let mut descriptions = csv::Reader::from_path(asset_root.join("cards.csv"))
            .map_err(|e| format!("Cannot read card descriptions: {e}"))?;
        let mut seen = vec![false; CARD_COUNT];
        for row in descriptions.deserialize::<CardText>() {
            let row = row.map_err(|e| format!("Invalid card description row: {e}"))?;
            let id = usize::from(row.id);
            if id >= CARD_COUNT || seen[id] {
                return Err("Invalid or duplicate ID in card descriptions".into());
            }
            seen[id] = true;
            cards[id].description = description_text(&row.description_markup);
            cards[id].description_markup = row.description_markup;
        }
        if seen.iter().any(|&found| !found) {
            return Err("Card descriptions do not cover all 901 cards".into());
        }

        let initial_deck = read_u16s(&asset_root, "gameplay/initial-deck.bin", DECK_SIZE)?;
        validate_deck(&initial_deck, "initial deck")?;
        let manifest: OpponentManifest = read_json(&asset_root.join("opponents/manifest.json"))?;
        if manifest.records.len() != OPPONENT_COUNT {
            return Err("Opponent export must contain exactly 200 records".into());
        }
        let mut opponents = Vec::with_capacity(OPPONENT_COUNT);
        for record in &manifest.records {
            if record.index != opponents.len() {
                return Err("Opponent records are not in numeric order".into());
            }
            validate_deck(&record.deck, &format!("opponent {}", record.index))?;
            let raw = read_exact_size(
                &asset_root,
                &format!("opponents/{}", record.record_file),
                40,
            )?;
            // duel_flow.c 08017CA8 reads +14/+16; InitializeDuelBoard reads byte +02.
            let terrain = raw[2];
            if terrain >= 7 {
                return Err(format!(
                    "Opponent {} has invalid terrain {terrain}",
                    record.index
                ));
            }
            let rewards = |kind: &str| -> Result<Vec<RewardEntry>, String> {
                let key = record.reward_tables.get(kind).ok_or_else(|| {
                    format!("Opponent {} has no {kind} reward table", record.index)
                })?;
                let table = manifest
                    .reward_tables
                    .get(key)
                    .ok_or_else(|| format!("Missing reward table {key}"))?;
                if table.entries.is_empty() || table.entries.last().unwrap().card_id != 0 {
                    return Err(format!("Reward table {key} has no terminator"));
                }
                if table
                    .entries
                    .iter()
                    .any(|entry| usize::from(entry.card_id) >= CARD_COUNT)
                {
                    return Err(format!("Reward table {key} contains an invalid card"));
                }
                Ok(table.entries.clone())
            };
            let mut opponent = Opponent {
                id: record.index,
                name: format!("Opponent {:03}", record.index),
                identifier: record.identifier,
                terrain,
                deck: record.deck.clone(),
                starting_lp: [
                    u32::from(u16::from_le_bytes([raw[20], raw[21]])),
                    u32::from(u16::from_le_bytes([raw[22], raw[23]])),
                ],
                capacity_reward: record.deck_capacity_reward,
                money_reward: 0,
                money_min: record.money_roll_bounds[0],
                money_max: record.money_roll_bounds[1],
                money_scale: record.money_decimal_scale,
                music: record.duel_music,
                normal_rewards: rewards("normal")?,
                shop_rewards: rewards("shop")?,
                special_rewards: rewards("special")?,
            };
            opponent.money_reward = opponent.money_for_roll(opponent.money_min);
            opponents.push(opponent);
        }

        let terrain_bytes = read_exact_size(&asset_root, "gameplay/terrain-modifiers.bin", 7 * 24)?;
        let terrain = terrain_bytes
            .as_chunks::<24>()
            .0
            .iter()
            .map(|row| row.to_vec())
            .collect();
        let effect_rules: EffectRules = read_json(&asset_root.join("gameplay/effect-rules.json"))?;
        let mut equipment_targets = HashMap::new();
        for rule in effect_rules.equipment {
            let mut targets = rule.eligible_card_ids;
            targets.sort_unstable();
            targets.dedup();
            equipment_targets.insert(rule.card_id, targets);
        }

        // deck_builder_state.c 08015868; list termination is checked before matching.
        let mut copy_limits = vec![3; CARD_COUNT];
        copy_limits[0] = 0;
        for id in native_u16_list(&asset_root, 0x080B4B34)? {
            copy_limits[usize::from(id)] = 2;
        }
        for id in native_u16_list(&asset_root, 0x080B4B1C)? {
            copy_limits[usize::from(id)] = 1;
        }

        Ok(Self {
            attribute_beats: read_exact_size(&asset_root, "gameplay/attribute_beats.bin", 12)?,
            attribute_loses_to: read_exact_size(
                &asset_root,
                "gameplay/attribute_loses_to.bin",
                12,
            )?,
            initial_collection: read_exact_size(
                &asset_root,
                "runtime/initial-collection.bin",
                CARD_COUNT,
            )?,
            initial_shop_stock: read_exact_size(
                &asset_root,
                "runtime/initial-shop-stock.bin",
                CARD_COUNT,
            )?,
            level_thresholds: read_u16s(
                &asset_root,
                "gameplay/level-capacity-thresholds.bin",
                1000,
            )?,
            tributes_by_level: read_exact_size(&asset_root, "gameplay/tributes-by-level.bin", 13)?,
            effect_immune_cards: read_u16s(&asset_root, "gameplay/effect-immunity.bin", 4)?
                .into_iter()
                .take_while(|&id| id != 0)
                .collect(),
            // UsesNormalRewardTable stops at the zero terminator before matching it.
            special_wager_cards: manifest
                .special_wager_cards
                .into_iter()
                .take_while(|&id| id != 0)
                .collect(),
            asset_root,
            cards,
            initial_deck,
            opponents,
            terrain,
            equipment_targets,
            copy_limits,
        })
    }

    pub fn card(&self, id: u16) -> &Card {
        &self.cards[usize::from(id)]
    }

    pub fn opponent(&self, id: usize) -> &Opponent {
        &self.opponents[id]
    }

    /// card_metadata.c 08006CB4: terrain is applied before the signed stage.
    pub fn stats(&self, id: u16, terrain: u8, stage: i8) -> (u16, u16) {
        let card = self.card(id);
        if !card.is_monster() {
            return (card.attack, card.defense);
        }
        let modifier = self.terrain[usize::from(terrain)][usize::from(card.type_id)];
        (
            apply_stat_stage(apply_terrain_modifier(card.attack, modifier), stage),
            apply_stat_stage(apply_terrain_modifier(card.defense, modifier), stage),
        )
    }

    /// summon_rules.c 08028414 does not classify before looking up the level.
    pub fn tributes(&self, id: u16) -> usize {
        usize::from(self.tributes_by_level[usize::from(self.card(id).level)])
    }

    pub fn effect_immune(&self, id: u16) -> bool {
        self.effect_immune_cards.contains(&id)
    }

    pub fn equipment_compatible(&self, equipment_id: u16, monster_id: u16) -> bool {
        self.equipment_targets
            .get(&equipment_id)
            .is_some_and(|targets| targets.binary_search(&monster_id).is_ok())
    }

    pub fn copy_limit(&self, id: u16) -> u8 {
        self.copy_limits[usize::from(id)]
    }

    pub fn description(&self, id: u16) -> &str {
        &self.card(id).description
    }
}

/// card_stats.c 08006DA0 clamps after signed 500-point increments.
pub fn apply_stat_stage(stat: u16, stage: i8) -> u16 {
    (i32::from(stat) + i32::from(stage) * 500).clamp(0, 65_534) as u16
}

/// card_stats.c 08006DD4: binary64 scaling, truncate, wrap to u16, then cap.
pub fn apply_terrain_modifier(stat: u16, modifier: u8) -> u16 {
    match modifier {
        1 => ((f64::from(stat) * f64::from_bits(0x3FE6666666666666)) as u32) as u16,
        3 => {
            let wrapped = ((f64::from(stat) * f64::from_bits(0x3FF4CCCCCCCCCCCD)) as u32) as u16;
            if wrapped > 65_533 {
                65_534
            } else {
                wrapped
            }
        }
        _ => stat,
    }
}

fn read_json<T: serde::de::DeserializeOwned>(path: &Path) -> Result<T, String> {
    let bytes = fs::read(path).map_err(|e| format!("Cannot read {}: {e}", path.display()))?;
    serde_json::from_slice(&bytes).map_err(|e| format!("Invalid {}: {e}", path.display()))
}

fn read_exact_size(root: &Path, name: &str, size: usize) -> Result<Vec<u8>, String> {
    let bytes = fs::read(root.join(name)).map_err(|e| format!("Cannot read {name}: {e}"))?;
    if bytes.len() != size {
        return Err(format!(
            "{name}: expected {size} bytes, found {}",
            bytes.len()
        ));
    }
    Ok(bytes)
}

fn read_u16s(root: &Path, name: &str, count: usize) -> Result<Vec<u16>, String> {
    Ok(read_exact_size(root, name, count * 2)?
        .as_chunks::<2>()
        .0
        .iter()
        .map(|pair| u16::from_le_bytes([pair[0], pair[1]]))
        .collect())
}

fn validate_deck(deck: &[u16], name: &str) -> Result<(), String> {
    if deck.len() != DECK_SIZE || deck.iter().any(|&id| usize::from(id) >= CARD_COUNT) {
        return Err(format!("{name} must contain 40 valid card IDs"));
    }
    Ok(())
}

fn native_u16_list(root: &Path, address: u64) -> Result<Vec<u16>, String> {
    // rom-data/manifest.json preserves [0803B61C,09000000), including these lists.
    let mut file = File::open(root.join("rom-data/original-data.bin"))
        .map_err(|e| format!("Cannot read native copy-limit data: {e}"))?;
    file.seek(SeekFrom::Start(address - 0x0803B61C))
        .map_err(|e| format!("Cannot seek native copy-limit data: {e}"))?;
    let mut ids = Vec::new();
    for _ in 0..CARD_COUNT {
        let mut bytes = [0; 2];
        file.read_exact(&mut bytes)
            .map_err(|e| format!("Truncated native copy-limit list: {e}"))?;
        let id = u16::from_le_bytes(bytes);
        if id == 0 {
            return Ok(ids);
        }
        if usize::from(id) >= CARD_COUNT {
            return Err("Invalid native copy-limit card ID".into());
        }
        ids.push(id);
    }
    Err("Unterminated native copy-limit list".into())
}

fn description_text(markup: &str) -> String {
    // card_presentation.c 080070D4/ShowCardDescription uses a 12-glyph first row,
    // then 14-glyph rows. Preserve the raw markup separately for native rendering.
    // Native ASCII '%' and ',' both point to glyph 8143 at 080B7180.
    let decoded = markup.replace("\\x81h", "\"").replace('%', ",");
    let content =
        if decoded.starts_with('^') && decoded.as_bytes().get(1).is_some_and(u8::is_ascii_digit) {
            &decoded[2..]
        } else {
            &decoded
        };
    let mut lines = Vec::new();
    for page in content.split('^').filter(|page| !page.is_empty()) {
        let glyphs: Vec<char> = page.chars().collect();
        let first = glyphs.len().min(12);
        lines.push(glyphs[..first].iter().collect::<String>());
        for row in glyphs[first..].chunks(14) {
            lines.push(row.iter().collect());
        }
    }
    lines
        .iter()
        .map(|line| line.trim())
        .filter(|line| !line.is_empty())
        .collect::<Vec<_>>()
        .join(" ")
}

#[cfg(test)]
mod tests {
    use super::*;

    fn database() -> Database {
        Database::load(
            Path::new(env!("CARGO_MANIFEST_DIR")).join("sacred-cards-decompiled/build/assets"),
        )
        .expect("Supplied native asset exports must load")
    }

    #[test]
    fn numeric_card_order_and_native_metadata_are_preserved() {
        let db = database();
        assert_eq!(db.cards.len(), 901);
        for (id, card) in db.cards.iter().enumerate() {
            assert_eq!(usize::from(card.id), id);
        }
        assert_eq!(db.card(1).name, "Blue-Eyes White Dragon");
        assert_eq!(
            (db.card(1).attack, db.card(1).defense, db.card(1).cost),
            (3000, 2500, 95)
        );
        assert!(db.card(1).is_monster());
        assert!(!db.card(0).is_monster());
        assert_eq!(db.card(0).attack, 65535); // Empty-card sentinel, not a monster.
        assert!(!db.card(336).is_monster());
        assert_eq!(db.card(336).name, "Dark Hole");
        assert!(db.card(686).is_trap()); // Widespread Ruin: type 22/category 3.
        assert!(!db.card(670).is_trap()); // Black Luster Ritual: type 23/category 4.
    }

    #[test]
    fn native_decks_rewards_and_limits_load_without_synthetic_cards() {
        let db = database();
        assert_eq!(db.initial_deck.len(), 40);
        assert_eq!(db.initial_deck[0], 794); // gInitialDeck at 080EBAF0.
        assert_eq!(db.opponents.len(), 200);
        assert_eq!(&db.opponent(1).deck[..4], &[17, 18, 19, 20]);
        assert_eq!(db.opponent(1).starting_lp, [8000, 8000]);
        assert_eq!(db.opponent(1).money_for_roll(2000), 2000);
        assert_eq!(db.opponent(2).money_for_roll(7000), 70000);
        assert_eq!(db.opponent(2).terrain, 6); // identifier 00060002, read byte 2.
        assert_eq!(
            (db.copy_limit(17), db.copy_limit(894), db.copy_limit(1)),
            (1, 2, 3)
        );
        assert!(db.effect_immune(832));
        assert!(!db.effect_immune(0));
        assert!(db.equipment_compatible(301, 12));
        assert!(!db.equipment_compatible(301, 1));
        assert_eq!((db.tributes(2), db.tributes(1)), (0, 2));
    }

    #[test]
    fn source_stat_order_signed_stage_and_u16_wrap_are_preserved() {
        assert_eq!(apply_stat_stage(300, -1), 0);
        assert_eq!(apply_stat_stage(65000, 2), 65534);
        assert_eq!(apply_terrain_modifier(1000, 1), 700);
        assert_eq!(apply_terrain_modifier(1000, 3), 1300);
        assert_eq!(apply_terrain_modifier(60000, 3), 12464); // wrap before cap.
        let db = database();
        let terrain = db.terrain.iter().position(|row| row[1] == 3).unwrap() as u8;
        assert_eq!(db.stats(1, terrain, -1), (3400, 2750));
        assert_eq!(db.stats(336, terrain, -1), (65535, 65535));
    }

    #[test]
    fn stock_pricing_and_description_rows_follow_source() {
        let db = database();
        let card = db.card(1);
        assert_eq!(card.buy_price(0), 0);
        assert_eq!(card.buy_price(1), 380);
        assert_eq!(card.buy_price(250), 1);
        assert_eq!(card.buy_price(251), 0);
        assert_eq!(card.sell_price(0), 190);
        assert_eq!(card.sell_price(250), 1);
        assert_eq!(db.description(1), "A legendary dragon that takes pride in its enormous power. Its powers of destruction far exceed comprehension.");
        assert!(db.description(2).contains("blue skin, yellow hair,"));
        assert!(db.description(583).contains("\"FINAL\""));
    }
}
