# RV64 result normalization

Compiler `f9998cdd7f047ad5ac6ce1234797f2a68ecf71a84bdd911427a472cc9f4cc135`
omits final word-normalization pairs after paths already producing zero-extended
bits: copy/cast, integer/FP comparisons, unsigned extensions, floating arithmetic
and negation, floating-result conversions, and word variadic loads. Every binary
operation, call, signed extension and integer conversion retains normalization.
In particular, negative OR/XOR immediates can set upper bits and still narrow.

All three RV64 modes pass 9,728 new independent C result checks and 9,216 existing
load/cast checks per mode, plus 896 floating and 1,228 conversion checks and mixed
floating variadics. Corruption controls are detected. Fresh units, the full RV64
target gate and an emission-only missing-tool guard pass. Execution uses QEMU;
no new native RV hardware or original-QBE comparison is claimed for this slice.
The existing target gate retains its separately qualified QBE comparisons.

Against compiler `59bd88b6aa90e73f6a5d3778ed871c36931d6b367b3d1a3dd3a6467bc32f94dc`,
17 zlib units shrink as follows:

| Mode | Before text | After text | Reduction |
| --- | ---: | ---: | ---: |
| Baseline | 573,892 | 564,456 | 1.64% |
| Allocated | 355,464 | 352,400 | 0.86% |
| Optimized | 258,600 | 257,252 | 0.52% |

All six before/after builds pass upstream zlib static tests and 72 payload/level
profiles, matching GCC compressed bytes and Python/compiled decompression.
Runtime speed was not measured. Strict auditing of all 51 assembly pairs accepts
only complete normalization-pair deletions; the initial, weaker comparison and
its provenance remain alongside the stronger audit. The measured isolated and
integrated binaries have identical identities and hashes.

Ordinary-corpus comparison records 1,216 identical assemblies, 89 intended RV-only
changes and 15 matching refusals. Raw exact comparison reports those differences;
a separate audit permits only 338 complete normalization-pair deletions and no
other byte changes. The proof audit's 147 reports remain unchanged. These tests
and assembly checks do not establish formal semantic preservation.
