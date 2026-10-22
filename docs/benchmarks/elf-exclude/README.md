# Ordinary ELF excluded sections

Ordinary ELF function/data sections now admit `e` (SHF_EXCLUDE), including its combinations with the existing `a`, `w`, `x` and `R` flags. This supports metadata that should exist in an object but disappear at final linking. Assembly emission is unchanged; the new behavior is bounded flag admission. Custom TLS still requires `awT` with optional `R` and rejects `e`. Apple segment/section grammar is unchanged, including a literal section named `e`.

```text
section ".build_metadata" "e"
data $metadata = { l 73 }
export data $kept = { l 41 }
```

Actual-main source identity `803fc0258d24899011d3f26fdf23b3c3e4cd6f9721ee25722f7a4ad4c012c759` matches the isolated candidate. Fresh build, full units and all **164 exact proof-audit statements** pass unchanged from the preceding proof checkpoint. This flag admission has no new proof. The retained five-target/three-mode corpus produces **1,305 identical assemblies and 15 identical refusals**. The full missing-tool emission gate passes, including the new helper under its execution guard. Full host/Linux regression gates were not rerun for this small admission change; their earlier results retain their original identities. New CI is pending.

Six toolchain profiles pass: GNU and LLVM assembly on each of Linux ARM64, x86-64 and RV64, followed by GNU linking through the target GCC driver. LLVM cross-assembly runs on the host; target linking/execution runs in the Linux VM. ARM executes natively there; x86/RV use QEMU. This is not qualification of an LLVM linker. Both Apple targets additionally pass grammar and before/after emission checks; no Apple execution is claimed here.

Each Linux profile covers all sixteen subsets of `a/w/x/R` combined with `e`, one reordered spelling and duplicate `e`, plus an excluded function. LCB baseline/allocated/optimized and unchanged original QBE all pass:

- Exact custom-section names, types, flags and data sizes in 48 objects: 912 custom-section header checks across the six profiles.
- Unreferenced excluded sections disappear at final link, including sections also marked retained. Removing only `e` keeps every custom section.
- Independent C checks the ordinary data/function in both versions; referencing excluded data/function deliberately fails link, while the same references pass after removing `e`. There are 72 successful C-profile executions and 24 expected link refusals across all modes/oracles/toolchains.
- A missing-`e` mutation is detected by exact metadata checks; corrupting the ordinary live value is detected by C. TLS and unrelated flag negatives remain refused. Before/after ordinary and remove-`e` assembly remains byte-identical.

The original guest QBE binary is hash-bound before and after, and all 47 C/header files match the pinned upstream source. No corrected QBE oracle is substituted. Host/guest digest barriers protect inputs and generated objects. `main/qualification.json.gz` records actual commands, including the mixed LLVM-assembly/GNU-link profile; per-profile reports retain every outcome. `compressed-artifacts.json` maps losslessly compressed reports, and `omitted-binaries.json` retains object/executable hashes.

Early test-development failures are preserved separately. A short ELF-looking pair can already be valid Apple syntax, so negative fixtures now use a genuinely invalid Apple segment length. RV executable sections can gain assembler relaxation padding at eight-byte alignment; flag fixtures use byte alignment for executable data, while referenced ordinary metadata remains eight-byte aligned. These fixtures test section flags, not a new alignment guarantee. The final helper also accepts a `Path` C-compiler command from the emission-only gate. No compiler wrong-code failure was found in these attempts.

This closes one scoped compatibility gap. It does not establish full QBE parity, add native memory protections or measure performance.
