# Upstream fixture coverage checkpoint

Pinned QBE 1.3, Apple ARM64; measured after Apple ARM64 aggregate ABI support.
This is compatibility testing, not formal certification.

2026-10-21 aggregate checkpoint: the all-fixture native scan passed at 71 emitted
fixtures, then the original abi1/abi4 drivers passed with both backends after the
unused-void-result normalization. Combined results are below. The full native Nix
suite is being rerun for this checkpoint; aggregate tests and 147 theorem audits
already pass. Ubuntu qualification builds/tests the compiler and models; it does
not imply a Linux assembly target.

- 73 of 76 fixtures emit assembly.
- 58 executable fixtures pass their original drivers/output expectations with both Lean and QBE output.
- 15 underscore-prefixed development fixtures assemble with both backends; they are not counted as executable passes.
- 3 fixtures remain unsupported: the two large CFG development inputs and dark.ssa.
  dark.ssa deliberately omits a required argument and is skipped upstream on Apple ARM64.

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
| `_bf99.ssa` | Unsupported: line 435 near '@.L64': block parsing limit exceeded |
| `_bfmandel.ssa` | Unsupported: line 289 near '@.L65': block parsing limit exceeded |
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
