# Session handoff — 2026-10-21

This is a continuation checkpoint, not a full QBE compatibility or verification
completion claim. QBE compatibility and useful, independently tested optimization
remain the priority; broader certification is deferred.

## Repository and current compiler

Work in `main` at `https://github.com/unbalancedparentheses/lean-compiler-backend`.
The current compiler source/build identity is
`475c428a6d6764abb797d7c706de170c69e550a58c215fd88c35918d88743e3b`.
Implementation checkpoint: `b5886af` (ARM64 adjacent memory offsets); `a589085`
introduced same-block memory forwarding; `6d3a7a4` adds current-identity Csmith/cproc
evidence. `1331a81` synchronizes the generated port inventory source after CI
caught drift in the documentation-only table update. Check Git for the latest documentation checkpoint. Work is
published in coherent tested commits; this document does not identify its own SHA.

## Final integer comparison branches

Allocated ARM64 emits a conditional branch directly from a final integer
comparison when its boolean result has exactly one whole-function use in that
terminator. Shared/phi uses, earlier comparisons and floating comparisons retain
materialized booleans. Independent review found no concrete defect. The C matrix
passes 176,400 cases per mode on Apple ARM64 and catches an inverted branch;
32 fresh fuzz seeds 20261429–20261460 pass, 256 functions / 3,328 inputs.
Zlib's original tests and 12 exact streams pass; linked text is 137,638 bytes,
4,764 below the earlier adjacent-address checkpoint. QBE bootstrap retains all
qualified fixture/self-IR reproductions and original runtime cases; object text
is 369,064 bytes (12,052 below the adjacent-address checkpoint), linked text
397,956 bytes. Identity-bound `zlib-branch-selection.json`,
`qbe-branch-selection.json` and `csmith-branch-selection.json` preserve results.
Csmith seeds 20261293–20261324 qualify 27/32, 225,632 IR lines, with five
reference timeouts excluded. Eleven disjoint default-profile batches total
246/304 attempts, 2,273,638 qualified IR lines and 58 reference timeouts. No proof
coverage is enlarged. The full local regression gate passed in `.build/branch-selection-full-check.log`.
The optimized target suites passed; corrected mode coverage is recorded below.

The target runners' global optimization flag was found to override individual
helper mode requests. Earlier optimized target invocations therefore did not
independently distinguish helper baseline/allocated modes; standalone/default
runs were unaffected. The runner correction preserves each matrix's explicit
mode while retaining optimized upstream fixtures and single-mode ABI helpers.
Actual compiler commands are counted by mode and each target suite requires
nonzero baseline, allocated and optimized counts. Guard-page copy tests add
27 sizes and 162 start/end boundary cases per mode; deliberately widening a
one-byte tail read faults as required. They passed native Apple/Linux ARM64,
Linux x86/RV QEMU and macOS x86 Rosetta with explicitly distinct mode flags.

## Active window: conservative memory forwarding

The optional optimizer now reuses exact loads and matching just-stored values
within a single SSA block. All stores invalidate previous facts, and calls,
variadic state, blits and allocations clear both load and store facts. No pointer
disjointness, cross-block memory facts or dead-store elimination is assumed.
The new C oracle passes 95,232 cases per mode across all five targets and detects
a deleted store. Lean units pass, as do 32 fresh fuzz seeds 20261365–20261396
(256 functions / 3,328 inputs). Full local gate completed successfully in `.build/memory-forward-full-check.log`.
The inventory gate additionally passes after synchronizing its source manifest. Independent review found
no concrete bug and requested additional stored-fact/variadic barrier coverage.

New identity-bound reports: `zlib-memory-forward.json`, `qbe-memory-forward.json`,
`cproc-memory-forward.json`, `cjson-memory-forward.json` and
`csmith-memory-forward.json`. Zlib retains upstream tests and 12 exact gzip streams;
QBE retains all qualified assembly reproductions and 58 original runtime tests;
cproc reproduces 19 stage-two IR files and passes 196/196 tests; cJSON retains 153
assertions and only the baseline deep-stack retry. QBE object text falls 5,752
bytes to 390,092; zlib linked text falls 696 bytes to 146,734. Timings remain local
measurements under concurrent test load, not controlled speedup claims.
Csmith seeds 20261229–20261260 qualify 29/32, 220,985 IR lines; three reference
timeouts remain unqualified. Nine disjoint scalar-profile batches total 195/240
attempts, 1,854,065 qualified IR lines and 45 reference timeouts. The restricted
pointer profile remains separate. Previous reports below retain older identities.

ARM64 adjacent constant-offset load/store selection is now committed in `b5886af`;
`df1f34d` adds current-identity Csmith evidence. The full local gate passed in
`.build/address-selection-full-check.log`, and 32 seeds 20261397–20261428 passed
(256 functions / 3,328 inputs). `zlib-address-selection.json` retains all original
checks with linked text 142,402 bytes; `qbe-address-selection.json` retains all
qualified checks with object text 381,116 and linked text 410,012 bytes. The latest
Csmith batch qualifies 24/32, 193,941 IR lines; eight reference timeouts are excluded.
Ten disjoint scalar batches total 219/272 attempts, 2,048,006 qualified IR lines
and 53 reference timeouts. Pointer-profile results remain separate.
Independent review found no codegen defect and requested more address-selection
pressure/FP-store/phi-use tests; those are being added before the next implementation.
Constant blits now accept 0..1 MiB (previously 4096), with compact eight-byte
copy loops above 128 bytes on ARM64, AMD64 and RV64. Zero-sized RV64 copies
also avoid resolving unused symbols. The independent matrix covers 22 sizes,
264 aligned/unaligned, disjoint/identical full-byte cases per mode, repeated loops,
retained pointer values and unresolved zero-copy symbols. Original QBE's routine
matrix stops at 65537 bytes; the separate native comparison includes all 1 MiB
cases with unchanged QBE. RV64 original QBE needs an explicitly logged non-PIE
link retry; LCB remains tested with the default link configuration.
The full local gate passed before the aligned-pair coverage correction; the final
matrix passed natively and on all five target suites. Independent emitter review
found no correctness defect. Aggregate-call and interpreter memory limits are
unchanged, and these loops are not formally proved.

Identity-bound reports `large-blit-compact.json`, `large-struct-8193.json` and
`large-struct-65537-refusal.json` preserve the exact qualification boundaries.
The complete direct-copy matrix produces 15,082 optimized assembly bytes versus
56,693,708 from original QBE's expansion; this deliberately large-copy workload
is a code-size observation, not a general performance claim.

The generated 8193-byte C structure assignment workload passes both GCC levels,
original QBE and all three LCB modes with checksum `154a4b0ba4aa02e0`. Pinned
cproc expands these assignments into scalar loads/stores, so this is separate
from direct blit qualification. At 65537 bytes, its 98,622-line IR exceeds our
500000-token parser limit: all LCB modes are explicitly unqualified, while
GCC O0/O2 and original QBE pass with checksum `b424c67700bbdde0`. This is a
concrete remaining resource/compatibility gap, not a backend pass. Raising the
token cap alone is insufficient: the two functions contain 65,607 and 32,934
instructions, also exceeding the parser/SSA/validator 16,384-instruction bounds.
Supporting that unchanged lowering requires a separate large-function effort.
No Windows implementation or new proof was added.

## Changes in the preceding window

- Integer identities and power-of-two multiplication become width-correct copies
  and shifts. Narrow entry-stack promotion handles initialized byte/halfword
  objects, explicit store truncation and load signedness.
- Unsigned division/remainder by a nonzero power of two becomes a logical
  shift/mask; normalized-zero divisors and signed operations retain their handling.
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
(`.build/symbol-hoist-full-check.log`). The loop-weight full run also passes
(`.build/loop-priority-full-check.log`). Current unsigned-strength full validation
completed successfully in `.build/unsigned-final-full-check.log`, including the
proof audit, native Apple ARM64 and Rosetta suites and final differential fuzz. All five target suites pass, including 216 unsigned division/
remainder functions and 2,592 independent cases per mode. Fresh differential
fuzz seeds 20261333–20261364 pass: 256 functions / 2,048 input cases. The earlier
`.build/unsigned-strength-full-check.log` was stopped during a size investigation
and is not a completed gate. The rebuilt final executable is byte-identical
to the independently qualified all-target/32-seed candidate (SHA-256
`5723d0ed232061cab4155dcaa120c1c729efb7f72a21b02404033236692fd7f4`).
Existing proof audits remain unchanged in scope.

Latest published reports in `docs/benchmarks`:

- `zlib-unsigned-strength.json` and `qbe-unsigned-strength.json` qualify their preceding
  identity with all original tests and exact stream/assembly reproductions.
  zlib text remains 147,430 bytes. QBE input-object text falls 448 bytes to 395,844;
  default-linked text is 432,940 because the default Cortex-A53 erratum workaround
  adds more layout-dependent overhead. `qbe-link-size-diagnostic.json` isolates
  that effect with hash-bound objects and diagnostic relinks. Production flags
  remain unchanged; disabling the workaround is not a qualification or recommendation.

- Loop-weight reports `zlib-loop-priority.json`, `cjson-loop-priority.json` and
  `qbe-loop-priority.json` retain every qualified test below on that
  loop-weight compiler. zlib text grows slightly to 147,430 bytes; median round trip is
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
  tests per qualified backend on the address-sharing identity. Original QBE-built cproc
  crashes on `attr`; that failure remains separate from the corrected oracle.
- `csmith-unsigned-strength.json` adds 25/32 qualified programs and 210,295 IR lines
  on the current compiler: aggregate 166/208 unique attempts, 1,633,080 qualified
  IR lines including runtime helpers, 42 reference timeouts across eight disjoint
  default-profile batches. Generator restrictions exclude pointers, packed structs,
  bitfields and volatile accesses because of frontend limits; this is not
  unrestricted whole-C coverage.

The separate `csmith-pointers.json` profile enables one-level pointers without
const qualifiers: 8/32 attempts qualify, with 49,596 IR lines. Twenty-one known
frontend pointer-type rejections and three reference timeouts remain unqualified;
these are separate from the default-profile corpus and not backend pass claims.

Reports retain their exact compiler/source/configuration hashes. Original QBE
and separately corrected oracle copies remain distinct; vendored QBE is unchanged.
See [benchmarks/README.md](benchmarks/README.md) and
[UPSTREAM_DISCREPANCIES.md](UPSTREAM_DISCREPANCIES.md).

CI is fully green through `9aec75e`, including both native Linux targets and
macOS. Final compiler `a66cde8` (run `39689969001`) has Linux x86-64 green; Linux
ARM64 and macOS are still running as of 23:05 UTC. Later benchmark/documentation
commits have the same compiler identity and their own pending CI runs. Inspect
exact run statuses rather than inferring their completion. The earlier host-
default failure at `a721ee7` was fixed by `72389df`; no known failure remains open.

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
