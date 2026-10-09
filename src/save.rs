//! Persistent player state, with native starting values and economy rules.
//!
//! `collection` records total ownership INCLUDING cards in the deck. The native
//! RAM collection is the reserve, so native collection/stock arithmetic is
//! applied to `owned - deck_count`. Save files are versioned JSON, validated on
//! load and written through a synced temporary file in the same directory.

use crate::data::{Database, RewardEntry};
use serde::{Deserialize, Serialize};
use std::io::Write;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};

pub const MONEY_LIMIT: u64 = 9_999_999_999_999;
const CARD_COUNT: usize = 901;
const FLAG_COUNT: usize = 400;
fn initial_version() -> u16 {
    1
}
fn initial_rank() -> u8 {
    1
}
fn initial_rng() -> u64 {
    1
}
fn unused_bonus_passwords() -> Vec<bool> {
    vec![false; 10]
}

#[derive(Debug, Clone, Serialize, Deserialize, PartialEq, Eq)]
pub struct Profile {
    #[serde(default = "initial_version")]
    pub version: u16,
    pub name: String,
    pub deck: Vec<u16>,
    pub collection: Vec<u16>,
    pub money: u64,
    pub capacity: u32,
    pub level: u32,
    pub scene: usize,
    pub variant: usize,
    pub x: i32,
    pub y: i32,
    pub wins: u32,
    pub losses: u32,
    pub flags: Vec<bool>,
    #[serde(default)]
    pub shop_stock: Vec<u8>,
    #[serde(default = "initial_rng")]
    pub rng_state: u64,
    #[serde(default)]
    pub wagered_card: u16,
    #[serde(default = "initial_rank")]
    pub progress_rank: u8,
    #[serde(default = "unused_bonus_passwords")]
    pub used_bonus_passwords: Vec<bool>,
}

impl Profile {
    /// Source: new_game.c 08006314, currency.c 08019C58, and
    /// overworld.c 080300E0. A host-readable name is chosen at name entry.
    pub fn new(db: &Database) -> Self {
        let mut collection: Vec<u16> = db.initial_collection.iter().map(|&n| n as u16).collect();
        collection.resize(CARD_COUNT, 0);
        let deck = db.initial_deck.clone();
        for &id in &deck {
            if let Some(count) = collection.get_mut(id as usize) {
                *count += 1;
            }
        }
        Self {
            version: 1,
            name: "Player".into(),
            deck,
            collection,
            money: 500,
            capacity: 1600,
            level: 72,
            scene: 28,
            variant: 0,
            x: 52,
            y: 48,
            wins: 0,
            losses: 0,
            flags: vec![false; FLAG_COUNT],
            shop_stock: db.initial_shop_stock.clone(),
            rng_state: initial_rng(),
            wagered_card: 0,
            progress_rank: 1,
            used_bonus_passwords: unused_bonus_passwords(),
        }
    }

    pub fn load(path: impl AsRef<Path>, db: &Database) -> Result<Self, String> {
        let path = path.as_ref();
        let bytes =
            std::fs::read(path).map_err(|e| format!("Cannot load {}: {e}", path.display()))?;
        if bytes.len() > 2_000_000 {
            return Err("Save is too large".into());
        }
        let mut profile: Self =
            serde_json::from_slice(&bytes).map_err(|e| format!("Invalid save: {e}"))?;
        // The stock field was added in save format v1 before its first release.
        if profile.shop_stock.is_empty() {
            profile.shop_stock = db.initial_shop_stock.clone();
        }
        profile.validate_storage(db)?;
        if profile.rng_state == 0 {
            profile.rng_state = initial_rng();
        }
        Ok(profile)
    }

    pub fn save(&self, path: impl AsRef<Path>) -> Result<(), String> {
        static SERIAL: AtomicU64 = AtomicU64::new(0);
        let path = path.as_ref();
        let parent = path
            .parent()
            .filter(|p| !p.as_os_str().is_empty())
            .unwrap_or_else(|| Path::new("."));
        std::fs::create_dir_all(parent)
            .map_err(|e| format!("Cannot create save directory: {e}"))?;
        let filename = path
            .file_name()
            .ok_or("Save path has no file name")?
            .to_string_lossy();
        let temporary = parent.join(format!(
            ".{filename}.{}.{}.tmp",
            std::process::id(),
            SERIAL.fetch_add(1, Ordering::Relaxed)
        ));
        let result = (|| {
            let bytes =
                serde_json::to_vec_pretty(self).map_err(|e| format!("Cannot encode save: {e}"))?;
            let mut file = std::fs::OpenOptions::new()
                .write(true)
                .create_new(true)
                .open(&temporary)
                .map_err(|e| format!("Cannot create temporary save: {e}"))?;
            file.write_all(&bytes)
                .map_err(|e| format!("Cannot write save: {e}"))?;
            file.sync_all()
                .map_err(|e| format!("Cannot sync save: {e}"))?;
            drop(file);
            std::fs::rename(&temporary, path).map_err(|e| format!("Cannot replace save: {e}"))?;
            // Persist the rename when the platform supports directory fsync.
            if let Ok(directory) = std::fs::File::open(parent) {
                let _ = directory.sync_all();
            }
            Ok(())
        })();
        if result.is_err() {
            let _ = std::fs::remove_file(&temporary);
        }
        result
    }

    fn validate_storage(&self, db: &Database) -> Result<(), String> {
        if self.version != 1 {
            return Err(format!("Unsupported save format {}", self.version));
        }
        if self.name.is_empty()
            || self.name.chars().count() > 18
            || self.name.chars().any(char::is_control)
        {
            return Err("Save contains an invalid player name".into());
        }
        if self.collection.len() != CARD_COUNT
            || self.shop_stock.len() != CARD_COUNT
            || self.flags.len() != FLAG_COUNT
            || self.used_bonus_passwords.len() != 10
        {
            return Err("Save contains invalid collection, stock, or event flags".into());
        }
        if self.deck.len() > 40
            || self
                .deck
                .iter()
                .any(|&id| id == 0 || id as usize >= db.cards.len())
        {
            return Err("Save contains an invalid deck".into());
        }
        if self.money > MONEY_LIMIT
            || self.capacity > 99999
            || self.level > 999
            || self.scene >= 58
            || self.variant >= 32
        {
            return Err("Save contains out-of-range player values".into());
        }
        if self.progress_rank & !63 != 0 || self.wagered_card as usize >= CARD_COUNT {
            return Err("Save contains invalid progression or ante state".into());
        }
        for id in 1..CARD_COUNT {
            let count = self.deck_count(id as u16);
            if self.collection[id] < count || self.collection[id] - count > 250 {
                return Err(format!("Save contains invalid ownership for card {id}"));
            }
        }
        Ok(())
    }

    pub fn deck_count(&self, id: u16) -> u16 {
        self.deck.iter().filter(|&&c| c == id).count() as u16
    }
    pub fn reserve_count(&self, id: u16) -> u16 {
        self.collection
            .get(id as usize)
            .copied()
            .unwrap_or(0)
            .saturating_sub(self.deck_count(id))
    }
    pub fn deck_cost(&self, db: &Database) -> u32 {
        self.deck
            .iter()
            .filter_map(|&id| db.cards.get(id as usize))
            .map(|card| card.cost)
            .sum()
    }
    pub fn validate_deck(&self, db: &Database) -> Result<(), String> {
        if self.deck.len() != 40 {
            return Err(format!(
                "A duel requires 40 cards; your deck has {}",
                self.deck.len()
            ));
        }
        for &id in &self.deck {
            let card = db
                .cards
                .get(id as usize)
                .filter(|_| id != 0)
                .ok_or("Deck contains an invalid card")?;
            if self.deck_count(id) > db.copy_limit(id) as u16 {
                return Err(format!("Too many copies of {}", card.name));
            }
            if self.collection.get(id as usize).copied().unwrap_or(0) < self.deck_count(id) {
                return Err(format!("You do not own every copy of {}", card.name));
            }
        }
        if self.deck_cost(db) > self.capacity {
            return Err(format!(
                "Deck cost {} exceeds capacity {}",
                self.deck_cost(db),
                self.capacity
            ));
        }
        Ok(())
    }
    pub fn add_to_deck(&mut self, db: &Database, id: u16) -> Result<(), String> {
        let card = db
            .cards
            .get(id as usize)
            .filter(|_| id != 0)
            .ok_or("Invalid card")?;
        if self.deck.len() >= 40 {
            return Err("The deck already has 40 cards".into());
        }
        if self.reserve_count(id) == 0 {
            return Err("No spare copy in your collection".into());
        }
        if self.wagered_card == id && self.reserve_count(id) == 1 {
            return Err("This card is reserved as your duel ante".into());
        }
        if self.deck_count(id) >= db.copy_limit(id) as u16 {
            return Err(format!(
                "{} permits at most {} copies",
                card.name,
                db.copy_limit(id)
            ));
        }
        // Native 08004558 tests individual card cost against Duelist Level.
        if card.cost > self.level {
            return Err(format!(
                "{} requires Duelist Level {}",
                card.name, card.cost
            ));
        }
        self.deck.push(id);
        Ok(())
    }
    pub fn remove_from_deck(&mut self, index: usize) -> Result<(), String> {
        if index >= self.deck.len() {
            return Err("Select a card in your deck".into());
        }
        let id = self.deck.remove(index);
        // Removing from the native deck view saturates the reserve at 250.
        let maximum = 250 + self.deck_count(id);
        self.collection[id as usize] = self.collection[id as usize].min(maximum);
        Ok(())
    }
    pub fn buy_price(&self, db: &Database, id: u16) -> u64 {
        db.cards
            .get(id as usize)
            .map(|c| c.buy_price(self.shop_stock.get(id as usize).copied().unwrap_or(0)))
            .unwrap_or(0)
    }
    pub fn sell_price(&self, db: &Database, id: u16) -> u64 {
        db.cards
            .get(id as usize)
            .map(|c| c.sell_price(self.shop_stock.get(id as usize).copied().unwrap_or(0)))
            .unwrap_or(0)
    }
    pub fn buy(&mut self, db: &Database, id: u16) -> Result<(), String> {
        if id == 0 || id as usize >= db.cards.len() {
            return Err("Invalid card".into());
        }
        let index = id as usize;
        let stock = self.shop_stock.get(index).copied().unwrap_or(0);
        if stock == 0 {
            return Err("This card is out of stock".into());
        }
        if stock > 250 {
            return Err("This card's stock value is invalid".into());
        }
        if self.reserve_count(id) >= 250 {
            return Err("Your collection already contains 250 spare copies".into());
        }
        let price = self.buy_price(db, id);
        if self.money < price {
            return Err(format!("You need {price} Domino to buy this card"));
        }
        self.money -= price;
        self.shop_stock[index] -= 1;
        self.collection[index] += 1;
        Ok(())
    }
    pub fn sell(&mut self, db: &Database, id: u16) -> Result<(), String> {
        if id == 0 || id as usize >= db.cards.len() {
            return Err("Invalid card".into());
        }
        if self.reserve_count(id) == 0 {
            return Err("Only spare collection cards can be sold".into());
        }
        if self.wagered_card == id && self.reserve_count(id) == 1 {
            return Err("This card is reserved as your duel ante".into());
        }
        let index = id as usize;
        let price = self.sell_price(db, id);
        self.money = self.money.saturating_add(price).min(MONEY_LIMIT);
        self.collection[index] -= 1;
        self.shop_stock[index] = self.shop_stock[index].saturating_add(1).min(250);
        Ok(())
    }
    pub fn set_wager(&mut self, id: u16) -> Result<(), String> {
        if id != 0 && self.reserve_count(id) == 0 {
            return Err("Ante must be a spare collection card".into());
        }
        self.wagered_card = id;
        Ok(())
    }
    /// password.c 0803428C. Card codes add a copy to SHOP stock; they do not
    /// give a free collection card. Bonus codes may only be applied once.
    pub fn redeem_password(&mut self, db: &Database, password: &str) -> Result<String, String> {
        #[derive(Deserialize)]
        struct PasswordFile {
            records: Vec<PasswordRecord>,
        }
        #[derive(Deserialize)]
        struct PasswordRecord {
            family: String,
            index: usize,
            kind: String,
            password: Option<String>,
        }
        let password = password.trim();
        if password.len() != 8 || !password.bytes().all(|c| c.is_ascii_digit()) {
            return Err("Enter exactly eight digits".into());
        }
        let bytes = std::fs::read(db.asset_root.join("passwords/manifest.json"))
            .map_err(|e| format!("Cannot load recovered password table: {e}"))?;
        let passwords: PasswordFile = serde_json::from_slice(&bytes)
            .map_err(|e| format!("Invalid recovered password table: {e}"))?;
        let record = passwords
            .records
            .iter()
            .find(|r| {
                r.family == "card"
                    && r.kind == "password"
                    && r.password.as_deref() == Some(password)
            })
            .or_else(|| {
                passwords.records.iter().find(|r| {
                    r.family == "bonus"
                        && r.kind == "password"
                        && r.password.as_deref() == Some(password)
                })
            })
            .ok_or("Password not recognized")?;
        if record.family == "card" {
            let id = record.index;
            if id == 0 || id >= self.shop_stock.len() || id >= db.cards.len() {
                return Err("Password card is unavailable".into());
            }
            self.shop_stock[id] = self.shop_stock[id].saturating_add(1).min(250);
            return Ok(format!("{} added to shop stock.", db.cards[id].name));
        }
        if self
            .used_bonus_passwords
            .get(record.index)
            .copied()
            .unwrap_or(true)
        {
            return Err("This bonus password has already been used".into());
        }
        self.used_bonus_passwords[record.index] = true;
        match record.index {
            1 => {
                self.money = self.money.saturating_add(50_000).min(MONEY_LIMIT);
                Ok("Bonus: +50,000 Domino.".into())
            }
            2 => {
                self.capacity = self.capacity.saturating_add(100).min(99999);
                while self.level < 999
                    && db
                        .level_thresholds
                        .get(self.level as usize + 1)
                        .is_some_and(|&n| n as u32 <= self.capacity)
                {
                    self.level += 1;
                }
                Ok("Bonus: +100 deck capacity.".into())
            }
            _ => Ok("Password accepted.".into()), // Native bonus index zero has no reward action.
        }
    }
    /// random.c 08034580..08034628. First generated byte is the high byte.
    /// State is shared across reward rolls and persisted in the profile.
    fn next_halfword(&mut self) -> u16 {
        let mut state = self.rng_state as u32;
        let mut result = 0u16;
        for _ in 0..16 {
            let bit = state >> 31;
            state = if bit != 0 {
                ((state ^ 0x10000).wrapping_shl(1)) | 1
            } else {
                state.wrapping_shl(1)
            };
            result = (result << 1) | bit as u16;
        }
        self.rng_state = state as u64;
        result
    }
    fn random(&mut self, maximum: u32) -> u32 {
        self.next_halfword() as u32 % (maximum + 1)
    }
    pub fn award_duel(&mut self, db: &Database, opponent_id: usize, won: bool) -> String {
        let Some(opponent) = db.opponents.get(opponent_id) else {
            return "Duel opponent record is unavailable".into();
        };
        if !won {
            self.losses = self.losses.saturating_add(1);
            let wager = std::mem::take(&mut self.wagered_card);
            if wager != 0 && self.reserve_count(wager) > 0 {
                self.collection[wager as usize] -= 1;
                return format!("Defeat. Lost ante: {}.", db.cards[wager as usize].name);
            }
            return "Defeat. Your record has been updated.".into();
        }
        self.wins = self.wins.saturating_add(1);
        let old_level = self.level;
        self.capacity = self
            .capacity
            .saturating_add(opponent.capacity_reward)
            .min(99999);
        while self.level < 999
            && db
                .level_thresholds
                .get(self.level as usize + 1)
                .is_some_and(|&n| n as u32 <= self.capacity)
        {
            self.level += 1;
        }
        let mut card_message = String::new();
        let wager = std::mem::take(&mut self.wagered_card);
        if wager != 0 {
            let table = if db.special_wager_cards.contains(&wager) {
                &opponent.special_rewards
            } else {
                &opponent.normal_rewards
            };
            let reward = pick_reward(table, self.random(2047) as u16);
            if reward > 0 && (reward as usize) < self.collection.len() {
                let maximum = 250 + self.deck_count(reward);
                self.collection[reward as usize] = self.collection[reward as usize]
                    .saturating_add(1)
                    .min(maximum);
                card_message = format!(" Card: {}.", db.cards[reward as usize].name);
            }
        }
        for _ in 0..50 {
            let id = pick_reward(&opponent.shop_rewards, self.random(29999) as u16) as usize;
            if id > 0 && id < self.shop_stock.len() {
                self.shop_stock[id] = self.shop_stock[id].saturating_add(1).min(250);
            }
        }
        // Native consumes a halfword even when money bounds are identical.
        let random = self.next_halfword() as i32;
        let span = opponent.money_max as i32 - opponent.money_min as i32 + 1;
        let money_roll =
            (opponent.money_min as i32 + if span == 0 { 0 } else { random % span }) as u16;
        let money = opponent.money_for_roll(money_roll);
        self.money = self.money.saturating_add(money).min(MONEY_LIMIT);
        let level_message = if self.level > old_level {
            format!(" Duelist Level {}!", self.level)
        } else {
            String::new()
        };
        format!(
            "Victory! +{} capacity, +{} Domino.{}{}",
            opponent.capacity_reward, money, card_message, level_message
        )
    }
}

fn pick_reward(table: &[RewardEntry], roll: u16) -> u16 {
    table
        .iter()
        .find(|entry| entry.card_id == 0 || entry.threshold > roll)
        .map(|entry| entry.card_id)
        .unwrap_or(0)
}

#[cfg(test)]
mod tests {
    use super::*;
    fn db() -> Database {
        Database::load(
            Path::new(env!("CARGO_MANIFEST_DIR")).join("sacred-cards-decompiled/build/assets"),
        )
        .unwrap()
    }
    #[test]
    fn starter_values_and_deck_match_archive() {
        let db = db();
        let profile = Profile::new(&db);
        assert_eq!(
            (profile.money, profile.capacity, profile.level),
            (500, 1600, 72)
        );
        assert_eq!(profile.deck.len(), 40);
        assert_eq!(profile.deck, db.initial_deck);
        profile.validate_deck(&db).unwrap();
        profile.validate_storage(&db).unwrap();
        for id in 1..CARD_COUNT {
            assert_eq!(
                profile.reserve_count(id as u16),
                db.initial_collection[id] as u16
            );
        }
    }
    #[test]
    fn buy_sell_and_deck_transfer_conserve_ownership() {
        let db = db();
        let mut profile = Profile::new(&db);
        profile.money = 1_000_000;
        let id = (1..CARD_COUNT as u16)
            .find(|&id| {
                db.cards[id as usize].cost <= profile.level
                    && profile.deck_count(id) < db.copy_limit(id) as u16
            })
            .unwrap();
        profile.shop_stock[id as usize] = 10;
        let owned = profile.collection[id as usize];
        let stock = profile.shop_stock[id as usize];
        let price = profile.buy_price(&db, id);
        let money = profile.money;
        profile.buy(&db, id).unwrap();
        assert_eq!(profile.money, money - price);
        assert_eq!(profile.collection[id as usize], owned + 1);
        assert_eq!(profile.shop_stock[id as usize], stock - 1);
        profile.remove_from_deck(0).unwrap();
        let owned = profile.collection[id as usize];
        profile.add_to_deck(&db, id).unwrap();
        assert_eq!(profile.collection[id as usize], owned);
        profile.remove_from_deck(profile.deck.len() - 1).unwrap();
        profile.sell(&db, id).unwrap();
        assert_eq!(profile.collection[id as usize], owned - 1);
    }
    #[test]
    fn rejected_transaction_does_not_mutate_state() {
        let db = db();
        let mut profile = Profile::new(&db);
        profile.money = 0;
        let id = 1;
        profile.shop_stock[id as usize] = 10;
        let original = profile.clone();
        assert!(profile.buy(&db, id).is_err());
        assert_eq!(profile, original);
        assert!(profile.add_to_deck(&db, id).is_err());
        assert_eq!(profile, original);
    }
    #[test]
    fn save_round_trip_and_corruption_rejection() {
        let db = db();
        let profile = Profile::new(&db);
        let path =
            std::env::temp_dir().join(format!("sacred-cards-save-{}.json", std::process::id()));
        profile.save(&path).unwrap();
        assert_eq!(Profile::load(&path, &db).unwrap(), profile);
        std::fs::write(&path, b"{broken").unwrap();
        assert!(Profile::load(&path, &db).is_err());
        let _ = std::fs::remove_file(path);
    }
    #[test]
    fn reward_thresholds_are_strictly_greater() {
        let table = vec![
            RewardEntry {
                card_id: 10,
                threshold: 12,
            },
            RewardEntry {
                card_id: 20,
                threshold: 20,
            },
            RewardEntry {
                card_id: 0,
                threshold: 0,
            },
        ];
        assert_eq!(pick_reward(&table, 11), 10);
        assert_eq!(pick_reward(&table, 12), 20);
        assert_eq!(pick_reward(&table, 20), 0);
    }
    #[test]
    fn winning_rewards_increase_capacity_and_level() {
        let db = db();
        let mut profile = Profile::new(&db);
        profile.rng_state = 1;
        let before = profile.capacity;
        let message = profile.award_duel(&db, 1, true);
        assert_eq!(profile.capacity, before + db.opponents[1].capacity_reward);
        assert_eq!(profile.wins, 1);
        assert!(message.starts_with("Victory!"));
        assert!(profile.money > 500);
    }
    #[test]
    fn native_passwords_stock_shop_and_bonus_codes_are_one_use() {
        let db = db();
        let mut profile = Profile::new(&db);
        let owned = profile.collection[1];
        let stock = profile.shop_stock[1];
        profile.redeem_password(&db, "89631139").unwrap();
        assert_eq!(profile.shop_stock[1], stock + 1);
        assert_eq!(profile.collection[1], owned);
        profile.redeem_password(&db, "62626514").unwrap();
        assert_eq!(profile.money, 50_500);
        assert!(profile.redeem_password(&db, "62626514").is_err());
        assert_eq!(profile.money, 50_500);
        profile.redeem_password(&db, "98025229").unwrap();
        assert_eq!(profile.capacity, 1700);
    }
    #[test]
    fn native_random_shift_register_and_money_range_are_preserved() {
        let db = db();
        let mut profile = Profile::new(&db);
        assert_eq!(profile.next_halfword(), 0);
        assert_eq!(profile.next_halfword(), 1);
        let mut profile = Profile::new(&db);
        let old_money = profile.money;
        profile.award_duel(&db, 1, true);
        assert_eq!(profile.money, old_money + 2000);
    }
}
