# Native state contract review

This review checked record layouts and selected global views against instructions
in the AY7E USA ROM (`093f986a92d73c48e11de0a83c6678c3620f8def6173f5e69133815301b40d8f`).
It used static Thumb disassembly, ROM data and consuming C. No emulator or
implementation tests were run. The registry covers the current unresolved data
inventory; this document does **not** claim every access to every view was audited.

## Corrections established during review

- `gInitialDuelLifePoints` belongs at **02020D70**, overlapping the two starting
  life halfwords in `gOpponentRecord` at +14/+16. Native 0802B2D8 loads base
  02020D30, then adds 40/42 before reading. The previous registry incorrectly
  treated the base literal itself as the data address and therefore invented an
  alias with the money reward. The active initializer calls this helper at
  08017D3E.
- The first opponent-record word contains a **halfword identifier, terrain byte
  and raw byte**, not a single logical identifier. At 08023D98..08023DA4 the
  terrain load uses 02020D30+2E, equivalent to record+2. The AI's word view
  remains available and is truncated to a halfword for its tag lookup. The
  fixed-width record now describes the separate fields.
- `gCreditsTextRow` is **two bytes**. Native 0800043A writes STRH, 0800045E reads
  LDRH, and 0800048A..0800048E increment and store a halfword. The animation
  review corrected the consuming C declaration; this review corrected the
  registry extent.
- The parent applied a consuming-C correction in `UpdateWanderingActors`:
  08030EB4..08030EBA tests only actor flag bit 2; 08030EBC..08030EC0 rejects bit
  5. The former C condition additionally rejected bits 0/1. The byte layout
  itself was already correct.
- Generic sprite descriptors now call byte zero `duration_or_tag`. Battle
  frame lists consume it as duration; portrait composition consumes count/+4
  and receives its timing from separate tables. A descriptor does not imply a
  particular timing interpretation across every family.

`state_views.json` contains `review_evidence` address ranges for the views checked
here. `src/native_state.h` adds offset assertions for the reviewed record fields;
these enforce the declared byte layout during compilation and are not behavioral
equivalence checks.

## Record associations reviewed

All addresses below are native provenance values. They need not become fixed
addresses in another implementation. A record stride can include untouched bytes;
the named `reserved` fields must not be interpreted as implicit initialization.

| Record/view | Layout reviewed | Native evidence |
| --- | --- | --- |
| Duel cell, physical board and hands | Cell stride 8; card halfword +0, signed stage +2, status byte +3, flags +4; board 4×5 and hands 2×5 | 08023CC0..08023D96; clear at 08023FD4; physical setters 0802432C..08024484 |
| Duel snapshot | Hands +A0, terrain +F0, two four-byte side records +F4; total 252 bytes | 08023D68..08023DFC |
| Duel side | Grave halfword +0; restriction/summon flags +2 | 080244A4..08024574; 08028348/08028360 |
| Duel deck | Forty halfwords, remaining byte +50, stride 54 | 08027300..08027328; 08027390..080273C6 |
| Selected-cell copy | Same eight-byte record; copy preserves specified bits and untouched tail bytes | 08024744/08024758 and `CopyDuelCell` consumer |
| Battle calculation | Two 12-byte sides; card/ATK/DEF/LP halfwords, attribute byte +8, row/column +9/+A; command +18, flags +19, owner indices +1A/+1B | Setup 08006518..08006A70; write-back 08023514..08023590 |
| Battle display | Two 12-byte sides; byte +B/+17 untouched by clear; result byte +18; view 25 bytes | 08023C8C..08023CAC; 08023514..08023590 |
| Card metadata | Two copies of the same name pointer +0/+4, description +8, cost +C; card/ATK/DEF +10/+12/+14; eight metadata bytes +16..+1D | 08006B90..08006BB2; 08006BE4..08006CAC |
| Collection menu | Selection halfword +0; sort/detail/choice +2/+3/+4; view12 bytes before list at 0201FCCC | Collection dispatcher 0800441C and editor 08003C8C..080041B4 |
| Player deck state | Cost word +0, signed selection +4, sort/detail/popup/count +5..+8; ten-byte view before cards at 02020C5A | 0801421C..0801469C; matching offsets in `deck_builder_state.c` |
| Shop menu | Signed halfword first row/count +0/+2; column/row/ring/sort/choice +4..+8 | 0801C114..0801C17A; 0801C50E..0801C544; base020214D0+7E2=02021CB2 |
| Shop pointer grid and card rows | 5×7 pointers at 020214D0 refer into 5×7 halfwords at 0202155C; ring orientation chooses physical rows | 0801C184..0801C1CC |
| Shop sorted cards | 904 halfwords cleared at 020215A2, including padding slots | 0801C4C4..0801C4E0, loop0..387 inclusive |
| Card-sort state and records | List address +0, count halfword +8, method +A; records12 bytes with key words +4/+8 | 0801FB80..0801FB94; 0801FB9E..0801FBE4 |
| Duel cursor | Column/row/saved column/saved row/mode/choice bytes; `gDuelViewport` is row byte +1 | Initialization 080274D4 and consuming `duel_player.c` state macros |
| Runtime actors | Fifteen 32-byte records from 02023498; coordinates +4/+6, cell +A, phase +C, scripts +10/+14, movement +18, signed wander timer +1A, flags +1C | 0802FD18..080300CC; 08030E58..08030F2E; scene base02023490+8 |
| Follower trail | Ten 8-byte entries at 02023678, pose +0 and coordinate halfwords +2/+4; unused bytes retained | 0803102C..0803105A; runtime update 08030FAC |
| Scene pointer fields | Entry020236C8, exit020236CC, grid020236F0 | 0802FD22..0802FD76, relative to 02023490 |
| Opponent | Ten-word 40-byte copied record; deck +4, reward pointers +8/+C/+10, LP +14/+16, capacity +18, money bounds +1C/+1E, scale +20, music +24 | 08017CAE..08017CE6; reward consumers 08016254/080164EC; LP 0802B2D8 |
| Link state | 36-byte 32-bit ABI record; explicit 32-bit send/receive addresses | Existing native contract in `link_transport.h`, consumed throughout `link_transport.c`; not independently audited in full here |
| OAM | 128 eight-byte entries, fourth halfword carries affine coefficient or padding | 080284CC..080284DE uploads 200 halfwords from 02018400 |
| Script state/node | 52-byte state, text/branch addresses +10/+14/+18; node three 32-bit addresses | 08031AA8..08031AB4; existing explicit offsets in `script_runtime.h` and dialogue consumers |
| Duel text state | 32-byte native stack record; state byte +8, text address +C, operands +10..+1A, index byte +1C | Existing `DuelTextState` declaration and accesses08024F2C/08025098/080254CC; inherited R8 is separate context |

The fixed-width scene header, save-region and sprite descriptors additionally
retain the native field widths of their existing loaders. They are portable
descriptions, not globals installed into the original RAM arrangement.

## Storage extents and aliases

- Background storage spans02000400..02010400; the actor graphics buffer follows
  through02018400, then OAM through02018800. Shared scratch begins02018800.
  Full-card tiles/palette/map and the menu/sort/battle scratch views reuse that
  region. Views sharing physical bytes require shared storage or explicit
  transfer semantics in another implementation.
- Full-card palette is256 **bytes**, followed immediately by the map at 0201C900.
  Loaders obtain their destinations through original ROM pointer words; treating
  those pointer-word addresses as the destination would produce a different map.
- `gBgOffsetsRaw` has 22 halfwords because native low halfwords occupy eleven
  four-byte-spaced slots. Upload 08028438..080284B8 reads the even indices. The
  odd indices are preserved spacing, not eleven more independently initialized
  display parameters.
- Dialogue initialization 08031B0C loads tiles at 0200DC00 and copies 280 halfwords
  to 0200EC00, giving the 1280-byte map extent.
- Description entry clears two 1180-byte pages. All 900 nonempty card descriptions
  have `^2` in their first matching language slots 0..4. Japanese slot 5 does not
  start with that markup. Card 106 contains a repeated set of language markers
  before its NUL; counting every regex match overstates the number of effective
  segments. The parser can accept a custom page count up to 9 without checking
  this observed two-page storage bound.
- SRAM initialization copies native read code to 0201EFF8 and compare code to
  0201EF58, then installs odd Thumb entry pointers0201EFF9/0201EF59 in separate
  RAM slots. The source's direct C loops are an explicit implementation choice
  documented in `save_storage.c`, not a claim to preserve placement/timing.

## Remaining uncertainty

Several reserved bytes and flag bits remain deliberately raw. Allocation extents
come from established consumers and clear/copy operations, not original linker
symbols. Register-dependent text behavior is outside the state layout itself.
This pass does not prove lifetime separation of overlapping scratch users or
runtime correctness of all callers. Compilation and complete symbol catalogs
cannot establish those properties on their own.
