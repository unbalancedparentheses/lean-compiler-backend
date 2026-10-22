# RV64 immediate instruction selection

Current compiler `41d5798117ef24c3cc3dd249da3dfdd7def1bff5e8fdfacf575b919eb5516d4b`
uses immediate instructions for encodable add/subtract and bitwise constants,
and masks constant shift counts to the operand width. Other constants retain
the existing register form. Word-result normalization and allocation are unchanged.

Fresh snapshots compare against syntax checkpoint
`821344c8800eb9e481a9a8275385296a4730a68dfd23e55085f36481c113c588`.
All three modes pass 576 functions × 190 inputs = 109,440 independent unsigned-C
checks each, covering both widths, signed 12-bit boundaries, modulo-32 constants,
negative/oversized shifts and arithmetic-right sign bits. Deliberately changing
an emitted immediate is detected.

Pinned QBE assembles and passes a separately qualified 393-function profile,
restricted to constant shift counts in range. The complete unchanged input
produces invalid original-QBE immediates such as `slliw ...,32`; its assembler
failure is retained. QBE's IL documentation specifies modulo-result-width shift
counts. Every boundary remains mandatory for LCB. Only the original-QBE executable
uses explicit non-PIE in this comparison.

## Zlib and corpus results

All 17 retained zlib IR units are recompiled with the two correctly identified
snapshots. Assembly instruction count falls from 92,764 to 90,537; summed object
`.text` falls from 265,296 to 258,600 bytes: 6,696 bytes, or 2.52%. Both builds
pass zlib examples and 12 payload/compression-level cases, matching GCC compressed
bytes and Python/original-data decompression. This is a code-size result; runtime
speed was not measured.

Fresh units, the unchanged 147-report proof audit and the complete RV target gate
pass. The ordinary corpus contains 1,177 byte-identical assemblies, 128 expected
RV-only changes and 15 matching refusals. A separate assembly audit confirms that
all changes are exactly the intended constant-load/register-operation replacements
(11,628 replacements), with all other bytes preserved. The raw exact-equivalence
report consequently records those 128 differences as failures; the separate audit
explains and checks them. Neither assembly comparison nor C tests are a formal
semantic-preservation proof.

Earlier private-candidate measurements had a stale embedded identity; those are
not relabeled or used as current qualification here. These reports were freshly
rerun with the recorded before/after identities and binary hashes.
