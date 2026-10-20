# Upstream fixture coverage checkpoint

Pinned QBE 1.3, Apple ARM64; measured after Apple ARM64 TLS support.
This is compatibility testing, not formal certification.

- 61 of 76 fixtures emit assembly.
- 46 executable fixtures pass their original drivers/output expectations with both Lean and QBE output.
- 15 underscore-prefixed development fixtures assemble with both backends; they are not counted as executable passes.
- 15 fixtures remain unsupported.

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
| `abi1.ssa` | Unsupported: line 5 near 'type': expected 'function' |
| `abi2.ssa` | Unsupported: line 1 near 'type': expected 'function' |
| `abi3.ssa` | Unsupported: line 1 near 'type': expected 'function' |
| `abi4.ssa` | Unsupported: line 3 near 'type': expected 'function' |
| `abi5.ssa` | Unsupported: line 3 near 'type': expected 'function' |
| `abi6.ssa` | Unsupported: line 5 near 'type': expected 'function' |
| `abi7.ssa` | Unsupported: line 4 near 'type': expected 'function' |
| `abi8.ssa` | Unsupported: line 4 near 'type': expected 'function' |
| `abi9.ssa` | Unsupported: line 1 near 'type': expected 'function' |
| `alias1.ssa` | passed |
| `align.ssa` | passed |
| `cmp1.ssa` | passed |
| `collatz.ssa` | passed |
| `conaddr.ssa` | passed |
| `copy.ssa` | passed |
| `cprime.ssa` | passed |
| `cup.ssa` | passed |
| `dark.ssa` | Unsupported: line 6 near 'type': expected 'function' |
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
| `mem1.ssa` | Unsupported: line 1 near 'type': expected 'function' |
| `mem2.ssa` | Unsupported: line 4 near 'type': expected 'function' |
| `mem3.ssa` | Unsupported: line 4 near 'type': expected 'function' |
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
