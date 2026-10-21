# Session handoff — 2026-10-21

This is a continuation checkpoint, not a full QBE compatibility or verification
completion claim. QBE compatibility and useful, independently tested optimization
remain the priority; broader certification is deferred.

## Repository and current compiler

Work in `main` at `https://github.com/unbalancedparentheses/lean-compiler-backend`.
The current compiler source/build identity is
`01fb509500e9265bd5d6f071241beba285bedb7da6fd42fd513b80d3e00a255d`.
Check Git for the exact latest implementation/documentation checkpoint. Work is
published in coherent tested commits; this document does not identify its own SHA.

## Changes in the latest window

- Integer identities and power-of-two multiplication become width-correct copies
  and shifts. Narrow entry-stack promotion handles initialized byte/halfword
  objects, explicit store truncation and load signedness.
- ARM64 stationary phi homes avoid staging. Acyclic register transfers are
  scheduled without overwriting pending inputs; cycles and stack/symbol moves
  retain simultaneous staging. Fall-through jumps are omitted.
- Existing allocation color groups are ranked by static read/write counts before
  assigning the callee-saved register bank. Bounded natural-loop weights now
  prefer loop accesses, saturate at three nesting levels and retain uniform
  weights above 512 blocks. Independent interference/home-flow
  checks run on the final assignment. This substantially reduced zlib spilling.
- ARM64 logical immediates handle repeated rotated masks, with independent
  exhaustive encoding and native execution checks.
- Repeated addresses of module-defined, non-TLS data can share an entry
  definition. External/TLS resolution stays in place, and memory contents are
  never cached. Calls may mutate referenced globals normally.
- Compatibility CLI default target now follows the compiler host on all five
  implemented configurations. First-path output remains Apple ARM64. Old
  architecture-specific refusal tests now request their intended target explicitly.
- Previous large-data/BSS, multiline-string, multi-module CLI and independent
  original-QBE discrepancy regressions remain in place.

These optional compatibility optimizations have execution evidence, not new
preservation proofs. No Windows target or end-to-end certification was added.

## Validation and larger workloads

All five targets retain 75/76 upstream fixture admission: 58 executable drivers
and 17 assembly-only fixtures. `dark.ssa` intentionally omits a required argument.
Linux ARM64 runs natively; local Linux x86/RV and macOS x86 runs use QEMU/Rosetta.
Linux x86 and ARM also have native CI. This is bounded coverage, not a parity percentage.

Latest target suites pass with common-address checks: 8,192 independent cases
per lowering mode, including calls that mutate globals, narrowing/phi uses,
loops and name collisions. The ARM64 wrong-address control must fail. Full
integer/FP/conversion matrices retain 30,460 / 896 / 1,228 cases per lowering mode.
The immediate matrix now covers 3,106 functions / 24,848 cases per mode. The
logical-encoding unit oracle checks 190,980 cases, including all 1,302 word and
5,334 long encodings. Phi tests cover 79 permutations / 5,372 cases per mode;
narrow-promotion tests cover 16,896 loop cases plus 1,024 scalar cases.

The full gate passed after allocation ranking and host-native CLI changes
(`.build/ranked-full-check.log`, `.build/host-default-full-check.log`). The common-address full run passed
(`.build/symbol-hoist-full-check.log`). The loop-weight full run is ongoing in
`.build/loop-priority-full-check.log`; verify completion before claiming a pass.
All five optimized target suites and fresh differential fuzz seeds
20261301–20261332 pass: 256 functions / 2,048 independent input cases.
Existing proof audits remain unchanged in scope.

Latest published reports in `docs/benchmarks`:

- Loop-weight reports `zlib-loop-priority.json`, `cjson-loop-priority.json` and
  `qbe-loop-priority.json` retain every qualified test below on the current
  compiler. zlib text grows slightly to 147,430 bytes; median round trip is
  9.37 ms versus original QBE 7.88 ms. cJSON text is 37,916 bytes, runtime
  0.2104 s versus QBE 0.1686 s. Compiled QBE text is 425,188 bytes, self-IR
  runtime 0.1856 s versus corrected QBE 0.1612 s. These local samples show a
  speed/size tradeoff, not controlled cross-workload performance parity.

The preceding identity-bound reports retain their own measurements:

- `zlib-symbol-hoist.json`: 17 unchanged C units / 271 functions, original static
  tests and 12 byte-exact gzip streams plus independent decompression/round trips.
  Native optimized text is 145,190 bytes. Same-run round-trip medians: optimized
  10.27 ms, original QBE 8.01 ms, corrected QBE 8.15 ms, baseline 68.92 ms and
  GCC 3.91 ms. Earlier text was 206,102 bytes / about 32 ms in the algebra report;
  cross-run timings are not controlled speedup claims. Optimization parity remains
  incomplete. `zlib-ranked-x86.json` and `zlib-ranked-rv.json` retain successful
  QEMU qualification and the original RV64 QBE link failure separately.
- `qbe-symbol-hoist.json`: 32 unchanged C units / 725 functions. Qualified builds
  reproduce 455 fixture assemblies across six QBE targets and 32 self-IR assemblies,
  one matching rejection, and 58 original tests generating native ARM64 output.
  Optimized text 420,484 bytes; median self-IR compile 0.1934 s versus corrected-QBE
  0.1672 s and GCC reference 0.0996 s. Original ARM64 QBE's parser failure remains
  unqualified. Compiled QBE emitting Windows assembly does not add Windows to LCB.
- `cjson-symbol-hoist.json`: 153 assertions across 18 executables, matching
  checksums; baseline alone needs a 64 MiB deep-recursion stack retry. Optimized
  library text 37,876 bytes; median 0.2267 s versus QBE 0.1798 s and GCC 0.1462 s.
- `cproc-symbol-hoist.json`: 18 C units, 19 exact IR reproductions, 196 original
  tests per qualified backend on the current identity. Original QBE-built cproc
  crashes on `attr`; that failure remains separate from the corrected oracle.
- `csmith-symbol-hoist.json` adds 26/32 qualified programs and 312,293 IR lines:
  aggregate 141/176 unique attempts, 1,422,785 qualified IR lines including runtime
  helpers, 35 reference timeouts across seven disjoint batches.
  Generator restrictions exclude pointers, packed structs, bitfields and volatile
  accesses because of cproc frontend limits; this is not unrestricted whole-C coverage.

Reports retain their exact compiler/source/configuration hashes. Original QBE
and separately corrected oracle copies remain distinct; vendored QBE is unchanged.
See [benchmarks/README.md](benchmarks/README.md) and
[UPSTREAM_DISCREPANCIES.md](UPSTREAM_DISCREPANCIES.md).

CI was all green through `c559be5`. `a721ee7` exposed three old Apple-specific
refusal controls under the new Linux default; `72389df` fixes their targets and
all three CI jobs pass. Both native Linux jobs also pass the logical-immediate
checkpoint; its macOS job and common-address CI remain in progress at 22:25 UTC.

## Next work

1. Use measured workloads to guide broader memory/CFG transformations and
   allocation improvements: caller-saved/FP banks,
   live-range splitting/coalescing. Current bounded loop-weight ranking remains a heuristic.
2. Close Windows AMD64 ABI/emission and remaining syntax/linkage/resource/ABI
   boundary cases. Host-native default-driver behavior is now implemented.
3. Obtain native RV64 and Intel macOS qualification; local evidence is emulated.
4. Keep the [roadmap](../ROADMAP.md) full-port-first ordering. Existing proofs cover
   restricted source/machine semantics, primitive ALU selection and first-path
   helpers/body steps. The new optimization passes, actual machine instruction
   effects, ABI and complete compatibility pipeline lack an end-to-end proof.
   Source/home checkers and execution tests do not establish that proof.

## Environment and continuation safety

The host is Apple ARM64, Lean 4.34.1. Linux tests use `lcb-parity-linux` with
`.build/linux-arm64` mounted at `/work`; it has native ARM64 GCC, x86/RV cross
compilers, QEMU and Csmith. Keep shared-file hash barriers for host-authored
source/assembly and guest-produced IR to avoid stale Docker Desktop reads.

Benchmark/target scripts snapshot the compiler. Do not rebuild while an older
nonsnapshot integration script uses `.lake/build/bin/lcb`, and do not edit tests
partway through a full run. Do not concurrently configure/build the same cproc
working directory. zlib's target directories are isolated; its configure-generated
Makefile/zconf.h live in a copy of the pristine pinned source. QBE's original
runner uses fixed temporary names: run its bootstrap target jobs sequentially.
Other user projects may compile concurrently; do not stop their processes.
