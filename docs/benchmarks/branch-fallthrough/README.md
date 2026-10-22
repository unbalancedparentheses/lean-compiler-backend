# AMD64/RV64 structured fallthrough

Allocated/optimized emitters now omit a terminal jump when its destination is
the next emitted block. This applies to unconditional jumps and conditional
false-edge tails, after all existing phi transfers have been emitted. Baseline,
block order, debug locations and conditional branch targets are unchanged. No
branch-reach assumption or conditional trampoline retargeting is introduced.

The measured before identity is signed-one `aa0f26deadbcf877fe7102d5f81ffa565a67129ea0b6e6551453d5511305fe1c`;
after is `7958046aa99bf6a1d836e954f5f022dfc8e62384a8e58013fdf529eb5808e282`.
Main and the independent combined candidate have identical executable hashes.
Earlier branch-only experiments are excluded from these size measurements.

All three target profiles pass 12,168 independent C branch/phi checks per LCB
mode, unchanged original-QBE comparisons, debug markers and wrong-edge controls.
Linux x86/RV run under QEMU; Apple x86 runs through Rosetta. Only the original RV
QBE fixture uses non-PIE linking. All three full main target gates, units,
missing-tools emission guard and unchanged 147-report proof audit pass.

The 1,320-case emission comparison has 999 identical assemblies and 15 matching
refusals. The strict audit accepts only jumps to the immediately following label
being deleted: 306 changed AMD64/RV64 assemblies, 5,523 removed jumps. ARM and all
baseline output remain byte-identical. The raw exact comparator reports these
intended differences; `assembly-audit.json` qualifies the narrow accepted edit.

Seventeen optimized zlib objects per target lose 2,082 instructions. AMD64 text
falls from 229,873 to 225,861 bytes in both object formats (4,012 bytes); RV64 text
falls from 257,116 to 252,940 (4,176 bytes). All 51 baseline assemblies are identical.
Linux before/after examples and 12 payload/level cases per backend match GCC gzip
bytes and pass own/Python decompression. Apple zlib evidence is object-only;
Rosetta executable evidence comes from the independent branch matrix. No runtime
speedup or new formal preservation proof is claimed.

An initial development negative fixture targeted an unreachable block, which
normalization removed; it was corrected to redirect an existing false edge.
A Docker stdin transport timeout on the GCC reference was resolved by running
the same payload checks inside one guest Python probe. These preflights are
excluded; the fresh combined report contains the successful final runs.
