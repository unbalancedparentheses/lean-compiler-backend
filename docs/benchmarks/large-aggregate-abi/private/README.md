# Bounded aggregate ABI copies

This package contains private qualification evidence and integration patches. Main was not modified. No performance claim is made.

## Integration

Apply these patches, then regenerate the actual-main build identity and rebuild:

1. `final/numeric-copy-core.patch`: compact exact-copy loops in the three emitters, leaving copies of at most 128 bytes unchanged.
2. `final/cap-only.patch`: raise the three aggregate ABI size limits from 4,096 bytes to 1 MiB. Existing layout, frame, and outgoing-area bounds remain.
3. `final/final-tests.patch`: reusable independent C regression helper.
4. `final/final-hooks.patch`: native check and all target-runner hooks.

Do not use the superseded named-label patch or earlier helper patches. The final loops use self-contained numeric local labels. Quoted numeric and formerly colliding named globals are executable regression cases.

## Qualified private stages

| Stage | Compiler source identity | Evidence |
|---|---|---|
| Before | `f159cc758be1a944534240d32728bb47d7f8e7f6abe77b0e2d1fd9446106b8f6` | Original 4,097-byte refusal; small-copy comparison baseline |
| Copy only, limit still 4,096 | `44f1e3ae9f87c9bda640b49b7c4da90f05422a7c1b25d8fc49a82c905d7d79fc` | Fresh units, five-target C/QBE matrix; 15 small-copy assembly comparisons identical |
| Copy plus bounded cap | `69c2f3b37185628b32e4fa7b25c16a924fce22bd94410fb4c2d44a1e0b3c090a` | Fresh units and final v3 qualification below |

These builds precede main's unused-return-elimination integration. A combined actual-main build needs its own identity and qualification.

## Final v3 result

All five targets passed baseline, allocated, and optimized LCB modes plus unchanged original QBE for 22 sizes from 127 through 65,537 bytes. Cases cover every loop-tail residue, caller-byte preservation, aliased by-value inputs, hidden returns, incoming and outgoing variadics, environment arguments, and eight raw-bit FP plus six GP arguments both before and after aggregates. Guard pages bound both source reads and destination writes. Wrong-copy mutations failed as expected on every target.

Separate maximum-size cases passed 30 executions: two sizes (1 MiB minus one and exactly 1 MiB), three modes, five targets. The helper also checked 45 mode-specific refusals for one-past layout, excessive private frame, and excessive outgoing area. All five emission-only tests used missing C/QBE tools and rejected any attempted external execution. The native default CLI passed separately.

Original-QBE qualification stops at 65,537 bytes. Maximum-size cases use independent C and ABI thunks, not an original-QBE comparison. RV reference-only `-no-pie` retries and preceding default-link failures are retained in command logs. QBE binaries were reused unchanged; their hashes are in the reports. The pinned source inventory is included, but this campaign did not rebuild those reference binaries. Partial-overlap copies have no memmove claim; disjoint and identical addresses are tested.

## Provenance and retained failures

`package-manifest.json` binds the packaged bytes. `file-origins.json` maps copied artifacts to their original paths. The original final-v3 manifest binds 345 files, including private compiler binaries and generated assemblies omitted here for size; their hashes and original paths remain auditable. Sources, C callers, ABI thunks, commands, reports, core source files, helper, hooks, and patches are included.

The earlier 244-artifact campaign's exact helper was recovered from its retained patch and checked against the original manifest hash. Its old live helper path subsequently changed: that live-path binding is superseded, not claimed current. Exact helper bytes and original manifests are retained under `superseded/`.

V1 failed report serialization because a fixture shadowed a thunk path with text. V2 was superseded by the final stress expansion; neither is final qualification evidence. Their diagnostics and reconstructed helper versions remain explicitly labeled. V3 ran fresh, with frozen helper/runner copies and matching post-run hashes.

## Prepared actual-main runner — not launched

After integration, provide a new compiler snapshot and its exact identity:

```sh
python3 /tmp/lcb-large-aggregate/publication/run_actual_main.py \
  --repo /Users/unbalancedparen/projects/lean-compiler-backend \
  --compiler /absolute/path/to/new-lcb-snapshot \
  --identity NEW_COMPILER_IDENTITY \
  --qbe-host /absolute/path/to/unchanged-host-qbe \
  --output /Users/unbalancedparen/projects/lean-compiler-backend/.build/linux-arm64/aggregate-main-FRESH
```

The output directory must be new and below the Docker-mounted base. The runner snapshots the compiler, current-main helper and dependencies, verifies the identity, executes all five target matrices, checks final snapshot and original source/helper/core/hook bindings, performs a bounded host/guest artifact hash barrier, and records failures without rebuilding anything. No run has been started from this prepared runner.

## Assembly-source size example

The unchanged 4,096-byte mixed-ABI fixture contains 11 functions. The table shows optimized emission before versus the copy-only candidate (both retain the old ABI cap). These are assembly-source lines and UTF-8 bytes, not object code size or runtime. The full report includes all 15 target/mode comparisons.

| Target | Lines before → after | Text bytes before → after |
|---|---:|---:|
| aarch64-macos | 13,927 → 732 | 313,474 → 12,836 |
| x86_64-macos | 14,256 → 1,035 | 319,415 → 18,335 |
| aarch64-linux | 14,079 → 884 | 316,056 → 15,418 |
| x86_64-linux | 14,278 → 1,057 | 320,089 → 19,009 |
| riscv64-linux | 27,596 → 1,115 | 409,515 → 15,745 |
