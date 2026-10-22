# ARM64 empty conditional-edge layout

Allocated and optimized ARM64 output now bypasses an empty false-edge trampoline
when the true successor immediately follows it. Phi moves, debug interposition,
other layouts and baseline emission remain conservative. The pass accepts only
`b.<condition>` and `cbz wN` patterns. A physical assembly-line upper bound of
900 KiB (including embedded newlines) and a directive whitelist preserve a margin
below conditional branches’ signed 1 MiB reach. Unknown directives disable the pass.

The exact before identity is `a2e10e57113b6cadafcca6a59c5206bde2a51282bd1ef55206e4079ed1121043`;
after is `de27b459436dbfc15e827f17fbfa30948b2192b598035c40ac5debd2952f33f9`.
The integrated main binary matches the isolated combined candidate byte for byte.
Earlier branch-only experiments are excluded from these measurements.

Both native Linux ARM64 and Apple ARM64 pass 11,661 independent C branch/phi
checks in each of baseline, allocated and optimized modes. The unchanged original
QBE also passes this complete fixture. A wrong-target mutation is detected.
Expanded functions exceeding 1 MiB retain local trampolines and execute both paths
in all three modes; allocated/optimized output exceeds 275,000 physical lines.
Missing-tool emission-only checks pass without executing C or QBE.

The full native Linux ARM64 gate and unit suite pass. The 147-report formal audit
is unchanged; this assembly optimization has no new end-to-end proof. Across the
1,320-case ordinary emission corpus, 1,187 assemblies and 15 refusals are unchanged.
The remaining 118 assemblies have only the exact intended ARM branch rewrite
(6,772 removed instructions). All baseline output and the other three targets are
byte-identical. The raw exact comparator deliberately reports these differences;
`assembly-audit.json` applies the narrower accepted rewrite.

Seventeen optimized zlib objects shrink from 132,636 to 124,156 text bytes on Linux
and from 132,940 to 124,460 on macOS: 8,480 bytes / 2,120 instructions per target,
about 6.4%. All 34 baseline assemblies are identical. Native Linux before/after
upstream examples and 12 payload/compression-level cases match GCC compressed
streams and pass own/Python decompression. These are size and correctness results,
not a runtime speedup claim. Full identities, hashes and raw records appear in
`combined-evidence.json`; original and corrected QBE findings from other workloads
remain separately qualified.
