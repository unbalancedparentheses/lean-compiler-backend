# Width-aware symbol initializers

Compiler identity `e1a329371ac31cb3af1d7ef3bf7f1fce81c72b11e2445525ab4520f74335aef9`
accepts `b`, `h`, `w`, `l`, `s` and `d` symbol initializers, with their declared
storage width and addends. Previously only eight-byte symbol fields were accepted.
The interpreter stores the low address bits in packed layout; native assembly
requests the corresponding relocation. Linker support and address range remain
separate requirements.

`scripts/data_relocations.py` checks 18 packed interpreter layouts with positive,
negative and wrapping addends. Native C independently compares exported, local,
external, quoted and function addresses, addends and surrounding guard bytes.
All three LCB modes and unchanged QBE receive the same IR. Default linking and
explicit non-PIE are separate profiles. A corrupted relocation is detected on
all five targets.

| Target | Executable profiles / link attempts |
| --- | ---: |
| Linux ARM64 | 24 / 48 |
| Linux x86-64 (QEMU) | 24 / 48 |
| Linux RV64 (QEMU) | 22 / 48 |
| Apple ARM64 | 16 / 48 |
| Apple x86-64 (Rosetta) | 16 / 48 |

The retained reports total 78 LCB and 24 original-QBE executable passes across
240 link attempts. All other attempts are retained linker refusals, not successful
runtime checks. Ordinary Linux word/single-width absolute relocations require
explicit non-PIE here; long/double-width fields pass both LCB link profiles.
Apple narrow fields are unsupported or exceed the available address range.
Original RV QBE's default-link GOT failure remains separate; LCB default linking
passes. The unchanged QBE source and snapshot provenance are recorded.

The absolute-symbol supplements additionally demonstrate byte relocations on
Linux x86 and halfword relocations on Linux ARM/x86 when the addresses fit.
They do not qualify ordinary object addresses at those widths. Static TLS
initializers remain rejected, and external interpreter addresses remain unevaluated.

Fresh unit tests, the existing data suite, all three Linux full target gates and
the Apple x86 Rosetta full gate pass. Ordinary-corpus comparison
retains 1,305 byte-identical emissions and 15 matching refusals across five targets
and three modes. The proof audit retains the same 147 reports; this change adds
no relocation or native correctness theorem.
