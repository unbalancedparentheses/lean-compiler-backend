# Bounded integer bit patterns

Compiler `3c25a0a8aaf94a6a53adf6c5d6cec78872809b1d7bebc66f45ad5d4c5202a40f`
accepts negative decimal magnitudes through `UINT64_MAX`, matching QBE's modular
negation. Previously the parser rejected values below `INT64_MIN`; for example,
`-18446744073709551615` now denotes 1. Magnitudes beyond `UINT64_MAX` remain
rejected under the explicitly bounded compatibility profile.

Normalization occurs before contextual checks for operands, data values and
zero fill, allocation/blit sizes, alignment, aggregate repetition/opaque sizes
and debug locations. Existing nonnegative checks, layout/data limits and 29-bit
debug bounds remain. Static symbol addends render canonically as signed 64-bit
values; the positive-`UINT64_MAX` spelling already passed the prior Apple C
comparison, so this rendering change is not presented as a wrong-code repair.

Each of five target matrices passes all three LCB modes and unchanged QBE against
independent C: 169 packed bytes, 22 word/long returned values, 24 interpreter
checks, 13 malformed/resource refusals and a corrupted-value control. Apple x86
runs through Rosetta and Linux x86/RV through QEMU; both ARM targets execute
natively. Every LCB link uses the default profile. The original RV default-link
failure and successful reference-only non-PIE retry are recorded separately.

Fresh units and existing parser, packed-data matrix, aggregate-layout,
debug-location and floating-constant suites pass. Ordinary-corpus comparison
records 1,305 identical assemblies and 15 matching refusals. The unchanged 147
proof-audit reports do not establish full parser/native correctness.

The current matrix runner initially copied the wrong harness and aborted during
summary validation after running a syntax fixture. That preflight is excluded;
the corrected run's script hashes and integer-specific report fields were checked
against current sources. Published reports contain only the completed integer
matrix, with the exact compiler and executed-harness provenance.
