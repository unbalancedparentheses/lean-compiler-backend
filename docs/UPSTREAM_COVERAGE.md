# Upstream fixture coverage checkpoint

Pinned QBE 1.3, Apple ARM64; measured after the indirect-call implementation.
This is compatibility testing, not formal certification.

- 35 of 76 fixtures emit assembly.
- 27 executable fixtures pass their original drivers/output expectations with both Lean and QBE output.
- 8 underscore-prefixed development fixtures assemble with both backends; they are not counted as executable passes.
- 41 fixtures remain unsupported.

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
| `_chacha20.ssa` | Unsupported: function $chacha20_rounds_qbe: duplicate SSA definition or duplicate parameter %in |
| `_dragon.ssa` | assembled only |
| `_fix1.ssa` | Unsupported: function $test: duplicate SSA definition or duplicate parameter %x |
| `_fix2.ssa` | Unsupported: function $test: duplicate SSA definition or duplicate parameter %x |
| `_fix3.ssa` | Unsupported: function $test: duplicate SSA definition or duplicate parameter %s |
| `_fix4.ssa` | Unsupported: function $test: duplicate SSA definition or duplicate parameter %x |
| `_gcm1.ssa` | Unsupported: function $ifmv: duplicate SSA definition or duplicate parameter %r |
| `_gcm2.ssa` | Unsupported: function $gcm_test2: duplicate SSA definition or duplicate parameter %f |
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
| `cmp1.ssa` | Unsupported: function $test: duplicate SSA definition or duplicate parameter %cmp |
| `collatz.ssa` | Unsupported: stack frame exceeds initial AArch64 immediate limit |
| `conaddr.ssa` | passed |
| `copy.ssa` | passed |
| `cprime.ssa` | passed |
| `cup.ssa` | passed |
| `dark.ssa` | Unsupported: line 6 near 'type': expected 'function' |
| `double.ssa` | Unsupported: line 4 near 'd': unsupported type: expected w (32-bit) or l (64-bit) |
| `dynalloc.ssa` | Unsupported: function $f: stack allocation outside the entry block is not yet supported |
| `echo.ssa` | Unsupported: line 23 near '...': unsupported type: expected w (32-bit) or l (64-bit) |
| `env.ssa` | Unsupported: line 3 near 'env': unsupported type: expected w (32-bit) or l (64-bit) |
| `eucl.ssa` | passed |
| `euclc.ssa` | passed |
| `fixarg.ssa` | passed |
| `fold1.ssa` | passed |
| `fpcnv.ssa` | Unsupported: line 4 near 's': unsupported type: expected w (32-bit) or l (64-bit) |
| `gvn1.ssa` | Unsupported: function $test: duplicate SSA definition or duplicate parameter %t2 |
| `gvn2.ssa` | Unsupported: function $test: duplicate SSA definition or duplicate parameter %rc |
| `ifc.ssa` | Unsupported: line 46 near 's': unsupported type: expected w (32-bit) or l (64-bit) |
| `isel1.ssa` | passed |
| `isel2.ssa` | Unsupported: line 4 near 'd': unsupported type: expected w (32-bit) or l (64-bit) |
| `isel3.ssa` | passed |
| `isel4.ssa` | passed |
| `isel5.ssa` | Unsupported: line 7 near 'd': unsupported type: expected w (32-bit) or l (64-bit) |
| `isel6.ssa` | passed |
| `ldbits.ssa` | passed |
| `ldhoist.ssa` | Unsupported: function $f: duplicate SSA definition or duplicate parameter %n |
| `load1.ssa` | passed |
| `load2.ssa` | Unsupported: function $f: duplicate SSA definition or duplicate parameter %n |
| `load3.ssa` | passed |
| `loop.ssa` | passed |
| `mandel.ssa` | Unsupported: line 4 near 'd': unsupported type: expected w (32-bit) or l (64-bit) |
| `max.ssa` | passed |
| `mem1.ssa` | Unsupported: line 1 near 'type': expected 'function' |
| `mem2.ssa` | Unsupported: line 4 near 'type': expected 'function' |
| `mem3.ssa` | Unsupported: line 4 near 'type': expected 'function' |
| `philv.ssa` | passed |
| `prime.ssa` | passed |
| `puts10.ssa` | passed |
| `queen.ssa` | passed |
| `rega1.ssa` | passed |
| `spill1.ssa` | Unsupported: function $f: duplicate SSA definition or duplicate parameter %a |
| `strcmp.ssa` | passed |
| `strspn.ssa` | passed |
| `sum.ssa` | passed |
| `tls.ssa` | Unsupported: line 2 near 'thread': expected 'function' |
| `vararg1.ssa` | Unsupported: line 2 near 'd': unsupported type: expected w (32-bit) or l (64-bit) |
| `vararg2.ssa` | Unsupported: line 1 near '...': unsupported type: expected w (32-bit) or l (64-bit) |
