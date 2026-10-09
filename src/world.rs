//! Native scene grids and the recovered scene script graph.
//!
//! Coordinates are the original two-pixel units (120 × 80), not tiles.
//! Collision and exits follow `overworld_movement.c`; command semantics follow
//! `script_commands.c`, `script_events.c`, and `script_actors.c`. Animation,
//! waits, and fades are left to the renderer. Dialogue is exported ROM text.

use crate::save::Profile;
use serde::Deserialize;
use std::collections::{HashMap, HashSet};
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock};

#[derive(Debug, Clone, Deserialize)]
pub struct Actor {
    #[serde(rename = "actor_id")]
    pub id: i32,
    pub x: i32,
    pub y: i32,
    pub script_a: String,
    pub script_b: String,
    #[serde(rename = "orientation_raw", default)]
    pub orientation: u8,
    #[serde(rename = "flags_raw", deserialize_with = "hex_flags")]
    pub flags: u32,
}

fn hex_flags<'de, D: serde::Deserializer<'de>>(d: D) -> Result<u32, D::Error> {
    let text = String::deserialize(d)?;
    u32::from_str_radix(text.trim_start_matches("0x"), 16).map_err(serde::de::Error::custom)
}

#[derive(Deserialize)]
struct SceneFile {
    grid_dimensions: [i32; 2],
    grid_file: GridFile,
    variants: Vec<Variant>,
}
#[derive(Deserialize)]
struct GridFile {
    file: String,
}
#[derive(Deserialize)]
struct Variant {
    variant: usize,
    music_id: u16,
    actors: Vec<Actor>,
    player_spawns: Vec<Actor>,
    scene_script_a: String,
    scene_script_b: String,
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum Transition {
    Scene {
        scene: usize,
        variant: usize,
        spawn: usize,
    },
    CityMap {
        origin: usize,
    },
}
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Step {
    pub x: i32,
    pub y: i32,
    pub transition: Option<Transition>,
}

#[derive(Deserialize)]
struct ScriptFile {
    nodes: Vec<ScriptNode>,
}
#[derive(Debug, Deserialize)]
struct ScriptNode {
    address: String,
    status: String,
    tokens: Vec<Token>,
    next_if_zero: Option<String>,
    next_if_nonzero: Option<String>,
}
#[derive(Debug, Deserialize)]
struct Token {
    kind: String,
    #[serde(default)]
    language: Option<u8>,
    #[serde(default)]
    text: String,
    #[serde(default)]
    command: String,
    #[serde(default)]
    operands: Vec<u8>,
}
type Scripts = HashMap<String, ScriptNode>;
type ScriptCache = Mutex<HashMap<PathBuf, Arc<Scripts>>>;
static SCRIPT_CACHE: OnceLock<ScriptCache> = OnceLock::new();

#[derive(Deserialize, Clone)]
struct VariantRule {
    scene: i32,
    variant: usize,
    flags: Vec<i32>,
    replacement: usize,
}
#[derive(Deserialize)]
struct RuntimeFile {
    scene_rules: Vec<VariantRule>,
}
#[derive(Deserialize)]
struct RemainingScreens {
    strings: Vec<ScreenString>,
}
#[derive(Deserialize)]
struct ScreenString {
    role: String,
    file: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct CityLocation {
    /// Native location ID; returned rows follow the original permutation.
    pub index: usize,
    pub name: String,
    pub scene: usize,
    pub variant: usize,
    pub spawn: usize,
    pub unlocked: bool,
    pub selected: bool,
}

pub struct World {
    pub scene: usize,
    pub variant: usize,
    pub width: i32,
    pub height: i32,
    pub actors: Vec<Actor>,
    pub music: u16,
    pub variant_count: usize,
    pub entry: String,
    pub exit: String,
    pub player_id: i32,
    pub spawns: Vec<Actor>,
    pub grid: Vec<u16>,
    root: PathBuf,
    scripts: Arc<Scripts>,
    rules: Vec<VariantRule>,
    motion_words: Vec<i32>,
    city_order: Vec<u8>,
    city_masks: Vec<u16>,
    city_destinations: Vec<[usize; 3]>,
    city_names: Vec<String>,
}

fn read_json<T: for<'de> Deserialize<'de>>(path: &Path) -> Result<T, String> {
    let bytes = std::fs::read(path).map_err(|e| format!("{}: {e}", path.display()))?;
    serde_json::from_slice(&bytes).map_err(|e| format!("{}: {e}", path.display()))
}

impl World {
    pub fn load(
        asset_root: impl AsRef<Path>,
        scene: usize,
        variant: usize,
    ) -> Result<Self, String> {
        let root = asset_root.as_ref().to_path_buf();
        let file: SceneFile = read_json(&root.join(format!("world/{scene:02}.json")))?;
        let variant_count = file.variants.len();
        let chosen = file
            .variants
            .into_iter()
            .find(|v| v.variant == variant)
            .ok_or_else(|| format!("Scene {scene} has no variant {variant}"))?;
        let grid_bytes = std::fs::read(root.join("world").join(file.grid_file.file))
            .map_err(|e| format!("Cannot load scene {scene} collision grid: {e}"))?;
        let expected = (file.grid_dimensions[0] * file.grid_dimensions[1]) as usize * 2;
        if grid_bytes.len() != expected {
            return Err(format!("Scene {scene}: invalid collision grid size"));
        }
        let grid = grid_bytes
            .as_chunks::<2>()
            .0
            .iter()
            .map(|b| u16::from_le_bytes([b[0], b[1]]))
            .collect();
        let cache = SCRIPT_CACHE.get_or_init(|| Mutex::new(HashMap::new()));
        let mut cache = cache.lock().map_err(|_| "Script cache was poisoned")?;
        let scripts = if let Some(scripts) = cache.get(&root) {
            scripts.clone()
        } else {
            let decoded: ScriptFile = read_json(&root.join("scripts/decoded.json"))?;
            let scripts: Arc<Scripts> = Arc::new(
                decoded
                    .nodes
                    .into_iter()
                    .map(|n| (n.address.clone(), n))
                    .collect(),
            );
            cache.insert(root.clone(), scripts.clone());
            scripts
        };
        let runtime: RuntimeFile = read_json(&root.join("runtime/manifest.json"))?;
        let motion_bytes = std::fs::read(root.join("runtime/script-motion-words.bin"))
            .map_err(|e| format!("Cannot load native actor motion: {e}"))?;
        let motion_words = motion_bytes
            .as_chunks::<4>()
            .0
            .iter()
            .map(|b| i32::from_le_bytes(*b))
            .collect();
        let player_id = chosen.player_spawns.first().map(|a| a.id).unwrap_or(25);
        let remaining = root.join("remaining-screens");
        let read = |name: &str| {
            std::fs::read(remaining.join(name)).map_err(|e| format!("Cannot load {name}: {e}"))
        };
        let city_order = read("city-map.location-order.bin")?;
        let city_masks = read("city-map.unlock-masks.u16")?
            .as_chunks::<2>()
            .0
            .iter()
            .map(|b| u16::from_le_bytes([b[0], b[1]]))
            .collect::<Vec<_>>();
        let city_destinations = read("city-map.scene-destinations.u16")?
            .as_chunks::<6>()
            .0
            .iter()
            .map(|b| {
                [
                    u16::from_le_bytes([b[0], b[1]]) as usize,
                    u16::from_le_bytes([b[2], b[3]]) as usize,
                    u16::from_le_bytes([b[4], b[5]]) as usize,
                ]
            })
            .collect::<Vec<_>>();
        if city_order.len() != 10 || city_masks.len() != 10 || city_destinations.len() != 10 {
            return Err("Invalid native city map tables".into());
        }
        let screen_strings: RemainingScreens = read_json(&remaining.join("manifest.json"))?;
        let mut city_names = vec![String::new(); 10];
        for label in screen_strings.strings {
            let Some(index) = label
                .role
                .strip_prefix("city location label")
                .and_then(|s| s.parse::<usize>().ok())
            else {
                continue;
            };
            if index >= 10 {
                continue;
            }
            let raw = read(&label.file)?;
            // These source labels are ASCII English language-zero strings.
            let start = raw
                .windows(2)
                .position(|b| b == b"$0")
                .map(|n| n + 2)
                .unwrap_or(0);
            let end = raw[start..]
                .iter()
                .position(|&b| b == b'$' || b == 0)
                .map(|n| start + n)
                .unwrap_or(raw.len());
            city_names[index] = String::from_utf8(raw[start..end].to_vec())
                .map_err(|_| "Invalid English city label")?;
        }
        if city_names.iter().any(String::is_empty) {
            return Err("Native city labels are incomplete".into());
        }
        Ok(Self {
            scene,
            variant,
            width: file.grid_dimensions[0],
            height: file.grid_dimensions[1],
            actors: chosen.actors,
            music: chosen.music_id,
            variant_count,
            entry: chosen.scene_script_a,
            exit: chosen.scene_script_b,
            player_id,
            spawns: chosen.player_spawns,
            grid,
            root,
            scripts,
            rules: runtime.scene_rules,
            motion_words,
            city_order,
            city_masks,
            city_destinations,
            city_names,
        })
    }

    /// Composite PNG is 256 × 256; the native viewport crops 240 × 160.
    pub fn scene_image(&self) -> PathBuf {
        self.root
            .join(format!("scenes/{:02}.normal.png", self.scene))
    }
    pub fn image_relative_path(&self) -> String {
        format!("scenes/{:02}.normal.png", self.scene)
    }
    pub fn spawn(&self, index: usize) -> (i32, i32) {
        self.spawns
            .get(index)
            .or_else(|| self.spawns.first())
            .map(|s| (s.x, s.y))
            .unwrap_or((60, 40))
    }
    pub fn cell(&self, x: i32, y: i32) -> u16 {
        if x < 0 || y < 0 || x >= self.width || y >= self.height {
            return 1;
        }
        self.grid[(y * self.width + x) as usize]
    }
    fn terrain_blocks(&self, x: i32, y: i32) -> bool {
        let cell = self.cell(x, y);
        cell & 0xFE00 == 0 && cell & 1 != 0
    }
    fn actor_blocks(&self, x: i32, y: i32) -> bool {
        self.actors
            .iter()
            .any(|a| a.id >= 0 && a.flags & 32 == 0 && (x - a.x).abs() < 7 && (y - a.y).abs() < 5)
    }
    pub fn can_move(&self, x: i32, y: i32) -> bool {
        x > 0
            && x < self.width
            && y > 0
            && y < self.height
            && !self.terrain_blocks(x, y)
            && !self.actor_blocks(x, y)
    }
    /// One native coordinate step. The first free one of three terrain probes
    /// allows gentle sliding around corners, matching 08031238 and 08031354.
    pub fn step(&self, x: i32, y: i32, dx: i32, dy: i32) -> Step {
        let mut result = Step {
            x,
            y,
            transition: None,
        };
        let direction = match (dx.signum(), dy.signum()) {
            (0, 1) => 0,
            (-1, 0) => 1,
            (0, -1) => 2,
            (1, 0) => 3,
            _ => return result,
        };
        let nx = x + dx.signum();
        let ny = y + dy.signum();
        if nx <= 0 || ny <= 0 || nx >= self.width || ny >= self.height || self.actor_blocks(nx, ny)
        {
            return result;
        }
        // ROM 08D4C9B0..08D4C9DF: signed halfwords indexed by probe/direction.
        const PX: [[i32; 4]; 3] = [[0, 0, 0, 0], [1, 0, -1, 0], [-1, 0, 1, 0]];
        const PY: [[i32; 4]; 3] = [[0, 0, 0, 0], [0, 1, 0, -1], [0, -1, 0, 1]];
        for probe in 0..3 {
            let (tx, ty) = (nx + PX[probe][direction], ny + PY[probe][direction]);
            if !self.terrain_blocks(tx, ty) {
                result.x = tx;
                result.y = ty;
                result.transition = self.transition_at(tx, ty);
                break;
            }
        }
        result
    }
    pub fn transition_at(&self, x: i32, y: i32) -> Option<Transition> {
        let cell = self.cell(x, y);
        if cell & 0x0200 != 0 {
            Some(Transition::Scene {
                scene: ((cell as u8) >> 2) as usize,
                variant: 0,
                spawn: (cell & 3) as usize,
            })
        } else if cell & 0x0400 != 0 {
            Some(Transition::CityMap {
                origin: (cell as u8) as usize,
            })
        } else {
            None
        }
    }
    /// Variant rules intentionally cascade in table order, as the C does.
    pub fn variant_for_flags(&self, scene: usize, variant: usize, flags: &[bool]) -> usize {
        let mut variant = variant;
        for rule in &self.rules {
            if rule.scene == scene as i32
                && rule.variant == variant
                && rule
                    .flags
                    .iter()
                    .all(|&f| f == -1 || flags.get(f as usize).copied().unwrap_or(false))
            {
                variant = rule.replacement;
            }
        }
        variant
    }
    /// city_map.c 08000934 and overworld.c 080300F4. Later milestone flags
    /// override earlier ones; the native masks determine the available cities.
    pub fn city_locations(&self, flags: &[bool], origin: usize) -> Vec<CityLocation> {
        const MILESTONES: [usize; 9] = [249, 250, 251, 252, 247, 253, 254, 255, 248];
        let progress = MILESTONES
            .iter()
            .enumerate()
            .filter(|(_, &f)| flags.get(f).copied().unwrap_or(false))
            .map(|(i, _)| i + 1)
            .next_back()
            .unwrap_or(0);
        let mask = self.city_masks[progress];
        self.city_order
            .iter()
            .map(|&id| {
                let index = id as usize;
                let [scene, variant, spawn] = self.city_destinations[index];
                CityLocation {
                    index,
                    name: self.city_names[index].clone(),
                    scene,
                    variant: self.variant_for_flags(scene, variant, flags),
                    spawn,
                    unlocked: mask & (1 << index) != 0,
                    selected: index == origin,
                }
            })
            .collect()
    }
    pub fn interaction_actor(&self, x: i32, y: i32, direction: u8) -> Option<usize> {
        const DX: [i32; 4] = [0, -1, 0, 1];
        const DY: [i32; 4] = [1, 0, -1, 0];
        let d = (direction % 4) as usize;
        let (x, y) = (x + DX[d], y + DY[d]);
        self.actors.iter().position(|a| {
            if a.id < 0 {
                return false;
            }
            let (dx, dy) = (x - a.x, y - a.y);
            match d {
                0 => dy > -9 && dy <= 0 && dx.abs() < 5,
                1 => (0..9).contains(&dx) && dy.abs() < 5,
                2 => (0..9).contains(&dy) && dx.abs() < 5,
                _ => dx > -9 && dx <= 0 && dy.abs() < 5,
            }
        })
    }
    pub fn nearest_actor(&self, x: i32, y: i32, radius: i32) -> Option<usize> {
        self.actors
            .iter()
            .enumerate()
            .filter(|(_, a)| a.id >= 0 && (x - a.x).abs() <= radius && (y - a.y).abs() <= radius)
            .min_by_key(|(_, a)| (x - a.x).pow(2) + (y - a.y).pow(2))
            .map(|(i, _)| i)
    }
    pub fn entry_script(&self) -> ScriptRunner {
        ScriptRunner::new(self.entry.clone())
    }
    pub fn exit_script(&self) -> ScriptRunner {
        ScriptRunner::new(self.exit.clone())
    }
    pub fn actor_script(&self, index: usize, alternate: bool) -> Option<ScriptRunner> {
        self.actors
            .get(index)
            .map(|a| ScriptRunner::new(if alternate { &a.script_b } else { &a.script_a }))
    }
    /// Read-only preview follows zero edges and stops before a duel or choice.
    /// For real story execution use ScriptRunner, which applies event flags.
    pub fn dialogue(&self, actor_index: usize) -> Vec<String> {
        let Some(actor) = self.actors.get(actor_index) else {
            return vec![];
        };
        let mut pages = vec![];
        let mut address = actor.script_a.as_str();
        let mut seen = HashSet::new();
        while seen.insert(address.to_string()) && seen.len() <= 128 {
            let Some(node) = self.scripts.get(address) else {
                break;
            };
            let mut text = String::new();
            for token in &node.tokens {
                if token.language.is_some_and(|l| l != 0) {
                    continue;
                }
                if token.kind == "text" {
                    text.push_str(&token.text.replace('%', ","));
                } else if token.command == "#0" {
                    text.push(' ');
                } else if token.command == "#5" {
                    text.push_str("Player");
                } else if token.command == "#1" && !text.trim().is_empty() {
                    pages.push(text.trim().to_string());
                    text.clear();
                } else if token.command == "#2" {
                    if !text.trim().is_empty() {
                        pages.push(text.trim().to_string());
                    }
                    return pages;
                } else if token.command == "#8" || token.command == "#3" {
                    return pages;
                }
            }
            if !text.trim().is_empty() {
                pages.push(text.trim().to_string());
            }
            let Some(next) = node.next_if_zero.as_deref() else {
                break;
            };
            address = next;
        }
        pages
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum ScriptEvent {
    Text { text: String, portrait: u16 },
    Choice { options: Vec<String> },
    Duel { opponent_id: usize },
    Save,
    Shop { selling: bool },
    Password,
    Name,
    Credits,
    Transition(Transition),
    End,
    Unsupported(String),
}

/// Resumable source-driven script VM. The caller resumes after displaying
/// Text; calls choose(false/true) after Choice; calls duel_result after Duel.
/// Motion is applied immediately; frame timing and sound belong to the host.
pub struct ScriptRunner {
    node: String,
    token: usize,
    branch: bool,
    portrait: u16,
    text: String,
    choice_mode: bool,
    skip_wait: bool,
    done: bool,
}
impl ScriptRunner {
    pub fn new(address: impl Into<String>) -> Self {
        Self {
            node: address.into(),
            token: 0,
            branch: false,
            portrait: 0,
            text: String::new(),
            choice_mode: false,
            skip_wait: false,
            done: false,
        }
    }
    pub fn choose(&mut self, nonzero: bool) {
        self.branch = nonzero;
        self.skip_wait = true;
    }
    pub fn duel_result(&mut self, won: bool) {
        self.branch = !won;
    }
    fn page(&mut self) -> ScriptEvent {
        let text = std::mem::take(&mut self.text).trim().to_owned();
        ScriptEvent::Text {
            text,
            portrait: self.portrait,
        }
    }
    pub fn next(&mut self, world: &mut World, profile: &mut Profile) -> ScriptEvent {
        if self.done {
            return ScriptEvent::End;
        }
        // Native scripts may contain cycles. Bound each uninterrupted execution
        // so malformed data cannot freeze the UI.
        for _ in 0..10000 {
            let scripts = world.scripts.clone();
            let Some(node) = scripts.get(&self.node) else {
                self.done = true;
                return ScriptEvent::Unsupported(format!("Missing script node {}", self.node));
            };
            if node.status == "terminal_Z" {
                self.done = true;
                return if self.text.trim().is_empty() {
                    ScriptEvent::End
                } else {
                    self.page()
                };
            }
            if self.token >= node.tokens.len() || node.tokens[self.token].kind == "end" {
                let edge = if self.branch {
                    &node.next_if_nonzero
                } else {
                    &node.next_if_zero
                };
                if let Some(next) = edge {
                    self.node = next.clone();
                    self.token = 0;
                    self.branch = false;
                    continue;
                }
                self.done = true;
                return if self.text.trim().is_empty() {
                    ScriptEvent::End
                } else {
                    self.page()
                };
            }
            let token = &node.tokens[self.token];
            self.token += 1;
            if token.language.is_some_and(|l| l != 0) {
                continue;
            }
            if token.kind == "text" {
                self.text.push_str(&token.text.replace('%', ","));
                continue;
            }
            if token.kind == "unknown_command" || token.kind == "unknown_language_marker" {
                self.done = true;
                return ScriptEvent::Unsupported(format!("Unknown script token in {}", self.node));
            }
            let args = &token.operands;
            let a = args.first().copied().unwrap_or(0) as usize;
            let b = args.get(1).copied().unwrap_or(0) as usize;
            match token.command.as_str() {
                "#0" => {
                    if !self.text.ends_with('\n') {
                        self.text.push(if self.choice_mode { '\n' } else { ' ' });
                    }
                }
                "#1" => {
                    if self.skip_wait {
                        self.skip_wait = false;
                    } else if !self.text.trim().is_empty() {
                        return self.page();
                    }
                }
                "#2" => {
                    self.choice_mode = true;
                    self.branch = false;
                    if !self.text.trim().is_empty() {
                        return self.page();
                    }
                }
                "#3" => {
                    self.choice_mode = false;
                    let options = std::mem::take(&mut self.text)
                        .lines()
                        .map(str::trim)
                        .filter(|s| !s.is_empty())
                        .map(str::to_owned)
                        .collect();
                    return ScriptEvent::Choice { options };
                }
                "#4" => self.portrait = a as u16,
                "#5" => self.text.push_str(&profile.name),
                "#6" => {
                    if let Some(flag) = profile.flags.get_mut(a) {
                        *flag = true;
                    }
                }
                "#7" => self.branch = profile.flags.get(a).copied().unwrap_or(false),
                "#8" => return ScriptEvent::Duel { opponent_id: a },
                "#9" => {
                    let id = a | (b << 8);
                    let maximum = 250 + profile.deck_count(id as u16);
                    if id > 0 {
                        if let Some(count) = profile.collection.get_mut(id) {
                            *count = count.saturating_add(1).min(maximum);
                        }
                    }
                }
                "@0" => {
                    let count = args.get(2).copied().unwrap_or(0) as i32;
                    const DX: [i32; 4] = [0, -1, 0, 1];
                    const DY: [i32; 4] = [1, 0, -1, 0];
                    if b < 4 {
                        if a == 0 {
                            profile.x += DX[b] * count;
                            profile.y += DY[b] * count;
                        } else if let Some(actor) = world.actors.get_mut(a - 1) {
                            actor.x += DX[b] * count;
                            actor.y += DY[b] * count;
                            actor.orientation = b as u8;
                            actor.flags =
                                (actor.flags & !4) | if args.get(3) == Some(&1) { 4 } else { 0 };
                        }
                    }
                }
                "@1" => {
                    let y = args.get(2).copied().unwrap_or(0) as i32;
                    if a == 0 {
                        profile.x = b as i32;
                        profile.y = y;
                    } else if let Some(actor) = world.actors.get_mut(a - 1) {
                        actor.x = b as i32;
                        actor.y = y;
                        actor.flags &= !4;
                    }
                }
                "@2" => return ScriptEvent::Save,
                "@4" | "@5" => {
                    if a == 0 {
                        if token.command == "@4" {
                            profile.x = b as i32;
                        } else {
                            profile.y = b as i32;
                        }
                    } else if let Some(actor) = world.actors.get_mut(a - 1) {
                        if token.command == "@4" {
                            actor.x = b as i32;
                        } else {
                            actor.y = b as i32;
                        }
                        actor.flags &= !4;
                    }
                }
                "@6" => {
                    if a > 0 {
                        if let Some(actor) = world.actors.get_mut(a - 1) {
                            actor.orientation = 4;
                            actor.flags &= !7;
                        }
                    }
                }
                "@9" => self.branch = world.cell(profile.x, profile.y) as u8 != a as u8,
                "^0" => {
                    self.branch = if a == 0 {
                        profile.level < 80
                    } else if a == 1 {
                        profile.progress_rank.count_ones() == 6
                    } else {
                        self.done = true;
                        return ScriptEvent::Unsupported(format!("Unknown script condition {a}"));
                    }
                }
                "^5" => {
                    if a == 0 {
                        world.player_id = b as i32;
                    } else if let Some(actor) = world.actors.get_mut(a - 1) {
                        actor.id = b as i32;
                    }
                }
                "^2" => {
                    if let Some(event) = script_event(a, world, profile) {
                        return event;
                    }
                }
                "@3" | "@7" | "@8" | "^1" | "^3" | "^4" | "^6" | "" => {} // Presentation and the explicitly operand-only ^6.
                command => {
                    self.done = true;
                    return ScriptEvent::Unsupported(format!(
                        "Unsupported script command {command}"
                    ));
                }
            }
        }
        self.done = true;
        ScriptEvent::Unsupported(format!("Script instruction limit reached at {}", self.node))
    }
}

fn script_event(event: usize, world: &mut World, profile: &mut Profile) -> Option<ScriptEvent> {
    let transition = match event {
        2 => Some((38, 7, 0)),
        13 => Some((1, 3, 0)),
        14 => Some((28, 1, 4)),
        15 => Some((world.scene, 0, 0)),
        19 => Some((19, 0, 3)),
        20 => Some((54, 0, 3)),
        21 => Some((55, 0, 3)),
        22 => Some((30, 1, 4)),
        25 => Some((42, 1, 4)),
        26 => Some((40, 1, 4)),
        28 => Some((42, 2, 4)),
        29 => Some((53, 0, 0)),
        30 => Some((40, 2, 4)),
        31 => Some((42, 3, 4)),
        32 => Some((51, 1, 0)),
        33 => Some((42, 4, 4)),
        34 => Some((51, 2, 4)),
        35 => Some((43, 0, 0)),
        39 => Some((41, 0, 3)),
        40 => Some((49, 0, 3)),
        41 => Some((42, 0, 3)),
        42 => Some((53, 1, 0)),
        43 => Some((45, 1, 0)),
        44 => Some((51, 4, 0)),
        45 => Some((23, 3, 0)),
        46 => Some((5, 5, 0)),
        47 => Some((57, 0, 0)),
        48 => Some((53, 3, 0)),
        49 => Some((53, 4, 0)),
        50 => Some((42, 5, 0)),
        51 => Some((45, 3, 0)),
        54 => Some((40, 0, 4)),
        55 => Some((22, 0, 4)),
        _ => None,
    };
    if let Some((scene, variant, spawn)) = transition {
        let variant = if event == 13 {
            variant
        } else {
            world.variant_for_flags(scene, variant, &profile.flags)
        };
        return Some(ScriptEvent::Transition(Transition::Scene {
            scene,
            variant,
            spawn,
        }));
    }
    match event {
        0 => {
            if let Some(actor) = world.actors.first_mut() {
                actor.x = 448;
                actor.y = 192;
            }
        }
        1 => {
            profile.x = 448;
            profile.y = 192;
        }
        3..=7 => profile.progress_rank |= 1 << (event - 2),
        8 => return Some(ScriptEvent::Shop { selling: false }),
        11 => return Some(ScriptEvent::Shop { selling: true }),
        9 => return Some(ScriptEvent::Credits),
        10 => return Some(ScriptEvent::Name),
        24 => return Some(ScriptEvent::Password),
        12 => {
            // Two source teleports followed by 16/8 rightward steps.
            if let Some(actor) = world.actors.first_mut() {
                actor.x = 90;
                actor.y = 40;
                actor.orientation = 1;
            }
            profile.x = 82;
            profile.y = 40;
        }
        16 => {
            // FollowMotion actor3, ROM 08D4F1DC / 08D4F204. Motion termination
            // checks the next X entry after applying the current delta.
            let x_start = (0x08D4F1DC - 0x08D4F124) / 4;
            let y_start = (0x08D4F204 - 0x08D4F124) / 4;
            let mut delta = (0, 0);
            for i in 0..64 {
                let (Some(&dx), Some(&dy)) = (
                    world.motion_words.get(x_start + i),
                    world.motion_words.get(y_start + i),
                ) else {
                    break;
                };
                delta.0 += dx;
                delta.1 += dy;
                if world.motion_words.get(x_start + i + 1) == Some(&127) {
                    break;
                }
            }
            if let Some(actor) = world.actors.get_mut(2) {
                actor.x += delta.0;
                actor.y += delta.1;
            }
        }
        17 => {
            if let Some(f) = profile.flags.get_mut(114) {
                *f = false;
            }
        }
        23 => {
            for actor in world.actors.iter_mut().skip(1).take(6) {
                actor.x = 0;
                actor.y = 0;
                actor.flags &= !36;
            }
        }
        18 | 27 | 37 | 38 | 52 | 53 => {
            let slot = match event {
                18 | 52 => 4,
                53 => 6,
                _ => 3,
            };
            if let Some(actor) = world.actors.get_mut(slot - 1) {
                actor.x = 192;
                actor.y = 192;
            }
        }
        56 => {
            for slot in [1, 10, 11, 12] {
                if let Some(actor) = world.actors.get_mut(slot - 1) {
                    actor.x = 192;
                    actor.y = 192;
                }
            }
        }
        36 | 57 => {} // Explicit native no-op and display restore.
        event => {
            return Some(ScriptEvent::Unsupported(format!(
                "Unknown script event {event}"
            )))
        }
    }
    None
}

#[cfg(test)]
mod tests {
    use super::*;
    fn assets() -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR")).join("sacred-cards-decompiled/build/assets")
    }
    #[test]
    fn native_world_dimensions_spawn_and_exit() {
        let world = World::load(assets(), 28, 0).unwrap();
        assert_eq!((world.width, world.height), (120, 80));
        assert_eq!(world.spawn(4), (52, 48));
        assert!(world.can_move(52, 48));
        assert!(!world.can_move(0, 0));
        let exit = world.grid.iter().position(|&c| c == 0x039D).unwrap();
        assert_eq!(
            world.transition_at(exit as i32 % 120, exit as i32 / 120),
            Some(Transition::Scene {
                scene: 39,
                variant: 0,
                spawn: 1
            })
        );
    }
    #[test]
    fn source_dialogue_is_clean_and_ordered() {
        let world = World::load(assets(), 28, 0).unwrap();
        assert_eq!(world.dialogue(2)[0], "Would you like to save?");
    }
    #[test]
    fn variant_rules_cascade() {
        let world = World::load(assets(), 28, 0).unwrap();
        let mut flags = vec![false; 400];
        flags[42] = true;
        assert_eq!(world.variant_for_flags(28, 0, &flags), 2);
    }
    #[test]
    fn opening_executes_source_choices_motion_and_flags() {
        let db = crate::data::Database::load(assets()).unwrap();
        let mut profile = Profile::new(&db);
        profile.name = "Tester".into();
        let mut world = World::load(assets(), 28, 0).unwrap();
        let mut runner = world.entry_script();
        let mut text = vec![];
        let mut choices = vec![];
        for _ in 0..40 {
            match runner.next(&mut world, &mut profile) {
                ScriptEvent::Text { text: page, .. } => text.push(page),
                ScriptEvent::Choice { options } => {
                    choices = options;
                    runner.choose(false);
                }
                ScriptEvent::End => break,
                unexpected => panic!("Unexpected opening event {unexpected:?}"),
            }
        }
        assert_eq!(text[0], "The Battle City Tournament is today, Tester.");
        assert_eq!(choices, vec!["Yes", "No"]);
        assert!(profile.flags[42]);
        assert_eq!(world.actors[0].y, 96);
        assert_eq!(world.actors[1].y, 96);
    }
    #[test]
    fn native_save_choice_resumes_after_answer() {
        let db = crate::data::Database::load(assets()).unwrap();
        let mut profile = Profile::new(&db);
        let mut world = World::load(assets(), 28, 0).unwrap();
        let mut runner = world.actor_script(2, false).unwrap();
        assert!(matches!(
            runner.next(&mut world, &mut profile),
            ScriptEvent::Text { .. }
        ));
        assert_eq!(
            runner.next(&mut world, &mut profile),
            ScriptEvent::Choice {
                options: vec!["Yes".into(), "No".into()]
            }
        );
        runner.choose(false);
        assert_eq!(runner.next(&mut world, &mut profile), ScriptEvent::Save);
        let mut runner = world.actor_script(2, false).unwrap();
        let _ = runner.next(&mut world, &mut profile);
        let _ = runner.next(&mut world, &mut profile);
        runner.choose(true);
        assert_eq!(runner.next(&mut world, &mut profile), ScriptEvent::End);
    }
    #[test]
    fn native_duel_result_selects_source_script_edge() {
        let db = crate::data::Database::load(assets()).unwrap();
        let mut profile = Profile::new(&db);
        let mut world = World::load(assets(), 0, 0).unwrap();
        let mut runner = ScriptRunner::new("0x08D5A4A4");
        assert!(matches!(
            runner.next(&mut world, &mut profile),
            ScriptEvent::Text { .. }
        ));
        assert_eq!(
            runner.next(&mut world, &mut profile),
            ScriptEvent::Duel { opponent_id: 30 }
        );
        runner.duel_result(true);
        assert!(
            matches!(runner.next(&mut world, &mut profile), ScriptEvent::Text { text, .. } if text == "I lost...")
        );
        let mut runner = ScriptRunner::new("0x08D5A4A4");
        let _ = runner.next(&mut world, &mut profile);
        let _ = runner.next(&mut world, &mut profile);
        runner.duel_result(false);
        assert_eq!(
            runner.next(&mut world, &mut profile),
            ScriptEvent::Transition(Transition::Scene {
                scene: 28,
                variant: 1,
                spawn: 4
            })
        );
    }
    #[test]
    fn city_map_uses_native_permutation_destinations_and_milestone_masks() {
        let world = World::load(assets(), 28, 0).unwrap();
        let mut flags = vec![false; 400];
        let cities = world.city_locations(&flags, 0);
        assert_eq!(
            cities.iter().map(|c| c.index).collect::<Vec<_>>(),
            vec![0, 1, 6, 2, 3, 4, 8, 5, 7, 9]
        );
        assert_eq!(
            (cities[0].name.as_str(), cities[0].scene, cities[0].spawn),
            ("Clock Tower Square", 5, 4)
        );
        assert_eq!(cities.iter().filter(|c| c.unlocked).count(), 1);
        flags[249] = true;
        let cities = world.city_locations(&flags, 1);
        assert_eq!(
            cities
                .iter()
                .filter(|c| c.unlocked)
                .map(|c| c.index)
                .collect::<Vec<_>>(),
            vec![0, 1, 6]
        );
        assert!(cities[1].selected);
        assert_eq!(cities[1].name, "Card Shop");
        flags[248] = true;
        assert!(world.city_locations(&flags, 0).iter().all(|c| c.unlocked));
    }
}
