# LZ4 1.10.0 library and upstream drivers

The unmodified upstream source commit `ebb370ca83af193212df4dcbadcc5d87bc0de2f0`
passes native Linux ARM64 and QEMU Linux x86-64/RV64 qualification with compiler identity
`de27b459436dbfc15e827f17fbfa30948b2192b598035c40ac5debd2952f33f9`.
All four library units (`lz4`, `lz4hc`, `lz4frame`, `xxhash`) and original `fuzzer`
and `frametest` drivers use the same target-specific cproc IR: 370 functions and
64,135 IR lines per ARM/x86 target; RV frontend output has 364 functions and
63,137 IR lines. All three LCB modes, GCC O0/O2, unchanged original QBE and the
separately corrected QBE pass this profile. This does not erase original-QBE
failures on other workloads.

Each backend runs:

- Both original drivers at seeds 1 and 20261022, 100 randomized cycles each.
  Frame tests also execute their built-in basic tests on each run.
- Fuzzer built-in unit tests at compression levels 9 and 10, followed by one
  automatically seeded cycle. The printed automatic seed is retained. Explicit
  `-s` skips these unit tests, so they run separately without that option.
- Fifteen deterministic compression profiles: empty, one-byte, repetitive,
  byte-pattern and seeded random inputs through standard block, HC block and frame
  compression. Compressed bytes match GCC O0 exactly, and candidate/GCC decoders
  cross-decompress them to the original input. GCC O2 agrees as well.

A small GCC-built caller drives the compression API; the libraries and two
upstream drivers themselves are compiled by each selected backend. Driver tests
require their success markers as well as exit zero. Output that includes timing
progress or addresses is retained but is not compared byte-for-byte. An intentional
mutation of the compiled library’s `LZ4_versionNumber` return is detected with
exit 99. Source/IR/compiler/oracle/executable hashes are bound and checked, and
Docker artifact digests synchronize before records are read.

This is a bounded upstream test profile and finite differential qualification,
not the full upstream suite, a proof, or a runtime-speed claim. No original C/header
or frontend IR is patched. Four standard integer-limit defines supply cproc’s
system-header configuration; exact commands and flags appear in the report.
Initial development runs before the final checks were added are excluded.

The ARM/x86 runs used a frozen copy of `scripts/lz4_compare.py` from commit
`ec42f2f`. The later timeout-only harness change is described below. Reproduction chooses a fresh Docker-mounted output directory:

```sh
PYTHONPATH="$PWD/scripts" LCB_CC=cc python3 scripts/lz4_compare.py \
  --compiler .build/lcb-arm-branch-layout \
  --work .build/linux-arm64/lz4-qualified-arm-new \
  --report .build/lz4-arm-new.json
```

The host benchmark runner compiles target assembly; Linux ARM runs natively in
the VM and Linux x86 uses QEMU user emulation. The RV run exceeded the original
600-second whole-probe timeout. Its guest eventually completed every backend,
but the runner failed before final provenance checks, so that attempt remains
**unqualified** in `riscv64-timeout-unqualified.json`. The whole-probe budget is
now 3,600 seconds; per-driver limits stay 240 seconds. The fresh RV run now passes all seven backends and final provenance checks,
recorded in `riscv64-linux.json`. Only the original RV QBE executables use
non-PIE linking; LCB uses the default link mode.
This is a harness-timeout adjustment, not a relaxed executable oracle.
