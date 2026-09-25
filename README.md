# Sacred Cards

This repository is the Godot 4.x project for a Sacred Cards recreation.

The first runnable slice is `scenes/main.tscn`, configured as the project's main scene in `project.godot`. The imported card records live in `data/cards_json/`; the story backlog lives in `stories/`.

Open the repository folder in Godot 4.x and press **Run Project**. The current screen is an intentionally small scaffold while the stories establish the card database and duel systems.

## Game art assets

Large extracted game art is kept out of Git. The local folders `assets/cards/`
and `extracted/` are ignored; each developer must supply the game files and
generate these assets locally.

The source for this project's Master Duel art dump is the Windows installation
of [Yu-Gi-Oh! Master Duel on Steam](https://store.steampowered.com/app/1449850/YuGiOh_Master_Duel/).
Install or update the game through Steam, then copy its installed game data to
an external drive. The prepared dump used for this project was at
`/Volumes/Lexar/Yu-Gi-Oh!  Master Duel` on the original machine. That mounted
path is machine-specific; use the path where your own copy is stored.

To inventory and extract candidate card images, follow
[`docs/ASSET_DUMP_PREPARATION.md`](docs/ASSET_DUMP_PREPARATION.md). That guide
uses the dump as read-only input and writes the full candidate set to
`extracted/card_art/candidates/`. It also explains how to recreate the local
curated card images from the mapping manifests. The game dump and extracted
images are not included in this repository.
