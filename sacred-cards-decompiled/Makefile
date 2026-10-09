PYTHON ?= python3
ARM_CC ?= clang --target=arm-none-eabi -mcpu=arm7tdmi -mthumb
ROM ?= Yu-Gi-Oh! - The Sacred Cards (USA).gba
empty :=
space := $(empty) $(empty)
ROM_DEP := $(subst $(space),\$(space),$(ROM))

.PHONY: recovery-contracts recovery-status decompile reassemble semantic-objects map-audio setup scan assets rip-assets verify-card-art verify-miniatures verify-world-data disasm discover expand all clean setup-audio rip-audio

setup:
	@if $(PYTHON) -c "import sys; sys.path.insert(0, 'build/python-deps'); import capstone" >/dev/null 2>&1; then \
		echo "Capstone is available under build/python-deps"; \
	else \
		$(PYTHON) -m pip install --disable-pip-version-check --target build/python-deps -r requirements.txt; \
	fi

scan:
	$(PYTHON) tools/rom_scan.py "$(ROM)"

disasm: scan setup
	$(PYTHON) tools/disassemble.py "$(ROM)"

discover: disasm
	$(PYTHON) tools/discover_functions.py "$(ROM)"

expand: discover
	$(PYTHON) tools/disassemble.py "$(ROM)" --seed-candidates build/disassembly/candidate_functions.csv

assets: scan expand
	$(PYTHON) tools/render_candidates.py

rip-assets:
	$(PYTHON) tools/rip_asset_tables.py "$(ROM)"
	$(PYTHON) tools/rip_world_data.py "$(ROM)"
	$(PYTHON) tools/rip_actor_graphics.py "$(ROM)"
	$(PYTHON) tools/rip_scripts.py "$(ROM)"
	$(PYTHON) tools/decode_scripts.py
	$(PYTHON) tools/rip_ui_graphics.py "$(ROM)"
	$(PYTHON) tools/rip_portraits.py "$(ROM)"
	$(PYTHON) tools/rip_game_data.py "$(ROM)"
	$(PYTHON) tools/rip_effects.py "$(ROM)"
	$(PYTHON) tools/rip_effect_rules.py "$(ROM)"
	$(PYTHON) tools/rip_ai_data.py "$(ROM)"
	$(PYTHON) tools/rip_runtime_data.py "$(ROM)"
	$(PYTHON) tools/rip_duel_graphics.py "$(ROM)"
	$(PYTHON) tools/rip_duel_text.py "$(ROM)"
	$(PYTHON) tools/rip_card_composites.py "$(ROM)"
	$(PYTHON) tools/rip_passwords.py "$(ROM)"
	$(PYTHON) tools/rip_player_menus.py "$(ROM)"
	$(PYTHON) tools/rip_remaining_screens.py "$(ROM)"
	$(PYTHON) tools/export_rom_data.py "$(ROM)"
	$(PYTHON) tools/rip_deck_builder.py "$(ROM)"
	$(PYTHON) tools/rip_opponents.py "$(ROM)"
	$(PYTHON) tools/rip_save_layout.py "$(ROM)"
	$(PYTHON) tools/rip_audio.py "$(ROM)" --raw-only
	$(PYTHON) tools/map_audio_usage.py "$(ROM)"

verify-card-art: rip-assets
	$(PYTHON) tools/verify_card_art.py "$(ROM)"

verify-miniatures: rip-assets
	$(PYTHON) tools/verify_miniatures.py "$(ROM)"

verify-world-data:
	$(PYTHON) tools/verify_world_data.py "$(ROM)"

setup-audio:
	$(PYTHON) tools/audio/build.py

rip-audio: setup-audio
	$(PYTHON) tools/rip_audio.py "$(ROM)"

map-audio: expand
	$(PYTHON) tools/map_audio_usage.py "$(ROM)"

reassemble: disasm
	$(PYTHON) tools/build_reassembly.py "$(ROM)"

decompile:
	$(PYTHON) tools/ghidra/run.py "$(ROM)"

SEMANTIC_SOURCES := $(wildcard src/*.c)
SEMANTIC_OBJECTS := $(patsubst src/%.c,build/semantic/%.o,$(SEMANTIC_SOURCES))
SEMANTIC_OBJECTS += $(patsubst src/%.s,build/semantic/%.o,$(wildcard src/*.s))
SEMANTIC_OBJECTS += build/semantic/effect_tables.o
SEMANTIC_OBJECTS += build/semantic/ai_card_scorers.o
SEMANTIC_OBJECTS += build/semantic/runtime_tables.o
semantic-objects: $(SEMANTIC_OBJECTS)

recovery-status:
	$(PYTHON) tools/function_coverage.py
	$(PYTHON) tools/code_coverage.py
	$(PYTHON) tools/recovery_status.py
	$(PYTHON) tools/screen_catalog.py

# Requires the extracted asset manifests and existing reviewed Ghidra project.
# Keep the object inventory before declaration/state and address catalogs.
recovery-contracts:
	$(MAKE) semantic-objects
	$(MAKE) recovery-status
	$(PYTHON) tools/inspect_source_contracts.py
	$(PYTHON) tools/build_state_contracts.py
	$(PYTHON) tools/build_animation_catalog.py "$(ROM)"
	$(PYTHON) tools/ghidra/export_bodies.py
	$(PYTHON) tools/inspect_register_context.py
	$(PYTHON) tools/build_resource_catalog.py "$(ROM)"
	$(PYTHON) tools/recovery_status.py

build/semantic/effect_tables.c: semantic_handlers.json tools/build_effect_tables.py
	$(PYTHON) tools/build_effect_tables.py

build/semantic/effect_tables.o: build/semantic/effect_tables.c
	$(ARM_CC) -std=c99 -ffreestanding -fno-builtin -Os -c $< -o $@

build/semantic/ai_card_scorers.c: tools/build_ai_scorers.py build/decompiled/functions.csv $(SEMANTIC_SOURCES) $(ROM_DEP)
	$(PYTHON) tools/build_ai_scorers.py "$(ROM)"

build/semantic/ai_card_scorers.o: build/semantic/ai_card_scorers.c
	$(ARM_CC) -std=c99 -ffreestanding -fno-builtin -Os -c $< -o $@

build/semantic/runtime_tables.c: tools/build_runtime_tables.py $(ROM_DEP)
	$(PYTHON) tools/build_runtime_tables.py "$(ROM)"

build/semantic/runtime_tables.o: build/semantic/runtime_tables.c
	$(ARM_CC) -std=c99 -ffreestanding -fno-builtin -Os -c $< -o $@

build/semantic/%.o: src/%.s
	@mkdir -p build/semantic
	$(ARM_CC) -c $< -o $@

build/semantic/%.o: src/%.c $(wildcard src/*.h)
	@mkdir -p build/semantic
	$(ARM_CC) -std=c99 -ffreestanding -fno-builtin -Os -c $< -o $@

all: assets rip-assets

clean:
	rm -rf build
