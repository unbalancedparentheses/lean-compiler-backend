# Signed division/remainder by normalized +1

The optional algebra pass changes signed `div x, 1` to a result-width copy and
signed `rem x, 1` to zero. Constants normalize to the operation width first, so
word constants such as 4294967297 also mean +1. The copy must retain word
truncation even when its input is long. Zero, -1 and every other signed divisor
retain the original operation; no signed-minimum/-1 overflow case is folded.
Calls that produce the dividend remain observable even when remainder becomes zero.

Before identity is `de27b459436dbfc15e827f17fbfa30948b2192b598035c40ac5debd2952f33f9`;
after is `aa0f26deadbcf877fe7102d5f81ffa565a67129ea0b6e6551453d5511305fe1c`.
The main integrated binary matches the independently built candidate byte for byte.

All five target profiles pass 5,628 independent C checks per LCB mode and the
unchanged original QBE comparison. Four signed-minimum/-1 C cases are explicitly
excluded as undefined; eight interpreter guards reject zero/overflow cases.
Structural checks retain zero/-1/8 divisions. Side-effect and wrong-return
controls pass. Linux ARM and Apple ARM execute natively, Linux x86/RV under QEMU,
and Apple x86 through Rosetta. Wrapper-specific reruns bind Docker-only QBE and
Path compiler handling; missing-tool emission-only runs invoke no target tools.
The helper was hardened after the initial isolated qualification; both report
sets and their distinct hashes are retained.

The main unit suite, all four full Linux/Rosetta target gates, native Apple ARM
helper, missing-tools emission guard and unchanged 147-report proof audit pass. The ordinary
1,320-case corpus is entirely unchanged: 1,305 identical assemblies and 15
matching refusals. Those fixtures do not exercise the new optimization; the
independent matrix and real-program reports provide its executable evidence.

On native ARM64, 17 optimized zlib objects lose 14 signed divides and 112 text
bytes (124,156 to 124,044). The 21 libyaml units lose 63 divides and 516 bytes
(270,108 to 269,592). All baseline/allocated assemblies across those 38 units are
byte-identical. Six before/after zlib builds pass upstream examples and 72
payload/level profiles against GCC compressed bytes and independent Python/own
decompression. Fresh libyaml builds pass all 52 historical GCC checks per mode.
No runtime speedup or additional formal preservation proof is claimed.

Reproduction uses `scripts/signed_division_one.py`, also integrated into the
host and target gates. `isolated-provenance.json` names and hashes the original
measurements; `wrapper-provenance.json` records the final helper qualification.
