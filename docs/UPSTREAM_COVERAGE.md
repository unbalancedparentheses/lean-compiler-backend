# Upstream fixture coverage checkpoint

Pinned QBE 1.3, Apple ARM64; measured after Apple ARM64 aggregate ABI support.
This is compatibility testing, not formal certification.

2026-10-21 aggregate checkpoint: the all-fixture native scan passed at 71 emitted
fixtures, then the original abi1/abi4 drivers passed with both backends after the
unused-void-result normalization. The large-CFG extension additionally emits and assembles _bf99 and _bfmandel.
Combined results are below. The full native Nix suite passed for aggregate commit `3f805da` (73/76 emitted,
58 executable passes and 15 assembly-only fixtures); the large-CFG extension
passed the full native Nix suite with linkage checkpoint `ae832d4`, following
the SSA cycle-guard correction in `fdda0c7`. All 147 theorem audits pass. Ubuntu qualification builds/tests the compiler and models; it does
not imply a Linux assembly target.

- 75 of 76 fixtures emit assembly.
- 58 executable fixtures pass their original drivers/output expectations with both Lean and QBE output.
- 17 underscore-prefixed development fixtures assemble with both backends; they are not counted as executable passes.
- dark.ssa remains unsupported; it deliberately omits a required argument and is skipped upstream on Apple ARM64.

`scripts/upstream_suite.py` scans every fixture and runs every accepted executable
fixture on native Apple ARM64. Other hosts check emission and report native execution
as unmeasured. `tests/upstream-coverage.json` prevents supported-input regressions;
newly accepted fixtures are automatically exercised. Failures retain assembly and
drivers under `.build/upstream-failures/`, with results in `.build/upstream-suite.json`.

Run `LCB_CC=clang python3 scripts/upstream_suite.py --require-native` to repeat.
Use `--write-baseline` only after a passing run to extend the emission baseline.

## Fixture results

| Fixture | Measured result |
| --- | --- |
| `_alt.ssa` | assembled only |
| `_bf99.ssa` | assembled only |
| `_bfmandel.ssa` | assembled only |
| `_chacha20.ssa` | assembled only |
| `_dragon.ssa` | assembled only |
| `_fix1.ssa` | assembled only |
| `_fix2.ssa` | assembled only |
| `_fix3.ssa` | assembled only |
| `_fix4.ssa` | assembled only |
| `_gcm1.ssa` | assembled only |
| `_gcm2.ssa` | assembled only |
| `_live.ssa` | assembled only |
| `_load-elim.ssa` | assembled only |
| `_rpo.ssa` | assembled only |
| `_spill1.ssa` | assembled only |
| `_spill2.ssa` | assembled only |
| `_spill3.ssa` | assembled only |
| `abi1.ssa` | passed |
| `abi2.ssa` | passed |
| `abi3.ssa` | passed |
| `abi4.ssa` | passed |
| `abi5.ssa` | passed |
| `abi6.ssa` | passed |
| `abi7.ssa` | passed |
| `abi8.ssa` | passed |
| `abi9.ssa` | passed |
| `alias1.ssa` | passed |
| `align.ssa` | passed |
| `cmp1.ssa` | passed |
| `collatz.ssa` | passed |
| `conaddr.ssa` | passed |
| `copy.ssa` | passed |
| `cprime.ssa` | passed |
| `cup.ssa` | passed |
| `dark.ssa` | Unsupported: intentional argument-count mismatch; upstream skips Apple ARM64 |
| `double.ssa` | passed |
| `dynalloc.ssa` | passed |
| `echo.ssa` | passed |
| `env.ssa` | passed |
| `eucl.ssa` | passed |
| `euclc.ssa` | passed |
| `fixarg.ssa` | passed |
| `fold1.ssa` | passed |
| `fpcnv.ssa` | passed |
| `gvn1.ssa` | passed |
| `gvn2.ssa` | passed |
| `ifc.ssa` | passed |
| `isel1.ssa` | passed |
| `isel2.ssa` | passed |
| `isel3.ssa` | passed |
| `isel4.ssa` | passed |
| `isel5.ssa` | passed |
| `isel6.ssa` | passed |
| `ldbits.ssa` | passed |
| `ldhoist.ssa` | passed |
| `load1.ssa` | passed |
| `load2.ssa` | passed |
| `load3.ssa` | passed |
| `loop.ssa` | passed |
| `mandel.ssa` | passed |
| `max.ssa` | passed |
| `mem1.ssa` | passed |
| `mem2.ssa` | passed |
| `mem3.ssa` | passed |
| `philv.ssa` | passed |
| `prime.ssa` | passed |
| `puts10.ssa` | passed |
| `queen.ssa` | passed |
| `rega1.ssa` | passed |
| `spill1.ssa` | passed |
| `strcmp.ssa` | passed |
| `strspn.ssa` | passed |
| `sum.ssa` | passed |
| `tls.ssa` | passed |
| `vararg1.ssa` | passed |
| `vararg2.ssa` | passed |

## Linux ARM64 checkpoint

The `--target aarch64-linux` implementation emits 75/76 fixtures. An
ARM64 Ubuntu 24.04 container running on the local ARM64 Linux Docker VM assembled
and executed 58 original drivers with both Lean and pinned QBE (`arm64`) output;
17 development fixtures assembled with both. Only `dark.ssa` remains unsupported
because its call omits a required argument. Additional tests cover Linux
variadic GP/FP exhaustion and eight concurrent TLS threads through executable
and shared-library linkage. This is native ARM64 instruction
execution inside a Linux VM, not x86 emulation or a proof.

`scripts/linux_arm64.py` runs emission checks everywhere, native qualification
on ARM64 Linux, or against an explicitly supplied Docker container. The retained
`tests/upstream-linux-arm64-coverage.json` prevents emission regressions. Ubuntu x86 CI checks emission and models; it does not count as Linux ARM64
execution. The new `ubuntu-24.04-arm` CI job runs the native Linux matrix, including
TLS, variadics and ELF section/constructor tests; its first run passed at `407180d` on Ubuntu ARM64, Ubuntu x86-64 and macOS.
The runner label is documented in [GitHub runner selection](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job).

## Linux x86-64 checkpoint

`--target x86_64-linux` emits 75/76 fixtures. Both Lean and pinned QBE
`amd64_sysv` output passed 58 original executable drivers and assembled 17
additional development fixtures using cross-GCC and QEMU user emulation in the
ARM64 Linux container. This is emulated x86-64 execution, not native x86 testing.
Additional C/QBE matrices cover mixed scalar signatures, subwords, variadics,
floating arithmetic/comparisons and numeric conversions. Aggregate checks cover
22 layouts, guarded short tails, private copies, callbacks, padding/nested-field
classification and GP/FP allocation rollback. TLS tests cover eight C threads and
executable/shared-library linkage. Only the deliberately missing argument in
`dark.ssa` remains unsupported. `tests/upstream-x86_64-coverage.json` prevents
emission regressions; `scripts/linux_targets.py` executes natively on Linux x86-64
CI and reports emulated execution separately when using the development container.


## Linux RV64 checkpoint

`--target riscv64-linux` emits 75/76 fixtures, with 58 original executable
and 17 assembly-only passes against pinned QBE under QEMU user emulation.
Native RV64 execution has not been measured. Tests additionally cover the full
scalar/float/conversion matrix, 22 aggregate layouts, exact short tails with
negative overread controls, by-value isolation, callbacks, split GP/stack
arguments, exact FP bank capacity, aligned variadic pairs, and eight-thread
executable/shared-library TLS. The emission baseline is
`tests/upstream-riscv64-coverage.json`; CI checks RV64 emission on other ISAs.

Oracle differences are explicit: pinned QBE RV64 output needs non-PIE linking
for some global addresses; Lean output is linked as PIE. The QBE subword reference
adds explicit narrow extensions (Lean uses the original input). Pinned RV64
`argsclass` uses `>=` instead of `>` for available aggregate registers, causing
three exact-capacity C pressure checks to fail. Tests identify those specific
failures and check the remaining QBE cases separately; all original C pressure
checks remain mandatory for Lean. These are oracle limitations, not ignored
compiler failures. Native Linux x86-64 and ARM64 CI passed at `6823743`;
local cross-Clang also passed the full AMD64 matrices and TLS checks.

## Optional optimized pipeline

The same 75 accepted upstream fixtures pass with `--optimize`: 58 executable
drivers plus 17 assembly-only fixtures on native Apple ARM64 and Linux ARM64,
under QEMU for Linux x86-64 and RV64, and through Rosetta for macOS x86-64. Run `scripts/upstream_suite.py
--optimize --require-native`, `scripts/linux_arm64.py --optimize`, or
`scripts/linux_targets.py --optimize --target TARGET` to reproduce. Optimized
reports use separate paths from baseline reports. Each target also compares
baseline/folded output with 256 independent arithmetic cases. The Linux optimized
runs include their scalar, aggregate, variadic and threaded TLS qualification.
The seeded fuzzer accepts `--optimize` to compare both baseline and optimized
output against independent Python results and QBE across generated integer,
branch and cyclic-phi loop programs. Standard CI enables this additional path
and checks that deliberate optimized-code corruption is detected. These are test
results, not a preservation proof or a full optimization port.


## macOS x86-64

`python3 scripts/macos_x86.py --require-execution` qualifies `amd64_apple`:
75/76 fixtures emit, 58 executable drivers pass and 17 development fixtures
assemble. These results were obtained through Rosetta on Apple ARM64; they are
not native Intel qualification. `dark.ssa` remains rejected for its missing
required aggregate argument.

The runner also checks scalar/floating/subword/variadic C interoperation, 22
aggregate layouts with guarded tails, eight-thread executable/shared TLS, quoted
symbols, custom sections, common coalescing/alignment, DWARF line tables,
independent arithmetic/CFG cases and a 4096-function call chain. Known pinned
QBE narrow-extension, quoted-TLS and zero-allocation discrepancies remain explicit.
Use `--optimize` for a separately reported optimized run.

## Larger frontend qualification

The [cproc self-compilation reports](benchmarks/README.md#cproc-frontend-self-compilation)
add a separate workload beyond the 76 QBE fixtures. Our baseline and optimized
backends compile the entire 18-unit frontend on Linux ARM64, x86-64 and RV64;
each resulting frontend reproduces 19 stage-one IR files and passes 196 original
cproc tests. ARM64 execution is native in the Linux VM; x86-64 and RV64 execute
under QEMU. Original QBE successes and retained ARM64/RV64 external-GOT-offset
failures are distinguished from separately corrected comparison oracles.
