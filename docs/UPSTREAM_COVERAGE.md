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
TLS, variadics and ELF section/constructor tests; its first run is pending.
The runner label is documented in [GitHub runner selection](https://docs.github.com/en/actions/how-tos/write-workflows/choose-where-workflows-run/choose-the-runner-for-a-job).
