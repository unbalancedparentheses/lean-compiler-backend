# Session handoff — 2026-10-21

This is a continuation checkpoint, not a full QBE compatibility or verification
completion claim. The active priority is QBE compatibility and optimization,
with existing proof checks preserved and broader certification deferred.

## Repository state

Work in `main` at `https://github.com/unbalancedparentheses/lean-compiler-backend`.
The latest implementation checkpoint is `0ab1828`: direct ARM64 integer binary
operations on assigned GP homes. It was committed and pushed after targeted
qualification. Its compiler source/build identity is
`3b4bbe28ef512a2fce654c3462a1a00e0752c9c360eaf942630139f3a8313643`.

Recent preceding checkpoints include initialized scalar stack promotion and
trivial-phi cleanup, unreachable-predecessor pruning with raw-name validation,
Linux cproc bootstrap qualification, constant stack objects through 1 MiB
subject to frame limits, Csmith comparisons and optimized memory-oracle coverage.
All checkpoints through `0ab1828` passed CI on Linux x86-64, Linux ARM64 and
Apple ARM64. The additional full local native integration run also completed
successfully, including the proof audit and final optimized differential fuzz.

## Working evidence

- All five target configurations emit 75 of 76 retained original QBE fixtures.
  The excluded fixture omits a required aggregate argument. Passing this suite
  does not establish complete QBE compatibility.
- All five optimized target suites passed before the direct ARM64 change.
  The new change passed the full optimized Linux ARM64 target/ABI suite, native
  Apple ARM64 allocation checks and wide-count shift checks on Apple ARM64 and
  Linux ARM64/x86-64/RV64.
- The new compiler passed 3,200 additional generated-function input comparisons
  against Python, the Lean interpreter, native baseline/optimized output and QBE.
- Independent memory checks passed 4,209 native cases per baseline/optimized/
  corrected-QBE backend, 1,664 C-owned-memory cases and 2,208 independent C
  reference cases. The original QBE overlap discrepancy is retained separately.
- Across 115 upstream/cproc/cJSON modules, each of eight unaffected target/mode
  combinations admitted 114 modules and produced byte-identical assembly to
  the preceding compiler: baseline on all five targets, optimized on x86/RV.
  The total is 912 identical successful assemblies; rejection status also agreed.
- cJSON passes 153 assertions across 18 executables. Baseline alone still needs
  a 64 MiB stack retry for the deep-recursion test. Optimized output passes with
  the default stack. Current optimized library text is 63,500 bytes; same-run
  median runtime is 0.3453 s versus QBE's 0.2031 s. Concurrent test workloads
  limit timing conclusions; see the raw samples.
- cproc self-compilation on all three Linux targets reproduces 19 IR files
  byte-for-byte and passes 196 original tests with our baseline and optimized
  frontends. ARM64 was requalified with the latest compiler; optimized frontend
  text is 281,892 bytes. Original QBE passes x86; original ARM64/RV64 external-GOT
  offset failures remain separate from passing, explicitly corrected oracles.
- Forty-four of 48 unique Csmith programs qualify, totaling 425,809 IR lines.
  Four reference timeouts remain unqualified. The latest compiler reruns 14
  passing programs and the same two reference timeouts from the original batch;
  those are repeated evidence, not extra unique programs.

Reports and reproduction details are in [benchmarks/README.md](benchmarks/README.md).
Original/corrected QBE discrepancies are in
[UPSTREAM_DISCREPANCIES.md](UPSTREAM_DISCREPANCIES.md).

## Immediate continuation

1. The full local run at `.build/direct-alu-full-check.log` passed, and CI for
   `0ab1828` is green. The local reproduction command
   is `LCB_CC=cc bash scripts/check.sh --require-native`.
2. Preserve the current identity and benchmark reports when measuring another
   compiler change. Benchmark scripts accept `--compiler PATH`; use a snapshot
   rather than rebuilding the executable while a test uses it.
3. Continue measured instruction-selection improvements, then fuller allocation
   and memory optimization, while closing real frontend compatibility gaps.
   ARM64 immediate selection is a bounded next optimization; it is not started.
4. Follow [ROADMAP.md](../ROADMAP.md): missing Windows AMD64, syntax/linkage and
   resource-bound edges, caller-saved/FP allocation, splitting/coalescing,
   alias analysis and broader CFG/GVN work remain. Obtain native RV64 and Intel
   macOS evidence; local qualification currently uses QEMU/Rosetta for these.

## Assurance and environment

The new optimization, scalar promotion, allocation and complete compatibility
pipeline are not semantically proved. Existing Lean theorems concern restricted
source/machine semantics, opcode selection and first-path helpers/body steps;
execution tests and independent checkers do not close the composition proof.
Maintain this distinction in status reports.

The host is Apple ARM64, Lean 4.34.1. Linux tests use the `lcb-parity-linux`
Docker container with `.build/linux-arm64` mounted at `/work`; it has native
ARM64 GCC, x86/RV cross compilers, QEMU and Csmith. Shared-file hash barriers
prevent Docker Desktop stale/partial reads. Original QBE lives in the pinned
`third_party/qbe` tree; do not patch it to hide comparison failures.
Other user projects may be compiling concurrently; do not stop their processes.
