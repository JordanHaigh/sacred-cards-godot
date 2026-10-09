# C recovery and automatic draft export

## What is available

- `src/`: 89 maintained semantic C modules plus two assembly modules. All compile as ARM7TDMI Thumb C99
  objects. Most have not been execution-compared; none are linked into the
  matching ROM build.
- `build/decompiled/index.html`: searchable C drafts for all 2,806 current
  reviewed/discovered function roots. Latest export: 2,739 drafts without an
  explicit Ghidra warning, 67 drafts with warnings, zero failed exports.
- `build/decompiled/functions.csv` and `manifest.json`: address, name, body size,
  status, diagnostic and source path for every root.
- `build/ghidra-project/AY7E.gpr`: local analysis project, including RAM regions,
  reviewed code ranges, callback roots and switch references.

**The automatic drafts are not reviewed C and do not form a standalone build.**
Ghidra infers types and signatures; it can omit arguments, misidentify return
values, retain `in_lr`/`unaff_*` register inputs, and misinterpret function
boundaries. The absence of a warning does not establish correctness. This root
list also does not establish discovery of all executable code. These files
accelerate manual reconstruction; they do not complete the faithful source recovery.

## Reproduce

With the tools already installed locally, run `make decompile`. This regenerates
inputs, replaces the AY7E program in the local Ghidra project, exports drafts and
rebuilds the catalog. Logs are under `build/research/ghidra-*.log`.

`tools/ghidra/prepare.py` consumes the reviewed instruction listing, symbols,
callback roots, card-handler catalog, manual jump tables and `function_entries.csv`. It records 3,605
instruction spans and 1,828 explicit `pop {register}; bx register` return patterns.
`RecoverRom.java` disassembles every byte in the reviewed instruction spans,
marks those exact epilogues as returns, and establishes each function entry before
expanding its body. Three copied SRAM routines require clearing inferred data
and retrying their reviewed spans with explicit Thumb context. ARM/Thumb mode comes from the listing. The memory map includes
EWRAM, IWRAM, IO, palette RAM, VRAM, OAM and SRAM. APCS is an analysis convention,
not proof of the original compiler or ABI.

The toolchain is local and ignored under `build/toolchains/`:

| Tool | Archive SHA-256 |
|---|---|
| Ghidra 12.1.4, `ghidra_12.1.4_PUBLIC_20260921.zip` | `ddac49f903da9d5bac833e5cc79395098b9c33cfd3279be5f31bd00387d2d4db` |
| Temurin JDK 21.0.12.1+1, macOS ARM64 | `3623232f33a9c3baadf304480b2535f9a3cba8a58d42ecbb438ba267315d9998` |

Downloads came from the official [Ghidra release](https://github.com/NationalSecurityAgency/ghidra/releases/tag/Ghidra_12.1.4_build)
and [Temurin release](https://github.com/adoptium/temurin21-binaries/releases/tag/jdk-21.0.12.1%2B1).
Archive hashes were compared with the release metadata before extraction.
The full JDK is required; a bundled application's JRE lacks the compiler.

The macOS ARM native decompiler was built from the source included in Ghidra:

```sh
cd build/toolchains/ghidra_12.1.4_PUBLIC/Ghidra/Features/Decompiler/src/decompile/cpp
make -j4 ghidra_opt ARCH_TYPE='-arch arm64' ADDITIONAL_FLAGS='-mmacosx-version-min=12.0' OSDIR=mac_arm_64
mkdir -p ../../../os/mac_arm_64
cp ghidra_opt ../../../os/mac_arm_64/decompile
chmod +x ../../../os/mac_arm_64/decompile
```

The runner supports `--ghidra` and `--java-home` for other installations. It uses
workspace-local Java/Ghidra caches. The script does not download anything.

## Three separate recovery results

1. Asset extraction: files decoded using traced ROM tables and loaders.
2. Semantic recovery: maintained C or automatic drafts, each labelled by evidence.
3. Instruction reassembly: byte-identical ROM assembled from recovered mnemonics
   with original bytes retained for gaps. This build does not use the C objects.

Do not combine these into a single completion percentage.
