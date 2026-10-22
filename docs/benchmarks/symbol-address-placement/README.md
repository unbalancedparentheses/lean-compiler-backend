# Global-address placement qualification

Repeated module-defined non-TLS addresses are now introduced immediately before
first use in a single-block function without phis or successors. General CFGs
retain entry hoisting only when at most eight addresses qualify; larger sets
retain their original expressions. This is a profitability heuristic, not a
register-pressure bound or a preservation proof. Interleaved lifetimes can
still overlap. External/TLS operands are not selected.

Before compiler: `e1166d5552d429214b74b5815154890a9ce5cf6c1ba9411df050301a2bdca9d4`.
After compiler: `240863b373737ef51e61b743b39ed0448646e993bc0bae175fdd780436bfaefd`.
After binary SHA-256: `a0166149c7afbd6457db31e5647027aca5c54028fc8b1ac4165b42eecd52c5f5`.

## Independent execution

The integrated `scripts/symbol_address_pressure.py` generates 13 functions:
8/9/16/64/512 sequential globals, 8/9-global branches and loops, overlapping
lifetimes, effect-only and multiple-global call first uses, and word-width first
use. Thirty-two seeded inputs per function give 416 independent uint64 C checks
per backend/target. All three LCB modes and unchanged original QBE pass on all
five targets: 8,320 checks total. Five wrong-global controls are detected.
Linux ARM and Apple ARM execute natively; Linux x86/RV use QEMU and Apple x86
uses Rosetta. The 132-file host/guest digest barrier passes. Baseline and
allocated output is byte-identical before/after. Emission-only checks run with
missing tool paths and reject any execution callback.

Fresh Lean units separately cover fresh-name collisions, repeated and trailing
debug locations, two addresses first used by one instruction, and the eight/nine
CFG boundary with branch/loop interpreter comparisons. Source evaluation must
succeed; equality cannot pass through two interpreter errors. Initial unit
builds failed for an untyped pattern and an unavailable `BEq Except` instance;
they are retained as failed preflights. The subsequent strict build and unit
execution pass. The 147 proof-audit reports are exactly unchanged; these tests
do not add an optimization preservation theorem.

## Resource profile

`Profile.lean` measures optimized liveness and a 13-register allocation plan;
`generate.py` emits short disjoint regions with three uses of each global.

| Globals | Before peak live / spills | After peak live / spills |
| --- | --- | --- |
| 8 | 11 / 0 | 4 / 0 |
| 16 | 19 / 6 | 4 / 0 |
| 64 | 67 / 54 | 4 / 0 |
| 512 | 515 / 502 | 4 / 0 |

The `no-symbol-hoist` rows remove module data only to disable this optimizer
selection for diagnostic profiling. They are not executable programs or a
compiler baseline. No runtime improvement or universal pressure bound is claimed.

Corpus comparison gives 1,300 identical assemblies, 15 identical refusals and
five expected optimized changes, exclusively original `tls.ssa` across the five
targets. Its ordinary `$fmtx` address moves from entry to first use; actual TLS
address operations retain their semantics. Baseline and allocated corpus output
remain identical. The exact comparator exits 1 for these intentional changes;
its report is preserved rather than presented as an equivalence pass.

All three Linux target gates pass: native ARM and QEMU x86/RV, each with 58
original executable drivers and 17 assembly-only fixtures per backend. Full host
gate is still running at this checkpoint; the independent five-target matrix
above already passed. Emission-only integration passes. The full target gates
also exercise existing global-address, TLS, calls, loops and fresh-name tests.

The [fresh zlib replay](zlib/README.md) passes six upstream examples and 72 exact
GCC/Python profiles on native Linux ARM. All 102 before/after assembly pairs
(17 units, three modes, two ARM targets) are byte-identical. This is real-program
non-regression evidence, not a zlib performance improvement. Apple objects are
assembled; no fresh QBE workload or timing run is claimed.
