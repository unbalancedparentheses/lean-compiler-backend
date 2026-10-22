# Private ELF `R` retention qualification

Base commit: `05188eb0192d15af8a4017cbc9394a069a57779b` (aggregate support integrated; custom TLS support not yet integrated).

Candidate identity: `b24b3ba3e80f00d564c33c1d19fe0efc37289c839ccaa006aa60dbab91311d74`. Before identity: `a23afe3b4889b9da79c50d5ddf5b7e3e4affe2ba26d1e2c5072ed14c73cbdaaa`.

The core adds `R` to the ordinary ELF flag whitelist alongside `a`, `w`, and `x`. No emitter changes are needed: quoted section fields already reach the assembler unchanged. Apple validation is untouched; a valid second field such as `aR` remains a literal section name there, not a GNU retain flag. TLS admission is not broadened by this patch; integration with the separate custom-TLS patch must retain that patch's independent `awT` validator.

## Results

Fresh private build and units passed. All 147 exact proof-audit assertions matched. Custom-section inputs remain outside the verified first-path profile; this is compatibility-layer qualification, not a new proof.

All three Linux targets passed baseline, allocated, optimized, and unchanged original-QBE output. Linux ARM executes natively in the Linux VM; x86-64 and RV64 execute under QEMU user mode. GCC 13.3 and GNU binutils 2.42 are recorded. All twelve executables were confirmed ELF DYN PIE and linked with `--gc-sections`. No timing or speed claim is made.

The independent C program references only `anchor` and `ref_data`. Unreferenced `awR`/`aR` data and an `axR` function must survive; unreferenced non-R data/function controls must disappear. After linking, `nm` supplies numeric offsets relative to `anchor`, passed as runtime arguments. These numbers create no linker relocations or retention roots. C reads the retained values 37 and 83 and calls the retained function expecting 71. This uses the tested Linux target ABI's function-pointer/integer representation; it is not a claim of universal ISO C portability.

Object metadata must contain the exact expected section flags. Removing R from optimized LCB and original-QBE fixtures makes metadata checks fail and all retained-only symbols disappear after GC. A separate retained-value mutation must return failure from the C oracle. Referenced ordinary data/function sections remain present.

Both Apple targets passed three-mode assembly byte equality against the before snapshot. This is emission evidence only, with no Apple runtime or retention claim. All five targets passed dedicated emission-only tests using missing C/QBE paths and an execution guard. The default native CLI passed its Apple emission scope. Hooks are provided for check.sh, all target runners, and the global emission-only suite; hook syntax was checked, but the entire global emission-only suite was not rerun here.

## Evidence and integration

`core.patch`, `helper.patch`, and `hooks.patch` are separate. Generated identity files are omitted; regenerate identity and rebuild after integration. The helper supports native defaults, explicit target/compiler/CC/runner, optional original QBE and before snapshot, and emission-only mode.

`matrix.json` binds the frozen candidate/before/helper/core/unit sources before and after the run. Linux fixture/object/executable/report files passed guest-to-host digest barriers. The publication manifest binds copied evidence and records hashes/paths for omitted binaries. The source inventory identifies the pinned QBE C/header tree; QBE binaries were reused unchanged, not rebuilt by this campaign.

Initial preflight v1 used one-line function syntax rejected by pinned QBE. Its script/log and source are preserved and unqualified. Corrected multiline preflight v2 passed original QBE, default-PIE linking, actual retained-content execution, and no-R controls on all three Linux targets. Final candidate evidence uses separate directories.
