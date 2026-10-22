# ARM64 adjacent unsigned load extensions

Compiler `a2e10e57113b6cadafcca6a59c5206bde2a51282bd1ef55206e4079ed1121043`
omits a matching unsigned byte/half extension immediately after a load only when
both SSA results occupy the same allocated register. The retained load already
zeroes the full register. This supports word-to-long uses without introducing an
invalid implicit IR widening. Baseline output is unchanged. Signed/mismatched
operations, spills, different registers, intervening instructions, block entries
and separate debug positions retain their existing code.

Both native ARM targets pass 10,496 independent guarded-page C checks per mode
and the existing 60,480 matching/mismatched/cross-width checks per mode. Tests
cover shared uses, aliases, register pressure, debug positions and fallback paths;
a deliberately widened byte load trips the guard. Fresh units, the full native
Linux ARM gate and emission-only unavailable-tool checks pass. The existing 147
proof-audit reports remain unchanged; this selector is not formally proved.

All 17 Linux ARM zlib units were rebuilt against compiler
`f9998cdd7f047ad5ac6ce1234797f2a68ecf71a84bdd911427a472cc9f4cc135`.
Optimized text falls from 133,048 to 132,636 bytes (412 bytes, 0.31%): 90 UXTB
and 13 UXTH instructions disappear. Allocated text falls from 181,600 to 179,464
bytes (1.18%); baseline text remains 416,468 bytes. Strict checks of all 51 assembly
pairs permit only same-register unsigned-extension deletions. Six before/after
builds pass upstream static tests and 72 payload/level profiles with GCC-exact
compressed bytes and Python/compiled decompression. No runtime speed was measured.

The measured isolated and integrated compiler binaries have identical identities
and hashes. Ordinary-corpus comparison records 1,303 unchanged assemblies, two
expected ARM changes and 15 matching refusals. A separate audit accepts only four
extension deletions; its raw exact-comparison differences remain retained.
