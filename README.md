# The Sacred Cards — Rust reconstruction

A native Rust application built from the fresh AY7E decompilation in
`sacred-cards-decompiled/`. Macroquad handles the window, drawing, input and
audio; ordinary Rust modules implement data, duel rules, world scripts and
player state. The original recovered artwork and music are loaded locally.

This is a playable reconstruction in progress. It is not a completed,
execution-equivalent port of the original cartridge. See
[implementation status](docs/PORT_STATUS.md) for the verified scope and gaps.

## Play

Double-click **run.command** on macOS, or run:

```sh
./run.command
```

With Rust on your PATH, `cargo run --bin sacred-cards` also works. The launcher
finds the project-local toolchain when one is present. Assets default to the
supplied `sacred-cards-decompiled/build/assets` directory. Override this with
`SACRED_ASSETS=/absolute/path/to/assets`. No GBA emulator or Godot installation
is used by the Rust game.

The local macOS app is `dist/Sacred Cards.app`. Rebuild it with
`./scripts/package-macos.sh` (release) or `./scripts/package-macos.sh --debug`.
Its assets are linked to this checkout. Rust 1.88 or newer is required to build.

Saves are local, versioned JSON in `saves/player.json`; `SACRED_SAVE` overrides
the location. Saving is explicit through the menu or a story save event.
New game does not overwrite an existing save until you save.

## Controls

| Screen | Controls |
| --- | --- |
| Menus | Mouse; Enter on title starts/continues; Escape returns |
| City hub | 1–5 open explore, duel, deck, shop and archive |
| Overworld | Arrows/WASD walk; Enter/Space speak; R uses the alternate actor script |
| Overworld atlas | Tab opens the exploration atlas, which bypasses story locks |
| Card lists | Click search to type; wheel or Page Up/Down scroll |
| Duel summon | Click a hand card, choose attack/defense, then click a friendly zone |
| Tribute summon/ritual | Right-click the required friendly monsters before placing/playing |
| Duel attack | Select your monster, then an enemy zone; use Direct attack when clear |
| Spell/equipment/ritual | Select hand card and, if required, friendly monster; Play / set card |
| Monster effect | Select a face-down friendly monster; Monster effect |
| Duel turn | End turn or E; click a selected hand card again to deselect |
| Sound | F10 toggles music |

The starting deck is the native 40-card deck, with capacity 1600, Duelist Level
72 and 500 Domino. The native initial shop inventory is empty. Duel wins and
card passwords restock the shop. Spare collection cards can be selected as an
ante from the deck screen.

## Develop and verify

```sh
./scripts/cargo.sh test --offline
./scripts/cargo.sh run --bin audit --offline
./scripts/cargo.sh run --bin audit --offline -- --simulate 200
./scripts/cargo.sh clippy --all-targets --offline -- -D warnings
./scripts/cargo.sh run --bin sacred-cards --offline -- --smoke duel /tmp/duel.png
```

The first build needs network access for Cargo dependencies; subsequent builds
use `Cargo.lock` and the local cache. Smoke capture opens a native window,
renders twelve frames, saves a PNG and exits. Supported capture screens are
`title`, `hub`, `world`, `duel`, `deck`, `shop`, `cards`, and `opponents`.

| Module | Responsibility |
| --- | --- |
| `src/data.rs` | 901 card records, 200 opponent slots, original tables and descriptions |
| `src/duel.rs` | Numerical battles, turns, effects, AI and special victories |
| `src/world.rs` | Collision, exits, city unlocks and resumable story script execution |
| `src/save.rs` | Collection/deck ownership, stock, progression, passwords and atomic saves |
| `src/ui.rs` | Native desktop screens, artwork, audio and input |
| `src/bin/audit.rs` | Headless asset and integration checks |

The decompilation's local generated files and supplied ROM are ignored by Git.
They are not bundled into a redistributable package. Existing deletions from the
previous Godot project are preserved.
