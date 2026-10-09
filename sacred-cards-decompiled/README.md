# Yu-Gi-Oh! The Sacred Cards (USA): source and assets

Faithful, readable C recovery and original asset extraction from USA Rev. 00
(AY7E). The supplied 16 MiB ROM remains unchanged. SHA-256:
`093f986a92d73c48e11de0a83c6678c3620f8def6173f5e69133815301b40d8f`.

## Current result

The remaining identified code has been recovered into **89 maintained C modules**,
**two assembly modules** for processor-specific entry/veneer behavior, and generated
ROM tables. These compile into ARM7TDMI objects. This is faithful source recovery;
it is not an engine-specific port or a standalone application.

The current inventory has **2,806 native function roots**. Every root has a source
locator or reviewed mapping to a shared implementation. All bytes in the reviewed
executable interval `08000000..0803B61C` have a static classification. There are no
unresolved address-named or named game-function symbols in the object inventory.
**These facts do not prove execution equivalence or exhaustive code discovery.**
Some mappings use factored implementations; automatic Ghidra output remains
separate from maintained source.

The latest recovery includes credits, overworld movement/collision and scene
transitions, the city map, startup/IRQ handling, intro logos, duel records,
link transport/protocol/menus, dormant helpers, additional audio controls and
software arithmetic/string routines. See [source recovery and contracts](docs/source_recovery.md)
and [the current checkpoint](docs/PROGRESS.md).

The latest contract audit adds [native state, resource translation and animation
playback catalogs](docs/rebuild_contracts.md): all 190 unbound data views,
31 ARM record layouts, 96 binary table exports and 68 animation source files.

Original compiler matching, byte-identical C output and native RAM/linker
placement are outside the requested target. Runtime behavior and hardware timing
have not been validated for the new source. Named global state, GBA BIOS calls,
registers and original pointer fields remain integration contracts.

## Start here

- [Duel, shop and deck-builder reuse guide](docs/screen_reuse.md).
- [Source map, recovered systems and explicit contracts](docs/source_recovery.md).
- [State, resource and animation handoff](docs/rebuild_contracts.md).
- [Build instructions](docs/build.md) and [automatic draft provenance](docs/decompilation.md).
- [Asset formats and original loader evidence](docs/asset_formats.md).
- `build/assets/index.html`: local card/scene gallery and asset-family links.
- `build/recovery-status.json`: current machine-readable checkpoint.
- `build/research/function-coverage.json`: per-root source locations and mappings.
- `build/research/semantic-linkage.json`: object dependencies and unbound data.

## Assets

Decoded families and their raw source files are under `build/assets/`:

| Folder | Contents |
|---|---|
| `cards/`, `full-cards/` | 901 card-art slots, miniatures and composed card previews |
| `scenes/`, `world/` | 58 scenes, grids and 237 configuration variants |
| `actors/` | 102 actor slots and 1,836 frame selections |
| `portraits/` | 33 slots, 273 part frames and animation/OAM tables |
| `ui/` | Fonts, 1,612 glyph PNGs, card frames, icons and palettes |
| `duel/`, `duel-text/` | Seven terrains, fourteen viewports, HUD/overlays and 1,031 text slots |
| `player-menus/`, `deck-builder/` | Title/shop/wager/battle and collection/deck/hub graphics |
| `remaining-screens/` | Credits, city-map and startup-logo resources: 26 previews, 233 files |
| `animations/` | Native descriptors/OAM/affine data and code-backed playback contracts |
| `audio/` | 134 WAVs (58 music, 76 effects), MIDIs, SoundFont and original driver data |
| `scripts/`, `runtime/` | Dialogue, scene scripts, rules, motion paths and runtime tables |
| `gameplay/`, `opponents/`, `save/`, `passwords/` | Card/rules/AI/opponent/save/password data |
| `rom-data/` | All 16,533,988 original bytes after the reviewed code interval |

The lossless data archive includes unused and uninterpreted data. Its manifest
records the original address base and hashes. Complete retention does not mean
every ROM byte or animation context has a confirmed semantic interpretation.
PNG/WAV previews and original timing/OAM/palette tables serve different purposes;
a preview alone is not an executable animation.

## Regenerate

```sh
make semantic-objects
make recovery-status
make recovery-contracts
make rip-assets
make rip-audio
```

- `semantic-objects`: compile maintained C/assembly and generated effect/scorer/ROM tables.
- `recovery-status`: static coverage, object symbols and three-screen dependency catalog.
- `recovery-contracts`: declaration/layout audit and state, resource, animation and register-context catalogs.
- `rip-assets`: decode confirmed families and preserve the complete original data interval.
- `rip-audio`: build the local conversion tools and produce playable audio, MIDI and SoundFont.
- `decompile`: regenerate Ghidra drafts and their searchable catalog.
- `disasm`: regenerate reviewed reachable ARM/Thumb instructions.
- `reassemble`: historical instruction rebuild approach, retaining original bytes for gaps.
- `all`: exploratory scan/disassembly/previews plus confirmed asset extraction.

Tools use the local supplied ROM; revision-specific extractors reject other
hashes. Generated data, drafts and local toolchains live under `build/`.
The previous byte-identical instruction reassembly does not incorporate the C.

Earlier focused execution comparisons for card art, miniatures and scene/flag
helpers are documented in their reports under `build/validation/`. They do not
validate the rest of the source. No implementation tests were added or run for
this final recovery pass.
