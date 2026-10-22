# Discarded scalar call results

Private candidate `60ffdd4c56bf26efa0eb8593923ccb094808ab4d91e6739d03bb360bea99c8bf` allows an explicit effect-only call to discard a defined scalar result. Previously validation rejected such calls when the callee definition was in the module, although unchanged QBE accepts them. The interpreter also rejected a returned value after executing the call. The patch adjusts only result compatibility and interpreter result discard; it preserves call effects, used-result matching, argument/environment checks, and aggregate hidden-result storage requirements. It changes no native emitter or SSA rewrite.

The matrix covers `w/l/s/d/sb/ub/sh/uh`, each through a defined direct call, local indirect call, external direct call, and parameter-supplied indirect call. Independent C callers check modular side effects over 32 seeded inputs. Additional checks retain the existing SSA normalization of an unused assigned result from a void callee, and discard a scalar variadic result with an explicit empty variadic tail. These are 320 C checks per backend/target, across baseline, allocated, optimized and unchanged original QBE on five targets: **6,400 successful checks**. Apple ARM and Linux ARM VM execute natively; Apple x86 uses Rosetta and Linux x86/RV use QEMU. Original QBE RV explicitly links with `-no-pie`.

Eight interpreter checks per target cover direct and indirect calls for the scalar types. Five signature controls per target reject defined aggregate omission, a used result from a void function, used floating/integer mismatch, wrong argument width, and an omitted used environment. An additional indirect aggregate call is rejected during interpreter target resolution. All five deliberately corrupted side-effect binaries fail with exit 1. The all-target emission-only run uses nonexistent C/QBE paths and rejects any attempt to execute target tools. Full executable units passed.

Unknown native external/indirect signatures remain existing link-time ABI assumptions: the compiler cannot identify an unknown aggregate-return callee and supply hidden storage. This qualification does not broaden that contract. Aggregate omission is not supported. The checks are finite and are not a general ABI correctness proof.

Three harness-only preflights failed before the final matrix: statement formatting, splitting an assigned-call instruction, and a stale mutation pattern. Their original IR and logs are retained with exact hashes and status in `preflights.json`. No compiler change occurred during those fixture repairs. The final source and caller are `calls.ssa` and `caller.c`.

`qualification.json` binds 179 files and records the complete host/guest digest barrier. `reports.json` contains compiler/QBE hashes, target modes, IR/caller/assembly hashes and outcomes; `compiler-build.json` binds the private source identity. Root integration must regenerate its identity and qualify the actual integrated binary rather than relabel this private evidence. Raw objects, binaries and per-target files remain under `.build/linux-arm64/scalar-result-discard-review/`. No timing was performed.

Suggested integration hooks, not edited in this checkpoint:

- `scripts/check.sh`: invoke `python3 scripts/scalar_result_discard.py` beside `symbol_address_pressure.py`.
- `linux_arm64.py`, `linux_targets.py`, `macos_x86.py`: call `exercise(compiler, work, run, cc, target, execute, qbe)` beside the symbol-pressure hook, using the wrapper's existing execution flag.
- `emission_only.py`: call for all five targets with `execute=False`; assert `checks_per_backend == 0`, `original_qbe == "not-run"`, and every backend execution is `"not-run"`.

Private reproduction: `lake build lcb lcb-tests`, `.lake/build/bin/lcb-tests`, then `python3 run.py`, `python3 emission.py`, `python3 finalize.py` in `/tmp/lcb-scalar-discard`. The retained runners contain original absolute paths.

## Integrated main qualification

The integrated main compiler has the same source identity `60ffdd4c56bf26efa0eb8593923ccb094808ab4d91e6739d03bb360bea99c8bf` and binary SHA-256 `44fa58bca4b95ed3c798f612452d3d32dafdd1fd6e0dba7b7fe17331eb1b943c`.
Fresh main build/units, all five execution matrices (6,400 C checks), emission-only
guards and the exact unchanged 147-report proof audit pass. The final integrated
matrix binds 108 host/guest files. Corpus output remains exactly unchanged:
1,305 assemblies and 15 refusals. Existing native Apple call, indirect-call and
variadic gates pass; the calls gate has 1,794 C cases per backend plus 69 external
ABI cases. Full host/all-Linux gates for this new identity are not claimed here;
the preceding Symbols identity passed those gates.

The old calls gate expected defined scalar-result discard to be rejected. Its
first integrated run failed on that stale expectation; the retained failure log
is `main/scalar-discard-main-calls.log`. The case is now a positive check and
interpreter test. Rejection/undefined controls consequently decrease from 19 to
18; no invalid case was silently removed. The corrected call gate passes.

The portable helper is integrated beside symbol-pressure checks in the host,
Linux ARM, Linux x86/RV, Rosetta and emission-only wrappers. The suggestions
above describe the private pre-integration checkpoint; these hooks are now present.
An agent accidentally invoked a cached build in the main directory during private
experiment setup. It replayed existing jobs; the main executable remained
byte-identical to the immutable matrix snapshot (SHA above), with no source edits.
