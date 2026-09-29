# Sacred Cards Godot port

This project is porting the recovered Sacred Cards source modules into native Godot GDScript. The recovered game tables now provide all 900 card definitions and original card artwork. Core translations cover card data and statistics, battle number resolution, currency, shop prices and transfers, deck rules, progression, deterministic random numbers, event flags, new-game initialization, duel slots/deck setup, reward tables, save data, and the original ASCII pixel font.

The title, duel, shop, deck, and pre-duel flows now run through Godot-owned GDScript state and controls. This is still an incomplete port: many of the 71 recovered C modules lack exact visual composition, timing, data tables, or ROM comparison. Track each module and its open fidelity gaps in [GDScript port status](docs/GDSCRIPT_PORTING.md).

## Run

Open this directory with Godot 4.7 and run `scenes/main.tscn`.

## Prototype navigation

- `F1`–`F4` switch between the current title, duel, shop, and deck screens.
- Arrow keys move the current selection; `Enter` or `Space` confirms.
- `Tab` switches between buy and sell in the shop and switches the title choice when a save exists.
- `Escape` returns to the title screen.

The ignored `decompiled/` directory contains the recovered C reference and source asset exports. Runtime card definitions, game tables, and card art needed by the Godot project are copied into tracked `resources/` and `art/` paths.
