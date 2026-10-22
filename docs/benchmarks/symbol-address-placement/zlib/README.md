# Symbols placement: retained zlib non-regression

Compared immutable compiler snapshots `e1166d5552d429214b74b5815154890a9ce5cf6c1ba9411df050301a2bdca9d4` (before) and `240863b373737ef51e61b743b39ed0448646e993bc0bae175fdd780436bfaefd` (after), using the same 17 retained, ARM-configured zlib IR units. The original source/configuration/frontend bindings are preserved in `binding-report.json`; neither source nor IR was regenerated or modified.

All 102 before/after assembly pairs are byte-identical: 17 units × three modes × two targets. No emitted global-address code differs in this workload. This is non-regression evidence, not evidence of a zlib optimization benefit or a register-pressure bound.

| Target | Baseline .text | Allocated .text | Optimized .text | Before/after change |
|---|---:|---:|---:|---:|
| Linux ARM64 | 416,468 | 166,340 | 115,792 | 0 |
| Apple ARM64 | 416,772 | 166,644 | 116,096 | 0 |

Fresh compilation produced 204 assemblies and 204 objects. Native ARM Linux VM execution passed six upstream `example` checks (before/after × three modes) and 72 `minigzip` compression profiles (four inputs × levels 1/6/9 × six binaries). Each compressed stream exactly matches the retained independently GCC-built reference; Python decompression and same-backend decompression recover the original bytes. The four inputs include empty, all-byte, patterned, and repetitive payloads. Apple ARM objects were assembled but these workload binaries were not executed on macOS. No original-QBE executable was rebuilt or run in this campaign.

The execution probe bound 439 files before/after. Final verification checked 408 assembly/object hashes against guest execution bindings and host files, the guest-to-host execution-report digest, original source/configuration/IR/reference files, and immutable compiler hashes. See `qualification.json`, `report.json`, and `execution.json` for exact identities and hashes. No performance timing was run.

Reproduction commands (original local paths are retained in the scripts):

```sh
python3 /tmp/qualify-symbol-placement-zlib.py
docker exec lcb-parity-linux python3 /work/symbol-placement-zlib-review/execute.py
python3 /tmp/finalize-symbol-placement-zlib.py
```

Raw assemblies, objects, binaries and inputs remain under `.build/linux-arm64/symbol-placement-zlib-review/`; the scripts and reports here are the publication subset.
