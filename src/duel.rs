//! Playable duel rules translated from the maintained AY7E semantic sources.
//!
//! Numerical battles, five-card hands, tribute levels, terrain/stages, and the
//! supported effect branches follow the decompilation rather than modern TCG
//! rules. The UI combines native placement and spell activation into one action.
//! Randomness and opponent decisions are a new deterministic Rust implementation.
//! Unsupported activation handlers return an error before changing state.

use crate::data::Database;

pub const FIELD_SLOTS: usize = 5;
pub const HAND_LIMIT: usize = 5;

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Monster {
    pub card_id: u16,
    pub defense: bool,
    pub face_down: bool,
    /// Native action lock: attacking, defending, or activating uses the action.
    pub attacked: bool,
    pub stage: i8,
}

impl Monster {
    pub fn new(card_id: u16, defense: bool) -> Self {
        Self {
            card_id,
            defense,
            face_down: true,
            attacked: false,
            stage: 0,
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Side {
    pub lp: u32,
    pub deck: Vec<u16>,
    pub hand: Vec<u16>,
    pub monsters: [Option<Monster>; FIELD_SLOTS],
    /// Traps and the five Destiny Board pieces occupy this row.
    pub spells: [Option<u16>; FIELD_SLOTS],
    pub graveyard: Vec<u16>,
}

impl Side {
    fn new(deck: Vec<u16>, lp: u32) -> Self {
        Self {
            lp,
            deck,
            hand: Vec::new(),
            monsters: std::array::from_fn(|_| None),
            spells: [None; FIELD_SLOTS],
            graveyard: Vec::new(),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct Duel {
    pub sides: [Side; 2],
    pub active: usize,
    pub turn: u32,
    pub terrain: u8,
    pub winner: Option<usize>,
    pub log: Vec<String>,
    pub normal_summoned: bool,
    pub attack_restrictions: [u8; 2],
    pub opponent_hand_revealed: [bool; 2],
    /// Known current hand cards, by absolute owner. Later draws stay hidden.
    revealed_hands: [Vec<u16>; 2],
    revealed_hand_flags: [Vec<bool>; 2],
    /// Native revival remembers one monster per side, rather than a grave stack.
    pub remembered_grave: [Option<u16>; 2],
    borrowed: [[bool; FIELD_SLOTS]; 2],
    forbid_defense: [bool; 2],
    rng: u64,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum AttributeRelation {
    AttackerWins,
    Neutral,
    DefenderWins,
}

/// The numerical stage of battle.c, including the unusual attribute overrides.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct BattleResult {
    pub destroy_attacker: bool,
    pub destroy_defender: bool,
    pub damage_attacker: u32,
    pub damage_defender: u32,
}

pub fn resolve_battle(
    attack: u16,
    opposing_value: u16,
    defense: bool,
    relation: AttributeRelation,
) -> BattleResult {
    use AttributeRelation::*;
    let mut result = BattleResult::default();
    match (relation, defense) {
        (AttackerWins, false) => {
            result.destroy_defender = true;
            result.damage_defender = u32::from(attack.saturating_sub(opposing_value));
        }
        (AttackerWins, true) => result.destroy_defender = true,
        (DefenderWins, _) => {
            result.destroy_attacker = true;
            result.damage_attacker = u32::from(opposing_value.saturating_sub(attack));
        }
        (Neutral, false) => {
            result.destroy_defender = attack >= opposing_value;
            result.destroy_attacker = attack <= opposing_value;
            result.damage_defender = u32::from(attack.saturating_sub(opposing_value));
            result.damage_attacker = u32::from(opposing_value.saturating_sub(attack));
        }
        (Neutral, true) => {
            result.destroy_defender = attack > opposing_value;
            result.damage_attacker = u32::from(opposing_value.saturating_sub(attack));
        }
    }
    result
}

impl Duel {
    pub fn new(db: &Database, player_deck: &[u16], opponent_id: usize, seed: u64) -> Self {
        let opponent = db.opponent(opponent_id);
        let mut duel = Self {
            // CountDuelDecks stops at the first zero sentinel. Several exported
            // opponent slots are placeholders containing forty zero IDs.
            sides: [
                Side::new(
                    player_deck
                        .iter()
                        .copied()
                        .take_while(|&id| id != 0)
                        .collect(),
                    opponent.starting_lp[0],
                ),
                Side::new(
                    opponent
                        .deck
                        .iter()
                        .copied()
                        .take_while(|&id| id != 0)
                        .collect(),
                    opponent.starting_lp[1],
                ),
            ],
            active: 0,
            turn: 1,
            terrain: opponent.terrain,
            winner: None,
            log: Vec::new(),
            normal_summoned: false,
            attack_restrictions: [0; 2],
            opponent_hand_revealed: [false; 2],
            revealed_hands: [Vec::new(), Vec::new()],
            revealed_hand_flags: [Vec::new(), Vec::new()],
            remembered_grave: [None; 2],
            borrowed: [[false; FIELD_SLOTS]; 2],
            forbid_defense: [false; 2],
            rng: if seed == 0 {
                0xA71E_5AC4_EDCA_4D51
            } else {
                seed
            },
        };
        for side in 0..2 {
            // Native ShuffleDuelDeck performs 200 pair swaps.
            let size = duel.sides[side].deck.len();
            if size > 0 {
                for _ in 0..200 {
                    let a = duel.random() as usize % size;
                    let b = duel.random() as usize % size;
                    duel.sides[side].deck.swap(a, b);
                }
            }
        }
        duel.active = duel.random() as usize % 2;
        for side in 0..2 {
            for _ in 0..HAND_LIMIT {
                if duel.winner.is_none() {
                    duel.draw(side);
                }
            }
        }
        duel.note(format!(
            "Duel begins. {} goes first. No attacks on the opening turn.",
            duel.side_name(duel.active)
        ));
        // RunDuel draws at the start, but a full opening hand skips it.
        duel.begin_turn(db);
        duel
    }

    fn random(&mut self) -> u64 {
        self.rng ^= self.rng << 13;
        self.rng ^= self.rng >> 7;
        self.rng ^= self.rng << 17;
        self.rng
    }

    fn side_name(&self, side: usize) -> &'static str {
        if side == 0 {
            "You"
        } else {
            "Opponent"
        }
    }

    fn note(&mut self, message: String) {
        self.log.push(message);
        if self.log.len() > 200 {
            self.log.remove(0);
        }
    }

    fn require_live(&self) -> Result<(), String> {
        if self.winner.is_some() {
            Err("The duel has ended.".into())
        } else {
            Ok(())
        }
    }

    fn hand_card(&self, index: usize) -> Result<u16, String> {
        self.sides[self.active]
            .hand
            .get(index)
            .copied()
            .ok_or_else(|| "Choose a card in your hand.".into())
    }

    fn remove_hand_card(&mut self, side: usize, index: usize) -> u16 {
        let id = self.sides[side].hand.remove(index);
        let revealed = if index < self.revealed_hand_flags[side].len() {
            self.revealed_hand_flags[side].remove(index)
        } else {
            false
        };
        if revealed {
            if let Some(known) = self.revealed_hands[side]
                .iter()
                .position(|&card| card == id)
            {
                self.revealed_hands[side].remove(known);
            }
        }
        id
    }

    fn reveal_opposing_hand(&mut self) {
        self.opponent_hand_revealed[self.active] = true;
        self.revealed_hands[1 - self.active] = self.sides[1 - self.active].hand.clone();
        self.revealed_hand_flags[1 - self.active] =
            vec![true; self.sides[1 - self.active].hand.len()];
    }

    pub fn known_opponent_hand(&self, viewer: usize) -> &[u16] {
        self.revealed_hands
            .get(1usize.wrapping_sub(viewer))
            .map(Vec::as_slice)
            .unwrap_or(&[])
    }

    fn draw(&mut self, side: usize) {
        if self.winner.is_some() || self.sides[side].hand.len() >= HAND_LIMIT {
            return;
        }
        if let Some(id) = self.sides[side].deck.pop() {
            self.revealed_hand_flags[side].resize(self.sides[side].hand.len(), false);
            self.sides[side].hand.push(id);
            self.revealed_hand_flags[side].push(false);
        } else {
            self.winner = Some(1 - side);
            self.note(format!("{} cannot draw. Deck-out!", self.side_name(side)));
        }
    }

    fn damage(&mut self, side: usize, amount: u32) {
        self.sides[side].lp = self.sides[side].lp.saturating_sub(amount);
        if self.sides[side].lp == 0 && self.winner.is_none() {
            self.winner = Some(1 - side);
            self.note(format!("{} has no life points left.", self.side_name(side)));
        }
    }

    fn heal(&mut self, side: usize, amount: u32) {
        self.sides[side].lp = self.sides[side].lp.saturating_add(amount).min(9999);
    }

    fn discard_card(&mut self, db: &Database, side: usize, id: u16) {
        if db.card(id).is_monster() {
            self.remembered_grave[side] = Some(id);
        }
        self.sides[side].graveyard.push(id);
    }

    fn destroy(&mut self, db: &Database, side: usize, slot: usize) {
        if let Some(monster) = self.sides[side].monsters[slot].take() {
            self.borrowed[side][slot] = false;
            self.discard_card(db, side, monster.card_id);
        }
    }

    fn consume_trap(&mut self, db: &Database, side: usize, slot: usize) {
        if let Some(id) = self.sides[side].spells[slot].take() {
            self.discard_card(db, side, id);
        }
    }

    fn check_special_win(&mut self) {
        if self.winner.is_some() {
            return;
        }
        let side = self.active;
        let mask = self.sides[side].hand.iter().fold(0u8, |mask, &id| {
            if (17..=21).contains(&id) {
                mask | (1 << (id - 17))
            } else {
                mask
            }
        });
        if mask == 31 {
            self.winner = Some(side);
            self.note(format!("{} assembled Exodia!", self.side_name(side)));
        }
        let mask = self.sides[side]
            .spells
            .iter()
            .flatten()
            .fold(0u8, |mask, &id| {
                if (583..=587).contains(&id) {
                    mask | (1 << (id - 583))
                } else {
                    mask
                }
            });
        if mask == 31 {
            self.winner = Some(side);
            self.note(format!("{} completed Destiny Board!", self.side_name(side)));
        }
    }

    fn begin_turn(&mut self, db: &Database) {
        self.normal_summoned = false;
        let side = self.active;
        self.draw(side);
        self.check_special_win();
        // TransformGrowingMonsters, 08019CE0. These four pairs are read from
        // ROM 08D419CC / 08D419D4 via the lossless original-data archive.
        const PAIRS: [(u16, u16); 4] = [(278, 56), (56, 72), (72, 57), (57, 67)];
        for monster in self.sides[side].monsters.iter_mut().flatten() {
            for (from, to) in PAIRS {
                if monster.card_id == from {
                    monster.card_id = to;
                    break;
                }
            }
        }
        let _ = db;
    }

    pub fn can_attack(&self, slot: usize) -> bool {
        self.winner.is_none()
            && self.turn > 1
            && self.attack_restrictions[self.active] == 0
            && self.sides[self.active]
                .monsters
                .get(slot)
                .and_then(Option::as_ref)
                .is_some_and(|m| !m.attacked)
    }

    pub fn summon(
        &mut self,
        db: &Database,
        hand_index: usize,
        slot: usize,
        defense: bool,
        tributes: &[usize],
    ) -> Result<(), String> {
        self.require_live()?;
        let id = self.hand_card(hand_index)?;
        let card = db.card(id);
        if !card.is_monster() {
            return Err("Choose a monster to summon.".into());
        }
        if self.normal_summoned {
            return Err("You have already summoned a monster this turn.".into());
        }
        if slot >= FIELD_SLOTS {
            return Err("Choose one of the five monster slots.".into());
        }
        if defense && self.forbid_defense[self.active] {
            return Err("Stop Defense prevents a defense position summon.".into());
        }
        let required = db.tributes(id);
        if tributes.len() != required {
            return Err(format!("{} needs {required} tribute(s).", card.name));
        }
        let mut selected = [false; FIELD_SLOTS];
        for &tribute in tributes {
            if tribute >= FIELD_SLOTS
                || selected[tribute]
                || self.sides[self.active].monsters[tribute].is_none()
            {
                return Err("Select distinct occupied monster slots as tributes.".into());
            }
            selected[tribute] = true;
        }
        if self.sides[self.active].monsters[slot].is_some() && !selected[slot] {
            return Err("The destination must be empty or one of the tributes.".into());
        }
        for &tribute in tributes {
            self.destroy(db, self.active, tribute);
        }
        self.remove_hand_card(self.active, hand_index);
        self.sides[self.active].monsters[slot] = Some(Monster::new(id, defense));
        self.borrowed[self.active][slot] = false;
        self.normal_summoned = true;
        self.note(format!(
            "{} summoned {}{}.",
            self.side_name(self.active),
            card.name,
            if defense { " in defense" } else { "" }
        ));
        Ok(())
    }

    pub fn set_position(&mut self, slot: usize) -> Result<(), String> {
        self.require_live()?;
        let forbid_defense = self.forbid_defense[self.active];
        let monster = self.sides[self.active]
            .monsters
            .get_mut(slot)
            .and_then(Option::as_mut)
            .ok_or("Choose an occupied monster slot.")?;
        if monster.attacked {
            return Err("That monster has already used its action this turn.".into());
        }
        if !monster.defense && forbid_defense {
            return Err("Stop Defense prevents defending this turn.".into());
        }
        monster.defense = !monster.defense;
        monster.attacked = true;
        self.note("Position changed. This monster has used its action.".into());
        Ok(())
    }

    pub fn attribute_relation(db: &Database, a: u16, b: u16) -> AttributeRelation {
        let a = db.card(a).summon as usize;
        let b = db.card(b).summon;
        if a == 11 || b == 11 {
            return AttributeRelation::Neutral;
        }
        if db.attribute_beats.get(a) == Some(&b) {
            AttributeRelation::AttackerWins
        } else if db.attribute_loses_to.get(a) == Some(&b) {
            AttributeRelation::DefenderWins
        } else {
            AttributeRelation::Neutral
        }
    }

    pub fn preview_battle(
        &self,
        db: &Database,
        from: usize,
        target: usize,
    ) -> Option<BattleResult> {
        let a = self.sides[self.active].monsters.get(from)?.as_ref()?;
        let b = self.sides[1 - self.active].monsters.get(target)?.as_ref()?;
        let attack = db.stats(a.card_id, self.terrain, a.stage).0;
        let (atk, def) = db.stats(b.card_id, self.terrain, b.stage);
        Some(resolve_battle(
            attack,
            if b.defense { def } else { atk },
            b.defense,
            Self::attribute_relation(db, a.card_id, b.card_id),
        ))
    }

    pub fn attack(
        &mut self,
        db: &Database,
        from: usize,
        target: Option<usize>,
    ) -> Result<(), String> {
        self.require_live()?;
        let side = self.active;
        let enemy = 1 - side;
        let attacker = self.sides[side]
            .monsters
            .get(from)
            .and_then(Option::as_ref)
            .ok_or("Choose a monster to attack with.")?
            .clone();
        if attacker.attacked {
            return Err("That monster has already used its action this turn.".into());
        }
        if self.turn == 1 {
            return Err("Attacks are forbidden on the opening turn.".into());
        }
        if self.attack_restrictions[side] > 0 {
            return Err(format!(
                "Swords of Revealing Light blocks attacks for {} more turn(s).",
                self.attack_restrictions[side]
            ));
        }
        match target {
            Some(slot) if slot >= FIELD_SLOTS || self.sides[enemy].monsters[slot].is_none() => {
                return Err("Choose an opposing monster.".into())
            }
            None if self.sides[enemy].monsters.iter().any(Option::is_some) => {
                return Err("Defeat the opposing monsters before attacking directly.".into())
            }
            _ => {}
        }
        // Native BeginAttack searches the first eligible trap before choosing a target.
        if self.trigger_monster_trap(db, from) {
            return Ok(());
        }
        let monster = self.sides[side].monsters[from].as_mut().unwrap();
        monster.attacked = true;
        monster.face_down = false;
        monster.defense = false;
        let attack = db.stats(attacker.card_id, self.terrain, attacker.stage).0;
        if let Some(slot) = target {
            self.sides[enemy].monsters[slot].as_mut().unwrap().face_down = false;
            let defender = self.sides[enemy].monsters[slot].as_ref().unwrap().clone();
            let result = self.preview_battle(db, from, slot).unwrap();
            if result.destroy_attacker {
                self.destroy(db, side, from);
            }
            if result.destroy_defender {
                self.destroy(db, enemy, slot);
            }
            self.damage(side, result.damage_attacker);
            self.damage(enemy, result.damage_defender);
            self.note(format!(
                "{} attacked {}. {}{}{}",
                db.card(attacker.card_id).name,
                db.card(defender.card_id).name,
                if result.destroy_attacker {
                    "Attacker destroyed. "
                } else {
                    ""
                },
                if result.destroy_defender {
                    "Defender destroyed. "
                } else {
                    ""
                },
                if result.damage_attacker > 0 {
                    format!("Attacker loses {} LP.", result.damage_attacker)
                } else if result.damage_defender > 0 {
                    format!("Defender loses {} LP.", result.damage_defender)
                } else {
                    "No LP damage.".into()
                }
            ));
        } else {
            self.damage(enemy, u32::from(attack));
            self.note(format!(
                "{} attacked directly for {attack} LP.",
                db.card(attacker.card_id).name
            ));
        }
        Ok(())
    }

    fn trigger_monster_trap(&mut self, db: &Database, source: usize) -> bool {
        let side = self.active;
        let enemy = 1 - side;
        let monster = self.sides[side].monsters[source].as_ref().unwrap();
        let id = monster.card_id;
        let attack = db.stats(id, self.terrain, monster.stage).0;
        let found = self.sides[enemy]
            .spells
            .iter()
            .enumerate()
            .find_map(|(slot, &id)| {
                let card = db.card(id?);
                let kind = card.metadata_1c;
                let activates = match kind {
                    1 | 12 | 13 | 14 => true,
                    2..=6 => attack <= [500, 1000, 1500, 2000, 3000][usize::from(kind - 2)],
                    _ => false,
                };
                activates.then_some((slot, kind, card.id))
            });
        let Some((slot, kind, trap)) = found else {
            return false;
        };
        self.consume_trap(db, enemy, slot);
        match kind {
            1..=6 => {
                if db.effect_immune(id) {
                    self.sides[side].monsters[source]
                        .as_mut()
                        .unwrap()
                        .face_down = false;
                } else {
                    self.destroy(db, side, source);
                }
            }
            12 => {
                let monster = self.sides[side].monsters[source].as_mut().unwrap();
                monster.face_down = false;
                monster.attacked = true;
            }
            13 => self.clear_monsters(db, side, true),
            14 => {
                let monster = self.sides[side].monsters[source].as_mut().unwrap();
                monster.stage = monster.stage.saturating_sub(1);
                monster.face_down = false;
                monster.attacked = true;
            }
            _ => unreachable!(),
        }
        self.note(format!(
            "{} activated {} against {}.",
            self.side_name(enemy),
            db.card(trap).name,
            db.card(id).name
        ));
        true
    }

    fn clear_monsters(&mut self, db: &Database, side: usize, immunity: bool) {
        for slot in 0..FIELD_SLOTS {
            if self.sides[side].monsters[slot]
                .as_ref()
                .is_some_and(|m| !immunity || !db.effect_immune(m.card_id))
            {
                self.destroy(db, side, slot);
            }
        }
    }

    fn clear_spells(&mut self, db: &Database, side: usize) {
        for slot in 0..FIELD_SLOTS {
            self.consume_trap(db, side, slot);
        }
    }

    fn strongest(&self, db: &Database, side: usize, vulnerable: bool) -> Option<usize> {
        let mut best = None;
        let mut score = 0;
        for (slot, monster) in self.sides[side].monsters.iter().enumerate() {
            if let Some(monster) = monster {
                if vulnerable && db.effect_immune(monster.card_id) {
                    continue;
                }
                let attack = db.stats(monster.card_id, self.terrain, monster.stage).0;
                if attack >= score {
                    score = attack;
                    best = Some(slot);
                }
            }
        }
        best
    }

    fn spell_trap(
        &mut self,
        db: &Database,
        spell: u16,
        amount: u32,
        equipment_target: Option<usize>,
    ) -> bool {
        let side = self.active;
        let enemy = 1 - side;
        let heal = (338..=342).contains(&spell);
        let damage = (343..=347).contains(&spell);
        let found = self.sides[enemy]
            .spells
            .iter()
            .enumerate()
            .find_map(|(slot, &id)| {
                let card = db.card(id?);
                let kind = card.metadata_1c;
                ((kind == 7 && damage)
                    || (kind == 8 && heal)
                    || (kind == 9 && equipment_target.is_some())
                    || (kind == 11 && spell == 337))
                    .then_some((slot, kind, card.id))
            });
        let Some((slot, kind, trap)) = found else {
            return false;
        };
        self.consume_trap(db, enemy, slot);
        match kind {
            7 | 8 => self.damage(side, amount),
            9 => {
                // EquipmentSpell's trap branch LOWERS the stage before activation.
                if let Some(target) = equipment_target {
                    let m = self.sides[side].monsters[target].as_mut().unwrap();
                    m.stage = m.stage.saturating_sub(1);
                }
            }
            11 => self.clear_monsters(db, side, true),
            _ => unreachable!(),
        }
        self.note(format!(
            "{} activated {} against {}.",
            self.side_name(enemy),
            db.card(trap).name,
            db.card(spell).name
        ));
        true
    }

    pub fn spell_needs_target(id: u16) -> bool {
        equipment_index(id).is_some() || matches!(id, 318 | 658)
    }

    pub fn spell_supported(db: &Database, id: u16) -> bool {
        let card = db.card(id);
        (card.is_trap() && matches!(card.metadata_1c, 1..=9 | 11..=14))
            || equipment_index(id).is_some()
            || ritual(id).is_some()
            || matches!(id, 318 | 320 | 329..=350 | 583..=587 | 653 | 655 | 656 | 658 |
                660..=664 | 667 | 669 | 672 | 675 | 722 | 781 | 784..=790 | 891..=898)
    }

    pub fn play_spell(
        &mut self,
        db: &Database,
        hand_index: usize,
        target: Option<usize>,
    ) -> Result<(), String> {
        self.play_spell_with_tributes(db, hand_index, target, &[])
    }

    pub fn required_spell_tributes(db: &Database, id: u16) -> usize {
        let card = db.card(id);
        if card.type_id != 23 {
            return 0;
        }
        const REQUIREMENTS: &[u8] = include_bytes!(
            "../sacred-cards-decompiled/build/assets/gameplay/category-requirements.bin"
        );
        REQUIREMENTS
            .get(usize::from(card.metadata_1d))
            .copied()
            .unwrap_or(0) as usize
    }

    pub fn play_spell_with_tributes(
        &mut self,
        db: &Database,
        hand_index: usize,
        target: Option<usize>,
        tributes: &[usize],
    ) -> Result<(), String> {
        self.require_live()?;
        let id = self.hand_card(hand_index)?;
        let card = db.card(id);
        if card.is_monster() {
            return Err("Use Summon to play a monster.".into());
        }
        if !Self::spell_supported(db, id) {
            return Err(format!(
                "{} is not implemented yet (effect {}, trap {}). Card kept in hand.",
                card.name, card.metadata_1a, card.metadata_1c
            ));
        }
        let side = self.active;
        let enemy = 1 - side;
        let required = Self::required_spell_tributes(db, id);
        if tributes.len() != required {
            return Err(format!(
                "{} needs {required} tribute(s) in addition to its ritual material.",
                card.name
            ));
        }
        let mut selected = [false; FIELD_SLOTS];
        for &slot in tributes {
            if slot >= FIELD_SLOTS || selected[slot] || self.sides[side].monsters[slot].is_none() {
                return Err("Select distinct occupied monster slots as tributes.".into());
            }
            selected[slot] = true;
        }
        if card.is_trap() || (583..=587).contains(&id) {
            let slot = self.sides[side]
                .spells
                .iter()
                .position(Option::is_none)
                .ok_or("All five spell/trap slots are occupied.")?;
            self.remove_hand_card(side, hand_index);
            self.sides[side].spells[slot] = Some(id);
            self.note(format!("{} set {}.", self.side_name(side), card.name));
            self.check_special_win();
            return Ok(());
        }
        if Self::spell_needs_target(id) {
            let slot = target.ok_or("Choose a friendly monster as the target.")?;
            let monster = self.sides[side]
                .monsters
                .get(slot)
                .and_then(Option::as_ref)
                .ok_or("Choose an occupied friendly monster slot.")?;
            if monster.attacked {
                return Err("The target has already used its action this turn.".into());
            }
            if equipment_index(id).is_some() && !db.equipment_compatible(id, monster.card_id) {
                return Err(format!(
                    "{} cannot equip {}. Card kept in hand.",
                    card.name,
                    db.card(monster.card_id).name
                ));
            }
            if id == 318 && !matches!(monster.card_id, 62 | 875) {
                return Err("Elegant Egotist needs Harpie Lady or Cyber Harpie.".into());
            }
            if id == 658 && !matches!(monster.card_id, 391 | 82 | 885) {
                return Err("Metalmorph needs a compatible native transformation material.".into());
            }
        }
        let ritual_plan = self.ritual_plan(id)?;
        if let Some((materials, _)) = &ritual_plan {
            if materials.iter().any(|&slot| selected[slot]) {
                return Err("A ritual material must remain on the field; choose other monsters as tributes.".into());
            }
        }
        // All validation completes before cards or the board are mutated.
        for &slot in tributes {
            self.destroy(db, side, slot);
        }
        self.remove_hand_card(side, hand_index);
        self.note(format!("{} activated {}.", self.side_name(side), card.name));
        let amount = match id {
            338 => 200,
            339 => 500,
            340 => 1000,
            341 => 2000,
            342 => 5000,
            343 => 50,
            344 => 100,
            345 => 200,
            346 => 500,
            347 => 1000,
            _ => 0,
        };
        if self.spell_trap(db, id, amount, equipment_index(id).and(target)) {
            self.discard_card(db, side, id);
            return Ok(());
        }
        if equipment_index(id).is_some() {
            let monster = self.sides[side].monsters[target.unwrap()].as_mut().unwrap();
            monster.stage = monster.stage.saturating_add(1);
        } else if let Some((slots, result)) = ritual_plan {
            let first = slots[0];
            for &slot in &slots[1..] {
                self.sides[side].monsters[slot] = None;
                self.borrowed[side][slot] = false;
            }
            self.sides[side].monsters[first] = Some(Monster::new(result, false));
            self.borrowed[side][first] = false;
        } else {
            match id {
                330..=335 => self.terrain = (id - 329) as u8,
                338..=342 => self.heal(side, amount),
                343..=347 => self.damage(enemy, amount),
                336 => {
                    self.clear_monsters(db, enemy, true);
                    self.clear_monsters(db, side, true);
                }
                337 => self.clear_monsters(db, enemy, true),
                320 => {
                    self.forbid_defense[enemy] = true;
                    for m in self.sides[enemy].monsters.iter_mut().flatten() {
                        m.defense = false;
                        m.face_down = false;
                    }
                }
                329 => self.eliminate_type(db, enemy, 1, true),
                348 => {
                    self.attack_restrictions[enemy] |= 3;
                    for m in self.sides[enemy].monsters.iter_mut().flatten() {
                        m.face_down = false;
                    }
                }
                350 => {
                    for m in self.sides[enemy].monsters.iter_mut().flatten() {
                        m.face_down = false;
                    }
                }
                349 | 669 => {
                    for m in self.sides[enemy].monsters.iter_mut().flatten() {
                        m.stage = m.stage.saturating_sub(if id == 669 { 2 } else { 1 });
                    }
                }
                318 => {
                    self.sides[side].monsters[target.unwrap()]
                        .as_mut()
                        .unwrap()
                        .card_id = 63
                }
                658 => {
                    let m = self.sides[side].monsters[target.unwrap()].as_mut().unwrap();
                    m.card_id = match m.card_id {
                        391 => 392,
                        82 => 742,
                        885 => 884,
                        _ => unreachable!(),
                    };
                }
                672 => self.clear_spells(db, enemy),
                661 => {
                    for slot in 0..FIELD_SLOTS {
                        let kill = self.sides[enemy].monsters[slot].as_ref().is_some_and(|m| {
                            !db.effect_immune(m.card_id)
                                && db.stats(m.card_id, self.terrain, m.stage).0 > 1499
                        });
                        if kill {
                            self.destroy(db, enemy, slot);
                        }
                    }
                }
                653 => self.eliminate_type(db, enemy, 4, true),
                656 => self.eliminate_type(db, enemy, 3, false),
                660 => self.eliminate_type(db, enemy, 15, true),
                662 => self.eliminate_type(db, enemy, 10, false),
                663 => self.eliminate_type(db, enemy, 19, false),
                664 => self.eliminate_type(db, enemy, 13, false),
                787 => self.eliminate_type(db, enemy, 2, false),
                786 => self.eliminate_type(db, enemy, 8, false),
                655 => {
                    for m in self.sides[side].monsters.iter_mut().flatten() {
                        if m.stage < 0 {
                            m.stage = 0;
                        }
                    }
                }
                790 => self.reveal_opposing_hand(),
                789 => {
                    self.draw(side);
                    self.draw(side);
                }
                788 => self.damage(enemy, self.sides[enemy].hand.len() as u32 * 200),
                785 => {
                    if self.sides[side]
                        .monsters
                        .iter()
                        .flatten()
                        .any(|m| m.card_id == 58)
                    {
                        for slot in 0..FIELD_SLOTS {
                            if self.sides[side].monsters[slot].is_none() {
                                let mut m = Monster::new(58, false);
                                m.face_down = false;
                                m.attacked = true;
                                self.sides[side].monsters[slot] = Some(m);
                            } else if let Some(m) = self.sides[side].monsters[slot].as_mut() {
                                if m.card_id == 58 {
                                    m.face_down = false;
                                    m.defense = false;
                                    m.attacked = true;
                                }
                            }
                        }
                    }
                }
                781 | 784 => {
                    if let (Some(dst), Some(src)) = (
                        self.sides[side].monsters.iter().position(Option::is_none),
                        self.strongest(db, enemy, true),
                    ) {
                        let mut monster = self.sides[enemy].monsters[src].take().unwrap();
                        self.borrowed[enemy][src] = false;
                        monster.face_down = false;
                        monster.defense = false;
                        monster.attacked = false;
                        self.sides[side].monsters[dst] = Some(monster);
                        self.borrowed[side][dst] = id == 781;
                    }
                }
                895 => {
                    if let Some(slot) = self.sides[side].monsters.iter().position(Option::is_none) {
                        if let Some(card_id) = self.remembered_grave[enemy].take() {
                            let mut m = Monster::new(card_id, false);
                            m.face_down = false;
                            self.sides[side].monsters[slot] = Some(m);
                        }
                    }
                }
                898 => {
                    if let Some(slot) = self.strongest(db, enemy, true) {
                        self.destroy(db, enemy, slot);
                    }
                }
                896 => self.remembered_grave = [None; 2],
                893 | 894 => {
                    for s in [enemy, side] {
                        self.clear_spells(db, s);
                        self.clear_monsters(db, s, true);
                    }
                    if id == 893 {
                        for s in [side, enemy] {
                            let hand = std::mem::take(&mut self.sides[s].hand);
                            let flags = std::mem::take(&mut self.revealed_hand_flags[s]);
                            self.revealed_hands[s].retain(|&card| db.effect_immune(card));
                            for (index, card) in hand.into_iter().enumerate() {
                                if db.effect_immune(card) {
                                    self.sides[s].hand.push(card);
                                    self.revealed_hand_flags[s]
                                        .push(flags.get(index).copied().unwrap_or(false));
                                } else {
                                    self.discard_card(db, s, card);
                                }
                            }
                        }
                    }
                }
                891 => {
                    for m in self.sides[enemy].monsters.iter_mut().flatten() {
                        if db.stats(m.card_id, self.terrain, m.stage).0 > 1499 {
                            m.attacked = true;
                        }
                    }
                }
                892 => {
                    for m in self.sides[side].monsters.iter_mut().flatten() {
                        m.face_down = true;
                    }
                }
                _ => unreachable!("supported spell must have an implementation: {id}"),
            }
        }
        self.discard_card(db, side, id);
        self.check_special_win();
        Ok(())
    }

    fn eliminate_type(&mut self, db: &Database, side: usize, type_id: u8, immunity: bool) {
        for slot in 0..FIELD_SLOTS {
            if self.sides[side].monsters[slot].as_ref().is_some_and(|m| {
                db.card(m.card_id).type_id == type_id && (!immunity || !db.effect_immune(m.card_id))
            }) {
                self.destroy(db, side, slot);
            }
        }
    }

    fn ritual_plan(&self, spell: u16) -> Result<Option<(Vec<usize>, u16)>, String> {
        if let Some((material, result)) = ritual(spell) {
            let slot = self.sides[self.active]
                .monsters
                .iter()
                .position(|m| m.as_ref().is_some_and(|m| m.card_id == material))
                .ok_or_else(|| {
                    format!(
                        "This ritual needs monster #{material} on your field. Card kept in hand."
                    )
                })?;
            return Ok(Some((vec![slot], result)));
        }
        if spell == 667 {
            let mut slots = Vec::new();
            for id in [371, 372, 373] {
                slots.push(
                    self.sides[self.active]
                        .monsters
                        .iter()
                        .position(|m| m.as_ref().is_some_and(|m| m.card_id == id))
                        .ok_or("Gate Guardian Ritual needs Sanga, Kazejin, and Suijin.")?,
                );
            }
            return Ok(Some((slots, 374)));
        }
        if spell == 722 {
            for material in [865, 35] {
                if let Some(slot) = self.sides[self.active]
                    .monsters
                    .iter()
                    .position(|m| m.as_ref().is_some_and(|m| m.card_id == material))
                {
                    return Ok(Some((vec![slot], 721)));
                }
            }
            return Err("Dark Magic Ritual needs Dark Magician or Dark Magician (Arkana).".into());
        }
        if spell == 675 {
            const RECIPES: &[u8] = include_bytes!(
                "../sacred-cards-decompiled/build/assets/gameplay/ritual-recipes.bin"
            );
            for index in [29, 28, 27, 5] {
                let row = &RECIPES[index * 8..index * 8 + 8];
                let recipe: Vec<u16> = row
                    .as_chunks::<2>()
                    .0
                    .iter()
                    .map(|b| u16::from_le_bytes([b[0], b[1]]))
                    .collect();
                let mut slots = Vec::new();
                for id in [recipe[0], recipe[2], recipe[3]] {
                    if let Some(slot) = self.sides[self.active]
                        .monsters
                        .iter()
                        .enumerate()
                        .position(|(slot, m)| {
                            !slots.contains(&slot) && m.as_ref().is_some_and(|m| m.card_id == id)
                        })
                    {
                        slots.push(slot);
                    } else {
                        break;
                    }
                }
                if slots.len() == 3 {
                    return Ok(Some((slots, recipe[1])));
                }
            }
            return Err(
                "Ultimate Dragon needs one of its native three-monster recipes on the field."
                    .into(),
            );
        }
        Ok(None)
    }

    pub fn monster_effect_supported(id: u16) -> bool {
        matches!(
            id,
            2 | 12
                | 15
                | 16
                | 26
                | 39
                | 42
                | 59
                | 62
                | 63
                | 73
                | 74
                | 83
                | 84
                | 89
                | 90
                | 99
                | 117
                | 129
                | 135
                | 140
                | 154
                | 160
                | 161
                | 195
                | 224
                | 229
                | 235
                | 258
                | 363
                | 370
                | 376
                | 387
                | 397
                | 402
                | 429
                | 492
                | 500
                | 525
                | 540
                | 554
                | 610
                | 612
                | 628
                | 637
                | 725
                | 731
                | 734
                | 738
                | 740
                | 743
                | 752
                | 756
                | 757
                | 760
                | 762
                | 763
                | 764
                | 766
                | 778
                | 810
                | 811
                | 812
                | 832
                | 833
                | 834
                | 838
                | 850
                | 858
                | 861
                | 871
                | 872
                | 873
                | 874
                | 875
                | 877
                | 878
                | 883
                | 890
        )
    }

    fn boost_cards(&mut self, side: usize, ids: &[u16], stages: i8) {
        for m in self.sides[side].monsters.iter_mut().flatten() {
            if ids.contains(&m.card_id) {
                m.stage = m.stage.saturating_add(stages);
            }
        }
    }

    fn lower_row(&mut self, side: usize) {
        for m in self.sides[side].monsters.iter_mut().flatten() {
            m.stage = m.stage.saturating_sub(1);
        }
    }

    fn lock_row(&mut self, side: usize) {
        for m in self.sides[side].monsters.iter_mut().flatten() {
            m.attacked = true;
        }
    }

    fn token(&mut self, side: usize, id: u16) {
        if let Some(slot) = self.sides[side].monsters.iter().position(Option::is_none) {
            let mut m = Monster::new(id, false);
            m.face_down = false;
            self.sides[side].monsters[slot] = Some(m);
            self.borrowed[side][slot] = false;
        }
    }

    fn fusion(&mut self, side: usize, slot: usize, id: u16) {
        let mut m = Monster::new(id, false);
        m.face_down = false;
        m.attacked = true;
        self.sides[side].monsters[slot] = Some(m);
        self.borrowed[side][slot] = false;
    }

    /// Explicit activation follows duel_player.c: only a face-down, unused
    /// monster may activate. Activation reveals it and usually uses its action.
    /// Absorption/ready helpers can clear that action lock, as in native code.
    pub fn activate_monster(&mut self, db: &Database, slot: usize) -> Result<(), String> {
        self.require_live()?;
        let side = self.active;
        let enemy = 1 - side;
        let monster = self.sides[side]
            .monsters
            .get(slot)
            .and_then(Option::as_ref)
            .ok_or("Choose an occupied friendly monster slot.")?
            .clone();
        let id = monster.card_id;
        if !monster.face_down {
            return Err("Monster effects can only be activated while face-down.".into());
        }
        if monster.attacked {
            return Err("That monster has already used its action this turn.".into());
        }
        if !Self::monster_effect_supported(id) {
            return Err(if db.card(id).metadata_1b == 0 {
                "This monster has no activated effect.".into()
            } else {
                format!(
                    "{}'s monster effect {} is not implemented. No state changed.",
                    db.card(id).name,
                    db.card(id).metadata_1b
                )
            });
        }
        let m = self.sides[side].monsters[slot].as_mut().unwrap();
        m.face_down = false;
        m.attacked = true;
        m.defense = false;
        self.note(format!(
            "{} activated {}'s effect.",
            self.side_name(side),
            db.card(id).name
        ));
        match id {
            84 | 752 => {
                for enemy_slot in 0..FIELD_SLOTS {
                    if self.sides[enemy].spells[enemy_slot]
                        .is_some_and(|id| db.card(id).metadata_1c != 0)
                    {
                        self.consume_trap(db, enemy, enemy_slot);
                        if id == 84 {
                            break;
                        }
                    }
                }
            }
            363 => self.heal(side, 1000),
            731 | 734 => {
                if let Some(source) = self.strongest(db, enemy, true) {
                    let mut copy = self.sides[enemy].monsters[source].take().unwrap();
                    copy.face_down = false;
                    copy.defense = false;
                    copy.attacked = false;
                    if id == 734 {
                        copy.stage = copy.stage.saturating_add(2);
                    }
                    self.sides[side].monsters[slot] = Some(copy);
                    self.borrowed[side][slot] = false;
                    self.borrowed[enemy][source] = false;
                }
            }
            540 => self.draw(side),
            62 | 875 => self.boost_cards(side, &[386], 1),
            63 => self.boost_cards(side, &[386], 2),
            16 => {
                for m in self.sides[side].monsters.iter_mut().flatten() {
                    m.card_id = match m.card_id {
                        4 => 69,
                        35 | 865 => 888,
                        other => other,
                    };
                }
            }
            83 => {
                self.terrain = 6;
                for m in self.sides[side].monsters.iter_mut().flatten() {
                    m.face_down = m.card_id != 83;
                }
            }
            2 => self.boost_cards(side, &[1, 887], 1),
            39 => self.terrain = 2,
            15 => self.eliminate_type(db, enemy, 11, false),
            74 => self.terrain = 0,
            26 => {
                for enemy_slot in 0..FIELD_SLOTS {
                    if self.sides[enemy].monsters[enemy_slot]
                        .as_ref()
                        .is_some_and(|m| db.card(m.card_id).summon == 5)
                    {
                        self.destroy(db, enemy, enemy_slot);
                    }
                }
            }
            376 => self.boost_cards(side, &[375], 1),
            99 => self.boost_cards(side, &[96, 97, 98], 1),
            59 => self.lower_row(enemy),
            89 => {
                let mut amount = 0u16;
                for own_slot in 0..FIELD_SLOTS {
                    if own_slot != slot {
                        if let Some(m) = &self.sides[side].monsters[own_slot] {
                            if !m.attacked {
                                amount = amount
                                    .wrapping_add(db.stats(m.card_id, self.terrain, m.stage).0);
                                self.destroy(db, side, own_slot);
                            }
                        }
                    }
                }
                self.damage(enemy, u32::from(amount));
            }
            429 => {
                self.draw(side);
                self.destroy(db, side, slot);
            }
            525 => self.terrain = 3,
            500 => self.eliminate_type(db, enemy, 1, true),
            224 => {
                if let Some(dst) = self.sides[side].spells.iter().position(Option::is_none) {
                    self.sides[side].spells[dst] = Some(685);
                }
            }
            135 => {
                if let Some(target) = self.strongest(db, enemy, true) {
                    self.destroy(db, enemy, target);
                }
                self.destroy(db, side, slot);
            }
            42 | 740 => self.lock_row(enemy),
            610 | 725 => {
                let mut best = None;
                let mut score = 0;
                for (target, m) in self.sides[enemy].monsters.iter().enumerate() {
                    if let Some(m) = m {
                        if !m.attacked {
                            let attack = db.stats(m.card_id, self.terrain, m.stage).0;
                            if attack >= score {
                                score = attack;
                                best = Some(target);
                            }
                        }
                    }
                }
                if let Some(target) = best {
                    let m = self.sides[enemy].monsters[target].as_mut().unwrap();
                    m.attacked = true;
                    if id == 725 {
                        m.stage = m.stage.saturating_sub(1);
                    }
                }
            }
            760 | 872 => {
                let count = self
                    .remembered_grave
                    .iter()
                    .filter(|&&id| matches!(id, Some(35 | 865)))
                    .count();
                let m = self.sides[side].monsters[slot].as_mut().unwrap();
                m.stage = m.stage.saturating_add(count as i8);
            }
            235 => {
                let count = self.sides[side]
                    .monsters
                    .iter()
                    .flatten()
                    .filter(|m| db.card(m.card_id).type_id == 20)
                    .count();
                let m = self.sides[side].monsters[slot].as_mut().unwrap();
                m.stage = m.stage.saturating_add(count as i8);
            }
            160 => self.boost_cards(side, &[161], 1),
            161 => self.boost_cards(side, &[160], 1),
            612 => self.heal(side, 500),
            154 => self.damage(enemy, 50),
            73 => self.terrain = 5,
            90 => {
                for m in self.sides[side].monsters.iter_mut().flatten() {
                    if db.stats(m.card_id, self.terrain, m.stage).0 <= 500 {
                        m.stage = m.stage.saturating_add(1);
                    }
                }
            }
            402 => self.reveal_opposing_hand(),
            195 | 810 => {
                if let Some(dst) = self.sides[side].monsters.iter().position(Option::is_none) {
                    self.sides[side].monsters[dst] = self.sides[side].monsters[slot].clone();
                    self.borrowed[side][dst] = self.borrowed[side][slot];
                }
            }
            12 => self.boost_cards(side, &[554], 1),
            554 => self.boost_cards(side, &[12], 1),
            637 => self.terrain = 1,
            370 => {
                let count = self.sides[side]
                    .monsters
                    .iter()
                    .flatten()
                    .filter(|m| m.card_id == 366)
                    .count();
                let m = self.sides[side].monsters[slot].as_mut().unwrap();
                m.stage = m.stage.saturating_add(count as i8);
            }
            117 => self.token(side, 486),
            140 => self.token(side, 549),
            861 => self.token(side, 379),
            229 => {
                for m in self.sides[side].monsters.iter_mut().flatten() {
                    m.stage = m.stage.saturating_add(1);
                }
                self.damage(side, 1000);
            }
            258 => {
                self.clear_monsters(db, enemy, true);
                self.clear_monsters(db, side, true);
            }
            129 => {
                self.lock_row(enemy);
                self.lock_row(side);
            }
            492 | 628 => {
                for m in self.sides[side].monsters.iter_mut().flatten() {
                    let attr = db.card(m.card_id).summon;
                    if attr == (if id == 492 { 1 } else { 2 }) {
                        m.stage = m.stage.saturating_sub(1);
                    }
                    if attr == (if id == 492 { 2 } else { 1 }) {
                        m.stage = m.stage.saturating_add(1);
                    }
                }
            }
            387 | 397 | 877 => {
                let m = self.sides[side].monsters[slot].as_ref().unwrap();
                self.damage(
                    enemy,
                    u32::from(db.stats(m.card_id, self.terrain, m.stage).0),
                );
                if id == 877 {
                    let m = self.sides[side].monsters[slot].as_mut().unwrap();
                    m.stage = m.stage.saturating_sub(1);
                }
            }
            762 | 811 | 890 => {
                let count = if id == 762 {
                    self.sides
                        .iter()
                        .flat_map(|s| s.monsters.iter().flatten())
                        .filter(|m| db.card(m.card_id).type_id == 10)
                        .count()
                } else {
                    self.sides[if id == 811 { enemy } else { side }]
                        .monsters
                        .iter()
                        .flatten()
                        .filter(|m| db.card(m.card_id).type_id == 1)
                        .count()
                };
                let m = self.sides[side].monsters[slot].as_mut().unwrap();
                m.stage = m.stage.saturating_add(count as i8);
            }
            832 => {
                self.clear_monsters(db, enemy, false);
                self.damage(enemy, 4000);
            }
            833 => {
                let count = self.sides[side].hand.len() as i8 * 3;
                let m = self.sides[side].monsters[slot].as_mut().unwrap();
                m.stage = m.stage.saturating_add(count);
            }
            834 => {
                let damage = self.sides[side].lp.saturating_sub(1);
                self.damage(enemy, damage);
                self.sides[side].lp = 1;
            }
            738 | 757 | 850 => {
                let materials: Vec<usize> = [738, 757, 850]
                    .iter()
                    .filter(|&&material| material != id)
                    .filter_map(|&material| {
                        self.sides[side]
                            .monsters
                            .iter()
                            .position(|m| m.as_ref().is_some_and(|m| m.card_id == material))
                    })
                    .collect();
                if materials.len() == 2 {
                    self.fusion(side, slot, 883);
                    for material in materials {
                        self.sides[side].monsters[material] = None;
                        self.borrowed[side][material] = false;
                    }
                }
            }
            883 => {
                if self.sides[side]
                    .monsters
                    .iter()
                    .filter(|m| m.is_none())
                    .count()
                    >= 2
                {
                    self.fusion(side, slot, 738);
                    let dst = self.sides[side]
                        .monsters
                        .iter()
                        .position(Option::is_none)
                        .unwrap();
                    self.fusion(side, dst, 757);
                    let dst = self.sides[side]
                        .monsters
                        .iter()
                        .position(Option::is_none)
                        .unwrap();
                    self.fusion(side, dst, 850);
                }
            }
            778 => {
                self.lower_row(enemy);
                self.destroy(db, side, slot);
            }
            812 => {
                // The native two guards both inspect the enemy row. If our
                // field is full, FindCardInDuelRow(0) returns slot zero.
                if let Some(src) = self.strongest(db, enemy, true) {
                    let dst = self.sides[side]
                        .monsters
                        .iter()
                        .position(Option::is_none)
                        .unwrap_or(0);
                    let mut m = self.sides[enemy].monsters[src].take().unwrap();
                    m.face_down = false;
                    m.defense = false;
                    m.attacked = false;
                    self.sides[side].monsters[dst] = Some(m);
                    self.borrowed[side][dst] = false;
                    self.borrowed[enemy][src] = false;
                }
            }
            858 | 874 | 871 => {
                if let Some(target) = self.strongest(db, enemy, true) {
                    if id == 874 {
                        self.sides[enemy].monsters[target] = None;
                        self.borrowed[enemy][target] = false;
                    } else {
                        self.destroy(db, enemy, target);
                    }
                    if id != 871 {
                        let m = self.sides[side].monsters[slot].as_mut().unwrap();
                        m.stage = if id == 874 {
                            m.stage.saturating_add(1)
                        } else {
                            m.stage.saturating_sub(1)
                        };
                    }
                }
                if id == 871 {
                    self.damage(enemy, 500);
                }
            }
            873 => self.clear_monsters(db, enemy, true),
            743 => {
                for _ in 0..3 {
                    let Some(target) = self.strongest(db, enemy, true) else {
                        break;
                    };
                    if self.random() % 2 == 1 {
                        self.destroy(db, enemy, target);
                    }
                }
            }
            756 => {
                if let Some(target) = self.strongest(db, enemy, false) {
                    let m = self.sides[enemy].monsters[target].as_ref().unwrap();
                    self.damage(
                        enemy,
                        u32::from(db.stats(m.card_id, self.terrain, m.stage).0),
                    );
                }
                self.destroy(db, side, slot);
            }
            763 => {
                if let Some(dst) = self.strongest(db, enemy, true) {
                    let mut m = self.sides[side].monsters[slot].take().unwrap();
                    m.face_down = false;
                    m.defense = false;
                    m.attacked = false;
                    self.sides[enemy].monsters[dst] = Some(m);
                    self.borrowed[side][slot] = false;
                    self.borrowed[enemy][dst] = false;
                }
            }
            764 => {
                self.heal(side, 500);
                self.destroy(db, side, slot);
            }
            766 => {
                self.destroy(db, side, slot);
                let target = self.sides[side]
                    .hand
                    .iter()
                    .enumerate()
                    .filter(|&(_, &id)| db.card(id).type_id == 10)
                    .map(|(i, &id)| (i, db.stats(id, self.terrain, 0).0))
                    .max_by_key(|&(_, attack)| attack)
                    .map(|(i, _)| i);
                if let Some(target) = target {
                    let id = self.remove_hand_card(side, target);
                    let mut m = Monster::new(id, false);
                    m.face_down = false;
                    self.sides[side].monsters[slot] = Some(m);
                }
            }
            838 => {
                if let Some(target) = self.strongest(db, enemy, false) {
                    let m = self.sides[enemy].monsters[target].as_mut().unwrap();
                    m.stage = m.stage.saturating_sub(1);
                }
            }
            878 => {
                let m = self.sides[side].monsters[slot].as_mut().unwrap();
                m.stage = m.stage.saturating_add(1);
            }
            _ => unreachable!("supported monster must have an implementation: {id}"),
        }
        self.check_special_win();
        Ok(())
    }

    pub fn discard_hand(&mut self, db: &Database, hand_index: usize) -> Result<(), String> {
        self.require_live()?;
        let id = self.hand_card(hand_index)?;
        self.remove_hand_card(self.active, hand_index);
        self.discard_card(db, self.active, id);
        self.note(format!(
            "{} discarded {}.",
            self.side_name(self.active),
            db.card(id).name
        ));
        Ok(())
    }

    /// Native duel context-menu discard, used to free an occupied own field.
    pub fn discard_monster(&mut self, db: &Database, slot: usize) -> Result<(), String> {
        self.require_live()?;
        let id = self.sides[self.active]
            .monsters
            .get(slot)
            .and_then(Option::as_ref)
            .ok_or("Choose an occupied friendly monster slot.")?
            .card_id;
        self.destroy(db, self.active, slot);
        self.note(format!(
            "{} discarded {}.",
            self.side_name(self.active),
            db.card(id).name
        ));
        Ok(())
    }

    pub fn discard_spell(&mut self, db: &Database, slot: usize) -> Result<(), String> {
        self.require_live()?;
        let id = self.sides[self.active]
            .spells
            .get(slot)
            .copied()
            .flatten()
            .ok_or("Choose an occupied friendly spell/trap slot.")?;
        self.consume_trap(db, self.active, slot);
        self.note(format!(
            "{} discarded {}.",
            self.side_name(self.active),
            db.card(id).name
        ));
        Ok(())
    }

    pub fn end_turn(&mut self, db: &Database) -> Result<(), String> {
        self.require_live()?;
        let side = self.active;
        let enemy = 1 - side;
        // Temporary Brain Control monsters return to the LAST free enemy slot.
        for slot in 0..FIELD_SLOTS {
            if self.borrowed[side][slot] {
                self.borrowed[side][slot] = false;
                if let Some(mut monster) = self.sides[side].monsters[slot].take() {
                    if let Some(dst) = self.sides[enemy].monsters.iter().rposition(Option::is_none)
                    {
                        monster.face_down = false;
                        monster.defense = false;
                        monster.attacked = false;
                        self.sides[enemy].monsters[dst] = Some(monster);
                    }
                    // Native clears the source without remembering a grave card.
                }
            }
        }
        for m in self.sides[side].monsters.iter_mut().flatten() {
            if !m.defense {
                m.face_down = false;
            }
            m.attacked = false;
        }
        self.forbid_defense[side] = false;
        self.attack_restrictions[side] = self.attack_restrictions[side].saturating_sub(1);
        self.active = enemy;
        self.turn += 1;
        self.note(format!("Turn {}: {}.", self.turn, self.side_name(enemy)));
        self.begin_turn(db);
        Ok(())
    }

    pub fn surrender(&mut self) {
        if self.winner.is_none() {
            self.winner = Some(1 - self.active);
            self.note(format!("{} surrendered.", self.side_name(self.active)));
        }
    }

    /// A legal, deterministic heuristic opponent; original AI callback emulation
    /// is outside this layer. Actions use exactly the same public rule methods.
    pub fn run_ai_turn(&mut self, db: &Database) {
        if self.active != 1 || self.winner.is_some() {
            return;
        }
        // Set traps and use beneficial spells. The cap prevents repeat-draw loops.
        for _ in 0..12 {
            let mut action = None;
            for (index, &id) in self.sides[1].hand.iter().enumerate() {
                if db.card(id).is_monster() || !Self::spell_supported(db, id) {
                    continue;
                }
                if !self.ai_wants_spell(db, id) {
                    continue;
                }
                let target = if Self::spell_needs_target(id) {
                    self.sides[1]
                        .monsters
                        .iter()
                        .enumerate()
                        .filter_map(|(slot, m)| {
                            let m = m.as_ref()?;
                            if m.attacked {
                                return None;
                            }
                            let valid = if equipment_index(id).is_some() {
                                db.equipment_compatible(id, m.card_id)
                            } else if id == 318 {
                                matches!(m.card_id, 62 | 875)
                            } else {
                                matches!(m.card_id, 391 | 82 | 885)
                            };
                            valid.then_some((slot, db.stats(m.card_id, self.terrain, m.stage).0))
                        })
                        .max_by_key(|&(_, attack)| attack)
                        .map(|(slot, _)| slot)
                } else {
                    None
                };
                if Self::spell_needs_target(id) && target.is_none() {
                    continue;
                }
                let Ok(plan) = self.ritual_plan(id) else {
                    continue;
                };
                let materials = plan
                    .as_ref()
                    .map(|(slots, _)| slots.as_slice())
                    .unwrap_or(&[]);
                let required = Self::required_spell_tributes(db, id);
                let mut candidates: Vec<(usize, u16)> = self.sides[1]
                    .monsters
                    .iter()
                    .enumerate()
                    .filter(|(slot, _)| !materials.contains(slot))
                    .filter_map(|(slot, m)| {
                        m.as_ref()
                            .map(|m| (slot, db.stats(m.card_id, self.terrain, m.stage).0))
                    })
                    .collect();
                candidates.sort_by_key(|&(_, attack)| attack);
                let tributes: Vec<usize> = candidates
                    .iter()
                    .take(required)
                    .map(|&(slot, _)| slot)
                    .collect();
                if tributes.len() != required {
                    continue;
                }
                action = Some((index, target, tributes));
                break;
            }
            if let Some((index, target, tributes)) = action {
                if self
                    .play_spell_with_tributes(db, index, target, &tributes)
                    .is_err()
                {
                    break;
                }
            } else {
                break;
            }
            if self.winner.is_some() {
                return;
            }
        }
        if !self.normal_summoned {
            let mut weakest: Vec<(usize, u16)> = self.sides[1]
                .monsters
                .iter()
                .enumerate()
                .filter_map(|(slot, m)| {
                    m.as_ref()
                        .map(|m| (slot, db.stats(m.card_id, self.terrain, m.stage).0))
                })
                .collect();
            weakest.sort_by_key(|&(_, attack)| attack);
            let mut best = None;
            for (index, &id) in self.sides[1].hand.iter().enumerate() {
                if !db.card(id).is_monster() {
                    continue;
                }
                let needed = db.tributes(id);
                if needed > weakest.len() {
                    continue;
                }
                let empty = self.sides[1].monsters.iter().position(Option::is_none);
                if empty.is_none() && needed == 0 {
                    continue;
                }
                let (attack, defense) = db.stats(id, self.terrain, 0);
                let sacrificed: u32 = weakest
                    .iter()
                    .take(needed)
                    .map(|&(_, atk)| u32::from(atk))
                    .sum();
                let score = i32::from(attack.max(defense)) - sacrificed as i32 / 2;
                if needed > 0 && attack <= weakest[needed - 1].1 {
                    continue;
                }
                if best
                    .as_ref()
                    .is_none_or(|&(_, _, old_score)| score > old_score)
                {
                    best = Some((index, needed, score));
                }
            }
            if let Some((index, needed, _)) = best {
                let tributes: Vec<usize> =
                    weakest.iter().take(needed).map(|&(slot, _)| slot).collect();
                let slot = self.sides[1]
                    .monsters
                    .iter()
                    .position(Option::is_none)
                    .or_else(|| tributes.first().copied())
                    .unwrap();
                let _ = self.summon(db, index, slot, false, &tributes);
            }
        }
        // Native monster effects are once per face-down lifetime and use action.
        for slot in 0..FIELD_SLOTS {
            if self.sides[1].monsters[slot].as_ref().is_some_and(|m| {
                m.face_down && !m.attacked && Self::monster_effect_supported(m.card_id)
            }) {
                let _ = self.activate_monster(db, slot);
            }
            if self.winner.is_some() {
                return;
            }
        }
        for slot in 0..FIELD_SLOTS {
            if !self.can_attack(slot) {
                continue;
            }
            if self.sides[0].monsters.iter().all(Option::is_none) {
                let _ = self.attack(db, slot, None);
            } else {
                let target = (0..FIELD_SLOTS)
                    .filter_map(|target| {
                        let result = self.preview_battle(db, slot, target)?;
                        if result.destroy_attacker || result.damage_attacker > 0 {
                            return None;
                        }
                        Some((
                            target,
                            i32::from(result.destroy_defender) * 10000
                                + result.damage_defender as i32,
                        ))
                    })
                    .filter(|&(_, score)| score > 0)
                    .max_by_key(|&(_, score)| score)
                    .map(|(target, _)| target);
                if let Some(target) = target {
                    let _ = self.attack(db, slot, Some(target));
                } else if self.sides[1].monsters[slot]
                    .as_ref()
                    .is_some_and(|m| !m.defense)
                {
                    let _ = self.set_position(slot);
                }
            }
            if self.winner.is_some() {
                return;
            }
        }
        // Free a hand slot when unusable cards would otherwise stop all draws.
        if self.sides[1].hand.len() == HAND_LIMIT {
            let index = self.sides[1]
                .hand
                .iter()
                .position(|&id| !db.card(id).is_monster() && !Self::spell_supported(db, id))
                .unwrap_or(0);
            let _ = self.discard_hand(db, index);
        }
        if self.winner.is_none() {
            let _ = self.end_turn(db);
        }
    }

    fn ai_wants_spell(&self, db: &Database, id: u16) -> bool {
        let own = self.sides[1].monsters.iter().flatten().count();
        let opposing = self.sides[0].monsters.iter().flatten().count();
        match id {
            336 | 893 | 894 => opposing > own,
            337
            | 329
            | 320
            | 348..=350
            | 653
            | 656
            | 660..=664
            | 669
            | 781
            | 784
            | 786
            | 787
            | 891
            | 898 => opposing > 0,
            338..=342 => self.sides[1].lp < 8000,
            672 => self.sides[0].spells.iter().any(Option::is_some),
            655 => self.sides[1].monsters.iter().flatten().any(|m| m.stage < 0),
            789 => self.sides[1].hand.len() >= 2,
            785 => self.sides[1]
                .monsters
                .iter()
                .flatten()
                .any(|m| m.card_id == 58),
            895 => self.remembered_grave[0].is_some() && own < FIELD_SLOTS,
            896 => self.remembered_grave[0].is_some(),
            330..=335 => {
                self.sides[1]
                    .monsters
                    .iter()
                    .flatten()
                    .map(|m| {
                        i32::from(db.stats(m.card_id, (id - 329) as u8, m.stage).0)
                            - i32::from(db.stats(m.card_id, self.terrain, m.stage).0)
                    })
                    .sum::<i32>()
                    > 0
            }
            892 => false,
            _ => true,
        }
    }
}

fn equipment_index(id: u16) -> Option<usize> {
    const IDS: [u16; 33] = [
        301, 302, 303, 304, 305, 306, 307, 308, 309, 310, 311, 312, 313, 314, 315, 316, 317, 319,
        321, 322, 323, 324, 325, 326, 327, 328, 652, 654, 651, 668, 657, 659, 900,
    ];
    IDS.iter().position(|&spell| spell == id)
}

fn ritual(id: u16) -> Option<(u16, u16)> {
    Some(match id {
        670 => (38, 364),
        671 => (377, 360),
        673 => (403, 356),
        674 => (595, 365),
        676 => (249, 701),
        677 => (295, 702),
        678 => (3, 703),
        679 => (160, 704),
        680 => (571, 705),
        691 => (168, 706),
        692 => (449, 710),
        693 => (102, 720),
        694 => (269, 709),
        695 => (166, 715),
        696 => (52, 717),
        697 => (621, 716),
        698 => (638, 708),
        699 => (146, 719),
        700 => (441, 718),
        665 => (296, 362),
        666 => (29, 357),
        783 => (730, 731),
        _ => return None,
    })
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::OnceLock;

    fn db() -> &'static Database {
        static DB: OnceLock<Database> = OnceLock::new();
        DB.get_or_init(|| {
            Database::load(concat!(
                env!("CARGO_MANIFEST_DIR"),
                "/sacred-cards-decompiled/build/assets"
            ))
            .unwrap()
        })
    }

    fn board() -> Duel {
        let mut duel = Duel::new(db(), &db().initial_deck, 0, 123);
        duel.active = 0;
        duel.turn = 2;
        duel.terrain = 0;
        duel.winner = None;
        duel.normal_summoned = false;
        duel.log.clear();
        duel.sides = [Side::new(vec![3; 20], 8000), Side::new(vec![3; 20], 8000)];
        duel
    }

    #[test]
    fn neutral_attack_battles_destroy_and_damage_exactly_as_native() {
        use AttributeRelation::Neutral;
        assert_eq!(
            resolve_battle(1800, 1500, false, Neutral),
            BattleResult {
                destroy_defender: true,
                damage_defender: 300,
                ..BattleResult::default()
            }
        );
        assert_eq!(
            resolve_battle(1500, 1800, false, Neutral),
            BattleResult {
                destroy_attacker: true,
                damage_attacker: 300,
                ..BattleResult::default()
            }
        );
        assert_eq!(
            resolve_battle(1500, 1500, false, Neutral),
            BattleResult {
                destroy_attacker: true,
                destroy_defender: true,
                ..BattleResult::default()
            }
        );
    }

    #[test]
    fn native_defense_battles_do_not_destroy_underpowered_attackers() {
        use AttributeRelation::Neutral;
        assert_eq!(
            resolve_battle(1000, 1500, true, Neutral),
            BattleResult {
                damage_attacker: 500,
                ..BattleResult::default()
            }
        );
        assert_eq!(
            resolve_battle(1500, 1500, true, Neutral),
            BattleResult::default()
        );
        assert_eq!(
            resolve_battle(1800, 1500, true, Neutral),
            BattleResult {
                destroy_defender: true,
                ..BattleResult::default()
            }
        );
    }

    #[test]
    fn attribute_override_destruction_and_damage_are_separate() {
        use AttributeRelation::*;
        assert_eq!(
            resolve_battle(300, 3000, false, AttackerWins),
            BattleResult {
                destroy_defender: true,
                ..BattleResult::default()
            }
        );
        assert_eq!(
            resolve_battle(3000, 300, false, DefenderWins),
            BattleResult {
                destroy_attacker: true,
                ..BattleResult::default()
            }
        );
        assert_eq!(
            resolve_battle(3000, 300, false, AttackerWins).damage_defender,
            2700
        );
        assert_eq!(
            resolve_battle(3000, 300, true, AttackerWins).damage_defender,
            0
        );
        assert_eq!(
            resolve_battle(300, 3000, true, DefenderWins),
            BattleResult {
                destroy_attacker: true,
                damage_attacker: 2700,
                ..BattleResult::default()
            }
        );
    }

    #[test]
    fn divine_attributes_bypass_the_lookup() {
        for god in [832, 833, 834] {
            for monster in [1, 3, 15, 58, 140] {
                assert_eq!(
                    Duel::attribute_relation(db(), god, monster),
                    AttributeRelation::Neutral
                );
                assert_eq!(
                    Duel::attribute_relation(db(), monster, god),
                    AttributeRelation::Neutral
                );
            }
        }
    }

    #[test]
    fn invalid_summons_are_atomic_including_duplicate_tributes() {
        let mut duel = board();
        duel.sides[0].hand = vec![1]; // Blue-Eyes requires two tributes.
        duel.sides[0].monsters[0] = Some(Monster::new(3, false));
        duel.sides[0].monsters[1] = Some(Monster::new(4, false));
        let before = duel.clone();
        assert!(duel.summon(db(), 0, 0, false, &[0, 0]).is_err());
        assert_eq!(duel, before);
        assert!(duel.summon(db(), 0, 9, false, &[0, 1]).is_err());
        assert_eq!(duel, before);
        duel.summon(db(), 0, 0, false, &[0, 1]).unwrap();
        assert_eq!(duel.sides[0].monsters[0].as_ref().unwrap().card_id, 1);
        assert!(duel.sides[0].monsters[1].is_none());
        assert_eq!(duel.sides[0].graveyard, [3, 4]);
        assert_eq!(duel.remembered_grave[0], Some(4));
        assert!(duel.normal_summoned);
    }

    #[test]
    fn one_summon_per_turn_and_failed_actions_do_not_consume_cards() {
        let mut duel = board();
        duel.sides[0].hand = vec![3, 4];
        duel.summon(db(), 0, 0, false, &[]).unwrap();
        let before = duel.clone();
        assert!(duel.summon(db(), 0, 1, false, &[]).is_err());
        assert_eq!(duel, before);
        duel.sides[1].monsters[0] = Some(Monster::new(4, false));
        let before = duel.clone();
        assert!(duel.attack(db(), 0, None).is_err());
        assert!(duel.attack(db(), 0, Some(5)).is_err());
        assert_eq!(duel, before);
    }

    #[test]
    fn opening_turn_attack_is_rejected_without_mutation() {
        let mut duel = board();
        duel.turn = 1;
        duel.sides[0].monsters[0] = Some(Monster::new(1, false));
        let before = duel.clone();
        assert!(duel.attack(db(), 0, None).is_err());
        assert_eq!(duel, before);
    }

    #[test]
    fn full_hand_skips_draw_even_with_an_empty_deck() {
        let mut duel = board();
        duel.sides[1].deck.clear();
        duel.sides[1].hand = vec![3; HAND_LIMIT];
        duel.end_turn(db()).unwrap();
        assert_eq!(duel.winner, None);
        assert_eq!(duel.sides[1].hand.len(), HAND_LIMIT);
        assert_eq!(duel.active, 1);
        duel.sides[1].hand.pop();
        duel.draw(1);
        assert_eq!(duel.winner, Some(0));
    }

    #[test]
    fn hand_draw_effect_respects_five_cards_and_checks_exodia() {
        let mut duel = board();
        duel.sides[0].hand = vec![789, 17, 18, 19, 20];
        duel.sides[0].deck = vec![21];
        duel.play_spell(db(), 0, None).unwrap();
        assert_eq!(duel.sides[0].hand, [17, 18, 19, 20, 21]);
        assert_eq!(duel.winner, Some(0));
        assert_eq!(duel.sides[0].graveyard, [789]);
    }

    #[test]
    fn unsupported_effects_and_bad_equipment_targets_leave_state_unchanged() {
        let mut duel = board();
        let unsupported = db()
            .cards
            .iter()
            .find(|c| c.id != 0 && !c.is_monster() && !Duel::spell_supported(db(), c.id))
            .unwrap()
            .id;
        duel.sides[0].hand = vec![unsupported, 301];
        let before = duel.clone();
        assert!(duel
            .play_spell(db(), 0, None)
            .unwrap_err()
            .contains("not implemented"));
        assert_eq!(duel, before);
        assert!(duel.play_spell(db(), 1, Some(0)).is_err());
        assert_eq!(duel, before);
    }

    #[test]
    fn traps_use_first_eligible_slot_and_are_consumed() {
        let mut duel = board();
        duel.sides[0].monsters[0] = Some(Monster::new(58, false)); // 300 ATK.
        duel.sides[1].spells[0] = Some(682); // <=1000.
        duel.sides[1].spells[1] = Some(681); // <=500.
        duel.attack(db(), 0, None).unwrap();
        assert!(duel.sides[0].monsters[0].is_none());
        assert_eq!(duel.sides[1].spells[0], None);
        assert_eq!(duel.sides[1].spells[1], Some(681));
        assert_eq!(duel.sides[1].lp, 8000);
    }

    #[test]
    fn setting_a_real_trap_moves_it_from_hand_to_the_spell_row() {
        let mut duel = board();
        duel.sides[0].hand = vec![686];
        duel.play_spell(db(), 0, None).unwrap();
        assert_eq!(duel.sides[0].spells[0], Some(686));
        assert!(duel.sides[0].hand.is_empty());
        assert!(duel.sides[0].graveyard.is_empty());
    }

    #[test]
    fn rituals_require_native_extra_tributes_and_preserve_their_material() {
        let mut duel = board();
        duel.sides[0].hand = vec![670];
        for (slot, id) in [38, 3, 4].into_iter().enumerate() {
            duel.sides[0].monsters[slot] = Some(Monster::new(id, false));
        }
        assert_eq!(Duel::required_spell_tributes(db(), 670), 2);
        let before = duel.clone();
        assert!(duel.play_spell(db(), 0, None).is_err());
        assert_eq!(duel, before);
        assert!(duel
            .play_spell_with_tributes(db(), 0, None, &[0, 1])
            .is_err());
        assert_eq!(duel, before);
        duel.play_spell_with_tributes(db(), 0, None, &[1, 2])
            .unwrap();
        assert_eq!(duel.sides[0].monsters[0].as_ref().unwrap().card_id, 364);
        assert!(duel.sides[0].monsters[1].is_none());
        assert!(duel.sides[0].monsters[2].is_none());
        assert_eq!(duel.sides[0].graveyard, [3, 4, 670]);
    }

    #[test]
    fn compound_rituals_use_exact_exported_native_recipes() {
        let mut duel = board();
        duel.sides[0].hand = vec![675];
        for slot in 0..3 {
            duel.sides[0].monsters[slot] = Some(Monster::new(1, false));
        }
        assert_eq!(Duel::required_spell_tributes(db(), 675), 0);
        duel.play_spell(db(), 0, None).unwrap();
        assert_eq!(duel.sides[0].monsters[0].as_ref().unwrap().card_id, 380);
        assert_eq!(duel.sides[0].monsters.iter().flatten().count(), 1);
        assert_eq!(duel.sides[0].graveyard, [675]);
    }

    #[test]
    fn dark_magic_ritual_transforms_to_monster_721() {
        let mut duel = board();
        duel.sides[0].hand = vec![722];
        for (slot, id) in [865, 3, 4].into_iter().enumerate() {
            duel.sides[0].monsters[slot] = Some(Monster::new(id, false));
        }
        duel.play_spell_with_tributes(db(), 0, None, &[1, 2])
            .unwrap();
        assert_eq!(duel.sides[0].monsters[0].as_ref().unwrap().card_id, 721);
    }

    #[test]
    fn supported_spell_dispatch_has_no_unhandled_native_card_ids() {
        for card in db()
            .cards
            .iter()
            .filter(|c| !c.is_monster() && Duel::spell_supported(db(), c.id))
        {
            let mut duel = board();
            duel.sides[0].hand = vec![card.id];
            // Material/target validation can legitimately fail; dispatch must
            // remain total for every supported card, including trap categories.
            let _ = duel.play_spell(db(), 0, Some(0));
        }
    }

    #[test]
    fn reflected_burn_and_inverted_healing_damage_the_acting_side() {
        for (spell, trap, amount) in [(347, 687, 1000), (341, 688, 2000)] {
            let mut duel = board();
            duel.sides[0].hand = vec![spell];
            duel.sides[1].spells[0] = Some(trap);
            duel.play_spell(db(), 0, None).unwrap();
            assert_eq!(duel.sides[0].lp, 8000 - amount);
            assert_eq!(duel.sides[1].lp, 8000);
            assert_eq!(duel.sides[1].spells[0], None);
            assert!(duel.sides[0].hand.is_empty());
        }
    }

    #[test]
    fn reversed_equipment_really_lowers_stage_in_the_native_wrapper() {
        let mut duel = board();
        duel.sides[0].hand = vec![301];
        duel.sides[0].monsters[0] = Some(Monster::new(12, false));
        duel.sides[1].spells[0] = Some(689);
        duel.play_spell(db(), 0, Some(0)).unwrap();
        assert_eq!(duel.sides[0].monsters[0].as_ref().unwrap().stage, -1);
        assert_eq!(duel.sides[1].spells[0], None);
    }

    #[test]
    fn enemy_action_locks_survive_the_start_of_their_turn() {
        let mut duel = board();
        duel.sides[0].monsters[0] = Some(Monster::new(42, false));
        duel.sides[1].monsters[0] = Some(Monster::new(3, false));
        duel.activate_monster(db(), 0).unwrap();
        duel.end_turn(db()).unwrap();
        assert!(duel.sides[1].monsters[0].as_ref().unwrap().attacked);
        assert!(!duel.can_attack(0));
        duel.end_turn(db()).unwrap();
        assert!(!duel.sides[1].monsters[0].as_ref().unwrap().attacked);
    }

    #[test]
    fn effect_immunity_is_respected_and_healing_caps_at_9999() {
        let mut duel = board();
        duel.sides[0].hand = vec![336, 342];
        duel.sides[1].monsters[0] = Some(Monster::new(832, false));
        duel.sides[1].monsters[1] = Some(Monster::new(3, false));
        duel.play_spell(db(), 0, None).unwrap();
        assert!(duel.sides[1].monsters[0].is_some());
        assert!(duel.sides[1].monsters[1].is_none());
        duel.play_spell(db(), 0, None).unwrap();
        assert_eq!(duel.sides[0].lp, 9999);
    }

    #[test]
    fn monster_reborn_uses_only_the_opposing_remembered_grave() {
        let mut duel = board();
        duel.remembered_grave = [Some(1), Some(3)];
        duel.sides[0].hand = vec![895];
        duel.play_spell(db(), 0, None).unwrap();
        assert_eq!(duel.sides[0].monsters[0].as_ref().unwrap().card_id, 3);
        assert_eq!(duel.remembered_grave, [Some(1), None]);
    }

    #[test]
    fn temporary_control_returns_to_the_last_enemy_slot() {
        let mut duel = board();
        duel.sides[0].hand = vec![781];
        duel.sides[1].monsters[0] = Some(Monster::new(3, false));
        duel.play_spell(db(), 0, None).unwrap();
        assert!(duel.sides[0].monsters[0].is_some());
        duel.end_turn(db()).unwrap();
        assert!(duel.sides[0].monsters[0].is_none());
        assert_eq!(duel.sides[1].monsters[4].as_ref().unwrap().card_id, 3);
    }

    #[test]
    fn swords_restriction_counts_only_affected_sides_completed_turns() {
        let mut duel = board();
        duel.sides[0].hand = vec![348];
        duel.sides[1].monsters[0] = Some(Monster::new(3, false));
        duel.play_spell(db(), 0, None).unwrap();
        duel.end_turn(db()).unwrap();
        assert_eq!(duel.attack_restrictions[1], 3);
        assert!(!duel.can_attack(0));
        duel.end_turn(db()).unwrap();
        assert_eq!(duel.attack_restrictions[1], 2);
        duel.end_turn(db()).unwrap();
        assert_eq!(duel.attack_restrictions[1], 2);
    }

    #[test]
    fn identical_seeds_produce_identical_starting_duels() {
        assert_eq!(
            Duel::new(db(), &db().initial_deck, 1, 761),
            Duel::new(db(), &db().initial_deck, 1, 761)
        );
    }

    #[test]
    fn native_field_discard_frees_slots_and_remembers_only_monsters() {
        let mut duel = board();
        duel.sides[0].monsters[0] = Some(Monster::new(3, false));
        duel.sides[0].spells[0] = Some(686);
        let before = duel.clone();
        assert!(duel.discard_monster(db(), 7).is_err());
        assert!(duel.discard_spell(db(), 7).is_err());
        assert_eq!(duel, before);
        duel.discard_monster(db(), 0).unwrap();
        duel.discard_spell(db(), 0).unwrap();
        assert!(duel.sides[0].monsters[0].is_none());
        assert!(duel.sides[0].spells[0].is_none());
        assert_eq!(duel.sides[0].graveyard, [3, 686]);
        assert_eq!(duel.remembered_grave[0], Some(3));
    }

    #[test]
    fn hand_reveal_tracks_known_cards_without_exposing_later_draws() {
        let mut duel = board();
        duel.sides[0].hand = vec![790];
        duel.sides[1].hand = vec![3, 4];
        duel.sides[1].deck = vec![3]; // A newly drawn duplicate stays hidden.
        duel.play_spell(db(), 0, None).unwrap();
        assert_eq!(duel.known_opponent_hand(0), [3, 4]);
        duel.end_turn(db()).unwrap();
        assert_eq!(duel.sides[1].hand, [3, 4, 3]);
        assert_eq!(duel.known_opponent_hand(0), [3, 4]);
        duel.discard_hand(db(), 2).unwrap();
        assert_eq!(duel.known_opponent_hand(0), [3, 4]);
        duel.summon(db(), 0, 0, false, &[]).unwrap();
        assert_eq!(duel.known_opponent_hand(0), [4]);
    }

    #[test]
    fn zero_sentinel_opponent_records_deck_out_instead_of_drawing_empty_cards() {
        let duel = Duel::new(db(), &db().initial_deck, 0, 761);
        assert_eq!(duel.winner, Some(0));
        assert!(duel.sides[1].deck.is_empty());
        assert!(duel.sides[1].hand.is_empty());
        assert!(duel.sides.iter().all(|s| s.hand.iter().all(|&id| id != 0)));
    }

    #[test]
    fn supported_activations_cover_each_native_referenced_monster_handler() {
        for card in db()
            .cards
            .iter()
            .filter(|c| c.is_monster() && c.metadata_1b != 0)
        {
            assert!(
                Duel::monster_effect_supported(card.id),
                "Missing handler for {} ({})",
                card.name,
                card.id
            );
            let mut duel = board();
            duel.sides[0].monsters[0] = Some(Monster::new(card.id, false));
            duel.activate_monster(db(), 0).unwrap();
        }
    }
}
