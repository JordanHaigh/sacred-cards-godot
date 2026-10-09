# Duel presentation, password entry and duel flow

The target is faithful, readable C and original assets. These routines compile
to ARM objects; runtime execution has not been compared. Compiler matching and
native linker integration are outside the requested completion criteria.

## Presentation

`src/duel_ui.c` covers the HUD, selected-card details, miniature overlays,
cursor OAM, sprite matrices and display restoration. Source entries include
`08024A14`, `08024B34`, `0802595C..08025BE0`, `08024598..0802460C`,
`0803466C..08034AF8`, and `08035840..08035AA0`.

The visible grid at `020232E0` is distinct from the effect grid at `02023270`.
Row-specific overlay order, hidden-card rules, special combined spell/trap
icons, palette destinations and native source-row overreads are retained.
The negative128 stage case draws a minus without a magnitude digit.

`src/duel_text.c` covers the `08024F2C..080257C4` message state machine:
language selection,28-character lines, confirmation prompts, card/player
names, numeric substitutions and per-frame uploads. Unsupported ordinary
ASCII draws glyph zero without consuming input, as the native dispatcher does.

Two German names (cards325 and771) are at least26 glyphs long with no ASCII
space in the first28 glyphs. Native wrapping then consumes inherited R8.
The `WithContext` APIs in `duel_text.h` expose that input; compatibility wrappers
read integration-owned `gDuelTextInheritedR8`. Original caller values remain
unestablished across every call chain. No invented default replaces the input.

Effect callers with a single meaningful card argument now pass zero for their
unused second field. Their fixed message domains contain no `#3` substitution.
Callers whose messages use `#3` preserve explicit second-card values. This
change expresses the observable message contract, not incidental CPU registers.

## Full card and description viewer

`src/card_presentation.c` covers `08018F1C..080194B8`, the card-detail layout
at `08006E58..080073D0`, and description viewer `08015DD8..08016228`.

- Full-card art retains Huffman decoding and per-row delta accumulation.
- Icons, frame palettes, up-to12 level stars and ATK/DEF overlays use native
  tiles and transparent-zero composition.
- Title glyphs retain the English abbreviations for cards364 and670.
- Description pages retain the native70-glyph page formatting and arrows.
- The detail cost field uses the low16 bits of cost and five initial blanks.
- The upper palette is supplied by the card-detail context, including the two
  art exceptions that use palette index255.

`tools/rip_card_composites.py` exports901 composed112×152 PNGs with their
tile buffers, maps and palettes. These are reconstructed previews, not emulator
captures. `tools/rip_duel_graphics.py` exports115 HUD/cursor/overlay images in
addition to the existing terrain views. `tools/rip_duel_text.py` preserves
original message bytes, language variants and substitution markup.

## Password entry and rewards

`src/password.c` covers entry UI `0801827C..08018D64`, key repeat `08018E08`,
lookup and bonus rules `080341B8..080344A0`, and feature orchestration `0803428C`.

- Highest set input bit wins; repeated navigation overrides ordinary presses.
- B moves the input digit and does not cancel the password screen.
- Eight-byte comparisons return10/11; skip and end records remain distinct.
-901 card records include eight skipped records, followed by a terminator.
- Three bonus records precede their terminator. Bonus1 grants50000 money;
  bonus2 grants100 capacity. Bonus0 has no reward action.
- Bonus-use bits are persistent; card passwords add shop stock rather than
  collection cards.

The exporter provides raw records, readable CSV, the background layer,20 digit
views,11 idle key highlights and22 pressed frames. Native palettes/OAM are
retained beside the53 sprite PNGs.

## Duel lifecycle

`src/duel_flow.c` recovers initialization `08017CA8`, deck preparation
`08027390..08027480`, board initialization/orientation `08023CC0..08024000`,
turn orchestration `08017B84`, transformations/borrowed-card returns,
and win/loss handling `08016234..08016740`/`08017D6C`.

Details preserved include200 random deck swaps per side, drawing from the end
of the remaining deck, native alternating hand-clear/draw order, physical versus
relative board orientation, transformation messages, and returning borrowed
monsters to the last free opposing slot. A full opposing row clears the
borrowed card without adding a graveyard entry. The money-message final divisor
is10^12 despite its localized wording. Player action selection and battle
animation bodies are now recovered; see [player/menu recovery](player_menus.md).

`src/duel_special_wins.c` adds Exodia/FINAL masks and their loss-flag, music and
message sequence. All five distinct pieces are required; duplicates cannot
replace a missing piece.
