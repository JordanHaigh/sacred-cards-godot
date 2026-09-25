# Sacred Cards

This repository is the Godot 4.x project for a Sacred Cards recreation.

The duel demo is `scenes/main.tscn`. The imported card records live in
`data/cards_json/`; the story backlog lives in `stories/`. Open the repository
folder in Godot 4.x and run `scenes/main.tscn` to see the playable duel. The
arena scene can also be run on its own while working on its visuals.

The duel UI uses `ui/hand_card.tscn` for one portrait card and
`ui/card_hand.tscn` to fan multiple cards across the bottom of the screen.
Hovering a card raises it; selecting one pins its full details in the
panel at the left of the duel screen. The hand sends selection and hover
signals to `scripts/ui/duel_screen.gd`; the duel state still owns the actual
cards and actions. Open `scenes/main.tscn` and run the current scene to inspect
the full hand and duel interface.

Click a card on the field to inspect its artwork and current stats in that
same panel. Opponent face-down cards keep their identity hidden.

In Godot's embedded Game window, choose **Stretch to Fit** from the Game bar's
top-right menu to fill the available editor space. The editor's default
**Fixed Size** view keeps the game at its configured 1920×1080 size. For a
true fullscreen game window, disable game embedding before running.

## Game art assets

Large extracted game art and audio are kept out of Git. The root
`local_assets/` folder is ignored; each developer supplies the game files and
places generated assets there using the same subfolder layout:

```text
local_assets/
├── card_art/
│   ├── cards/<sacred-card-id>/illustration.png
│   └── candidates/                 # Full offline candidate library; Godot ignores it
├── audio/
    ├── music/                      # Runtime selections
    ├── sfx/                        # Runtime selections
    ├── voice/                      # Runtime selections
    └── library/                    # Full extracted library; Godot ignores it
        ├── music/
        ├── sfx/
        └── voice/
├── animation_probe/               # Unity model and animation conversion inputs
└── arenas/
    ├── mat_029_near.glb           # Optional forest reference, player side
    └── mat_029_far.glb            # Optional forest reference, opponent side
```

The playable duel uses a small Godot-native forest arena made from simple
meshes and colors. The large source GLBs are optional references for designing
new low-poly arenas; the game does not load them. To run the game, a fork needs
only curated files in `local_assets/card_art/cards/`, `local_assets/audio/music/`,
and `local_assets/audio/sfx/`. Extracted candidate art, the full audio archive,
and raw animation probe data are kept out of Godot's asset scan with `.gdignore`
markers created by the extraction tools. The optional forest source preview
uses the ignored `local_assets/arenas/mat_029_*.glb` files; see
`docs/ASSET_DUMP_PREPARATION.md` to recreate them from your own game dump.
The current duel demo uses one music track and four sound cues; these selected
files can be copied from `audio/library/` into the matching runtime folders.
We will curate media as the game develops. The full extraction libraries stay
local; only chosen runtime files are candidates for inclusion in Git. Any
distributed copies of extracted music, effects, or smaller card images need a
separate redistribution decision. The low-poly arena itself is already in the
repository and needs no extracted arena model.
To set up a fork, download the game data and run the documented extraction
steps, then add any selected runtime assets under this one `local_assets/` root.

The source for this project's Master Duel art dump is the Windows installation
of [Yu-Gi-Oh! Master Duel on Steam](https://store.steampowered.com/app/1449850/YuGiOh_Master_Duel/).
Install or update the game through Steam, then copy its installed game data to
an external drive. The prepared dump used for this project was at
`/Volumes/Lexar/Yu-Gi-Oh!  Master Duel` on the original machine. That mounted
path is machine-specific; use the path where your own copy is stored.

To inventory and extract assets, follow
[`docs/ASSET_DUMP_PREPARATION.md`](docs/ASSET_DUMP_PREPARATION.md). The scripts
use the dump as read-only input and write outputs under `local_assets/`. The
game dump and extracted images or audio are not included in this repository.
