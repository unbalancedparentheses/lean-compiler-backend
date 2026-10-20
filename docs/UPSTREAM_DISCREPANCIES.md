# Measured upstream discrepancies

These are retained comparisons against pinned QBE 1.3, not claims about later
upstream revisions. No upstream report has been submitted by this project.
The original `third_party/qbe` snapshot and its hashes remain unchanged.

## Partial store forwarding leaks discarded bits

The memory generator found this while comparing independently evaluated byte
arrays, Lean interpretation and native output from both backends. The reduced
[IL case](../tests/regressions/qbe-storew-overlapping-load.ssa) initializes eight
bytes to zero, stores the low 32 bits of a 64-bit argument, then loads four bytes
starting at offset one. A [native C reference](../tests/regressions/qbe-storew-overlapping-load.c)
uses `memcpy` to perform the same defined, unaligned accesses.

For input `0x123456789abcdef0`:

| Path | Result |
| --- | --- |
| Python byte-array model | `0x009abcde` |
| Native C reference through Nix Clang | `0x009abcde` |
| Lean interpreter | `0x009abcde` |
| Lean-generated ARM64 | `0x009abcde` |
| Original QBE 1.3 ARM64 | `0x789abcde` |

The zero-initialized byte at offset four must remain zero. QBE's load-forwarding
pass instead shifts a long value without masking away a byte outside the stored
word. Its `load.c` `MustAlias` path computes a coverage mask `msk1`, but the
condition before `mask()` can omit that mask for a partial slice. The disposable
test-oracle correction checks the actual intersection against the whole slice
mask, `msks`, before deciding to omit masking.

## How qualification handles it

`scripts/memory.py` builds and runs **both** the original pinned QBE and a
separately named comparison copy with the exact
[test-only correction](../tests/upstream/qbe-1.3-loadopt-mask.json). The correction
is applied only after checking the original `load.c` hash against the lock and
requiring one exact source match. Production `lcb` remains Lean code; it neither
invokes nor links either C compiler backend.

The reduced control requires the original QBE result to differ and the Lean,
corrected comparison and C results to agree. Generated overlap cases compare
Python, Lean interpretation, Lean native code, corrected-QBE native code and
separately generated native C references. Every original-QBE mismatch is recorded
and explicitly reported as a mismatch, rather than counted as a match. An
original-QBE mismatch outside the generated overlap cases still fails the gate.
Any disagreement with Python, C or the corrected comparison also fails.

Successful runs retain exact input batches, expected values, original/corrected
outputs and discrepancy records under `.build/memory-qbe-discrepancies/`. Failures
retain their own artifacts under `.build/memory-failures/`. The original-versus-
corrected split is part of the reported evidence; it is not full upstream-suite
qualification or a proof of the correction. Re-audit this control and remove or
revise the correction when changing the upstream baseline.

The lesson for the full port is to preserve the documented memory semantics and
retain this regression when porting QBE's load optimization. Passing comparison
tests against a single existing compiler cannot establish correctness.

## Two inline TLS call arguments assert during register allocation

Pinned QBE 1.3 with `-t arm64_apple` aborts in `rega.c` (`!isreg(i->to)`) on the
[reduced two-TLS-argument input](../tests/regressions/qbe-two-tls-call-arguments.ssa).
The two operands refer to the same current-thread object. The retained
[C driver](../tests/regressions/qbe-two-tls-call-arguments.c) checks pointer identity
and the initialized value; Lean-generated native code passes it.

`scripts/tls.py` explicitly reproduces and reports the original assertion, never
counting it as a matching QBE result. Its larger native Lean/C test checks eight
concurrent threads, external TLS, and TLS resolution among live GP/FP call
arguments. For the QBE comparison only, that input resolves addresses through
separate address-returning helper calls before passing ordinary temporaries.
That source-level workaround passes the same C checks; it is reported separately
and is not a claim that original QBE compiles the inline form. The vendored QBE
source is unchanged. The original upstream `tls.ssa` fixture needs no workaround.
