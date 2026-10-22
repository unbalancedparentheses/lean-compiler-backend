# Private ARM wide-only indexed-load experiment

**Unmerged private candidate: two timing windows show a workload tradeoff.** Candidate `64dbcae4e590ac512d783a569df8b9ccbc286c83a92f4c29be05e4e8ee737e9d` is based on compiler `240863b373737ef51e61b743b39ed0448646e993bc0bae175fdd780436bfaefd`. It retains adjacent temporary-indexed loads only for accesses of at least four bytes. Byte and halfword accesses use the existing separate address calculation and load. The guard tests access width, not result width or function name. Scalar-result-discard integration on main is outside this private source identity; any main integration needs fresh identity and assembly equivalence.

Both native Apple ARM and native Linux ARM VM matrices pass 37,124 C case groups per LCB mode (baseline, allocated, optimized), plus unchanged original QBE. A group can contain multiple independent comparisons. Existing narrow semantic cases, exact-width guard pages, raw FP bits, indices, spills, aliases, barriers and debug fixtures are retained. Structural tests require ordinary narrow address/load sequences and preserve wide-fold positives. Wrong-wide-index and overwide-byte mutations are detected. Both target emission-only runs pass with unavailable C/QBE tools. Full unit executable passes; the proof audit matches all 147 expected lines without `sorryAx`. This is not an expanded proof claim.

All six before/after large-spill assembly pairs are byte-identical, so the previously qualified wide-load x15 large-offset path is unaffected. These particular large-spill binaries were not freshly executed. Baseline matrix and all 34 baseline zlib assembly pairs remain identical.

Fresh 17-unit zlib qualification on both ARM targets passes six native Linux ARM upstream examples and 72 exact GCC-compressed stream profiles, independently decompressed by Python and the corresponding backend. Apple ARM objects are assembled only. Optimized .text increases by 384 bytes on each target; allocated .text increases by 476 bytes. The full-API timing windows below measure this candidate separately from correctness qualification.

The optimized change restores 96 separate address-add instructions across 22 functions in six units. Exactly 39 indexed byte loads and 57 indexed halfword loads stop folding. Unit split:

| Unit | Byte | Halfword |
|---|---:|---:|
| deflate | 23 | 9 |
| trees | 11 | 27 |
| inflate | 4 | 1 |
| inftrees | 0 | 18 |
| infback | 0 | 1 |
| gzwrite | 1 | 0 |

`narrow-width-audit.json` lists every function. `function-differences.json` records before/after instruction and indexed-load counts. CRC assembly is byte-identical in all modes and both targets; exact hashes are in `crc-identity.json`.

The original qualified helper is retained unchanged in `arm-wide-indexed-review`. `prepared/` contains **unexecuted follow-up patches**, held during coordinated timing: stricter immediate debug-location adjacency and two generic byte-only/halfword-only fallback experiments. These expected-width sets retain all semantic cases; they were not qualified in this original package. Later width-specific qualification is separate.

The in-process build initially prepared six independently bound labels: indexed240863, wide-only64dbca, phi e7ef407, GCC, unchanged QBE and separately corrected QBE. All fresh builds, correctness checks and pre/post provenance checks passed. The subsequent timing windows are archived separately below. No candidate or compiler snapshot was mutated during timing.

Raw artifacts remain under `.build/linux-arm64/arm-wide-indexed-review`, `arm-wide-indexed-zlib-review`, and `zlib-inprocess-wide-indexed`. The matrix qualification has an 80-file host/guest digest barrier. The zlib qualification includes all reported assembly/object bindings and guest-to-host execution-report digest. Exact compiler/source/oracle hashes are retained in the reports.

The bundled build-only in-process provenance contains the first two completed correctness stages; its bytes exactly match the pre-timing SHA-256 already bound in the matrix qualification. Later parent timing stages append to the live file and are deliberately excluded from this correctness package.

## Two completed full-API timing windows

`timing-window1/` and `timing-window2/` each contain 162 samples: six labels × three payloads × nine paired rounds, 500 ms calibration batches and two warmups. The unchanged full-API protocol measures compression, decompression and CRC. All labels passed 15 correctness profiles, wrong-CRC mutation detection, sink agreement, and 502-file host/guest pre/post provenance barriers. Original and separately corrected QBE remain distinct labels.

Wide-only / indexed median runtime ratios (below 1 means faster):

| Payload / API | Window 1 (bootstrap 95%) | Window 2 (bootstrap 95%) |
|---|---|---|
| Repeated compression | 1.0105 [0.9988, 1.0205] | 1.0092 [1.0035, 1.0178] |
| Random compression | 1.0195 [1.0067, 1.0602] | 1.0234 [1.0183, 1.0391] |
| Mixed compression | 0.9547 [0.9396, 0.9824] | 0.9360 [0.9195, 0.9415] |
| Repeated decompression | 1.0036 [0.9916, 1.0344] | 1.0020 [0.9995, 1.0095] |
| Random decompression | 0.9989 [0.9937, 1.0072] | 0.9996 [0.9966, 1.0034] |
| Mixed decompression | 1.0062 [1.0018, 1.0297] | 1.0014 [1.0000, 1.0102] |
| Repeated CRC | 1.0029 [0.9798, 1.0722] | 1.0035 [0.9911, 1.0380] |
| Random CRC | 1.0062 [0.9882, 1.0135] | 0.9966 [0.9730, 1.0157] |
| Mixed CRC | 0.9980 [0.9583, 1.0195] | 0.9992 [0.9961, 1.0036] |

The repeated 4.5–6.4% mixed-compression gain comes with a 2.0–2.3% random-compression loss and roughly 1% repeated-compression loss. CRC intervals overlap parity; its assemblies are identical. Consequently this broad restriction remains **unmerged**. Byte-only and halfword-only follow-ups investigate the tradeoff without function-name special cases. Within-window bootstrap intervals do not establish universal performance or isolate instruction latency from layout/cache effects. Own heavy jobs were held during timing; unrelated user/system activity was not controlled.

`two-window-summary.json` retains exact ratios for all nine payload/API combinations. `prior-control-equivalence.json` verifies that the fresh indexed240863 and phi e7ef407 controls have byte-identical assemblies, objects, caller objects, and executable drivers to the earlier differently identified e1166/1fb controls. The identities remain distinct.

The first archive-copy attempt expected the private hybrid harness's `bindings.json`, while this unchanged protocol uses `binding-report.json`. It failed after copying some files; timing itself had completed and passed postvalidation. `archive-layout-preflight/` preserves the failed archiver and partial copies. The corrected archiver validated complete unique sample tuples, report hashes and the manifest-derived binding set before producing both final archives. No timing samples were discarded because of that archive-layout error.

The subsequent [width-specific experiments](../arm-width-fallbacks/README.md) now have their own correctness qualification and two compression-only windows. They remain unmerged and use a distinct timing protocol.
