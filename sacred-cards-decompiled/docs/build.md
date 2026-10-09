# Build status

## Maintained source

Run `make semantic-objects`. **89 C modules and two assembly modules** compile
with Clang for ARM7TDMI, using freestanding C99 for C. Generated effect dispatch,
AI scorer and 96 immutable ROM table definitions compile as additional objects.
The assembly retains reset/IRQ mode transitions and register-call veneers.

Run `make recovery-status` after compiling to regenerate the static inventories.
The current objects have no duplicate definitions, missing objects or unresolved
game-function symbols. Unbound global state/native pointer views and compiler
support symbols remain; see `build/research/semantic-linkage.json` and
[source contracts](source_recovery.md). The objects are not linked into a ROM
or standalone host application. Compilation does not establish runtime equivalence.
No implementation tests were added or run for the final recovery pass.

Run `make recovery-contracts` to compile and refresh the declaration/layout,
state, animation, resource and register-context catalogs. It requires the
existing extraction manifests and reviewed Ghidra project. See
[rebuild contracts](rebuild_contracts.md) for outputs and regeneration details.

## Original data

`make rip-assets` regenerates the confirmed decoded families and the complete raw
post-code interval at `build/assets/rom-data/original-data.bin`. Native address
`A` corresponds to offset `A - 0x0803B61C` in that file. Manifest hashes identify
the supplied ROM and exported bytes. Uninterpreted data and padding are retained.

## Historical instruction reassembly

`make reassemble` regenerates an instruction rebuild at
`build/reassembly/sacred-cards.gba`. `tools/build_reassembly.py` emits ARM/Thumb
assembly from the reviewed listing, assembles it with Clang and retains original
ROM bytes for data/gaps. Unresolved relocations are rejected.

The retained earlier report records SHA-256
`093f986a92d73c48e11de0a83c6678c3620f8def6173f5e69133815301b40d8f`.
It predates the final callback/root additions. It does not incorporate maintained
C and is not evidence of a C rebuild or original compiler recovery.

Original compiler matching, byte-identical C output and native RAM/linker
placement are outside the requested target.

## Automatic drafts

`make decompile` exports 2,806 known roots through the local Ghidra toolchain.
Drafts are separate, inferred source and are not compiled or linked. See
[decompilation.md](decompilation.md) for provenance and limitations.
