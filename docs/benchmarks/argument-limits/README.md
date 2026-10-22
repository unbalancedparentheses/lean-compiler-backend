# Bounded 1024-argument compatibility

The compatibility cap increases from 64 to 1024 typed arguments/parameters,
including aggregate arguments. The certified profile still permits at most
eight parameters. Incoming fixed frames and each outgoing argument area remain
bounded to 1 MiB, including dynamic calls and private aggregate copies.
AArch64 uses its reserved address scratch register for outgoing stores whose
byte/half/word offsets exceed the instruction's scaled immediate range.

Compiler identity: `97ca481485a7977677a97f62e8f5955ac59f404173063f37d8af44209041dd20`.
The [independent harness](../../../scripts/argument_limits.py) checks seven
signatures: mixed scalars at 64/65/128/1024 arguments, narrow/aggregate mixtures
at 65/1024, and 1024 all-aggregate arguments. Sixteen seeds and five call paths
(C to LCB, internal direct/indirect, LCB to C direct/callback) give 560 C cases
per lowering mode and target. All three modes run; corrupted return values must
fail the C oracle. 1025 parameters/direct/indirect arguments, oversized incoming
and outgoing areas, and nine certified parameters must be rejected.

[Validation](validation.json) records fresh build/units and target gates.
The [ordinary corpus comparison](assembly-equivalence.json) retains 1,305
byte-identical assemblies and 15 matching refusals against the preceding
lookup-map compiler. This is bounded compatibility evidence, not unlimited
resource support or end-to-end verification. The proof audit is unchanged.

Original QBE comparison covers all seven profiles on both ARM targets and Linux
x86, five on Apple x86 (four scalar profiles plus all-aggregate), and four scalar
profiles on RV64. Every LCB profile still runs against independent C. See
[upstream discrepancy details](../../UPSTREAM_DISCREPANCIES.md) and the
[current reduced RV results](minimal-current.json). The signed-byte case needs
an optimized C callee (`-O1`) to expose the caller extension error. The RV
132-pair signature emits an illegal positive 2048-byte immediate in original
QBE; its 131-pair control assembles. Vendored QBE remains unchanged. RV original
oracle executables use `-no-pie`, while LCB executables use the default link.

The [dynamic outgoing suite](dynamic-outgoing.json) adds 529 ordinary arguments
(530 with environment), including 515 four-double HFAs. Eighty calls per mode
check direct/indirect/environment paths, late TLS address resolution, and live
16/8192-byte runtime allocations across calls. Every HFA field and scalar tail
is checked by C; ARM tests require the expected large byte/half/word offsets and
detect a deliberately displaced byte store. All five targets pass all three LCB
modes and unchanged original QBE on this identical fixture, using default links
(including RV). TLS coverage here is single-threaded. This independent regression
is integrated into host and target gates.
