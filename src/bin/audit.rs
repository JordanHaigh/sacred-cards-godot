//! Headless integrity and gameplay audit. No window or audio device is opened.

use macroquad::prelude::{Image, ImageFormat};
use sacred_cards::{
    data::{Database, CARD_COUNT, DECK_SIZE, OPPONENT_COUNT},
    duel::{Duel, FIELD_SLOTS, HAND_LIMIT},
    save::{Profile, MONEY_LIMIT},
    world::World,
};
use serde_json::Value;
use std::collections::HashSet;
use std::fs;
use std::path::{Path, PathBuf};
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Default)]
struct Report {
    faults: Vec<String>,
    files: usize,
    json: usize,
    references: usize,
    sizes: usize,
    referenced_files: HashSet<PathBuf>,
    png: usize,
    scenes: usize,
    variants: usize,
}

impl Report {
    fn check(&mut self, okay: bool, message: impl Into<String>) {
        if !okay {
            self.faults.push(message.into());
        }
    }
    fn fault(&mut self, message: impl Into<String>) {
        self.faults.push(message.into());
    }
}

struct Options {
    root: PathBuf,
    simulate: usize,
}

fn options() -> Result<Option<Options>, String> {
    let mut options = Options {
        root: std::env::var_os("SACRED_ASSETS")
            .map(PathBuf::from)
            .unwrap_or_else(|| {
                Path::new(env!("CARGO_MANIFEST_DIR")).join("sacred-cards-decompiled/build/assets")
            }),
        simulate: 0,
    };
    let mut arguments = std::env::args().skip(1);
    while let Some(argument) = arguments.next() {
        match argument.as_str() {
            "--assets" => {
                options.root = arguments.next().ok_or("--assets needs a directory")?.into()
            }
            "--simulate" => {
                options.simulate = arguments
                    .next()
                    .ok_or("--simulate needs a count")?
                    .parse()
                    .map_err(|_| "--simulate count must be a nonnegative integer")?;
                if options.simulate > 100_000 {
                    return Err("--simulate is limited to 100000 duels".into());
                }
            }
            "--help" | "-h" => {
                println!(
                    "Usage: cargo run --bin audit -- [--assets DIRECTORY] [--simulate COUNT]\n\
                    SACRED_ASSETS overrides the default recovered build/assets directory.\n\
                    Checks JSON/file references, declared sizes, PNG decoding, worlds, decks,\n\
                    economy and temporary save roundtrip. Optional duels use fixed seeds.\n\
                    This audit does not recompute asset hashes or establish original-game parity."
                );
                return Ok(None);
            }
            _ => return Err(format!("Unknown argument {argument}; use --help")),
        }
    }
    Ok(Some(options))
}

fn main() {
    match std::panic::catch_unwind(run) {
        Ok(Ok(())) => {}
        Ok(Err(error)) => {
            eprintln!("AUDIT FAILED: {error}");
            std::process::exit(1);
        }
        Err(_) => {
            eprintln!("AUDIT FAILED: unexpected panic; see the diagnostic above");
            std::process::exit(1);
        }
    }
}

fn run() -> Result<(), String> {
    let Some(options) = options()? else {
        return Ok(());
    };
    let root = fs::canonicalize(&options.root)
        .map_err(|e| format!("Cannot open assets {}: {e}", options.root.display()))?;
    println!("Auditing {}", root.display());
    let db = Database::load(&root)?;
    let mut report = Report::default();
    let files = inventory(&root)?;
    report.files = files.len();
    for path in &files {
        match path.extension().and_then(|s| s.to_str()) {
            Some("json") => audit_json(&root, path, &mut report),
            Some("png") => audit_png(path, &mut report),
            _ => {}
        }
    }
    println!("Exports: {} files; {} JSON documents; {} file references ({} unique); {} declared sizes; {} PNGs decoded.",
        report.files, report.json, report.references, report.referenced_files.len(), report.sizes, report.png);
    audit_cards(&db, &mut report);
    audit_opponents(&db, &mut report);
    audit_worlds(&root, &mut report);
    println!("Game data: {} card slots; {} opponent records ({} populated decks); {} scenes; {} variants.",
        db.cards.len(), db.opponents.len(), db.opponents.iter().filter(|o| o.deck.iter().any(|&id| id != 0)).count(),
        report.scenes, report.variants);
    audit_economy_and_save(&db, &mut report);
    if options.simulate > 0 {
        audit_simulations(&db, options.simulate, &mut report);
    }
    let spells = db
        .cards
        .iter()
        .filter(|card| !card.is_monster() && card.id != 0 && Duel::spell_supported(&db, card.id))
        .count();
    let monsters = db
        .cards
        .iter()
        .filter(|card| card.is_monster() && Duel::monster_effect_supported(card.id))
        .count();
    println!("Activation coverage: {spells} spell/trap card IDs; {monsters} monster card IDs. Coverage counts are not parity claims.");
    if !report.faults.is_empty() {
        for fault in &report.faults {
            eprintln!("  FAIL: {fault}");
        }
        return Err(format!("{} fault(s)", report.faults.len()));
    }
    println!("AUDIT PASSED. File/size and decoded-image integrity checked; original runtime equivalence is unverified.");
    Ok(())
}

fn inventory(root: &Path) -> Result<Vec<PathBuf>, String> {
    let mut pending = vec![root.to_path_buf()];
    let mut files = Vec::new();
    while let Some(directory) = pending.pop() {
        for entry in
            fs::read_dir(&directory).map_err(|e| format!("{}: {e}", directory.display()))?
        {
            let entry = entry.map_err(|e| e.to_string())?;
            let kind = entry.file_type().map_err(|e| e.to_string())?;
            if kind.is_dir() {
                pending.push(entry.path());
            } else if kind.is_file() {
                files.push(entry.path());
            } else if kind.is_symlink() {
                return Err(format!(
                    "Unexpected symbolic link in asset tree: {}",
                    entry.path().display()
                ));
            }
        }
    }
    files.sort();
    Ok(files)
}

fn audit_json(root: &Path, path: &Path, report: &mut Report) {
    let result = fs::read(path)
        .map_err(|e| e.to_string())
        .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).map_err(|e| e.to_string()));
    match result {
        Ok(document) => {
            report.json += 1;
            let asset_base = document
                .get("asset_base")
                .and_then(Value::as_str)
                .unwrap_or("");
            inspect_references(root, path, asset_base, &document, report);
        }
        Err(error) => report.fault(format!("Invalid JSON {}: {error}", path.display())),
    }
}

fn inspect_references(
    root: &Path,
    manifest: &Path,
    asset_base: &str,
    value: &Value,
    report: &mut Report,
) {
    match value {
        Value::Object(object) => {
            if let Some(name) = object.get("file").and_then(Value::as_str) {
                report.references += 1;
                if let Some(path) = resolve_reference(root, manifest, asset_base, name) {
                    report.referenced_files.insert(path.clone());
                    if let Some(size) = object.get("size").and_then(Value::as_u64) {
                        report.sizes += 1;
                        match fs::metadata(&path) {
                            Ok(metadata) => report.check(
                                metadata.len() == size,
                                format!(
                                    "{}: expected {size} bytes, found {}",
                                    path.display(),
                                    metadata.len()
                                ),
                            ),
                            Err(error) => report.fault(format!("{}: {error}", path.display())),
                        }
                    }
                } else {
                    report.fault(format!(
                        "{} references missing file {name}",
                        manifest.display()
                    ));
                }
            }
            // Other manifests name raster/audio/payload files directly rather
            // than wrapping them in a {file,size} resource record.
            const PATH_KEYS: [&str; 18] = [
                "image",
                "miniature",
                "framed_miniature",
                "record_file",
                "deck_file",
                "descriptors_file",
                "assets",
                "raw_header",
                "raw_sequence_region",
                "wav",
                "raw",
                "header",
                "raw_file",
                "raw_node",
                "raw_payload_window",
                "tiles",
                "palette",
                "normal_image",
            ];
            for key in PATH_KEYS {
                if let Some(name) = object.get(key).and_then(Value::as_str) {
                    if ![
                        ".png", ".bin", ".u16", ".wav", ".csv", ".json", ".lz", ".pal",
                    ]
                    .iter()
                    .any(|extension| name.ends_with(extension))
                    {
                        continue;
                    }
                    report.references += 1;
                    if let Some(path) = resolve_reference(root, manifest, asset_base, name) {
                        report.referenced_files.insert(path);
                    } else {
                        report.fault(format!(
                            "{} references missing {key}: {name}",
                            manifest.display()
                        ));
                    }
                }
            }
            for child in object.values() {
                inspect_references(root, manifest, asset_base, child, report);
            }
        }
        Value::Array(values) => {
            for child in values {
                inspect_references(root, manifest, asset_base, child, report);
            }
        }
        _ => {}
    }
}

fn resolve_reference(
    root: &Path,
    manifest: &Path,
    asset_base: &str,
    name: &str,
) -> Option<PathBuf> {
    let parent = manifest.parent().unwrap_or(root);
    // runtime/resources.json also references the retained data archive and
    // maintained C source files outside the exported-assets folder.
    let source_root = root.parent().and_then(Path::parent).unwrap_or(root);
    [
        parent.join(name),
        root.join(name),
        root.join(asset_base).join(name),
        root.join("rom-data").join(name),
        source_root.join(name),
    ]
    .into_iter()
    .find(|path| path.is_file())
    .and_then(|path| fs::canonicalize(path).ok())
}

fn audit_png(path: &Path, report: &mut Report) {
    match fs::read(path).map_err(|e| e.to_string()).and_then(|bytes| {
        Image::from_file_with_format(&bytes, Some(ImageFormat::Png)).map_err(|e| e.to_string())
    }) {
        Ok(image) => {
            report.png += 1;
            report.check(
                image.width > 0
                    && image.height > 0
                    && image.bytes.len()
                        == usize::from(image.width) * usize::from(image.height) * 4,
                format!("Invalid decoded PNG dimensions/data: {}", path.display()),
            );
        }
        Err(error) => report.fault(format!("Cannot decode PNG {}: {error}", path.display())),
    }
}

fn audit_cards(db: &Database, report: &mut Report) {
    report.check(db.cards.len() == CARD_COUNT, "Expected 901 card slots");
    let classes = fs::read(db.asset_root.join("gameplay/duel-card-type-classes.bin"));
    match classes {
        Ok(classes) if classes.len() == 24 => {
            for card in &db.cards {
                let class = classes[usize::from(card.type_id)];
                report.check(
                    card.is_monster() == (card.id != 0 && class == 1),
                    format!(
                        "Card {} monster classification disagrees with native type classes",
                        card.id
                    ),
                );
                report.check(
                    card.is_trap() == (card.id != 0 && class == 3),
                    format!(
                        "Card {} trap classification disagrees with native type classes",
                        card.id
                    ),
                );
            }
        }
        _ => report.fault("Invalid native duel-card-type-classes.bin"),
    }
    for card in &db.cards {
        for name in [
            format!("cards/{:04}.png", card.id),
            format!("cards/{:04}.mini.png", card.id),
            format!("cards/{:04}.framed.png", card.id),
            format!("full-cards/{:04}.png", card.id),
        ] {
            report.check(
                db.asset_root.join(&name).is_file(),
                format!("Missing card image {name}"),
            );
        }
    }
    for (name, width, values) in [
        (
            "attack",
            2,
            db.cards
                .iter()
                .map(|c| u64::from(c.attack))
                .collect::<Vec<_>>(),
        ),
        (
            "defense",
            2,
            db.cards.iter().map(|c| u64::from(c.defense)).collect(),
        ),
        (
            "cost",
            4,
            db.cards.iter().map(|c| u64::from(c.cost)).collect(),
        ),
        (
            "type",
            1,
            db.cards.iter().map(|c| u64::from(c.type_id)).collect(),
        ),
        (
            "summon",
            1,
            db.cards.iter().map(|c| u64::from(c.summon)).collect(),
        ),
        (
            "level",
            1,
            db.cards.iter().map(|c| u64::from(c.level)).collect(),
        ),
        (
            "frame",
            1,
            db.cards.iter().map(|c| u64::from(c.frame)).collect(),
        ),
        (
            "metadata_1a",
            1,
            db.cards.iter().map(|c| u64::from(c.metadata_1a)).collect(),
        ),
        (
            "metadata_1b",
            1,
            db.cards.iter().map(|c| u64::from(c.metadata_1b)).collect(),
        ),
        (
            "metadata_1c",
            1,
            db.cards.iter().map(|c| u64::from(c.metadata_1c)).collect(),
        ),
        (
            "base_shop_price",
            8,
            db.cards.iter().map(|c| c.base_shop_price).collect(),
        ),
    ] {
        let path = db.asset_root.join(format!("gameplay/{name}.bin"));
        match fs::read(&path) {
            Ok(bytes) if bytes.len() == CARD_COUNT * width => {
                for (id, (raw, value)) in bytes.chunks_exact(width).zip(values).enumerate() {
                    let native = raw
                        .iter()
                        .enumerate()
                        .fold(0u64, |n, (i, &byte)| n | (u64::from(byte) << (i * 8)));
                    report.check(
                        native == value,
                        format!("Card {id} {name} differs from native binary table"),
                    );
                }
            }
            _ => report.fault(format!("Missing or invalid card table {}", path.display())),
        }
    }
}

fn audit_opponents(db: &Database, report: &mut Report) {
    report.check(
        db.opponents.len() == OPPONENT_COUNT,
        "Expected 200 opponent records",
    );
    for opponent in &db.opponents {
        let record_path = db
            .asset_root
            .join(format!("opponents/{:03}.record.bin", opponent.id));
        match fs::read(&record_path) {
            Ok(raw) if raw.len() == 40 => {
                let word = |offset| u32::from_le_bytes(raw[offset..offset + 4].try_into().unwrap());
                let half = |offset| u16::from_le_bytes(raw[offset..offset + 2].try_into().unwrap());
                report.check(
                    opponent.identifier == word(0)
                        && opponent.terrain == raw[2]
                        && opponent.starting_lp == [u32::from(half(20)), u32::from(half(22))]
                        && opponent.capacity_reward == word(24)
                        && opponent.money_min == half(28)
                        && opponent.money_max == half(30)
                        && opponent.money_scale == raw[32]
                        && u32::from(opponent.music) == word(36),
                    format!(
                        "Opponent {} fields differ from native binary record",
                        opponent.id
                    ),
                );
            }
            _ => report.fault(format!(
                "Missing or invalid native record {}",
                record_path.display()
            )),
        }
        let path = db
            .asset_root
            .join(format!("opponents/{:03}.deck.bin", opponent.id));
        match fs::read(&path) {
            Ok(bytes) if bytes.len() == DECK_SIZE * 2 => {
                let deck: Vec<u16> = bytes
                    .as_chunks::<2>()
                    .0
                    .iter()
                    .map(|b| u16::from_le_bytes([b[0], b[1]]))
                    .collect();
                report.check(
                    deck == opponent.deck,
                    format!(
                        "Opponent {} JSON deck differs from raw native deck",
                        opponent.id
                    ),
                );
            }
            _ => report.fault(format!("Missing or invalid native deck {}", path.display())),
        }
        report.check(
            opponent.money_min <= opponent.money_max,
            format!("Opponent {} money range is reversed", opponent.id),
        );
        for table in [
            &opponent.normal_rewards,
            &opponent.shop_rewards,
            &opponent.special_rewards,
        ] {
            let mut previous = 0;
            for entry in table.iter().take_while(|entry| entry.card_id != 0) {
                report.check(
                    entry.threshold >= previous,
                    format!(
                        "Opponent {} reward thresholds are not monotonic",
                        opponent.id
                    ),
                );
                previous = entry.threshold;
            }
        }
    }
}

fn audit_worlds(root: &Path, report: &mut Report) {
    let path = root.join("world/manifest.json");
    let manifest = fs::read(&path)
        .map_err(|e| e.to_string())
        .and_then(|bytes| serde_json::from_slice::<Value>(&bytes).map_err(|e| e.to_string()));
    let document = match manifest {
        Ok(document) => document,
        Err(error) => {
            report.fault(format!("World manifest: {error}"));
            return;
        }
    };
    let Some(scenes) = document.get("scenes").and_then(Value::as_array) else {
        report.fault("World manifest has no scenes");
        return;
    };
    for (expected_scene, scene) in scenes.iter().enumerate() {
        let Some(id) = scene
            .get("scene")
            .and_then(Value::as_u64)
            .map(|n| n as usize)
        else {
            report.fault("Scene record has no numeric ID");
            continue;
        };
        report.check(
            id == expected_scene,
            "Scene IDs are not consecutive numeric slots",
        );
        report.scenes += 1;
        let Some(variants) = scene.get("variants").and_then(Value::as_array) else {
            report.fault(format!("Scene {id} has no variants"));
            continue;
        };
        for variant in variants {
            let Some(variant_id) = variant
                .get("variant")
                .and_then(Value::as_u64)
                .map(|n| n as usize)
            else {
                report.fault(format!("Scene {id} has an invalid variant"));
                continue;
            };
            match World::load(root, id, variant_id) {
                Ok(world) => {
                    report.variants += 1;
                    report.check(
                        world.width == 120 && world.height == 80 && world.grid.len() == 9600,
                        format!("World {id}/{variant_id} has invalid native grid dimensions"),
                    );
                    report.check(
                        world.variant_count == variants.len(),
                        format!("World {id}/{variant_id} variant count differs from manifest"),
                    );
                    report.check(
                        world.scene_image().is_file(),
                        format!("World {id}/{variant_id} scene image missing"),
                    );
                    for y in 0..world.height {
                        for x in 0..world.width {
                            let _ = world.cell(x, y);
                        }
                    }
                }
                Err(error) => report.fault(format!("Cannot load world {id}/{variant_id}: {error}")),
            }
        }
    }
    report.check(
        report.scenes == 58,
        format!("Expected 58 worlds; loaded {}", report.scenes),
    );
    report.check(
        report.variants == 237,
        format!("Expected 237 variants; loaded {}", report.variants),
    );
}

struct TemporaryDirectory(PathBuf);
impl Drop for TemporaryDirectory {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}
fn temporary_directory() -> Result<TemporaryDirectory, String> {
    let ticks = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|e| e.to_string())?
        .as_nanos();
    for attempt in 0..100 {
        let path = std::env::temp_dir().join(format!(
            "sacred-cards-audit-{}-{ticks}-{attempt}",
            std::process::id()
        ));
        match fs::create_dir(&path) {
            Ok(()) => return Ok(TemporaryDirectory(path)),
            Err(error) if error.kind() == std::io::ErrorKind::AlreadyExists => continue,
            Err(error) => return Err(format!("Cannot create audit save directory: {error}")),
        }
    }
    Err("Could not allocate a unique audit save directory".into())
}

fn audit_economy_and_save(db: &Database, report: &mut Report) {
    let check = || -> Result<(), String> {
        let mut profile = Profile::new(db);
        if (profile.money, profile.capacity, profile.level) != (500, 1600, 72) {
            return Err("Initial money/capacity/level differ from source".into());
        }
        profile.validate_deck(db)?;
        for id in 1..CARD_COUNT {
            if profile.reserve_count(id as u16) != u16::from(db.initial_collection[id]) {
                return Err(format!("Initial reserve differs for card {id}"));
            }
        }
        if profile.shop_stock != db.initial_shop_stock {
            return Err("Initial shop stock differs from native table".into());
        }
        // The native starting shop is empty. Exercise transactions after the
        // actual 50-roll duel reward restock instead of inventing starting stock.
        profile.rng_state = 1;
        profile.award_duel(db, 1, true);
        let id = (1..CARD_COUNT as u16)
            .find(|&id| {
                profile.shop_stock[id as usize] > 0
                    && profile.buy_price(db, id) <= profile.money
                    && profile.reserve_count(id) < 250
            })
            .ok_or("No affordable native shop stock for economy audit")?;
        let index = usize::from(id);
        let before = profile.clone();
        let buy = profile.buy_price(db, id);
        profile.buy(db, id)?;
        if profile.money != before.money - buy
            || profile.collection[index] != before.collection[index] + 1
            || profile.shop_stock[index] != before.shop_stock[index] - 1
        {
            return Err("Buy transaction arithmetic failed".into());
        }
        let sell = profile.sell_price(db, id);
        profile.sell(db, id)?;
        if profile.money != before.money - buy + sell
            || profile.collection != before.collection
            || profile.shop_stock != before.shop_stock
        {
            return Err("Sell transaction arithmetic failed".into());
        }
        let original = profile.clone();
        if profile.buy(db, 0).is_ok() || profile != original {
            return Err("Invalid card purchase mutated state".into());
        }
        for opponent in &db.opponents {
            let mut rewarded = before.clone();
            rewarded.rng_state = 1;
            rewarded.award_duel(db, opponent.id, true);
            let min = before
                .money
                .saturating_add(opponent.money_for_roll(opponent.money_min))
                .min(MONEY_LIMIT);
            let max = before
                .money
                .saturating_add(opponent.money_for_roll(opponent.money_max))
                .min(MONEY_LIMIT);
            if rewarded.money < min || rewarded.money > max {
                return Err(format!(
                    "Opponent {} money award is outside native bounds",
                    opponent.id
                ));
            }
        }
        let temporary = temporary_directory()?;
        let path = temporary.0.join("profile.json");
        profile.save(&path)?;
        if Profile::load(&path, db)? != profile {
            return Err("Save roundtrip changed player state".into());
        }
        fs::write(&path, b"{broken").map_err(|e| e.to_string())?;
        if Profile::load(&path, db).is_ok() {
            return Err("Corrupt save was accepted".into());
        }
        Ok(())
    };
    match check() { Ok(()) => println!("Economy/save: native starting values, duel restock/buy/sell, 200 money reward ranges, roundtrip and corruption rejection passed."), Err(error) => report.fault(format!("Economy/save: {error}")) }
}

#[derive(Default)]
struct Actions {
    summons: usize,
    spells: usize,
    effects: usize,
    attacks: usize,
    ai: usize,
}

fn audit_simulations(db: &Database, count: usize, report: &mut Report) {
    let playable: Vec<usize> = db
        .opponents
        .iter()
        .filter(|o| o.deck.iter().all(|&id| id != 0))
        .map(|o| o.id)
        .collect();
    if playable.is_empty() {
        report.fault("No populated native opponent decks for simulation");
        return;
    }
    let mut completed = 0;
    let mut wins = [0; 2];
    let mut actions = Actions::default();
    for simulation in 0..count {
        let opponent = playable[simulation % playable.len()];
        let deck = if simulation % 2 == 0 {
            &db.initial_deck
        } else {
            &db.opponent(playable[(simulation + 37) % playable.len()])
                .deck
        };
        let seed = 0xA71E_0000_0000_0001u64.wrapping_add(simulation as u64);
        let result = std::panic::catch_unwind(|| simulate(db, deck, opponent, seed));
        match result {
            Ok(Ok((duel, tally))) => {
                completed += 1;
                wins[duel.winner.unwrap()] += 1;
                actions.summons += tally.summons;
                actions.spells += tally.spells;
                actions.effects += tally.effects;
                actions.attacks += tally.attacks;
                actions.ai += tally.ai;
            }
            Ok(Err(error)) => report.fault(format!(
                "Simulation {simulation}, opponent {opponent}, seed {seed:#x}: {error}"
            )),
            Err(_) => report.fault(format!(
                "Simulation {simulation}, opponent {opponent}, seed {seed:#x}: panic"
            )),
        }
    }
    println!("Simulations: {completed}/{count} completed within 240 turns; wins player/opponent {}/{}; player actions: {} summons, {} spells, {} monster effects, {} attacks; {} AI turns.",
        wins[0], wins[1], actions.summons, actions.spells, actions.effects, actions.attacks, actions.ai);
}

fn invariant(db: &Database, duel: &Duel) -> Result<(), String> {
    if duel.active >= 2 || duel.winner.is_some_and(|side| side >= 2) || duel.terrain >= 7 {
        return Err("Invalid active side, winner or terrain".into());
    }
    for (index, side) in duel.sides.iter().enumerate() {
        if side.hand.len() > HAND_LIMIT || side.deck.len() > DECK_SIZE || side.lp > 9999 {
            return Err(format!("Side {index} hand, deck or LP invariant failed"));
        }
        for &id in side
            .deck
            .iter()
            .chain(&side.hand)
            .chain(&side.graveyard)
            .chain(side.spells.iter().flatten())
        {
            if id == 0 || usize::from(id) >= CARD_COUNT {
                return Err(format!("Side {index} contains invalid card ID {id}"));
            }
        }
        for monster in side.monsters.iter().flatten() {
            if usize::from(monster.card_id) >= CARD_COUNT || !db.card(monster.card_id).is_monster()
            {
                return Err(format!(
                    "Side {index} monster row contains invalid card {}",
                    monster.card_id
                ));
            }
        }
    }
    Ok(())
}

fn simulate(
    db: &Database,
    deck: &[u16],
    opponent: usize,
    seed: u64,
) -> Result<(Duel, Actions), String> {
    let mut duel = Duel::new(db, deck, opponent, seed);
    let replay = Duel::new(db, deck, opponent, seed);
    if duel != replay {
        return Err("Seeded initial state is not deterministic".into());
    }
    let mut actions = Actions::default();
    while duel.winner.is_none() && duel.turn <= 240 {
        invariant(db, &duel)?;
        let previous_turn = duel.turn;
        if duel.active == 1 {
            duel.run_ai_turn(db);
            actions.ai += 1;
        } else {
            player_turn(db, &mut duel, &mut actions)?;
        }
        invariant(db, &duel)?;
        if duel.winner.is_none() && duel.turn <= previous_turn {
            return Err("Turn did not advance".into());
        }
    }
    if duel.winner.is_none() {
        return Err("No result within 240-turn cap".into());
    }
    Ok((duel, actions))
}

fn player_turn(db: &Database, duel: &mut Duel, tally: &mut Actions) -> Result<(), String> {
    // Try public legal actions; rejected spell validation must keep state intact.
    for _ in 0..12 {
        if duel.winner.is_some() {
            return Ok(());
        }
        let mut played = false;
        for hand in 0..duel.sides[0].hand.len() {
            let id = duel.sides[0].hand[hand];
            if db.card(id).is_monster() {
                continue;
            }
            let targets: Vec<Option<usize>> = if Duel::spell_needs_target(id) {
                (0..FIELD_SLOTS).map(Some).collect()
            } else {
                vec![None]
            };
            for target in targets {
                let original = duel.clone();
                match duel.play_spell(db, hand, target) {
                    Ok(()) => {
                        played = true;
                        tally.spells += 1;
                        break;
                    }
                    Err(_) if *duel != original => {
                        return Err(format!("Rejected spell {} changed state", id))
                    }
                    Err(_) => {}
                }
            }
            if played {
                break;
            }
        }
        if !played {
            break;
        }
    }
    if duel.winner.is_some() {
        return Ok(());
    }
    if !duel.normal_summoned {
        let mut occupied: Vec<(usize, u16)> = duel.sides[0]
            .monsters
            .iter()
            .enumerate()
            .filter_map(|(slot, m)| {
                m.as_ref()
                    .map(|m| (slot, db.stats(m.card_id, duel.terrain, m.stage).0))
            })
            .collect();
        occupied.sort_by_key(|&(_, attack)| attack);
        let mut choices: Vec<(usize, u16)> = duel.sides[0]
            .hand
            .iter()
            .enumerate()
            .filter(|(_, id)| db.card(**id).is_monster())
            .map(|(i, &id)| (i, id))
            .collect();
        choices.sort_by_key(|&(_, id)| std::cmp::Reverse(db.stats(id, duel.terrain, 0).0));
        for (hand, id) in choices {
            let required = db.tributes(id);
            if required > occupied.len() {
                continue;
            }
            let tributes: Vec<usize> = occupied
                .iter()
                .take(required)
                .map(|&(slot, _)| slot)
                .collect();
            let destination = duel.sides[0]
                .monsters
                .iter()
                .position(Option::is_none)
                .or_else(|| tributes.first().copied());
            let Some(slot) = destination else {
                continue;
            };
            if duel.summon(db, hand, slot, false, &tributes).is_ok() {
                tally.summons += 1;
                break;
            }
        }
    }
    for slot in 0..FIELD_SLOTS {
        if duel.winner.is_some() {
            return Ok(());
        }
        let activate = duel.sides[0].monsters[slot]
            .as_ref()
            .is_some_and(|monster| {
                monster.face_down
                    && !monster.attacked
                    && Duel::monster_effect_supported(monster.card_id)
            });
        if activate && duel.activate_monster(db, slot).is_ok() {
            tally.effects += 1;
        }
    }
    for slot in 0..FIELD_SLOTS {
        if duel.winner.is_some() {
            return Ok(());
        }
        if !duel.can_attack(slot) {
            continue;
        }
        let target = (0..FIELD_SLOTS)
            .filter_map(|target| {
                duel.preview_battle(db, slot, target).map(|result| {
                    (
                        target,
                        i64::from(result.damage_defender) - i64::from(result.damage_attacker)
                            + if result.destroy_defender { 10_000 } else { 0 }
                            - if result.destroy_attacker { 20_000 } else { 0 },
                    )
                })
            })
            .max_by_key(|&(_, score)| score)
            .map(|(target, _)| target);
        if duel.attack(db, slot, target).is_ok() {
            tally.attacks += 1;
        }
    }
    if duel.winner.is_none() {
        if duel.sides[0].hand.len() == HAND_LIMIT {
            duel.discard_hand(db, 0)?;
        }
        duel.end_turn(db)?;
    }
    Ok(())
}
