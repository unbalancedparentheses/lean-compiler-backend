# Session handoff — 2026-10-21

This is a continuation checkpoint, not a full QBE compatibility or verification
completion claim. QBE compatibility and useful, independently tested optimization
remain the priority; broader certification is deferred.

## Repository and current compiler

Work in `main` at `https://github.com/unbalancedparentheses/lean-compiler-backend`.
The latest compiler implementation checkpoint is `f52fa92`; its source/build
identity is `0f70bfb3f1e74bf5ca9cad3c1c32e241323dbc6d744e1950289c92dbe6e00d34`.
Subsequent checkpoints add larger-program qualification and accurate inventory.
All work is committed/pushed in coherent checkpoints; check Git for the latest
handoff/documentation commit rather than treating this file as its own head ID.

This window added:

- ARM64 direct assigned-home lowering for comparisons, scalar/FP operations,
  memory operands and scalar call results, with word normalization and legal
  address/result aliasing retained. Immediate arithmetic and shifted MOVZ/MOVN
  constant materialization remove more redundant instructions.
- Native data admission through 256 MiB and compact BSS for ordinary zero-only
  globals, while the interpreter keeps its 1 MiB initialization budget.
- QBE-style target aliases/options, stdin/stdout and multiple input modules,
  plus a real cproc-to-backend pipeline. The default remains `aarch64-macos`;
  explicit targets are required for other hosts. Windows/debug-driver options
  remain unsupported.
- Literal multiline data strings, with preserved UTF-8/control bytes and source
  locations. QBE reference strings use escaped line breaks because raw multiline
  assembler strings have platform-dependent handling.
- QBE itself and zlib/example/minigzip compiled for all three Linux targets.
  x86-64/RV64 executables run under explicitly labelled QEMU emulation.
- A reduced original-QBE AMD64 external-address/CMP/CMOV flag-clobber defect,
  independent C checks and an exact separately applied oracle-only correction.
  The vendored QBE snapshot remains unchanged.

## Validation and measurements

`LCB_CC=cc bash scripts/check.sh --require-native` completed successfully on the
final compiler, including the proof audit, native Apple ARM64 checks, Rosetta
macOS AMD64 suite and final optimized differential fuzz. Its retained log is
`.build/compact-constants-full-check.log`; the preceding memory-home full run
also passed (`.build/memory-homes-full-check.log`). Linux target execution is
separate from the nonnative emission checks within this host's full run.

- All five targets retain 75/76 upstream fixture admission. Target suites cover
  58 executable drivers and 17 assembly-only fixtures; `dark.ssa` intentionally
  omits a required argument. This is bounded coverage, not complete compatibility.
- Latest optimized Linux ARM64 target/ABI suite passed. Independent Linux scalar
  matrices are now wired into both baseline and optimized runs. The new AMD64
  conditional-address regression passed Linux/QEMU and macOS/Rosetta in all
  lowering modes, retaining the original QBE failure.
- The integer immediate/materialization matrix passes 10,192 independent cases
  across 1,274 functions per baseline/allocated/optimized mode, including wrong
  arithmetic/comparison immediates and a corrupted MOVN control.
- Full native integer/FP/conversion matrices pass 30,460 / 896 / 1,228 cases per
  baseline/allocated/optimized/QBE mode. Allocation controls include 24-value FP
  pressure, FP call results, signed narrow loads and address/result aliasing.
- Memory checks pass 4,209 native cases per baseline/optimized/corrected-QBE
  backend, 1,664 C-owned-buffer cases and 2,208 independent C cases. Original
  QBE overlap mismatches remain separate.
- Multiline data checks pass 39 objects/759 exact bytes in all three lowering
  modes on all five targets. The lexer preserved 750 fixture assemblies; compact
  constants preserved all 600 baseline/non-ARM fixture assemblies.
- An additional 32-seed campaign (20261109–20261140) passes 256 generated functions
  and 2,048 input cases across Python, interpretation, baseline/optimized native
  output and QBE. Log: `.build/final-32-seed-fuzz.log`.
- cJSON retains 153 assertions across 18 executables and matching checksums.
  Baseline alone needs a 64 MiB stack retry for deep recursion. Latest optimized
  library text is 47,136 bytes; see `cjson-compact-constants.json` for raw timings.
- QBE self-compilation has 32 C units/725 functions. Each passing executable
  reproduces 455 successful fixture assemblies across six QBE targets plus 32
  self-IR assemblies, matches one original rejection, and passes 58 original
  tests generating native ARM64 output. Original failures are retained separately.
  Latest ARM64 optimized text is 557,352 bytes; cross-target reports retain their
  own earlier compiler identities. Emitting Windows output with compiled QBE does
  not implement a Windows target in our backend.
- zlib compiles 17 unchanged C units/271 functions, including its test programs.
  Every qualified build passes the original static test recipe and 12 exact gzip
  streams/independent round trips. Native ARM64 and QEMU x86-64/RV64 qualify;
  original RV64 QBE link failure remains unqualified. Native optimized round trip
  is about 33 ms versus original QBE's 8 ms in the published run: optimization
  parity is still clearly incomplete. GCC and backend builds link the same set
  of library objects; source configuration and section-size caveats are recorded.
- Earlier cproc bootstrap reports remain valid historical evidence: 19 reproduced
  IR files and 196 original tests per qualified Linux target/backend. They were
  not rerun with the final constant-materialization compiler in this window.
- The published Csmith corpus qualifies 91/112 unique attempts, with
  905,656 IR lines including runtime helpers and twenty-one reference timeouts.
  The final batch uses seeds 20261101–20261132 on the final compiler; its 23
  passing programs match GCC O0/O2, both backend modes and original QBE. The
  repeated original batch is not counted as extra unique programs.

Reports and reproduction commands: [benchmarks/README.md](benchmarks/README.md).
Original/corrected oracle details: [UPSTREAM_DISCREPANCIES.md](UPSTREAM_DISCREPANCIES.md).
As of 18:47 UTC, all three CI jobs are green through `8b1b1ea`, including the final compiler and
cross-QBE regression wiring. Later benchmark/inventory/documentation runs may
still be queued; inspect their exact statuses rather than inferring a pass.

## Next work

1. Use the new zlib workload to guide broader memory/CFG optimizations, then
   caller-saved/FP allocation and splitting/coalescing. Small instruction-selection
   wins alone do not close the measured compression gap.
2. Close remaining compatibility gaps deliberately: Windows AMD64 ABI/emission,
   host-native default-driver behavior, remaining syntax/linkage/resource edges
   and target-specific ABI cases. Preserve the current explicit-target behavior
   and baseline evidence when changing the default CLI target.
3. Obtain native RV64 and Intel macOS qualification; local evidence for these
   remains QEMU/Rosetta. Linux x86-64 and ARM64 also have native CI coverage.
4. Keep the [roadmap](../ROADMAP.md) full-port-first ordering. Existing proofs
   cover restricted source/machine semantics, primitive selection and first-path
   helpers/body steps. Neither these optimizations nor the complete compatibility
   pipeline have an end-to-end preservation proof. Source/home checkers and
   execution tests do not establish machine-level semantic correctness.

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
