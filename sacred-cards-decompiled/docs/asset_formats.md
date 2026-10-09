# Confirmed AY7E asset families

Offsets below are ROM file offsets. Add `0x08000000` for CPU addresses.
Only the USA Rev. 00 SHA-256 recorded in the extractor is supported.

## Card artwork

There are 901 table slots, including blank slot zero. This count describes the
ROM tables, not a claim that every slot is available during normal gameplay.

| Data | Pointer table | Entries | Record/output size |
| --- | --- | --- | --- |
| Full artwork | `0xD51958` | 901 | 6,400 decoded bytes |
| Artwork palette | `0xD5276C` | 901 | 128 bytes, 64 RGB555 colors |
| Miniature artwork | `0xD536F0` | 901 | 576 decoded bytes |
| Multilingual name | `0xD310E0` | 901 | NUL-terminated string |

The full artwork table ends exactly at the palette table. The palette table
ends at `0xD53580`, where the card frame data table starts. The miniature table
ends at `0xD54504`. The previous assumption that this table had 1,196 entries
incorrectly included neighboring pointer tables; the previous claim of 905
valid streams was also incorrect. The actual miniature family has 901 streams.

The renderer at `0x08018FC8` reads the artwork and palette tables using the card
ID at `0x02020B10`. It calls `0x08009118`, which invokes the Huffman BIOS wrapper
at `0x08036930` (`svc #0x13`) and then calls `0x0800917C` with `(10, 10)`.

Full art decoding proceeds as follows:

1. Decode BIOS Huffman `0x28` to 6,400 bytes.
2. Traverse the image in raster order, addressing bytes in 8×8 tiled storage.
3. Reset an accumulator to zero at each 80-pixel row. Add each stored byte modulo
   256, replacing it with the cumulative value.
4. Untile the resulting 10×10 tiles to an 80×80 image.
5. Use the corresponding 64-color RGB555 palette.

The original delta routine uses horizontal increments `[1,1,1,1,1,1,1,57]`
from `0xAAEB8` and row corrections `[632,632,632,632,632,632,632,56]` from
`0xAAEC0`. These establish the 80-pixel tiled traversal independently of visual
inspection. The C reconstruction specializes the routine to the `(10,10)`
arguments used by these callers. Its compiler output is not ROM matched.

`tools/verify_card_art.py` executes the original Thumb routine and its original
ROM memcpy in Unicorn, then compares all 6,400 output bytes with the Python
extractor and compiled C for every card slot. It also checks inverse filtering,
output redzones, and preservation of SP and the callee-saved registers. This
verifies the delta transformation, not BIOS Huffman emulation or a full ROM build.
The report is `build/validation/card_art.json`.

Two card images contain index 255 after the verified delta transformation:
Flying Fish (ID 835, 25 pixels) and Twin-Headed Fire Dragon (ID 844, 2 pixels).
Their per-card palettes do not define that index. Exported PNGs mark those pixels
magenta, and the manifest records the unresolved index. Recovering the full
runtime palette is still required for those pixels. All other card slots use
only their recovered palette entries.

Miniatures are LZ77-compressed 3×3 8bpp tiles (24×24 pixels).
`0x08034AF8` loads them, and `0x08034B40` inserts them into card frames.
The palette loader at `0x08034658` copies 160 RGB555 colors (320 bytes) from
`0x9C54B0` to its argument destination. `0x0803466C` copies the same colors to
the object-palette shadow at `0x02000200`. All miniature indices fit this palette.
The earlier grayscale interpretation is retained as an additional preview;
the gallery now uses the recovered colors.

Ten frame pointers at `0xD536C8` select 1,024-byte 4×4 8bpp tile images.
The card's frame type is the byte in the 901-entry array at `0x8A693`, copied to
`0x02020B19` by the metadata loader. The compositor overlays the 24×24 art at
pixel `(4,2)` within a 32×32 frame and writes it to a surface 16 tiles wide,
leaving the other tiles untouched. `ComposeMiniCard` in `src/card_art.c` and the
Python compositor match execution of the original ROM function for all 901
cards, including untouched gaps and output redzones. `build/validation/miniatures.json`
records this comparison. All ten raw frame templates and their PNGs are exported.

Names have language markers `$0` through `$5`; the CSV selects `$0` (English),
preserves raw multilingual strings in `.name.bin`, and escapes any unrecognized
non-ASCII English bytes. The card data loader at `0x08006BE4` also provides the
attack (`0x886E6`, u16), defense (`0x87FDC`, u16), and cost (`0x88DF0`, u32)
arrays. Values are exported raw, including sentinel values such as 65535.

The description-pointer table at `0xE94E78` has 901 entries and is accessed at
`0x08006CA0`. Descriptions include language markers, padding, and control bytes.
The extractor retains NUL-terminated multilingual originals in `.description.bin`
and exports the `$0` segment as `description_markup`. Characters such as `^` and
`%` are preserved literally pending recovery of the text renderer; this is not
a normalized prose transcription. Blank slot zero has an empty description.

## Scene backgrounds

Four adjacent tables have 58 entries each:

| Table | Contents | File offset |
| --- | --- | --- |
| Tiles | LZ77-compressed 8bpp tiles | `0xD514D0` |
| Normal map | 32×32 u16 text background map | `0xD515B8` |
| Alternate map | Another 32×32 u16 map | `0xD516A0` |
| Palette | 240 RGB555 colors | `0xD51788` |

The scene loader at `0x0803032C` sets BG3CNT to `0x1F83`, selecting 8bpp text
background graphics. It decompresses 44,544 tile bytes to `0x02000400`, copies
480 palette bytes to `0x02000020` (color index 16), and copies a 2,048-byte map
to `0x0200FC00`. `0x080303B0` copies the alternate map.

The exporter applies the map's tile indices and horizontal/vertical flip bits.
Both maps are rendered in full at 256×256. Index zero is displayed black; none
of the rendered maps uses unresolved palette entries 1..15. This is a source
background reconstruction; runtime scroll offsets, sprites, and other layers
are not simulated.

## Scene attributes and actor configurations

The table at `0xD51870` holds 58 pointers to consecutive 19,200-byte resources
from `0x496E38` through `0x5A6C38`. `0x0802FD2A` selects the scene's pointer and
stores it at `0x020236F0`. The accessor at `0x080311B0` loads a halfword at
`grid + 2 * (120 * (uint8_t)y + (uint8_t)x)`. Combined with the exact resource
extents this establishes a 120×80 grid of 16-bit cells per scene.

Recovered predicates are defined precisely without assigning guessed meanings:

- `0x0803181C`: `(cell & 0xFE00) == 0 && (cell & 1) != 0`.
- `0x0803183C`: `(cell & 0x0100) != 0`.
- `0x08031854`: returns 1 for bit 9, else 2 for bit 10, else 0.

These are used by movement/scene-event code. The exporter renders bit 0 and mask
`0xFE00` as raw categories, not a definitive walkability map. C reconstructions
match original Thumb execution for all 65,536 u16 inputs to each predicate,
including nonzero upper register bits to verify truncation. The grid accessor
was compared at nine corner/middle positions in each of the 58 scenes. Reports
are in `build/validation/world_data.json`.

The 58-entry table at `0xD548B8` points to variant sublists within the adjacent
`0xD54504..0xD548B8` region. Those lists contain 237 pointers in total. Their
records are contiguous from `0x9C68F0` to `0x9DF52C`, 428 bytes apiece.
The loader at `0x0802FD18` indexes first by scene, then configuration variant.
It consumes this layout:

| Offset | Size | Contents |
| --- | --- | --- |
| `0x000` | 320 | 16 actor slots, 20 bytes each; active list ends at signed ID -1 |
| `0x140` | 4 | Scene script pointer A |
| `0x144` | 4 | Scene script pointer B |
| `0x148` | 100 | Five player spawn records, 20 bytes each |

Each actor/spawn record contains a signed u16-sized actor ID at +0, an orientation
byte at +2, one reserved byte at +3, signed 16-bit x/y at +4/+6, two ROM-address
script fields at +8/+12, and a raw u32 flag field at +16. The loader's field
accesses and stride arithmetic establish these offsets; semantic names for
actor IDs, orientation values, and script instructions still need recovery.
`src/scene_data.h` contains corresponding C layouts with compiled size/offset
assertions. The export preserves all slots, including entries after the sentinel,
as well as parsed active actors and all five spawns.

## Actor sprites

`0xD511A0` contains 102 sheet pointers; `0xD51338` contains their palette pointers.
IDs 22 and 23 alias the same resources. The 101 distinct sheets are 128 pixels
wide, 192 or 256 pixels tall, in 4bpp tile order. Eight actor IDs (27–32, 42, 43)
have two adjacent 16-color RGB555 banks; the others have one. Index zero is
transparent. The final sheet ends at `0x2B16EC`, the next separately referenced
graphics resource; the final palette ends at `0x2B268C`.

The frame-copy routine at `0x08030554` takes an actor ID, frame ID, and destination.
It selects a u16 tile offset from the 18-entry table at `0xFBB10`, multiplies it
by 32, and copies four 128-byte rows. Source rows have a 512-byte stride and
destination rows a 1,024-byte stride. This produces a 32×32 frame inside a larger
destination surface. `src/actor_graphics.c` is a portable reconstruction of
that loop, with the table lookups resolved by its caller. Assembly inspection
establishes the layout; execution comparison has not been performed.

`0x080305A4` selects walking frames as `orientation * 3 + phase[state]` for
orientations 0–3. The 20-byte phase table at `0xD4C71C` is exported. The adjacent
seven special-frame bytes are retained, but their full state semantics remain
unresolved. `0x08030464` chooses a 16-color bank using entity flag bits 3–5.
The gallery exports every sheet and all 18 frame selections for each actor,
including blank selections; this does not imply all frames are used in play.
Walking previews use adjustable timing, not recovered engine timing. Actor IDs
link to the scene configurations that reference them; names remain unidentified.
Binary manifests record each original source row for repacked frames.

## Scene script graph

Scene configurations supply 449 non-null root pointers. Following their two
edges reaches 1,288 nodes. The node loader at `0x08031AA8` reads three u32 fields:
payload pointer, next node when the interpreter state byte at +0x1E is zero,
and next node when that byte is nonzero. It stores these at state offsets
+0x10/+0x14/+0x18. The loop at `0x08031D84` takes an edge at a payload terminator
and exits for a payload whose first byte is ASCII `Z`.

The command dispatcher at `0x08031E40` handles `#`, `@`, `^`, language markers,
and glyphs. Command operands can contain zero bytes, so reading until the first
NUL is **not** a correct general payload decoder. The exporter retains conservative
windows ending at the next known payload or node address, plus a contiguous
source region. Windows may include padding or unreferenced bytes. The gallery's
906 English candidates are selected by `$0`/language markers; control markup and
binary operands remain visible, not interpreted as prose. Reachability covers
these configuration roots, not every possible event or hard-coded game script.

`jump_tables.csv` documents seven range-checked dispatch tables in the audio,
script and stat-modifier routines. The disassembler follows those cases and stops at Thumb
`MOV PC`, preventing linear decoding into the adjacent table. Other indirect
branches remain unresolved. These changes improve the research listing; they
do not establish complete code/data classification.

## Audio

See [audio recovery](audio.md) for music, effects, samples, sequence tables,
scene music selection, tooling and playback limitations.

## Provenance and limitations

All binary assets come from the supplied local ROM. `manifest.json` records
source offsets, lengths, and SHA-256 values for exported binary resources.
Compressed streams, intermediate delta data, decoded tiles, maps, palettes,
and raw names are retained so the extraction can be audited or extended.

The [mGBA BIOS implementation](https://github.com/mgba-emu/mgba/blob/master/src/gba/bios.c)
was consulted for Huffman format facts: tree layout, child offsets, terminal
flags, and MSB-first traversal of little-endian bitstream words. The Python
decoder is an independent implementation. Semantic card-filter recovery and
all ROM offsets above derive from the supplied ROM.

Known scene/UI/animation families, dialogue and audio resources are exported;
credits/map/logo resources are now in `build/assets/remaining-screens/`. Complete
semantic classification of every data byte and animation context is unestablished.
`build/assets/rom-data/` retains all bytes after the reviewed code interval,
including unused and uninterpreted data. See [the current checkpoint](PROGRESS.md).

## Additional UI and font extraction

`tools/rip_ui_graphics.py` writes `build/assets/ui/`:

| Preview | Tiles | Map | Palette | Loader |
| --- | --- | --- | --- | --- |
| City-map menu, 240×160, 8bpp | 56D28 (LZ77) | 5FFBC | 5FE3C, 192 colors | 08000A64 |
| Name entry, 240×160, 4bpp | 70A84 (LZ77) | 776D8 | 774D8, 256 colors | 0800181C |
| Card-detail labels, 248×160, 4bpp | 8BA8C (LZ77) | 8E2D0 | 8E1D0, 128 colors at index 128 | 08006E58 |

Tilemap flip bits and 4bpp palette banks are applied. These are isolated layers;
runtime text/OAM overlays are not composited. The 31st card-detail tile column
is retained. Additional object tiles, palettes and maps are saved as raw data.
All rendered indices in these 48 UI/frame/icon previews have resolved palettes.

Full-card frame tiles at 94681C and the 14×19 map at 9489A8 produce 112×152
frames with nine palettes through D53584. Loader 08018F44 copies 20 colors to
index 64. Type icons use D535A8/D53608 for tiles/palettes: 24 slots, with the
last three 32×16 and the others 16×16. Summon icons use D53668/D53698: twelve
16×16 slots. Zero slots are retained; image index zero is transparent.

Small and large bitmap font banks start at D2AAEA and D2CA66. The first bank's
boundary gives 806 ten-byte records. Both accessors use glyph-index routine
080178B0; 806 large records of eighteen bytes are exported on that evidence.
Rasterizers consume 8 or 16 row bytes, shift away bit 7, emit bits 6..0 and
append a blank column. The two extra record bytes remain in raw exports.
The gallery includes two atlases and 1612 individual transparent glyph PNGs.
`font-mapping.json` records candidate Shift-JIS mappings through the recovered
index arithmetic; exact localization/ASCII conversion is not yet established.

See [gameplay recovery](game_logic.md) for extended card metadata, terrain
modifiers, level thresholds, deck data and reconstructed C.

### Script glyph mapping and card-detail palette exceptions

The ASCII conversion path at 080323B0 uses pointer table D35FB8, gated by the
91-entry character switch at 08032244. The exporter now records the 63 ASCII
characters that enter this conversion path in `script-ascii-mapping.json`, with
ROM glyph bytes and recovered font indices. This is specific to that script
renderer; it does not establish every localized text path.

The two raw card-art exceptions (835 and 844) use index 255. In card-detail view,
08006E58 loads the 128-color upper palette from 8E1D0; its final color at 8E2CE is
zero (black). The card's own palette copy at 08006EF2 fills only the lower 128
colors at 02000000. Separate `ui/card-0835-detail-context.png` and
`ui/card-0844-detail-context.png` therefore resolve those pixels for this screen.
Raw source-art previews still mark them unresolved because their own 64-color
palettes do not define index 255. Other display contexts require their own palette
state; the exporter does not generalize this screen-specific result.

## Dialogue portrait family

`tools/rip_portraits.py` traces loader 08031BA4 and compositor 08031C58:
33 entries each at graphics table 08D4EDBC, palette table 08D4EE40 and part table
08D4EEC4. Slot 0 is a placeholder and runtime portrait ID zero takes the
no-portrait path. Each graphic decompresses to 32 KiB via BIOS Huffman, then
08009160 applies a single cumulative byte sum across the whole buffer. Unlike
card artwork, this delta chain does not reset on image rows.

Each portrait supplies 256 RGB555 colors and up to four part descriptors.
The exporter retains compressed streams, delta data, decoded tiles, palettes,
OAM attributes and 273 part-frame PNGs. It assembles 42 static frame-zero previews,
including separate optional-part-3 variants for nine slots. These are transparent
240×160 compositions with native OAM order, coordinates and flips. The sprite
mapping is 8bpp/2D (128×256 sheet), consistent with DISPCNT 0x5D00 and
[GBATEK's OBJ mapping](https://mgba-emu.github.io/gbatek/#lcd-obj---vram-character-tile-mapping).
Dialogue backgrounds, blending and per-scanline sprite limits are not simulated.

Blink duration/frame tables at 0817578C / 081757C8 and mouth tables at
08D4F10C / 08D4F114 are retained in the manifest. Counter behavior is reconstructed
in `src/script_runtime.c`; these static exports do not establish hardware timing.
