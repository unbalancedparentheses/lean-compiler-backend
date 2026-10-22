# AMD64 word-result normalization

Compiler `11be972e96d4fc9de4c6df28cd1fe7f5ddf5c728ff01348bd6d1398eef1748b4`
omits a final EAX self-move after word copy, cast, binary, unary and load paths
that already normalize their result. Calls, conversions, allocations and other
paths retain conservative normalization. Fresh measurements compare against
`3c25a0a8aaf94a6a53adf6c5d6cec78872809b1d7bebc66f45ad5d4c5202a40f`.

Both AMD targets pass all three compiler modes against independent C:
109,440 arithmetic/bitwise/shift checks plus 3,232 narrowing, load, symbol/TLS
and ABI checks per mode. Linux x86 executes through QEMU and macOS x86 through
Rosetta. Original QBE passes a separate legal-shift arithmetic profile of 74,670
checks; that profile does not cover the additional C-only cases. Tests retain
structural checks for call and unsigned-FP conversion normalization. A mutation
corrupting low call-result bits is detected; explicit widening means this is
not evidence that omitted upper-call normalization alone would be observable.

Recompiling the same 17 zlib IR units reduces summed object text from 250,905 to
245,583 bytes (5,322 bytes, 2.12%). Assembly instructions fall from 70,920 to
68,303 and EAX self-moves from 4,377 to 1,760. Both snapshots pass zlib examples
and 12 payload/compression-level cases: compressed bytes match GCC, and Python
and compiled decompression reproduce the inputs. Runtime speed was not measured.

Fresh units and both full AMD target gates pass. The proof audit's 147 reports
remain exactly unchanged. Corpus comparison has 1,001 identical assemblies,
304 expected AMD-only changes and 15 matching refusals. The raw exact-equivalence
report records those changes as failures; the separate audit permits only
deleting 3,044 EAX self-moves, with all other bytes unchanged. Neither these
tests nor the assembly audit constitute a semantic-preservation proof.

Reports retain the actual compiler identities and hashes. Matrix IR and C,
the narrowed original-QBE profile and per-object measurements are included.
