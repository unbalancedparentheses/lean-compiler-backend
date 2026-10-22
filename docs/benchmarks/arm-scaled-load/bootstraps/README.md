# Fresh QBE and cproc qualification on combined scaled-load checkpoint

Compiler source/build identity: `210a515a50b54c9b78a824349deea8e4a78cc0d0b26f9bde5f61a886f8e6b2b5`.
Immutable binary SHA-256: `a89759b4fe0c27ab08142a90ae0bc8f517e664af09fbc1166800abfadd22392b`.
The exact source manifest and all its files were captured before each campaign, including the then-uncommitted scaled ARM load change. This qualification covers that precise combined source, not a later identity.

All target campaigns ran sequentially with fresh `--work` directories. QBE v1 and cproc v2 passed; all source/helper/compiler pre/post checks, helper guest/host barriers and added final-report guest/host barriers passed. There is no assembly/executable reuse from historical workload campaigns. Main source files were not edited.

## QBE

All 32 unchanged QBE translation units were freshly compiled for each Linux target. On each target, LCB baseline and optimized, and explicitly corrected QBE, reproduced 455 fixture assemblies plus 32 self-IR assemblies and passed 58 original ARM-output runtime tests. LCB totals are 2,922 exact assembly comparisons and 348 runtime tests. Corrected-reference totals remain separate.

ARM compiler executables run natively in the Linux VM; x86/RV compiler executables run under QEMU. Generated ARM test programs execute natively. QBE's other output targets are exact assembly comparisons, not runtime qualification, and do not extend LCB target support. Windows remains deferred. The upstream runtime runner's shared guest lock was retained, and target runs did not overlap.

Unchanged original-QBE self-compilation outcomes remain failures: ARM rejects `_alt.ssa`; x86 differs on `arm64_apple/abi8.ssa`; RV fails linkage on GOT_HI20 addends. None is counted as a qualified original-QBE self-compilation. The original GCC-built QBE remains the assembly reference. All three exact-comparator mutation controls detected their deliberately altered output; these test comparator sensitivity, not semantic independence.

## cproc

All 18 pinned cproc frontend translation units were freshly compiled per target. LCB baseline and optimized reproduce 19 exact stage-two IR files (the 18 frontend units plus cJSON) and pass 196 original tests on each target: 114 exact IR reproductions and 1,176 upstream tests in total. Actual stage-two executables run natively on ARM or via QEMU on x86/RV; test counts are the original suite's results, not a claim that each test executes backend-generated native code.

Original QBE passes the x86 campaign. Its ARM frontend fails on attr with exit 139, and its RV build fails linkage on GOT addends. Explicitly corrected ARM/RV references pass separately. All nine successful-backend sentinel controls detect a valid-IR return-constant change from 37 to 38; this is comparator-sensitivity evidence, not an independent proof of generated code semantics.

## Provenance and retained limitations

QBE pre/post bindings: 1,148 ARM, 1,148 x86, 1,147 RV; guest/host files: 3,276 / 3,382 / 3,273. cproc pre/post bindings: 1,039 / 947 / 1,038; guest/host files: 931 / 892 / 930. Exact details and source/oracle/binary hashes are retained in reports; each final report additionally passed a guest/host digest barrier. The source snapshot, exact helper scripts, target correction descriptions, compressed inputs/control artifacts and complete stdout logs are included.

The first cproc v1 helper completed ARM successfully, but the collection wrapper used QBE's top-level compiler_sha256 field instead of cproc's provenance.compiler_sha256 and raised KeyError. Its original helper report/log and captured wrapper failure remain under wrapper-preflight-cproc-v1. It has no successful outer post-validation barrier and is superseded by fresh cproc v2. The original run.py bytes remain untouched for QBE's bindings; run-v2.py fixes only the wrapper schema lookup.

QBE retained one diagnostic repetition. Full regression gates ran concurrently elsewhere. All duration samples are diagnostic under shared load; no runtime performance comparison is made. Fresh runtime correctness was required despite any possible workload assembly identity.

Raw full work directories remain under `.build/linux-arm64/combined-scaled-v1-qbe-{target}` and `.build/linux-arm64/combined-scaled-v2-cproc-{target}`. Their report manifests bind assemblies, objects, executables, sources and outputs. This compact publication includes reports plus compressed IR/control journals, not every binary artifact. `manifest.json` binds the publication by relative path. Per-campaign manifests are original absolute-work snapshots and should not be interpreted as relative publication manifests.
