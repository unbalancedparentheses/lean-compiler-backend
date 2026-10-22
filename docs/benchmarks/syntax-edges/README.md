# Hexadecimal strings and symbol annotation order

Compiler identity `821344c8800eb9e481a9a8275385296a4730a68dfd23e55085f36481c113c588`
accepts hexadecimal byte-string escapes and either order of `extern`/`thread`
operand annotations. Repeated annotations are idempotent, as in QBE's parser.
Hex escapes require at least one digit, consume every following hex digit and
retain the low byte. Incremental modulo reduction bounds intermediate values.

The five-target matrix uses independent C expected bytes and mutable TLS/global
values. Each LCB mode passes the 314-byte fixture and 25 annotation checks, with
eight interpreter byte spot checks, five malformed-input rejections and two
wrong-source corruption controls per target. Hex coverage includes all 256 byte
values, mixed-case digits, lengths 1/2/3/4/16/17/600, termination by a non-hex
character, ordinary ASCII, octal and portable control escapes.

| Target | Executable LCB/QBE profiles | Original-QBE qualification |
| --- | ---: | --- |
| Apple ARM64 | 8/8 | Both fixtures pass |
| Apple x86-64, Rosetta | 8/8 | Both fixtures pass |
| Linux ARM64 | 7/8 | Combined extern/thread emitter refusal retained |
| Linux x86-64, QEMU | 8/8 | Both fixtures pass |
| Linux RV64, QEMU | 7/8 | Combined annotation refusal; hex reference uses explicit non-PIE retry |

All LCB links use the default profile. The original RV default-link failure and
successful reference-only non-PIE retry are both retained. QBE source is unchanged;
compiler, harness, helper and QBE-source provenance accompany the reports.

This does not claim general assembler escape equivalence. Existing LCB octal
values above 255 remain rejected. Existing `\a`/`\v` interpretation also differs
from some assemblers used by original QBE: Apple rejects these spellings, while
GNU emits literal `a` for `\a`. The separate discrepancy artifact preserves that
finding; shared success fixtures spell bell and vertical tab with octal escapes.

Fresh build/unit tests, existing native data and quoted-name suites pass.
Before/after corpus comparison records 1,305 identical assemblies and 15 matching
refusals. The same 147 proof-audit reports remain; no new native or parser theorem
is claimed. Longer full-target regression runs are separately qualified by their
recorded compiler identities; these parser changes use the dedicated five-target
matrix and unchanged-assembly gate.
