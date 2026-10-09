use macroquad::{
    audio::{load_sound, play_sound, stop_sound, PlaySoundParams, Sound},
    prelude::*,
};
use sacred_cards::{
    data::Database,
    duel::Duel,
    save::Profile,
    world::{ScriptEvent, ScriptRunner, Transition, World},
};
use std::{collections::HashMap, path::PathBuf};

const W: f32 = 1280.;
const H: f32 = 800.;
const INK: Color = Color::new(0.035, 0.051, 0.082, 1.);
const PANEL: Color = Color::new(0.068, 0.091, 0.132, 1.);
const PANEL2: Color = Color::new(0.092, 0.120, 0.169, 1.);
const GOLD: Color = Color::new(0.88, 0.70, 0.40, 1.);
const TEXT: Color = Color::new(0.90, 0.91, 0.88, 1.);
const MUTED: Color = Color::new(0.48, 0.57, 0.64, 1.);
const TEAL: Color = Color::new(0.35, 0.79, 0.71, 1.);
const RED: Color = Color::new(0.91, 0.40, 0.40, 1.);

#[derive(Clone, Copy, PartialEq)]
enum View {
    Title,
    Hub,
    World,
    Opponents,
    Duel,
    Deck,
    Shop,
    Catalog,
    Atlas,
    City,
}

#[derive(PartialEq)]
enum Modal {
    Name,
    Password,
    Credits,
    Hand,
}

#[derive(Default)]
struct Art {
    textures: HashMap<String, Texture2D>,
    root: PathBuf,
}
impl Art {
    fn draw(&mut self, name: &str, rect: Rect, tint: Color) -> bool {
        self.draw_source(name, rect, None, tint)
    }
    fn draw_source(&mut self, name: &str, rect: Rect, source: Option<Rect>, tint: Color) -> bool {
        if !self.textures.contains_key(name) {
            if let Ok(bytes) = std::fs::read(self.root.join(name)) {
                let texture = Texture2D::from_file_with_format(&bytes, Some(ImageFormat::Png));
                texture.set_filter(FilterMode::Nearest);
                self.textures.insert(name.into(), texture);
            } else {
                return false;
            }
        }
        draw_texture_ex(
            &self.textures[name],
            rect.x,
            rect.y,
            tint,
            DrawTextureParams {
                dest_size: Some(vec2(rect.w, rect.h)),
                source,
                ..Default::default()
            },
        );
        true
    }
}

pub struct App {
    db: Database,
    profile: Profile,
    world: Option<World>,
    view: View,
    art: Art,
    duel: Option<Duel>,
    opponent: usize,
    card: u16,
    hand: Option<usize>,
    monster: Option<usize>,
    spell: Option<usize>,
    tributes: Vec<usize>,
    defense: bool,
    list_offset: usize,
    query: String,
    search_focus: bool,
    dialogue: Vec<String>,
    dialogue_line: usize,
    script: Option<ScriptRunner>,
    choices: Vec<String>,
    portrait: u16,
    modal: Option<Modal>,
    input: String,
    story_duel: bool,
    outcome: String,
    city_origin: usize,
    toast: String,
    toast_until: f64,
    move_timer: f32,
    facing: usize,
    settled: bool,
    muted: bool,
    music_id: u16,
    sound: Option<Sound>,
    save_path: PathBuf,
    pub quit: bool,
}

impl App {
    pub fn new(db: Database) -> Self {
        let save_path = std::env::var_os("SACRED_SAVE")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("saves/player.json"));
        let profile = Profile::new(&db);
        let art = Art {
            root: db.asset_root.clone(),
            ..Default::default()
        };
        Self {
            db,
            profile,
            world: None,
            view: View::Title,
            art,
            duel: None,
            opponent: 1,
            card: 794,
            hand: None,
            monster: None,
            spell: None,
            tributes: vec![],
            defense: false,
            list_offset: 0,
            query: String::new(),
            search_focus: false,
            dialogue: vec![],
            dialogue_line: 0,
            script: None,
            choices: vec![],
            portrait: 0,
            modal: None,
            input: String::new(),
            story_duel: false,
            outcome: String::new(),
            city_origin: 0,
            toast: String::new(),
            toast_until: 0.,
            move_timer: 0.,
            facing: 0,
            settled: false,
            muted: false,
            music_id: u16::MAX,
            sound: None,
            save_path,
            quit: false,
        }
    }

    pub fn prepare_smoke(&mut self, screen: &str) {
        self.muted = true;
        match screen {
            "hub" => self.view = View::Hub,
            "world" => self.enter_world(),
            "duel" => self.start_duel(),
            "deck" => self.change_view(View::Deck),
            "shop" => self.change_view(View::Shop),
            "cards" => self.change_view(View::Catalog),
            "opponents" => self.change_view(View::Opponents),
            _ => self.view = View::Title,
        }
    }

    fn notify(&mut self, text: impl Into<String>) {
        self.toast = text.into();
        self.toast_until = get_time() + 5.;
    }
    fn result(&mut self, result: Result<(), String>, success: &str) {
        match result {
            Ok(()) => self.notify(success),
            Err(e) => self.notify(e),
        }
    }
    fn change_view(&mut self, view: View) {
        self.view = view;
        self.list_offset = 0;
        self.query.clear();
        self.search_focus = false;
    }
    fn enter_world(&mut self) {
        match World::load(
            &self.db.asset_root,
            self.profile.scene,
            self.profile.variant,
        ) {
            Ok(world) => {
                let variant =
                    world.variant_for_flags(world.scene, world.variant, &self.profile.flags);
                let world = if variant != world.variant {
                    World::load(&self.db.asset_root, world.scene, variant).unwrap_or(world)
                } else {
                    world
                };
                self.profile.variant = world.variant;
                self.dialogue.clear();
                self.choices.clear();
                self.script = Some(world.entry_script());
                self.world = Some(world);
                self.change_view(View::World);
            }
            Err(error) => self.notify(error),
        }
    }
    fn start_duel(&mut self) {
        if let Err(e) = self.profile.validate_deck(&self.db) {
            self.notify(e);
            return;
        }
        let mut duel = Duel::new(
            &self.db,
            &self.profile.deck,
            self.opponent,
            get_time().to_bits(),
        );
        if duel.active == 1 {
            duel.run_ai_turn(&self.db);
        }
        self.card = duel.sides[0].hand.first().copied().unwrap_or(1);
        self.duel = Some(duel);
        self.view = View::Duel;
        self.hand = None;
        self.monster = None;
        self.spell = None;
        self.tributes.clear();
        self.settled = false;
    }

    pub fn frame(&mut self) {
        set_camera(&canvas_camera());
        clear_background(INK);
        if self.modal.is_some() {
            if is_key_pressed(KeyCode::Escape) {
                self.modal = None;
            } else {
                self.modal_screen();
            }
            self.draw_toast();
            set_default_camera();
            return;
        }
        if is_key_pressed(KeyCode::F10) {
            self.muted = !self.muted;
            if self.muted {
                if let Some(sound) = &self.sound {
                    stop_sound(sound);
                }
            }
            self.music_id = u16::MAX;
        }
        if is_key_pressed(KeyCode::Escape) {
            if self.modal.is_some() {
                self.modal = None;
            } else if !self.dialogue.is_empty() && self.script.is_none() {
                self.dialogue.clear();
            } else if self.search_focus {
                self.search_focus = false;
            } else if self.view == View::Duel {
                self.notify("Finish the duel or use Surrender to return.");
            } else if self.view == View::Title {
                self.quit = true;
            } else {
                self.change_view(View::Hub);
            }
        }
        if self.view == View::World
            && self.dialogue.is_empty()
            && self.choices.is_empty()
            && self.modal.is_none()
        {
            self.advance_script();
        }
        match self.view {
            View::Title => self.title(),
            View::Hub => self.hub(),
            View::World => self.overworld(),
            View::Opponents => self.opponents(),
            View::Duel => self.duel_screen(),
            View::Deck | View::Shop | View::Catalog => self.collection(),
            View::Atlas => self.atlas(),
            View::City => self.city(),
        }
        self.modal_screen();
        self.draw_toast();
        label(
            if self.muted {
                "F10  SOUND OFF"
            } else {
                "F10  SOUND ON"
            },
            1125.,
            790.,
            13.,
            MUTED,
        );
        set_default_camera();
    }

    fn draw_toast(&self) {
        if !self.toast.is_empty() && get_time() < self.toast_until {
            let rect = if self.view == View::Duel {
                Rect::new(28., 42., 820., 29.)
            } else {
                Rect::new(24., 714., 1232., 57.)
            };
            panel(rect);
            text_fit(
                &self.toast,
                rect.x + 12.,
                rect.y + rect.h * 0.68,
                rect.w - 24.,
                if self.view == View::Duel { 14. } else { 19. },
                GOLD,
            );
        }
    }

    pub async fn sync_music(&mut self) {
        let desired = match self.view {
            View::Title => 1,
            View::Duel => self.db.opponent(self.opponent).music,
            View::World => self.world.as_ref().map(|w| w.music).unwrap_or(4),
            _ => 4,
        };
        if self.muted || desired == self.music_id {
            return;
        }
        self.music_id = desired;
        if let Some(sound) = self.sound.take() {
            stop_sound(&sound);
        }
        let path = self
            .db
            .asset_root
            .join(format!("audio/music/{desired:03}.wav"));
        if path.exists() {
            match load_sound(&path.to_string_lossy()).await {
                Ok(sound) => {
                    play_sound(
                        &sound,
                        PlaySoundParams {
                            looped: true,
                            volume: 0.18,
                        },
                    );
                    self.sound = Some(sound);
                }
                Err(e) => self.notify(format!("Audio could not load: {e}")),
            }
        }
    }

    fn title(&mut self) {
        for i in 0..12 {
            draw_line(
                i as f32 * 128. - 160.,
                0.,
                i as f32 * 128. + 640.,
                H,
                1.,
                Color::new(0.16, 0.13, 0.08, 0.3),
            );
        }
        self.art.draw(
            "player-menus/title-background.png",
            Rect::new(65., 120., 720., 480.),
            WHITE,
        );
        draw_rectangle_lines(65., 120., 720., 480., 2., GOLD);
        label("NATIVE RUST EDITION", 65., 84., 16., GOLD);
        label("A city. A tournament. Your deck.", 67., 650., 28., TEXT);
        label(
            "Original recovered art, music, and card data",
            67.,
            680.,
            17.,
            MUTED,
        );
        panel(Rect::new(845., 120., 370., 480.));
        label("THE SACRED CARDS", 875., 174., 22., GOLD);
        label("Choose your next move", 875., 208., 18., MUTED);
        let has_save = self.save_path.exists();
        if button(Rect::new(875., 249., 310., 52.), "Continue", has_save)
            || (has_save && is_key_pressed(KeyCode::Enter))
        {
            match Profile::load(&self.save_path, &self.db) {
                Ok(p) => {
                    self.profile = p;
                    self.world = None;
                    self.script = None;
                    self.dialogue.clear();
                    self.choices.clear();
                    self.change_view(View::Hub);
                    self.notify("Save loaded.");
                }
                Err(e) => self.notify(e),
            }
        }
        if button(Rect::new(875., 315., 310., 52.), "New game", true)
            || (!has_save && is_key_pressed(KeyCode::Enter))
        {
            self.profile = Profile::new(&self.db);
            self.enter_world();
            self.input.clear();
            self.modal = Some(Modal::Name);
        }
        if button(Rect::new(875., 381., 310., 52.), "Card archive", true) {
            self.change_view(View::Catalog);
        }
        if button(Rect::new(875., 447., 310., 52.), "Quit", true) {
            self.quit = true;
        }
        label("ENTER  PLAY     /     ESC  QUIT", 875., 560., 14., MUTED);
        label(
            "Local reconstruction · work in progress",
            65.,
            760.,
            15.,
            MUTED,
        );
    }

    fn header(&mut self, title: &str, subtitle: &str) {
        label("YU-GI-OH!", 30., 34., 14., GOLD);
        label(title, 30., 76., 32., TEXT);
        label(subtitle, 31., 104., 16., MUTED);
        if self.view != View::Hub && button(Rect::new(1130., 38., 120., 42.), "Back", true) {
            if self.script.is_some() && self.view != View::World {
                self.change_view(View::World);
            } else {
                self.change_view(View::Hub);
            }
        }
        draw_line(30., 122., 1250., 122., 1., Color::new(0.25, 0.28, 0.30, 1.));
    }
    fn hub(&mut self) {
        self.header(
            "Battle City",
            "Build your deck, explore the city, and challenge a duelist.",
        );
        panel(Rect::new(30., 146., 780., 540.));
        self.art.draw(
            "remaining-screens/city-map-background.png",
            Rect::new(50., 166., 740., 493.),
            WHITE,
        );
        panel(Rect::new(840., 146., 410., 540.));
        label(&self.profile.name, 865., 187., 26., GOLD);
        label(
            &format!("DUELIST LEVEL  {}", self.profile.level),
            865.,
            222.,
            15.,
            TEAL,
        );
        label(
            &format!("{} Domino", self.profile.money),
            865.,
            251.,
            22.,
            TEXT,
        );
        label(
            &format!(
                "DECK  {}/40    COST  {}/{}",
                self.profile.deck.len(),
                self.profile.deck_cost(&self.db),
                self.profile.capacity
            ),
            865.,
            280.,
            15.,
            MUTED,
        );
        let options = [
            ("Explore", View::World),
            ("Duel", View::Opponents),
            ("Deck & collection", View::Deck),
            ("Card shop", View::Shop),
            ("Card archive", View::Catalog),
        ];
        for (i, (name, view)) in options.iter().enumerate() {
            if button(
                Rect::new(865., 302. + i as f32 * 53., 360., 43.),
                name,
                true,
            ) || is_key_pressed(
                [
                    KeyCode::Key1,
                    KeyCode::Key2,
                    KeyCode::Key3,
                    KeyCode::Key4,
                    KeyCode::Key5,
                ][i],
            ) {
                if *view == View::World {
                    if self.world.is_some() {
                        self.view = View::World;
                    } else {
                        self.enter_world();
                    }
                } else {
                    self.change_view(*view);
                }
            }
        }
        if button(Rect::new(865., 581., 174., 43.), "Save game", true) {
            let result = self.profile.save(&self.save_path);
            self.result(result, "Game saved.");
        }
        if button(Rect::new(1051., 581., 174., 43.), "Title", true) {
            self.view = View::Title;
        }
        label(
            &format!(
                "RECORD   {} WINS / {} LOSSES",
                self.profile.wins, self.profile.losses
            ),
            865.,
            658.,
            14.,
            MUTED,
        );
        label(
            "1-5  OPEN A SCREEN     /     ESC  RETURN     /     F10  MUSIC",
            32.,
            750.,
            14.,
            MUTED,
        );
    }

    fn opponents(&mut self) {
        self.header(
            "Duelists",
            "Choose an opponent. Win duels to increase your capacity.",
        );
        self.scroll_list(self.db.opponents.len().saturating_sub(1), 9);
        panel(Rect::new(30., 146., 770., 540.));
        for row in 0..9 {
            let index = self.list_offset + row + 1;
            if index >= self.db.opponents.len() {
                break;
            }
            let opponent = &self.db.opponents[index];
            let rect = Rect::new(44., 160. + row as f32 * 56., 742., 49.);
            if row_button(rect, &opponent.name, self.opponent == index) {
                self.opponent = index;
            }
            label(
                &format!("+{} CAPACITY", opponent.capacity_reward),
                605.,
                rect.y + 31.,
                14.,
                TEAL,
            );
        }
        panel(Rect::new(830., 146., 420., 540.));
        let opponent = self.db.opponent(self.opponent);
        label(&opponent.name, 857., 190., 24., GOLD);
        label("SIGNATURE CARDS", 857., 228., 14., MUTED);
        let mut ids = opponent.deck.clone();
        ids.sort_by_key(|id| std::cmp::Reverse(self.db.card(*id).attack.min(9999)));
        ids.dedup();
        for (i, id) in ids.iter().take(3).enumerate() {
            self.art.draw(
                &format!("full-cards/{id:04}.png"),
                Rect::new(854. + i as f32 * 123., 250., 112., 152.),
                WHITE,
            );
        }
        label(
            &format!(
                "Life points   {} / {}",
                opponent.starting_lp[0], opponent.starting_lp[1]
            ),
            857.,
            448.,
            20.,
            TEXT,
        );
        label(
            &format!("Capacity reward   +{}", opponent.capacity_reward),
            857.,
            484.,
            20.,
            TEAL,
        );
        label(
            &format!("Money reward   {}", opponent.money_reward),
            857.,
            520.,
            20.,
            TEXT,
        );
        let populated = opponent.deck.first().copied().unwrap_or(0) != 0;
        if button(Rect::new(857., 574., 366., 64.), "Begin duel", populated)
            || (populated && is_key_pressed(KeyCode::Enter))
        {
            self.start_duel();
        }
        label(
            "SCROLL  BROWSE     /     ENTER  CHALLENGE",
            32.,
            750.,
            14.,
            MUTED,
        );
    }

    fn collection(&mut self) {
        let title = match self.view {
            View::Deck => "Deck & collection",
            View::Shop => "Card shop",
            _ => "Card archive",
        };
        self.header(
            title,
            &format!(
                "{} cards in deck  ·  {}/{} capacity  ·  Duelist level {}  ·  {} Domino",
                self.profile.deck.len(),
                self.profile.deck_cost(&self.db),
                self.profile.capacity,
                self.profile.level,
                self.profile.money
            ),
        );
        let search = Rect::new(30., 144., 758., 43.);
        panel(search);
        if clicked(search) {
            self.search_focus = true;
        }
        if self.search_focus {
            while let Some(c) = get_char_pressed() {
                if !c.is_control() && self.query.len() < 60 {
                    self.query.push(c);
                    self.list_offset = 0;
                }
            }
            if is_key_pressed(KeyCode::Backspace) {
                self.query.pop();
                self.list_offset = 0;
            }
        }
        label(
            &if self.query.is_empty() {
                "Search cards by name...".into()
            } else {
                self.query.clone()
            },
            45.,
            172.,
            18.,
            if self.query.is_empty() { MUTED } else { TEXT },
        );
        let ids: Vec<u16> = self
            .db
            .cards
            .iter()
            .filter(|c| c.id != 0)
            .filter(|c| {
                self.view != View::Deck
                    || self
                        .profile
                        .collection
                        .get(c.id as usize)
                        .copied()
                        .unwrap_or(0)
                        > 0
            })
            .filter(|c| {
                self.view != View::Shop
                    || self
                        .profile
                        .shop_stock
                        .get(c.id as usize)
                        .copied()
                        .unwrap_or(0)
                        > 0
                    || self.profile.reserve_count(c.id) > 0
            })
            .filter(|c| c.name.to_lowercase().contains(&self.query.to_lowercase()))
            .map(|c| c.id)
            .collect();
        self.scroll_list(ids.len(), 8);
        label("CARD", 47., 215., 13., MUTED);
        label("ATK / DEF", 480., 215., 13., MUTED);
        label("COST", 625., 215., 13., MUTED);
        label(
            if self.view == View::Shop {
                "STOCK / OWN"
            } else {
                "OWN / DECK"
            },
            684.,
            215.,
            13.,
            MUTED,
        );
        if ids.is_empty() {
            wrapped(
                if self.view == View::Shop {
                    "The shop is empty. Winning duels restocks cards. Enter a card password to unlock a card in the shop."
                } else {
                    "No cards match your search."
                },
                65.,
                285.,
                660.,
                23.,
                MUTED,
                5,
            );
        }
        for row in 0..8 {
            let Some(id) = ids.get(self.list_offset + row).copied() else {
                break;
            };
            let c = self.db.card(id);
            let rect = Rect::new(30., 230. + row as f32 * 54., 758., 49.);
            if row_button(rect, "", self.card == id) {
                self.card = id;
                self.search_focus = false;
            }
            self.art.draw(
                &format!("cards/{id:04}.mini.png"),
                Rect::new(39., rect.y + 5., 40., 38.),
                WHITE,
            );
            text_fit(&c.name, 88., rect.y + 29., 378., 18., TEXT);
            let stats = if c.is_monster() {
                format!("{} / {}", c.attack, c.defense)
            } else {
                c.type_name.clone()
            };
            label(&stats, 481., rect.y + 29., 15., MUTED);
            label(
                &c.cost.to_string(),
                626.,
                rect.y + 29.,
                16.,
                if c.cost > self.profile.level {
                    RED
                } else {
                    TEAL
                },
            );
            label(
                &if self.view == View::Shop {
                    format!(
                        "{} / {}",
                        self.profile.shop_stock[id as usize],
                        self.profile.reserve_count(id)
                    )
                } else {
                    format!(
                        "{} / {}",
                        self.profile
                            .collection
                            .get(id as usize)
                            .copied()
                            .unwrap_or(0),
                        self.profile.deck_count(id)
                    )
                },
                697.,
                rect.y + 29.,
                16.,
                TEXT,
            );
        }
        self.card_details(Rect::new(814., 144., 436., 506.));
        if self.view == View::Deck {
            if button(
                Rect::new(30., 666., 758., 42.),
                &if self.profile.wagered_card == self.card {
                    "Clear ante".into()
                } else {
                    format!("Ante {} for your next duel", self.db.card(self.card).name)
                },
                true,
            ) {
                let id = if self.profile.wagered_card == self.card {
                    0
                } else {
                    self.card
                };
                let r = self.profile.set_wager(id);
                self.result(r, "Duel ante updated.");
            }
            if button(Rect::new(814., 666., 213., 42.), "+ Add to deck", true) {
                let r = self.profile.add_to_deck(&self.db, self.card);
                self.result(r, "Card added to deck.");
            }
            if button(Rect::new(1038., 666., 212., 42.), "- Remove", true) {
                if let Some(i) = self.profile.deck.iter().position(|id| *id == self.card) {
                    let r = self.profile.remove_from_deck(i);
                    self.result(r, "Card returned to collection.");
                } else {
                    self.notify("This card is not in your deck.");
                }
            }
        } else if self.view == View::Shop {
            if button(Rect::new(30., 666., 758., 42.), "Enter card password", true) {
                self.modal = Some(Modal::Password);
                self.input.clear();
            }
            let price = self.profile.buy_price(&self.db, self.card);
            if button(
                Rect::new(814., 666., 213., 42.),
                &format!("Buy · {price}"),
                self.profile.shop_stock[self.card as usize] > 0,
            ) {
                let r = self.profile.buy(&self.db, self.card);
                self.result(r, "Card purchased.");
            }
            if button(
                Rect::new(1038., 666., 212., 42.),
                &format!("Sell · {}", self.profile.sell_price(&self.db, self.card)),
                self.profile.reserve_count(self.card) > 0,
            ) {
                let r = self.profile.sell(&self.db, self.card);
                self.result(r, "Card sold.");
            }
        }
        label(
            &format!(
                "{} CARDS     /     SCROLL OR PAGE UP / DOWN TO BROWSE",
                ids.len()
            ),
            32.,
            750.,
            14.,
            MUTED,
        );
    }

    fn card_details(&mut self, rect: Rect) {
        panel(rect);
        let card = self.db.card(self.card);
        let card_name = card.name.clone();
        label(
            &format!("CARD  {:03}", self.card),
            rect.x + 22.,
            rect.y + 30.,
            13.,
            GOLD,
        );
        text_fit(
            &card_name,
            rect.x + 22.,
            rect.y + 64.,
            rect.w - 44.,
            25.,
            TEXT,
        );
        let compact = rect.w < 400.;
        let image_w = if compact { 134. } else { 168. };
        let stats_x = rect.x + image_w + 42.;
        self.art.draw(
            &format!("full-cards/{:04}.png", self.card),
            Rect::new(rect.x + 22., rect.y + 86., image_w, image_w * 152. / 112.),
            WHITE,
        );
        text_fit(
            &card.type_name,
            stats_x,
            rect.y + 112.,
            rect.w - image_w - 64.,
            18.,
            TEAL,
        );
        label(&card.summon_name, stats_x, rect.y + 141., 17., MUTED);
        if card.is_monster() {
            label(
                &format!("ATK  {}", card.attack),
                stats_x,
                rect.y + 186.,
                if compact { 19. } else { 23. },
                TEXT,
            );
            label(
                &format!("DEF  {}", card.defense),
                stats_x,
                rect.y + 221.,
                if compact { 19. } else { 23. },
                TEXT,
            );
            label(
                &format!("LEVEL  {}", card.level),
                stats_x,
                rect.y + 264.,
                15.,
                GOLD,
            );
        }
        label(
            &format!("COST  {}", card.cost),
            stats_x,
            rect.y + 296.,
            15.,
            MUTED,
        );
        wrapped(
            &card.description,
            rect.x + 22.,
            rect.y + 345.,
            rect.w - 44.,
            17.,
            TEXT,
            if compact { 4 } else { 7 },
        );
    }

    fn scroll_list(&mut self, len: usize, visible: usize) {
        let (_, wheel) = mouse_wheel();
        let amount = if wheel > 0. {
            -3
        } else if wheel < 0. {
            3
        } else if is_key_pressed(KeyCode::PageDown) {
            visible as i32
        } else if is_key_pressed(KeyCode::PageUp) {
            -(visible as i32)
        } else {
            0
        };
        self.list_offset = (self.list_offset as i32 + amount).max(0) as usize;
        self.list_offset = self.list_offset.min(len.saturating_sub(visible));
    }

    fn overworld(&mut self) {
        self.header(
            "Explore",
            "Arrow keys or WASD to walk. Enter or Space to speak. Tab opens the atlas.",
        );
        if is_key_pressed(KeyCode::Tab) {
            self.change_view(View::Atlas);
            return;
        }
        if self.world.is_none() {
            self.enter_world();
            return;
        }
        let world = self.world.as_ref().unwrap();
        let scene = world.scene;
        let native_w = (world.width * 2).max(240) as f32;
        let native_h = (world.height * 2).max(160) as f32;
        let cam_x = (self.profile.x as f32 * 2. - 120.).clamp(0., (native_w - 240.).max(0.));
        let cam_y = (self.profile.y as f32 * 2. - 80.).clamp(0., (native_h - 160.).max(0.));
        let viewport = Rect::new(30., 146., 864., 576.);
        panel(viewport);
        self.art.draw_source(
            &format!("scenes/{scene:02}.normal.png"),
            viewport,
            Some(Rect::new(cam_x, cam_y, 240., 160.)),
            WHITE,
        );
        let scale = 3.6;
        let mut actors: Vec<(i32, i32, i32, usize, bool)> = world
            .actors
            .iter()
            .filter(|a| a.id >= 0)
            .map(|a| (a.id, a.x, a.y, a.orientation as usize, false))
            .collect();
        actors.push((
            world.player_id,
            self.profile.x,
            self.profile.y,
            self.facing,
            true,
        ));
        actors.sort_by_key(|a| a.2);
        for (id, x, y, orientation, is_player) in actors {
            let frame = orientation.min(3) * 3
                + if is_player && self.move_timer > 0. {
                    ((get_time() * 8.) as usize % 3).min(2)
                } else {
                    0
                };
            let px = viewport.x + (x as f32 * 2. - cam_x - 16.) * scale;
            let py = viewport.y + (y as f32 * 2. - cam_y - 24.) * scale;
            if px > viewport.x - 32.
                && px < viewport.x + viewport.w
                && py > viewport.y - 80.
                && py < viewport.y + viewport.h
            {
                self.art.draw(
                    &format!("actors/{id:03}/frame-{frame:02}-p0.png"),
                    Rect::new(px, py, 32. * scale, 32. * scale),
                    WHITE,
                );
            }
        }
        panel(Rect::new(924., 146., 326., 540.));
        label("YOUR JOURNEY", 947., 190., 24., GOLD);
        label(&self.profile.name, 947., 225., 16., MUTED);
        if self.portrait != 0 && (!self.dialogue.is_empty() || !self.choices.is_empty()) {
            self.art.draw(
                &format!("portraits/portrait-{:02}.png", self.portrait),
                Rect::new(947., 250., 278., 185.),
                WHITE,
            );
        } else {
            wrapped("Speak to the people around you. Follow paths and doorways to travel between locations.", 947., 267., 278., 19., TEXT, 6);
        }
        if button(Rect::new(946., 445., 282., 46.), "Atlas", true) {
            self.change_view(View::Atlas);
        }
        if button(Rect::new(946., 505., 282., 46.), "Save game", true) {
            let r = self.profile.save(&self.save_path);
            self.result(r, "Game saved.");
        }
        if !self.choices.is_empty() {
            panel(Rect::new(50., 475., 824., 225.));
            for (i, option) in self.choices.clone().iter().enumerate().take(4) {
                if button(
                    Rect::new(75., 495. + i as f32 * 47., 774., 40.),
                    option,
                    true,
                ) {
                    if let Some(script) = self.script.as_mut() {
                        script.choose(i != 0);
                    }
                    self.choices.clear();
                }
            }
            return;
        }
        if !self.dialogue.is_empty() {
            panel(Rect::new(50., 535., 824., 165.));
            wrapped(
                self.dialogue
                    .get(self.dialogue_line)
                    .map(String::as_str)
                    .unwrap_or(""),
                75.,
                570.,
                775.,
                22.,
                TEXT,
                4,
            );
            label("ENTER  NEXT", 718., 681., 13., GOLD);
            if is_key_pressed(KeyCode::Enter)
                || is_key_pressed(KeyCode::Space)
                || clicked(Rect::new(50., 535., 824., 165.))
            {
                self.dialogue_line += 1;
                if self.dialogue_line >= self.dialogue.len() {
                    self.dialogue.clear();
                }
            }
            return;
        }
        if self.modal.is_some() || self.script.is_some() {
            return;
        }
        self.move_timer = (self.move_timer - get_frame_time()).max(0.);
        if self.move_timer <= 0. {
            let movement = if is_key_down(KeyCode::Down) || is_key_down(KeyCode::S) {
                Some((0, 1, 0))
            } else if is_key_down(KeyCode::Up) || is_key_down(KeyCode::W) {
                Some((0, -1, 2))
            } else if is_key_down(KeyCode::Left) || is_key_down(KeyCode::A) {
                Some((-1, 0, 1))
            } else if is_key_down(KeyCode::Right) || is_key_down(KeyCode::D) {
                Some((1, 0, 3))
            } else {
                None
            };
            if let Some((dx, dy, face)) = movement {
                self.facing = face;
                self.move_timer = 0.07;
                let world = self.world.as_ref().unwrap();
                let step = world.step(self.profile.x, self.profile.y, dx, dy);
                self.profile.x = step.x;
                self.profile.y = step.y;
                if let Some(transition) = step.transition {
                    self.transition(transition);
                }
            }
        }
        if is_key_pressed(KeyCode::Enter)
            || is_key_pressed(KeyCode::Space)
            || is_key_pressed(KeyCode::R)
        {
            let world = self.world.as_ref().unwrap();
            if let Some(i) =
                world.interaction_actor(self.profile.x, self.profile.y, self.facing as u8)
            {
                self.script = world.actor_script(i, is_key_pressed(KeyCode::R));
            } else {
                self.notify("Move closer to someone to speak.");
            }
        }
    }

    fn atlas(&mut self) {
        self.header("Scene atlas", "Visit the recovered locations. Story locks are not yet applied to this exploration atlas.");
        self.scroll_list(58, 10);
        for row in 0..10 {
            let index = self.list_offset + row;
            if index >= 58 {
                break;
            }
            let rect = Rect::new(30., 145. + row as f32 * 51., 350., 44.);
            if row_button(
                rect,
                &format!("Scene {index:02}"),
                self.profile.scene == index,
            ) {
                match World::load(&self.db.asset_root, index, 0) {
                    Ok(world) => {
                        let (x, y) = world.spawn(0);
                        self.profile.scene = index;
                        self.profile.variant = 0;
                        self.profile.x = x;
                        self.profile.y = y;
                        self.world = Some(world);
                        self.view = View::World;
                    }
                    Err(e) => self.notify(e),
                }
            }
            self.art.draw_source(
                &format!("scenes/{index:02}.normal.png"),
                Rect::new(
                    400. + (row % 5) as f32 * 170.,
                    145. + (row / 5) as f32 * 260.,
                    160.,
                    240.,
                ),
                Some(Rect::new(0., 0., 160., 240.)),
                WHITE,
            );
        }
    }

    fn transition(&mut self, transition: Transition) {
        match transition {
            Transition::Scene {
                scene,
                variant,
                spawn,
            } => {
                let variant = self
                    .world
                    .as_ref()
                    .map(|w| w.variant_for_flags(scene, variant, &self.profile.flags))
                    .unwrap_or(variant);
                match World::load(&self.db.asset_root, scene, variant) {
                    Ok(next) => {
                        let (x, y) = next.spawn(spawn);
                        self.profile.scene = scene;
                        self.profile.variant = variant;
                        self.profile.x = x;
                        self.profile.y = y;
                        self.script = Some(next.entry_script());
                        self.world = Some(next);
                        self.view = View::World;
                        self.dialogue.clear();
                        self.choices.clear();
                    }
                    Err(e) => {
                        self.script = None;
                        self.notify(e);
                    }
                }
            }
            Transition::CityMap { origin } => {
                self.script = None;
                self.city_origin = origin;
                self.change_view(View::City);
            }
        }
    }

    fn advance_script(&mut self) {
        let Some(mut script) = self.script.take() else {
            return;
        };
        let Some(world) = self.world.as_mut() else {
            return;
        };
        let event = script.next(world, &mut self.profile);
        self.script = Some(script);
        match event {
            ScriptEvent::Text { text, portrait } => {
                self.dialogue = vec![text];
                self.dialogue_line = 0;
                self.portrait = portrait;
            }
            ScriptEvent::Choice { options } => {
                self.choices = if options.is_empty() {
                    vec!["Yes".into(), "No".into()]
                } else {
                    options
                };
            }
            ScriptEvent::Duel { opponent_id } => {
                self.opponent = opponent_id;
                self.start_duel();
                self.story_duel = self.view == View::Duel;
                if !self.story_duel {
                    self.script = None;
                }
            }
            ScriptEvent::Save => {
                let r = self.profile.save(&self.save_path);
                self.result(r, "Game saved.");
            }
            ScriptEvent::Shop { .. } => self.change_view(View::Shop),
            ScriptEvent::Name => {
                self.input = self.profile.name.clone();
                self.modal = Some(Modal::Name);
            }
            ScriptEvent::Password => {
                self.input.clear();
                self.modal = Some(Modal::Password);
            }
            ScriptEvent::Credits => self.modal = Some(Modal::Credits),
            ScriptEvent::Transition(transition) => self.transition(transition),
            ScriptEvent::End => {
                self.script = None;
                if let Some(world) = self.world.as_ref() {
                    let variant =
                        world.variant_for_flags(world.scene, world.variant, &self.profile.flags);
                    if variant != world.variant {
                        self.profile.variant = variant;
                        self.enter_world();
                    }
                }
            }
            ScriptEvent::Unsupported(error) => {
                self.script = None;
                self.notify(error);
            }
        }
    }

    fn modal_screen(&mut self) {
        let Some(modal) = self.modal.as_ref() else {
            return;
        };
        draw_rectangle(0., 0., W, H, Color::new(0., 0., 0., 0.83));
        panel(Rect::new(350., 220., 580., 360.));
        if *modal == Modal::Hand {
            label("Revealed opponent cards", 390., 285., 27., GOLD);
            let hand = self
                .duel
                .as_ref()
                .map(|d| d.known_opponent_hand(0).to_vec())
                .unwrap_or_default();
            for (i, id) in hand.iter().enumerate().take(5) {
                self.art.draw(
                    &format!("full-cards/{id:04}.png"),
                    Rect::new(390. + i as f32 * 100., 335., 90., 122.),
                    WHITE,
                );
            }
            if button(Rect::new(390., 503., 500., 46.), "Return to duel", true)
                || is_key_pressed(KeyCode::Escape)
            {
                self.modal = None;
            }
            return;
        }
        if *modal == Modal::Credits {
            label("THE SACRED CARDS", 390., 285., 31., GOLD);
            wrapped("Original game © Kazuki Takahashi / Konami. This local Rust reconstruction uses the supplied recovered source and original assets. See the project README and port status for implementation and fidelity details.",390.,335.,500.,20.,TEXT,7);
            if button(Rect::new(390., 503., 500., 46.), "Continue", true)
                || is_key_pressed(KeyCode::Enter)
            {
                self.modal = None;
            }
            return;
        }
        let is_name = *modal == Modal::Name;
        label(
            if is_name {
                "Your name"
            } else {
                "Card password"
            },
            390.,
            285.,
            31.,
            GOLD,
        );
        label(
            if is_name {
                "Enter up to 18 characters."
            } else {
                "Enter the eight digits printed on your card."
            },
            390.,
            325.,
            18.,
            MUTED,
        );
        while let Some(c) = get_char_pressed() {
            if (is_name && c.is_ascii_graphic() && self.input.len() < 18)
                || (is_name && c == ' ' && self.input.len() < 18)
                || (!is_name && c.is_ascii_digit() && self.input.len() < 8)
            {
                self.input.push(c);
            }
        }
        if is_key_pressed(KeyCode::Backspace) {
            self.input.pop();
        }
        panel(Rect::new(390., 355., 500., 65.));
        label(&format!("{}|", self.input), 410., 398., 30., TEXT);
        if button(
            Rect::new(390., 458., 500., 52.),
            "Confirm",
            !self.input.trim().is_empty(),
        ) || is_key_pressed(KeyCode::Enter)
        {
            if is_name {
                if !self.input.trim().is_empty() {
                    self.profile.name = self.input.trim().to_owned();
                    self.modal = None;
                }
            } else {
                match self.profile.redeem_password(&self.db, &self.input) {
                    Ok(message) => {
                        self.notify(message);
                        self.modal = None;
                    }
                    Err(error) => self.notify(error),
                }
            }
        }
    }

    fn city(&mut self) {
        self.header(
            "City map",
            "Choose an unlocked destination to continue your journey.",
        );
        panel(Rect::new(30., 146., 780., 540.));
        self.art.draw(
            "remaining-screens/city-map-background.png",
            Rect::new(50., 166., 740., 493.),
            WHITE,
        );
        let locations = if let Some(world) = self.world.as_ref() {
            world.city_locations(&self.profile.flags, self.city_origin)
        } else {
            return;
        };
        for (row, location) in locations.iter().enumerate() {
            if button(
                Rect::new(840., 146. + row as f32 * 51., 410., 44.),
                &location.name,
                location.unlocked,
            ) {
                self.transition(Transition::Scene {
                    scene: location.scene,
                    variant: location.variant,
                    spawn: location.spawn,
                });
            }
        }
    }

    fn duel_screen(&mut self) {
        let Some(mut duel) = self.duel.take() else {
            self.view = View::Hub;
            return;
        };
        let opponent_name = self.db.opponent(self.opponent).name.clone();
        label("DUEL", 28., 35., 14., GOLD);
        label(&opponent_name, 28., 75., 29., TEXT);
        label(
            &format!(
                "TURN {}   ·   {}",
                duel.turn,
                if duel.active == 0 {
                    "YOUR TURN"
                } else {
                    "OPPONENT TURN"
                }
            ),
            350.,
            44.,
            17.,
            TEAL,
        );
        label(
            &format!("YOU   {} LP", duel.sides[0].lp),
            350.,
            81.,
            26.,
            TEXT,
        );
        label(
            &format!("RIVAL   {} LP", duel.sides[1].lp),
            622.,
            81.,
            26.,
            RED,
        );
        if duel.opponent_hand_revealed[0]
            && button(
                Rect::new(895., 50., 357., 39.),
                "Inspect revealed cards",
                true,
            )
        {
            self.modal = Some(Modal::Hand);
        }
        let board = Rect::new(24., 105., 846., 463.);
        self.art.draw(
            &format!("duel/terrain-{}-view-0.png", duel.terrain.min(6)),
            board,
            Color::new(0.25, 0.30, 0.35, 1.),
        );
        draw_rectangle_lines(board.x, board.y, board.w, board.h, 1., GOLD);
        label(
            &format!(
                "RIVAL   DECK {}   /   HAND {}",
                duel.sides[1].deck.len(),
                duel.sides[1].hand.len()
            ),
            42.,
            132.,
            14.,
            TEXT,
        );
        label(
            &format!(
                "YOU   DECK {}   /   GRAVE {}",
                duel.sides[0].deck.len(),
                duel.sides[0].graveyard.len()
            ),
            42.,
            550.,
            14.,
            TEXT,
        );
        for side in [1, 0] {
            for slot in 0..5 {
                let x = 99. + slot as f32 * 143.;
                let y = if side == 1 { 154. } else { 347. };
                let rect = Rect::new(x, y, 112., 147.);
                let selected = side == 0 && self.monster == Some(slot);
                draw_rectangle(
                    rect.x,
                    rect.y,
                    rect.w,
                    rect.h,
                    Color::new(0.035, 0.045, 0.06, 0.70),
                );
                draw_rectangle_lines(
                    rect.x,
                    rect.y,
                    rect.w,
                    rect.h,
                    if selected { 3. } else { 1. },
                    if selected {
                        TEAL
                    } else {
                        Color::new(0.45, 0.47, 0.44, 0.6)
                    },
                );
                if let Some(monster) = &duel.sides[side].monsters[slot] {
                    let id = monster.card_id;
                    if monster.face_down && side == 1 {
                        card_back(rect);
                    } else {
                        self.art.draw(
                            &format!("full-cards/{id:04}.png"),
                            rect,
                            if monster.attacked {
                                Color::new(0.55, 0.55, 0.55, 1.)
                            } else {
                                WHITE
                            },
                        );
                    }
                    let (atk, def) = self.db.stats(id, duel.terrain, monster.stage);
                    label(
                        &if monster.face_down && side == 1 {
                            "FACE DOWN".into()
                        } else {
                            format!(
                                "{}  {}",
                                if monster.defense { "DEF" } else { "ATK" },
                                if monster.defense { def } else { atk }
                            )
                        },
                        x + 4.,
                        y + 164.,
                        15.,
                        if monster.defense { GOLD } else { TEXT },
                    );
                    if self.tributes.contains(&slot) && side == 0 {
                        label("TRIBUTE", x + 12., y + 75., 18., RED);
                    }
                    if hovered(rect) && !(side == 1 && monster.face_down) {
                        self.card = id;
                    }
                    if side == 0 && hovered(rect) && is_mouse_button_pressed(MouseButton::Right) {
                        if self.tributes.contains(&slot) {
                            self.tributes.retain(|s| *s != slot);
                        } else {
                            self.tributes.push(slot);
                        }
                    }
                } else {
                    label(&format!("{:02}", slot + 1), x + 45., y + 78., 22., MUTED);
                }
                if clicked(rect) && duel.winner.is_none() && duel.active == 0 {
                    if side == 0 {
                        if let Some(hand) = self.hand {
                            let card = duel.sides[0].hand.get(hand).copied().unwrap_or(0);
                            if card != 0 && self.db.card(card).is_monster() {
                                let result =
                                    duel.summon(&self.db, hand, slot, self.defense, &self.tributes);
                                if result.is_ok() {
                                    self.hand = None;
                                    self.tributes.clear();
                                }
                                self.result(result, "Monster summoned.");
                            } else {
                                self.monster = Some(slot);
                            }
                        } else {
                            self.monster = Some(slot);
                            self.spell = None;
                        }
                    } else if let Some(from) = self.monster {
                        let result = duel.attack(&self.db, from, Some(slot));
                        self.result(result, "Battle resolved.");
                    }
                }
            }
        }
        for side in [1, 0] {
            for slot in 0..5 {
                if let Some(id) = duel.sides[side].spells[slot] {
                    let x = 99. + slot as f32 * 143.;
                    let y = if side == 1 { 315. } else { 514. };
                    draw_rectangle(x, y, 112., 21., PANEL2);
                    if side == 0 && self.spell == Some(slot) {
                        draw_rectangle_lines(x, y, 112., 21., 2., TEAL);
                    }
                    text_fit(
                        &if side == 1 {
                            "SET CARD".into()
                        } else {
                            self.db.card(id).name.clone()
                        },
                        x + 3.,
                        y + 15.,
                        106.,
                        12.,
                        GOLD,
                    );
                    if side == 0 && clicked(Rect::new(x, y, 112., 21.)) {
                        self.spell = Some(slot);
                        self.monster = None;
                        self.hand = None;
                        self.card = id;
                    }
                }
            }
        }
        self.card_details(Rect::new(895., 105., 357., 467.));
        label("YOUR HAND", 28., 598., 13., GOLD);
        for (i, id) in duel.sides[0].hand.clone().into_iter().enumerate() {
            let rect = Rect::new(28. + i as f32 * 130., 610., 112., 152.);
            self.art
                .draw(&format!("full-cards/{id:04}.png"), rect, WHITE);
            if self.hand == Some(i) {
                draw_rectangle_lines(rect.x - 3., rect.y - 3., rect.w + 6., rect.h + 6., 3., TEAL);
            }
            if hovered(rect) {
                self.card = id;
            }
            if clicked(rect) {
                self.hand = if self.hand == Some(i) { None } else { Some(i) };
                self.card = id;
                self.monster = None;
                self.spell = None;
            }
        }
        if button(
            Rect::new(692., 610., 178., 42.),
            if self.defense {
                "Set in defense"
            } else {
                "Summon in attack"
            },
            true,
        ) {
            self.defense = !self.defense;
        }
        if button(
            Rect::new(692., 662., 178., 42.),
            "Play / set card",
            self.hand.is_some(),
        ) {
            if let Some(hand) = self.hand {
                let r = duel.play_spell_with_tributes(&self.db, hand, self.monster, &self.tributes);
                if r.is_ok() {
                    self.hand = None;
                    self.tributes.clear();
                }
                self.result(r, "Card played.");
            }
        }
        if button(
            Rect::new(692., 714., 178., 42.),
            "End turn",
            duel.winner.is_none(),
        ) || is_key_pressed(KeyCode::E)
        {
            let result = duel.end_turn(&self.db);
            if result.is_ok() && duel.winner.is_none() {
                duel.run_ai_turn(&self.db);
            }
            self.result(result, "Your turn.");
            self.hand = None;
            self.monster = None;
            self.spell = None;
            self.tributes.clear();
        }
        if button(
            Rect::new(895., 585., 170., 39.),
            "Direct attack",
            self.monster.is_some(),
        ) {
            if let Some(slot) = self.monster {
                let r = duel.attack(&self.db, slot, None);
                self.result(r, "Direct attack resolved.");
            }
        }
        if button(
            Rect::new(1080., 585., 172., 39.),
            "Change stance",
            self.monster.is_some(),
        ) {
            if let Some(slot) = self.monster {
                let r = duel.set_position(slot);
                self.result(r, "Stance changed.");
            }
        }
        if button(
            Rect::new(895., 632., 170., 39.),
            "Monster effect",
            self.monster.is_some(),
        ) {
            if let Some(slot) = self.monster {
                let r = duel.activate_monster(&self.db, slot);
                self.result(r, "Effect activated.");
            }
        }
        if button(
            Rect::new(1080., 632., 172., 39.),
            "Surrender",
            duel.winner.is_none(),
        ) {
            duel.surrender();
        }
        if button(
            Rect::new(895., 678., 170., 32.),
            "Discard selected",
            self.hand.is_some() || self.monster.is_some() || self.spell.is_some(),
        ) {
            let result = if let Some(hand) = self.hand {
                duel.discard_hand(&self.db, hand)
            } else if let Some(monster) = self.monster {
                duel.discard_monster(&self.db, monster)
            } else if let Some(spell) = self.spell {
                duel.discard_spell(&self.db, spell)
            } else {
                Err("Select a card first".into())
            };
            if result.is_ok() {
                self.hand = None;
                self.monster = None;
                self.spell = None;
            }
            self.result(result, "Card discarded.");
        }
        if button(Rect::new(1080., 678., 172., 32.), "Clear selection", true) {
            self.hand = None;
            self.monster = None;
            self.spell = None;
            self.tributes.clear();
        }
        for (i, line) in duel.log.iter().rev().take(2).rev().enumerate() {
            text_fit(line, 895., 735. + i as f32 * 23., 357., 14., MUTED);
        }
        label(
            "CLICK HAND > ZONE   /   CLICK ATTACKER > TARGET   /   RIGHT CLICK TO TRIBUTE",
            28.,
            788.,
            12.,
            MUTED,
        );
        if let Some(winner) = duel.winner {
            if !self.settled {
                self.outcome = self
                    .profile
                    .award_duel(&self.db, self.opponent, winner == 0);
                self.settled = true;
            }
            draw_rectangle(0., 0., W, H, Color::new(0., 0., 0., 0.72));
            panel(Rect::new(360., 245., 560., 300.));
            label(
                if winner == 0 { "VICTORY" } else { "DEFEAT" },
                410.,
                315.,
                48.,
                if winner == 0 { GOLD } else { RED },
            );
            label(
                &format!(
                    "{} wins · {} losses",
                    self.profile.wins, self.profile.losses
                ),
                410.,
                365.,
                22.,
                TEXT,
            );
            wrapped(&self.outcome, 410., 402., 460., 18., TEAL, 2);
            if button(
                Rect::new(410., 469., 460., 52.),
                if self.story_duel {
                    "Continue story"
                } else {
                    "Return to Battle City"
                },
                true,
            ) || is_key_pressed(KeyCode::Enter)
            {
                if self.story_duel {
                    if let Some(script) = self.script.as_mut() {
                        script.duel_result(winner == 0);
                    }
                    self.view = View::World;
                    self.story_duel = false;
                } else {
                    self.change_view(View::Hub);
                }
            }
        }
        self.duel = Some(duel);
    }
}

fn mouse() -> Vec2 {
    let (x, y) = mouse_position();
    vec2(x / screen_width() * W, y / screen_height() * H)
}
fn canvas_camera() -> Camera2D {
    // Screen cameras invert Y in Camera2D::matrix; positive zoom gives the
    // same top-left origin used by the mouse and all desktop layout coordinates.
    Camera2D {
        target: vec2(W / 2., H / 2.),
        zoom: vec2(2. / W, 2. / H),
        ..Default::default()
    }
}
fn hovered(r: Rect) -> bool {
    r.contains(mouse())
}
fn clicked(r: Rect) -> bool {
    hovered(r) && is_mouse_button_pressed(MouseButton::Left)
}
fn panel(r: Rect) {
    draw_rectangle(r.x, r.y, r.w, r.h, PANEL);
    draw_rectangle_lines(r.x, r.y, r.w, r.h, 1., Color::new(0.22, 0.27, 0.32, 1.));
}
fn label(s: &str, x: f32, y: f32, size: f32, color: Color) {
    draw_text(s, x, y, size, color);
}
fn text_fit(s: &str, x: f32, y: f32, width: f32, size: f32, color: Color) {
    let mut t = s.to_string();
    while measure_text(&t, None, size as u16, 1.).width > width && t.chars().count() > 3 {
        t.pop();
    }
    if t != s {
        t.pop();
        t.push_str("...");
    }
    label(&t, x, y, size, color);
}
fn button(r: Rect, s: &str, enabled: bool) -> bool {
    draw_rectangle(
        r.x,
        r.y,
        r.w,
        r.h,
        if hovered(r) && enabled {
            Color::new(0.18, 0.22, 0.26, 1.)
        } else {
            PANEL2
        },
    );
    draw_rectangle_lines(r.x, r.y, r.w, r.h, 1., if enabled { GOLD } else { MUTED });
    let size = if s.len() > 20 { 16. } else { 19. };
    let width = measure_text(s, None, size as u16, 1.).width;
    label(
        s,
        r.x + (r.w - width) / 2.,
        r.y + r.h / 2. + size / 3.,
        size,
        if enabled { TEXT } else { MUTED },
    );
    enabled && clicked(r)
}
fn row_button(r: Rect, s: &str, selected: bool) -> bool {
    draw_rectangle(
        r.x,
        r.y,
        r.w,
        r.h,
        if selected {
            Color::new(0.15, 0.20, 0.23, 1.)
        } else if hovered(r) {
            PANEL2
        } else {
            PANEL
        },
    );
    if selected {
        draw_rectangle(r.x, r.y, 3., r.h, GOLD);
    }
    text_fit(
        s,
        r.x + 16.,
        r.y + 31.,
        r.w - 32.,
        20.,
        if selected { GOLD } else { TEXT },
    );
    clicked(r)
}
fn wrapped(s: &str, x: f32, y: f32, width: f32, size: f32, color: Color, max: usize) {
    let mut line = String::new();
    let mut row = 0;
    for word in s.split_whitespace() {
        let candidate = if line.is_empty() {
            word.into()
        } else {
            format!("{line} {word}")
        };
        if measure_text(&candidate, None, size as u16, 1.).width > width && !line.is_empty() {
            label(&line, x, y + row as f32 * (size + 6.), size, color);
            row += 1;
            line = word.into();
            if row >= max {
                return;
            }
        } else {
            line = candidate;
        }
    }
    if row < max {
        label(&line, x, y + row as f32 * (size + 6.), size, color);
    }
}
fn card_back(r: Rect) {
    draw_rectangle(r.x, r.y, r.w, r.h, Color::from_hex(0x583b2a));
    for i in 0..8 {
        let p = i as f32 * 5.;
        draw_rectangle_lines(
            r.x + p,
            r.y + p,
            r.w - p * 2.,
            r.h - p * 2.,
            2.,
            if i % 2 == 0 { GOLD } else { INK },
        );
    }
    label("?", r.x + 41., r.y + 89., 42., GOLD);
}

#[cfg(test)]
mod tests {
    use super::*;
    use macroquad::camera::Camera;
    #[test]
    fn canvas_and_pointer_share_a_top_left_origin() {
        let matrix = canvas_camera().matrix();
        assert_eq!(matrix.transform_point3(vec3(0., 0., 0.)), vec3(-1., 1., 0.));
        assert_eq!(matrix.transform_point3(vec3(W, H, 0.)), vec3(1., -1., 0.));
    }
}
