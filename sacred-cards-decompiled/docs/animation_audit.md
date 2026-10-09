# Native animation audit

This review compares the maintained C and exported playback contracts with
Thumb instructions in the AY7E USA Rev00 ROM. It does not execute the recovered
implementation or compare emulator frames. Timing below counts explicit frame
waits or caller updates; host rendering and interrupt timing remain unverified.

## Battle presentation

Reviewed entries include `08012358`, `080127D8`, `08012928/12964/129EC`,
`08012A74/12B3C/12B70/12C74/12DD0/12DDC`, `08013090/130F0/131EC/132D0/1331C/13330`,
`08013420/13464/1351C/1353C`, `0801376C/137C4/13828/1384C/13978/13B24`,
and card staging at `08006AA0/06B08`.

| Sequence | Native playback rule |
| --- | --- |
| Ordinary hit | Four descriptors, two uploads each: eight draw ticks. Adjacent equal OAM pointers terminate; descriptor duration bytes are ignored. |
| Attribute hit | Five descriptors, two uploads each: ten draw ticks. The fifth repeated-pointer descriptor is drawable. Zero duration terminates. Matrix zero is initialized; the matrix advances after each upload. |
| Destruction | Steps 1 through 17, three upload ticks each: 51 ticks. Twelve particles each have five offsets and two possible OAM planes, starting at slots 0 and 60. Particle descriptors wrap on equal adjacent low ten tile bits. |
| Life points | Fifteen initial ticks, subtract 72 per damage tick with a clamp to the target, then thirty ticks for a decrease. The native 10,000-iteration guard is retained. Sound 71 occurs on even damage ticks, beginning at zero. |

Each sequence also has its own setup and cleanup callback tick. Battle setup
has two callback ticks and a fifteen-tick hold. Side 1 runs before side 0; each
side requires `flags & 6`, then performs hit, destruction and LP in that order.
There is a thirty-tick gap when both sides qualify and an additional final
thirty-tick hold for results 5 and 8.

The review confirmed coordinate wrapping, blend/priority/palette masks,
attribute-hit affine padding preservation, 128-entry card palette darkening,
and destruction RNG behavior. Particle initialization consumes one gameplay
seed-selector draw, saves that resulting RNG state, temporarily uses a seed
table, then restores the saved state. The native jitter helper `080131EC`
exists but the ordinary hit loop does not call it.

No battle behavior correction was established in this pass. Source comments now
record the different terminators and particle fields. The earlier palette type
correction is consistent with staging: the full-card palette is 256 bytes,
containing 128 RGB555 colors; its map immediately follows at `0201C900`.

## Portraits, actors and menus

| Entries reviewed | Confirmed behavior |
| --- | --- |
| `08032744/327AC` | Portrait blink indices descend 29 to 0, with duration multiplied by four. Mouth indices descend 3 to 0, with multiplier one while speaking and four while silent. A silent mouth stays at index 0 with timer one. Portrait zero bypasses these updates. |
| `080305A4/30620/30914/30940/30960/30974` | Normal walking draws before decrementing phase, wrapping to 19. Running uses sheets 89/90 and wraps to 25. Stopped actors reset to phase 19 before drawing. |
| `08032944` | Script walking moves one coordinate, updates height, decrements phase, draws, and performs two scene upload cycles. Completion resets phase 19 and performs one final cycle. |
| `080027DC/02BE4` | Name arrows and focused labels compare the old timer with duration before incrementing. Steady holds are duration plus one draws. From zero state the first descriptor has duration draws; the initial screen draw also advances timers. Up/down arrows share phase. Focused labels share phase across page changes. |
| `08002E24/02ECC` | Name confirmation holds thirty ticks, then runs a 150-tick fade loop with brightness changes every seven ticks. Affine coefficients use signed 8.8 products truncated toward zero. |
| `08022424/227B8` | Title pulse uses thirty alpha entries and advances each call because the native timer is reset to zero. Fade performs sixteen brightness updates four ticks apart and exits after 61 ticks. |
| `08019534/19598/195E8` | Intro fades have sixteen levels at four ticks per level. Copyright and both logo holds have 120 ticks. Input is polled during logo holds and ignored. |
| `08000224/0038C/0053C` | Credits pages use an inclusive timer threshold, giving table value plus one calls per period. Header rendering, five row calls and upload occur on ticks 0, 1 through 5 and 6. Backdrop scrolling advances every third frame; loads can repeat while a matching scroll phase is held. The frame counter wraps at sixteen bits. |
| `08000CF8/0116C` | City selection uses a static two-object marker. Fade has fifteen initial ticks, sixteen brightness levels at two ticks each, then fifteen final ticks: 62 ticks. |
| `08025098/253F4/31D84` | Duel text performs one VM step before each wait/upload. Its input prompt is drawn on old timer 0, erased at 15, and resets after 29. Scene portrait updates occur before script dispatch and the frame wait. |

Credits inspection established one source discrepancy: the text-row counter at
`0201CB20` is read and written with native halfword instructions, while its C
declaration was a byte. `src/credits.c` now declares `uint16_t gCreditsTextRow`.
Its ordinary values stay within 0 through 5, but the declaration now preserves
the native extent and stores. The animation catalog also explicitly distinguishes
credits timer thresholds from full page periods.

## Exports and limits

`tools/build_animation_catalog.py` writes `build/assets/animations/manifest.json`
and `build/assets/runtime/animations.json`. These include raw frame descriptors,
OAM files, decoded OAM fields, affine matrices, timing rules and reviewed entry
addresses. Destruction's catalog terminator now explicitly matches the native
tile-index comparison; the stock table happens to repeat its pointer too.

Decoded OAM coordinates retain native unsigned wrapping. Affine enable changes
the meaning of the disable/double-size and flip/matrix bits. Raw attributes are
preserved alongside the decoded fields; procedural code still changes them.
The descriptor fourth halfword represents an OAM affine parameter slot when
uploaded, rather than an additional independent object attribute.

Script commands and game state determine which animations play. This review
covers the listed scheduler, descriptor, palette and procedural playback paths;
it is not an instruction-by-instruction review of every related source module.
Asset extraction plus this static review does not establish complete runtime,
compositor or interrupt equivalence for every game scene.
