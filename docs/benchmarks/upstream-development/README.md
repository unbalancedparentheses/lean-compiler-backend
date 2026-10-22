# Supplementary QBE development-fixture execution

The 17 underscore-prefixed fixtures have no embedded C driver or expected-output section. Original QBE's `tools/test.sh` deliberately excludes them from its normal `[!_]*.ssa` suite. This is not an extraction gap. The existing count stays **58 original executable drivers plus 17 assembly-only fixtures**; the new caller evidence below is supplementary.

The unchanged `_gcm1.ssa`, `_fix3.ssa` and `_fix4.ssa` now pass independent callers across all five supported targets, all three LCB modes and unchanged QBE: 60 program executions, 770 independent input/result cases per mode/target, and five detected wrong-return controls. Compiler identity is `e1166d5552d429214b74b5815154890a9ce5cf6c1ba9411df050301a2bdca9d4`.

- `_gcm1`: independent uint32 arithmetic for its three functions, including high-bit inputs and bounded nonzero loop counts. Zero loop counts that would run 2^32 iterations are excluded.
- `_fix3`: independently calculated return value -4965.
- `_fix4`: an independent C sieve computes the 10,000th prime, 104729; a dirty upper half of the 64-bit global also checks that the original store changes only its lower 32 bits.

Original SSA bytes and emitted function bodies remain unchanged. Private test functions are exposed with a tail-branch adapter appended in the same assembly translation unit. Native Apple/Linux ARM, Rosetta Apple x86 and QEMU Linux x86/RV execution are distinguished in the reports. Original QBE RV links with its explicitly retained `-no-pie` qualification.

The 357-file host/guest digest barrier passes. Fresh main native Apple checks and all five missing-tool emission-only guards pass after integration. The helper is hooked into the host and target gates. Other development fixtures include deliberate infinite loops, tests requiring a special three-register build, and void functions with no observable result; they are not counted as independently executed here. Prior `_chacha20` coverage remains separately qualified as one double-round.
