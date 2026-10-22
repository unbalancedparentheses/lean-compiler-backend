# Bounded aggregate ABI copies — private integration candidate

No main files were changed. Base source f48b2ca; the main unused-return-elimination work is not present in these private compiler identities. Regenerate actual-main identity after integration.

## Patches

Apply numeric-copy-core.patch (three emitter helpers), cap-only.patch (three ABI checks), final-tests.patch (new portable helper), and final-hooks.patch (check.sh and all target runners). Do not apply stale copy-only-core.patch, which used named labels, or old tests.patch, which preserves the earlier qualified helper. Generated identity files are not included in the patches.

## Stages and identities

- Before: f159cc758be1a944534240d32728bb47d7f8e7f6abe77b0e2d1fd9446106b8f6.
- Copy-only, still4096 limit:44f1e3ae9f87c9bda640b49b7c4da90f05422a7c1b25d8fc49a82c905d7d79fc. Fresh build/units and five-target executable reference matrix passed.127/128 copies retain byte-identical assembly across all15target/mode combinations.
- Bounded1MiB cap:69c2f3b37185628b32e4fa7b25c16a924fce22bd94410fb4c2d44a1e0b3c090a. Fresh build/units passed. Compiler snapshot remains unchanged throughout final helper expansion.

## Final reusable helper coverage

Default22sizes127..65537 include threshold128, all8tail residues,4096/4097,32768and65536boundaries. All baseline/allocated/optimized modes plus optional unchanged originalQBE compile/link/run the same independent C oracle. Every caller byte is checked; input-parameter mutation must not escape; aliased source pointers become independent by-value arguments. Hidden result copies test disjoint and identical addresses with both start/end guard pages. Odd-size end-guard addresses also exercise misalignment. Partial overlaps are outside this forward-copy qualification.

Eight floating raw-bit arguments (including NaN payload, signed zero and subnormal) and six integer arguments are tested both before and after aggregates. Incoming LCB variadic functions consume the same8FP/6GP values; outgoing calls to C variadics exercise AL/staging. Explicit environment calls, ordinary C hidden returns, repeated copies, formerly colliding named globals and quoted numeric global $"8" execute. Zeroing compact-copy stores must fail the independent oracle.

The helper also emits/executes guarded1MiB−1 and1MiB hidden-return copies in all3modes. One-past layout, excessive private frame and excessive outgoing argument area must fail with expected diagnostic categories in all3modes. These maximum cases are independent C qualification ONLY: originalQBE reference scope is the22-size matrix through65537. RV reference-only-no-PIE retry is explicitly recorded when needed; default link diagnostics remain in reports. No correctedQBE source is used.

All-five emission-only tests use nonexistent C/QBE paths and reject any attempted external execution; reported executed mode counts remain zero. Default native CLI --require-native is tested separately. Hook syntax is checked; complete shared target runners are for subsequent actual-main qualification.

## Provenance and limitations

Final-v3 helper/runner copies were frozen before final runs completed and checked against live files afterward. final-v3-manifest.json binds compiler binary, all6core source files, helper/hooks, runners, emitted IR/C/assembly, reports and controls. Commands, originalQBE binary hash, exact compiler identity and source hashes are in per-target reports. No new timing or speed claim.

The earlier244-artifact campaign has its original manifest and exact qualified helper preserved in immutable-helper-history (helper recovered from retained tests.patch and SHA checked). Its old live helper path was later changed, so that live-path binding is explicitly superseded. V1 failed during report serialization because a maximum fixture shadowed the thunk Path with text; source and diagnostic retained, unqualified. V2 was superseded by review-driven stress expansion and is not final bound evidence. Final-v3 is a fresh campaign in separate directories.
