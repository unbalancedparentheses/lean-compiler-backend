# Private ARM byte/halfword indexed-load fallback experiments

All candidates remain **unmerged**. These generic access-width guards never inspect function names. Byte fallback keeps halfword/wide indexed loads; halfword fallback keeps byte/wide indexed loads. The existing compiler still folds every qualified load width.

Both private candidates pass fresh units, both native ARM matrices (37,124 independent C case groups per LCB mode and target), unchanged QBE comparisons, wrong-index/overread mutations, strict immediate debug-location/load adjacency and missing-tool emission-only controls. The original correctness qualification binds 122 host/guest artifacts. Each candidate's fresh 17-unit zlib comparison passes six Linux ARM examples and 72 exact GCC/Python stream profiles; Apple objects are assembled only. Baseline and CRC assemblies remain identical. Byte fallback restores 39 optimized address adds (+156 text bytes per ARM target); halfword fallback restores 57 (+228 bytes). Allocated code changes are separately recorded; one halfword fallback also exposes a spilled-address store/load pair.

The new, explicitly named compression-only protocol uses eight fresh build labels: GCC, indexed, wide-only, byte-fallback, half-fallback, phi, original QBE and separately corrected QBE. Full correctness remains unchanged. Compression batches are calibrated to 500 ms; decompression/CRC loops are fixed at one and their raw durations are diagnostic only, excluded from summaries. This protocol is separate from the earlier full-API windows. Its exact summary path passed a synthetic-data preflight before timing; synthetic rows are not performance evidence.

Two quiet windows each complete 216 samples (eight labels × three payloads × nine paired rounds), two warmups, sink agreement and host/guest postvalidation. Compiler/test jobs were held; unrelated user/system activity was not controlled. Ratios below compare each candidate with indexed within the same window; below one means faster.

| Candidate / payload | Window 1 (bootstrap 95%) | Window 2 (bootstrap 95%) |
|---|---|---|
| wide-only / repeated | 1.0107 [1.0078, 1.0145] | 1.0097 [1.0052, 1.0242] |
| wide-only / random | 1.0269 [1.0157, 1.0304] | 1.0225 [1.0065, 1.0465] |
| wide-only / mixed | 0.9307 [0.9266, 0.9393] | 0.9319 [0.9257, 0.9497] |
| byte-fallback / repeated | 1.0072 [1.0014, 1.0261] | 1.0067 [1.0012, 1.0105] |
| byte-fallback / random | 1.0106 [0.9971, 1.0232] | 1.0095 [0.9985, 1.0198] |
| byte-fallback / mixed | 0.9541 [0.9520, 0.9662] | 0.9557 [0.9347, 0.9749] |
| half-fallback / repeated | 1.0028 [0.9990, 1.0056] | 1.0030 [1.0008, 1.0320] |
| half-fallback / random | 1.0042 [0.9956, 1.0439] | 0.9964 [0.9856, 1.0099] |
| half-fallback / mixed | 0.9697 [0.9651, 0.9744] | 0.9737 [0.9594, 0.9840] |

Halfword fallback gives a repeatable 2.6–3.0% mixed-compression gain with about a 0.3% repeated-payload cost; random-payload intervals overlap parity. Byte fallback gives 4.4–4.6% mixed gains with roughly 0.7% repeated cost and uncertain random cost. The broad fallback repeats its larger tradeoff. None is established as a universal default-policy improvement. Broader workload and full-API qualification would be needed before choosing a policy; no candidate is merged from this exploratory comparison. Multiple candidate comparisons and layout/cache effects limit causal interpretation.

`arm-width-experiments-qualification.json` retains the exact private identities and original raw artifact bindings. Its build-only in-process provenance hash describes the earlier preparation state, not the later live file with appended timing stages. Each timing archive independently binds its complete protocol, caller, manifest, raw samples, correctness and pre/post provenance. Original and corrected QBE remain separate references. No proof coverage expands.

The `zlib-byte` and `zlib-half` directories preserve the separate correctness campaign reports and runners referenced by the candidate qualification hashes. Each covers six native Linux example executions and 72 exact compression profiles; Apple objects were assembled only. These are correctness records, separate from the compression-only timing windows above.
