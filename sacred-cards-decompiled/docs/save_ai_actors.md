# Save lifecycle, AI selection and script actors

These are semantic reconstructions, compiled to ARM7TDMI Thumb objects. They
are not linked into the ROM or execution-compared. Native layout, timing and
runtime bindings remain limitations. The final source pass supplies the identified callees.

## SRAM lifecycle

`src/save_storage.c` / `.h` reconstructs 08006068..0800650E and the byte driver
at 080369C0..08036C6A. Its API accepts a 32 KiB SRAM view, an 8 KiB scratch buffer
and WAITCNT. This parameterization differs from the original ABI.

| SRAM offset | Data |
|---|---|
| 0000 | Commit marker |
| 0001 | 15-byte `020322_DM7_KCEJ` signature (NUL excluded) |
| 0040 | Primary 0x80A-byte payload |
| 401E | Primary little-endian u16 checksum |
| 4020 | Backup 0x80A-byte payload |
| 7FFE | Backup little-endian u16 checksum |

Checksum is byte sum modulo 65536. Each byte read/write/compare sets WAITCNT's
lowest two bits to 3 without restoring them. Verified writes retry at most
three times and return zero or the native address of the first mismatching byte.
The higher-level game ignores those error results; this behavior is preserved.

Saving packs/checksums once, writes marker 1, primary data/checksum, marker 2,
backup data/checksum, then marker 0. Initialization clears 32 KiB in four 8 KiB
writes, initializes game globals, saves both copies and writes the signature
under marker 3 before committing marker 0. New-game initializer 08006314 remains
an external dependency.

Validation is **not a pure read-only predicate on game RAM**: it loads and
unpacks each payload before checksum comparison, leaving the backup's values in
RAM. It rejects a bad signature or marker >=3. The return state depends on the
marker and both checksums:

| Marker | Neither valid | Backup only | Primary only | Both valid |
|---:|---|---|---|---|
| 0 | Initialize | Repair primary | Repair backup | Ready |
| 1 | Initialize | Repair primary | Initialize | Repair primary |
| 2 | Initialize | Initialize | Repair backup | Repair backup |

Repair loads the selected good copy and copies its stored checksum. General
preparation initializes invalid storage; the repair-only wrapper does not.
The payload descriptor still saves only 32 of the event bank's 50 bytes.

Three byte-driver routines were previously missed because callers copy them to
RAM or the stack. `function_entries.csv` now seeds 08036A00, 08036ACC and
08036B4C with evidence. Ghidra explicitly clears data definitions and retries
these reviewed instruction spans in Thumb mode. All three now have drafts.
Native code relocation/timing is not reproduced by the direct C byte loops.

## Opponent AI selection

`src/ai_turn.c` recovers the candidate-search loop at 080114BC, state snapshot
and restore helpers, score storage, and best-candidate selection. There are 616
8-byte actions at 080AAED4, with kind u16 plus six operand bytes. Kinds 0..24
index five 25-entry callback tables: simulation, execution, before-score,
after-score and validation. All are exported in `build/assets/gameplay/ai.json`,
with CSV and binary files and a browseable `ai.html`.

Each decision suppresses presentation, enumerates candidates and, for each
validator result equal to 1, snapshots state, begins scoring, simulates, finishes
scoring and restores state. It then enables presentation and executes the best
candidate, repeating until no positive score remains or the duel-end predicate
succeeds. The final wait is 30 frame calls.

Snapshots retain 252 bytes at 02023160, one byte at offset 80 of each 84-byte
deck record, two life-point values and two auxiliary flags. This is the native
snapshot scope, not a full-RAM copy. Scratch is shared with saves at 02018800.
There are 616 score records, eight bytes each. Clearing resets candidate ID and
score but preserves the two padding bytes. Scores compare as unsigned u32;
strictly greater wins, so the first equal positive score remains selected.
No positive score returns candidate zero as a sentinel.

All 125 top-level callback slots and 432 distinct card-scoring bodies now have
semantic C. See [runtime recovery](runtime_recovery.md) for native quirks and
template/maintained coverage. Presentation source is recovered; runtime integration and execution remain unverified.

## Script actor commands

`src/script_actors.c` / `.h` adds seven command bodies at 08032944..08032D22,
called by the existing 27-form script dispatcher:

| Form | Operation |
|---|---|
| @0 | Move by direction and step count |
| @1 | Place actor at coordinates and frame |
| @4 / @5 | Move to X / Y |
| @6 | Set pose four |
| ^5 | Change actor sprite and palette |
| ^3 | Fade to dark |

The 32-byte actor records start at 02023498. Movement updates coordinates with
signed direction deltas, refreshes height, decrements the walk phase, chooses a
frame, and performs two frame/upload cycles per step. The phase wraps to 19.
Finish-walk clears flag bit 2, setting it only for keep-flag value exactly 1.
Placement neither hides dialogue nor clears the script dirty flag.

Frame tiles use actor sheet table 08D511A0, offsets 080FBB10 and destination
tiles 080FBB34. Sprite palette selection uses actor flag bits 3..4. Fade writes
DISPCNT 1D00, BLDCNT 00DC, and 16 brightness levels with the commanded delay.
Height sampling, frame/upload helpers, supported dialogue glyphs and portrait
composition are now recovered in the [runtime modules](runtime_recovery.md).
Collision/movement and scene lifecycle are now recovered in `overworld.c` and
`overworld_movement.c`. No native timing equivalence is claimed.
