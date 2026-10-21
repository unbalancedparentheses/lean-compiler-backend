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

## Apple ARM64 aggregate ABI discrepancies

`scripts/aggregate_edges.py` reproduces each of these on pinned QBE 1.3 and checks
that Lean-generated code passes the same C driver. These are separate discrepancy
controls, never included in the count of matching upstream fixture executions.
Vendored QBE remains unchanged.

- [Padded float aggregate](../tests/regressions/qbe-padded-float-aggregate.ssa):
  `align 8 { s }` has one float plus tail padding. QBE's `typclass` divides its
  eight-byte size by four and consumes two FP registers. The C ABI passes this
  padded object in a GP register, leaving d0 for the next double. The
  [driver](../tests/regressions/qbe-padded-float-aggregate.c) clears d2 and verifies
  the next double; QBE returns the wrong value. Lean requires a homogeneous
  layout's extent to match its size, including when nested.
- [Aggregate variadic argument](../tests/regressions/qbe-aggregate-variadic.ssa):
  QBE's aggregate branch of `argsclass` ignores the Darwin variadic marker and
  puts a small aggregate in GP registers. C `va_arg` reads the stack instead.
  The [driver](../tests/regressions/qbe-aggregate-variadic.c) reads 123 with Lean
  output; original QBE puts the subsequent scalar 7 in that stack position.
- [Short aggregate return](../tests/regressions/qbe-aggregate-tail-overread.ssa):
  QBE's `ldregs` loads a full eight-byte register from a one-byte object. Its
  source already notes the possible out-of-bounds read. The
  [driver](../tests/regressions/qbe-aggregate-tail-overread.c) places the byte
  immediately before a protected page; original QBE faults, while Lean loads
  exactly one byte and returns 42. Ordinary aggregate comparisons use readable
  objects and remain separate from this guarded boundary test.

## Linux scalar and aggregate ABI discrepancies

The original QBE source remains unchanged. `scripts/target_scalar.py` retains
original Lean inputs and makes narrow argument/return extensions explicit only
for the QBE reference: pinned RV64 omits required subword return extensions, and
AMD64 narrow call arguments disagree with Clang C callees in some signed-halfword
cases. The independent C caller still checks the original Lean source.

`scripts/target_aggregate.py` isolates three RV64 exact-capacity pressure failures
(single float, single double and mixed float/integer aggregates). In pinned
`rv64/abi.c`, `argsclass` uses `>=` when deciding whether aggregate register banks
fit, incorrectly falling back when the remaining capacity exactly matches the
required count. Full original Lean/C pressure checks remain mandatory. Other QBE
cases run separately, with the specific oracle failures printed explicitly.
`scripts/riscv_abi.py` also reproduces the reduced
[exact-FP-capacity input](../tests/regressions/qbe-rv64-exact-fp-capacity.ssa)
with its [C caller](../tests/regressions/qbe-rv64-exact-fp-capacity.c): Lean must
pass and pinned QBE must return the specific failure status.

## AMD64 zero-allocation alignment

`scripts/zero_alloc.py` reproduces an empty-leaf-frame `alloc16 0` mismatch:
pinned QBE emits the unadjusted entry stack pointer, which is only 8 modulo 16
because of the return address. The reduced probe returns `50 42 42` instead of
`42 42 42` for static, dynamic and loop cases. Lean passes the original source.
A separate QBE reference uses 16-byte allocations for the zero-sized constants;
this preserves the tested alignment/live-object properties without claiming
that original QBE passed. Zero-sized objects are never dereferenced in the
native test; the interpreter separately rejects such accesses.
