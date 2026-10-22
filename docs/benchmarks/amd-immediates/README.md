# AMD64 arithmetic and shift immediates

Compiler `59bd88b6aa90e73f6a5d3778ed871c36931d6b367b3d1a3dd3a6467bc32f94dc`
selects encodable right-hand constants directly for add/subtract, bitwise and
multiply operations. Word arithmetic accepts every low-32-bit pattern; long
arithmetic requires a sign-extended 32-bit immediate. Constant shifts use the
operand-width modulo count. Other operands retain register instructions.

Both AMD targets pass 810 functions × 190 inputs = 153,900 independent unsigned-C
checks per mode, in baseline, allocated and optimized lowering. These cover
immediate boundaries, multiply, large and negative shifts, variable/LHS-constant
fallbacks and TLS operands. Wrong-immediate corruption is detected. The complete
Linux x86 and Rosetta macOS x86 gates pass, as do fresh units and the unchanged
147-report proof audit. Linux x86 executes locally through QEMU.

Original QBE passes a separately named 573-function profile (108,870 checks),
with legal constant shifts and without the TLS supplement. Its raw shift
assembler failures remain recorded. A reduced seven-line TLS word-subtract case
also fails unchanged QBE: Linux default linking truncates an R_X86_64_TPOFF32
relocation, and Apple assembly rejects `addq $4294967295,%rax`. All three LCB
modes pass the same reduced source against independent C on both targets.
These reference exclusions do not remove cases from mandatory LCB checks.

Against compiler `11be972e96d4fc9de4c6df28cd1fe7f5ddf5c728ff01348bd6d1398eef1748b4`,
all 17 zlib units have smaller summed object text:

| Mode | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Baseline | 553,360 | 507,643 | 8.26% |
| Allocated | 334,535 | 313,266 | 6.36% |
| Optimized | 245,583 | 230,162 | 6.28% |

All 51 object comparisons differ only by intended immediate substitutions.
Six before/after builds pass upstream static tests and 72 payload/level profiles,
matching GCC compressed bytes and Python decompression, including compiled
cross-decompression checks. Runtime speed was not measured. The isolated
candidate and integrated compiler have the same source identity and binary hash;
the raw provenance is retained, not relabeled from a different binary.

The ordinary corpus has 1,041 identical assemblies, 264 expected AMD-only changes
and 15 matching refusals. Its raw exact comparison reports intended differences;
the separate audit permits only corresponding encodable constant-load/register-op
substitutions and preserves every other byte. This is not a preservation proof.

Initial integrated target runs exposed harness assumptions about compiler-path
types and guest QBE invocation; those preflights are excluded. Fresh complete
gates use the corrected harness. A persistent emission-only guard also checks
that AMD helpers invoke no target tools when target C compiler/QBE executables are absent,
and reports zero executed cases in that mode.
