# Pinned YAML corpus compiler comparison

All three Linux targets pass exact parser stdout (events), stderr (errors), and exit comparison with GCC O0/O2 for **402 unchanged inputs** from yaml-test-suite data commit `6ad3d2c62885d82fc349026c136ef560838fdf3d`. Each backend accepts 273 inputs and rejects 129. This compares compiler behavior for libyaml 0.2.5; it is **not YAML specification conformance**, and suite goldens are not the oracle.

| Target | LCB modes | Corrected QBE | Unchanged QBE parser | Execution |
|---|---|---|---|---|
| aarch64-linux | baseline/allocated/optimized: 402 each | 402 | 402 | Native Linux ARM64 VM |
| x86_64-linux | baseline/allocated/optimized: 402 each | 402 | 402 | QEMU user |
| riscv64-linux | baseline/allocated/optimized: 402 each | 402 | Skipped: reference build link failure | QEMU user |

There are 8,040 corpus executions, including 3,618 LCB executions. GCC O0 and O2 are mandatory, as are all three LCB modes and the explicitly corrected QBE reference. Unchanged QBE remains separately labeled. Its ARM parser passing these inputs does not erase the upstream `test-reader` failure in the retained build qualification.

Compiler source identity: `11be972e96d4fc9de4c6df28cd1fe7f5ddf5c728ff01348bd6d1398eef1748b4`. Existing executables were reused without rebuilding source or running a newer compiler. Compiler snapshot, source, and frontend IR hashes were checked against the retained `libyaml-{arm,x86,rv}.json` reference reports. Those reports predate executable hashes: the replay captures executable hashes before/after execution and also requires all seven generated parser fixtures to reproduce each mandatory backend's recorded reference output. This is a behavioral binding, not a claim that the earlier reports recorded executable hashes.

`{aarch64,x86_64,riscv64}-linux.json` retain every input's payload hash/size, executable hashes, reference-report hash, compiler identity/hash, harness hash, per-input output/error hashes and exits, counts, and original QBE build qualification. The byte-exact reference reports are retained alongside them. Runtime performance and emitter/loader corpus coverage are not measured here.

Two separate negative controls failed as required: replacing the expected baseline executable hash with zeros and replacing an optimized fixture's expected stdout hash with zeros. Their reduced reports are `build-mismatch-negative.json` and `output-mismatch-negative.json`. They test the artifact and reference-output guards without modifying any executable.

To replay after obtaining the pinned data checkout and the existing reference builds:

```sh
python3 scripts/libyaml_corpus.py --reference .build/libyaml-arm.json
python3 scripts/libyaml_corpus.py --reference .build/libyaml-x86.json
python3 scripts/libyaml_corpus.py --reference .build/libyaml-rv.json
```

The script refuses stale harness references, mismatched compiler/source/IR artifacts, missing mandatory successful builds, changed executable hashes, changed inputs, and mandatory output mismatches. It does not fetch, rebuild, or silently substitute an oracle.
