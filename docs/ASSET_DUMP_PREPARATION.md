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
`extracted/card_art/candidates/`, preserving the original market and numeric
asset path. All 13,999 files are present and readable; 13,625 are 512×512 and
374 are 512×1024. The candidate CSV records the original path, bundle, object
ID, dimensions, export path, and status.

To reproduce the extraction:

```sh
PYTHONPATH=/private/tmp/sacred-cards-unitypy python3 tools/assets/extract_card_art_candidates.py "/path/to/dump"
```

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
images are copied to `assets/cards/`; the full candidate export and mapping
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
