# Master Duel asset dump preparation

The full Master Duel dump is mounted at
`/Volumes/Lexar/Yu-Gi-Oh!  Master Duel`. Inventory and Unity object manifests
have been generated without modifying the source dump.

## First pass

Run the read-only inventory against the dump's root folder:

```sh
python3 tools/assets/inventory_asset_dump.py "/path/to/dump" --output-dir manifests
```

The script writes `raw_asset_inventory.csv` and `raw_asset_inventory.json` and
prints totals for files, bytes, likely or possible Unity bundles, and duplicate
SHA-256 hashes. Paths in the manifests are relative to the dump root. Format
identification is signature-based where known and deliberately conservative;
it does not prove that a file is a valid Unity bundle. The script never writes
to the source folder.

## After inventory

The initial inventory of the mounted Lexar dump found 40,537 files (about 13.5
GiB), including 40,509 likely or possible UnityFS bundles and 113 duplicate
files by SHA-256. Bundle headers identify Unity `6000.0.39f1` and
`6000.0.61f1` builds. The main executable and DLLs indicate this is a Windows
game installation. UnityPy 1.25.3 enumerated all 40,509 likely or possible
bundles: 876,321 object rows, with no bundle parse errors. The temporary parser
install is under `/private/tmp`, not in the game project.

Object enumeration uses UnityPy 1.25.3 as an isolated temporary tool, not a game
project dependency. To recreate the current temporary setup and run it:

```sh
python3 -m pip install --target /private/tmp/sacred-cards-unitypy "UnityPy==1.25.3"
PYTHONPATH=/private/tmp/sacred-cards-unitypy python3 tools/assets/inventory_unity_objects.py "/path/to/dump"
```

It writes `manifests/unity_objects.csv` and
`manifests/unity_object_errors.csv`. Candidate categories are name/type hints
for later review, not verified mappings. Keep extraction output separate from
the original dump, preserve bundle/object provenance, and use Sacred Cards IDs
as canonical IDs only after card identity has been evidenced. Artwork mappings
should retain confidence and evidence rather than accepting fuzzy name matches
silently.

## Illustration candidates

The object manifest contains 13,999 bundles whose internal AssetBundle paths
are under `card/images/illust/`: 12,972 `common`, 1,014 `tcg`, and 13 `ocg`.
Each candidate bundle had one Texture2D connected through its AssetBundle
container. They are exported as decoded PNGs under
`local_assets/card_art/candidates/`, preserving the original market and numeric
asset path. All 13,999 files are present and readable; 13,625 are 512×512 and
374 are 512×1024. The candidate CSV records the original path, bundle, object
ID, dimensions, export path, and status.

To reproduce the extraction:

```sh
PYTHONPATH=/private/tmp/sacred-cards-unitypy python3 tools/assets/extract_card_art_candidates.py "/path/to/dump"
```

## Sound effects and music

The Unity object inventory found 2,388 named AudioClips: 163 music clips
(`BGM_`), 2,144 sound effects (`SE_`), and 81 voice clips (`V_`). Exported
audio is kept locally under the ignored `local_assets/audio/library/` folder,
split into `music/`, `sfx/`, and `voice/`. The extractor adds a `.gdignore`
marker there so the full offline library is not scanned by Godot. Curated files
for the game go into the sibling `local_assets/audio/music/`, `sfx/`, and
`voice/` folders. The script writes a provenance manifest with
the source bundle, Unity path ID, duration, file hash, and decode method.

```sh
PYTHONPATH=/private/tmp/sacred-cards-unitypy python3 tools/assets/extract_audio_assets.py "/path/to/dump"
```

UnityPy can decode the separate LocalData clips directly. The main
`data.unity3d` bundle references the shared `resources.resource` sidecar; for
those clips the extractor reads the recorded byte range from that sidecar and
decodes the FMOD sample data. All exported files are checked against their
source metadata in `manifests/audio_assets.csv`.

## Animation clips

The inventory contains 9,513 AnimationClips, 929 AnimatorControllers, and 41
Avatars. The catalog script inspects clip duration, sample rate, rig binding
counts, curve counts, and animation events, and writes
`manifests/animation_catalog.csv`:

```sh
PYTHONPATH=/private/tmp/sacred-cards-unitypy python3 tools/assets/catalog_unity_animations.py "/path/to/dump"
```

Most clips use Unity humanoid muscle curves and need their matching character
model, Avatar, and AnimatorController to play correctly. Unity's clip format is
not directly loadable as a Godot animation, so this pass catalogs the source
clips for selection and conversion; it does not pretend the Unity data is a
Godot-ready animation. The source object names and bundle paths are retained
for tracing candidates back to the dump.

To export a small conversion probe with one clip and its `_EFF` companion,
matching controller, Avatar, and skinned meshes:

```sh
PYTHONPATH=/private/tmp/sacred-cards-unitypy python3 tools/assets/export_animation_probe.py \
  "/path/to/dump" --clip M13144_c
```

The current probe maps the `M13144_c` clips to the controller's `Attack` state
and resolves all 90 clip bindings to Avatar bone paths. It writes Unity source
data under the ignored `local_assets/animation_probe/` folder. OBJ files are
for geometry inspection only; companion JSON preserves the mesh skin data,
Avatar, controller, and animation curves for a converter. This probe is not a
Godot-importable animated model yet.

## Forest duel arena model

The playable forest arena is made with Godot meshes and materials in
`scripts/duel/duel_arena_3d.gd`; it is included in Git and has no external arena
asset requirement. The local models below are visual references for building
future low-poly arenas, not game runtime dependencies. Each new arena should
be authored as Godot scene/script resources so a fresh clone only needs the
curated card art, sound effects, and music.

`Mat_029_near` and `Mat_029_far` are the two halves of the first arena selected
for conversion. Their Unity bundles contain the duel field, grass, woods,
leaves, and blossom art. The exporter preserves each static mesh hierarchy,
transforms, and common base-color textures in separate GLBs. It omits alternate
destroyed field pieces, Unity particle effects, and leaf-shadow planes whose
custom shader data texture looks incorrect as a standard color texture. These
GLBs are importable 3D models; they are not Blender `.blend` projects.

```sh
PYTHONPATH=/private/tmp/sacred-cards-unitypy python3 tools/assets/export_unity_arena_glb.py \
  "/path/to/dump" --arena 029 --variant near \
  --include-root duelfield --include-root grass_near --include-root outside \
  --omit-damage-meshes --omit-leaf-shadows
PYTHONPATH=/private/tmp/sacred-cards-unitypy python3 tools/assets/export_unity_arena_glb.py \
  "/path/to/dump" --arena 029 --variant far \
  --include-root duelfield --include-root grass_far --include-root outside \
  --omit-damage-meshes --omit-leaf-shadows
```

This writes `local_assets/arenas/mat_029_near.glb`, `mat_029_far.glb`, and a JSON
provenance file for each.
The `local_assets/` directory is ignored by Git. To inspect the imported model
without changing the live duel scene, open
`scenes/previews/forest_arena_asset_preview.tscn` and run the current scene in
Godot. The preview camera frames both imported halves automatically.

## Sacred Cards mapping

The repo already has the 900 canonical Sacred Cards records in
`data/cards_json/`, with schema findings in `docs/DATA_SCHEMA.md`; no parallel
card database was created. The dump also contains localized `CARD_Name`,
`CARD_Indx`, and `CARD_Prop` tables. A local decoder links numeric card IDs to
English Master Duel names, and the mapping script compares those names to the
existing Sacred Cards names using Unicode normalization, case-folding, and
whitespace normalization only. It does not fuzzy-match.

`CARD_Prop` IDs and `CARD_Name` entries align row-for-row through `CARD_Indx`.
The numeric ID in each `card/images/illust/.../<id>` bundle path joins directly
to that card ID. Visual inspection confirmed one sample: ID 20487 resolves to
Chaos Allure Queen, and its exported illustration shows that card. An earlier
attempt used `CARD_IntID` as if it were a name index; it produced an incorrect
Blue-Eyes Ultimate Dragon association and was removed from the mapping script.

Exact-name and illustration matches are generated into the mapping files below.
The current join covers 840 Sacred Cards with an exported illustration, 10
exact-name cards have no image in the candidate set, and 58 need an alias or
manual cross-reference. The curated manifest classifies 12 records as having
multiple card or artwork candidates; those records are left out of the
default-art tree. Two further single-candidate records are medium confidence
and are also held back. The remaining 826 single-candidate, high-confidence
images are copied to `local_assets/card_art/cards/`; the full candidate export and mapping
keep all alternate art choices. Duplicate names or multiple Master Duel IDs
are marked medium confidence.

Generated files:

- `manifests/card_asset_mapping.csv`
- `manifests/card_asset_mapping.json`
- `manifests/curated_card_art.csv`

The encrypted CARD table decoding approach was cross-checked against the
community's [Master Duel CARD file processing reference](https://github.com/RndUser0/YGOMD_Card_files_processing); the repo script uses only local dump data and writes only manifests.

The existing Sacred Cards card records are in `data/cards_json/`; inspect and
adapt that schema before creating a parallel card database. The handoff's
proposed `data/sacred_cards/cards.json` and `.csv` are candidates, not a reason
to duplicate existing records before reconciliation.

## Current limitations

- The object candidate categories are search hints, not verified mappings.
- The Windows build and Unity 6 headers describe the dump format; they do not
  establish which assets will load directly in Godot.
- Godot is not on the current shell `PATH`; `project.godot` declares Godot 4.7.
