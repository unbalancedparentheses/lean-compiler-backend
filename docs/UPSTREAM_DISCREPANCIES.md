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
Python, Lean interpretation, baseline and optimized Lean native code, corrected-QBE native code and
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

The 1024-argument boundary suite also retains a [single signed-byte outbound
call](benchmarks/argument-limits/rv-narrow-input.ssa) with an [independent C
callee](benchmarks/argument-limits/rv-narrow-caller.c): pinned RV64 and both AMD64 targets under Clang
QBE pass 140 where an optimized C callee (`-O1`) expects -116; an
unoptimized callee may mask the missing extension. QBE's call specification explicitly permits
unextended subword arguments; this differs from consuming unspecified upper bits
of a subword return. The AMD64 results belong to the existing Clang
narrow-call discrepancy class. The [Linux Clang reproduction](benchmarks/argument-limits/linuxx86-clang-narrow.json)
retains passing LCB controls and a GCC callee that masks the original-QBE defect. All LCB profiles run unchanged against C; original
QBE comparisons omit the two narrow/aggregate mixtures on these targets.

Pinned RV64 also emits an out-of-range `add t0,fp,2048` for the second field of
the final argument in a [132-pair signature](benchmarks/argument-limits/rv-aggregate-132.ssa).
The [131-pair control](benchmarks/argument-limits/rv-aggregate-131.ssa) assembles.
The retained [assembler result](benchmarks/argument-limits/argument-rv-aggregate-minimal.log)
records the boundary. The emitter's `Oaddr` test checks the negative side of the
immediate bound but admits this oversized positive offset. The argument suite
therefore additionally excludes the 1024-all-aggregate original RV64 oracle;
LCB's independent C execution still covers it in all three modes. Original QBE
source is unchanged, and RV64 oracle executables retain their explicit `-no-pie`
link profile while LCB uses the default.

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


## Darwin quoted TLS names

`scripts/quoted_names.py` reproduces pinned QBE's assembly failure for a quoted
thread-local name: it appends `$tlv$init` outside the closing quote. Lean puts this
compiler-generated suffix inside the quote. The original Lean source must pass
C lookup/call tests; the separate QBE reference renames only the TLS symbol to an
ordinary identifier. Quoted functions/data and exact Darwin prefix behavior
remain checked in both outputs. Vendored QBE is unchanged.

## ARM64 ELF external-symbol offsets use the wrong GOT relocation

The cproc self-compilation comparison exposed this on native Linux ARM64. The
[reduced IR](../tests/regressions/qbe-arm64-extern-offset.ssa) returns
`extern $external_bytes + 32`; its [C driver](../tests/regressions/qbe-arm64-extern-offset.c)
checks the result against `external_bytes + 32`. Both Lean modes pass. Original
QBE 1.3 links successfully but returns the wrong pointer (driver exit 1).

QBE folds the addition into a symbol constant and emits `:got:symbol+32` /
`#:got_lo12:symbol+32`, then treats the loaded GOT value as the offset address.
A GOT lookup must obtain the symbol's base address before applying the offset.
The original QBE-compiled cproc subsequently crashes in `strtoull`, having read
an incorrect `tok.literal` pointer. Rebuilding QBE inside Linux reproduces the
same failure, excluding the macOS-hosted cross-compiler as its sole cause.

`scripts/linux_arm64.py` retains the original wrong-pointer control and requires
both Lean modes to match C. `scripts/cproc_bootstrap.py` additionally builds a
separately named oracle with the exact
[test-only correction](../tests/upstream/qbe-1.3-arm64-extern-offset.json), after
checking the pinned `arm64/isel.c` hash. It splits long external symbol constants
into a zero-offset address load and an explicit integer addition before register
allocation. The original upstream source and cproc input IR remain unchanged.

With this bounded oracle correction, the QBE-compiled cproc frontend reproduces
19 stage-one IR files byte-for-byte and passes all 196 original cproc tests, as
do the baseline and optimized Lean-compiled frontends. The original QBE crash
remains a recorded failure; corrected-oracle successes are reported separately.
This is a tested comparison correction, not a proof or a claim about newer QBE.

The same correction is also needed when compiling QBE itself from cproc IR.
Original QBE's resulting executable rejects the first retained fixture with
“missing second operand in copy.” With the existing external-offset correction,
it reproduces 487 successful assemblies and passes 58 original ARM64 runtime
tests, matching both Lean-built executables. See the
[QBE bootstrap report](benchmarks/qbe-bootstrap.json); the original failed
self-compilation remains separate from the corrected oracle.

## RV64 external-symbol offsets fail GOT relocation linking

The same reduced external-offset IR also exposes a pinned QBE 1.3 RV64 issue.
Its emitted `la a0, external_bytes+32` creates an `R_RISCV_GOT_HI20` relocation
whose addend is forbidden by the linker. The C driver therefore fails to link
with the original QBE output. Both Lean modes link and return the correct pointer.

The RV64 cproc self-compilation comparison records the original QBE frontend
link failure separately. Its separately named oracle applies the exact
[RV64 test-only correction](../tests/upstream/qbe-1.3-rv64-extern-offset.json),
checking the pinned `rv64/isel.c` hash first. As in ARM64, long external symbol
constants become a zero-addend address load plus a normal integer addition before
allocation. Under QEMU RV64, our baseline, optimized backend and the corrected
oracle each reproduce 19 stage-one IR files and pass all 196 original cproc tests.

`scripts/linux_targets.py` retains the original link rejection on RV64 and
requires matching pointer results from both Lean modes. On x86-64 the original
QBE pointer check passes; this unconditional-address regression needs no correction.


## AMD64 external-address formation overwrites conditional flags

QBE self-compilation for x86-64 exposed a separate pinned QBE 1.3 issue.
Its generated compiler emits `_"Lfp2"` instead of `"Lfp2"` for Apple ARM64
floating constants. Replacing only the backend-built `arm64/emit.c` object with
our baseline object restores the exact original assembly output.

The [reduced IR](../tests/regressions/qbe-amd64-extern-flags.ssa) chooses between
a local symbol and an external symbol plus 140, based on an integer equality.
The independent [C caller](../tests/regressions/qbe-amd64-extern-flags.c) checks
both branches. Original QBE places an `addq $140` between `cmpl` and `cmov`,
overwriting the equality flags. Our baseline, allocated and optimized outputs
pass; original QBE returns the wrong pointer. Linux x86-64 and macOS x86-64
runners retain this mismatch explicitly.

The [test-only correction](../tests/upstream/qbe-1.3-amd64-extern-flags.json)
uses a flag-preserving LEA plus constant materialization for the address addend.
It snapshots the symbol constant before growing QBE's internal vectors. The
bootstrap harness verifies the pinned source hash and applies the exact patch
only to a separately named oracle copy; vendored sources and frontend IR remain
unchanged. The reduced checks also cover positive/negative signed-32-bit addends.
This addresses the measured oracle discrepancy without extending our proof claims.

## AMD64 oversized immediate shift counts

Pinned QBE 1.3 defines shift counts modulo the result width (`doc/il.txt`,
lines 698–703), but its AMD64 emitter can leave an oversized immediate in the
assembly. For example:

```qbe
export function w $shift(w %x) {
@entry
 %result =w shr %x,1553590636
 ret %result
}
```

The count is equivalent to 12 for a word result. Original QBE emits
`shrl $1553590636, %eax`, which GNU assembler rejects with an operand-type
mismatch. The generated long-shift cases also expose `shrq $4294967295`.
No vendored source or original oracle is patched.

The raw cross-target campaign (`scripts/cross_fuzz.py`, seeds
20263000–20263031) qualifies all 32 seeds / 3,328 inputs per LCB mode on Linux
ARM64, x86-64 and RV64. Original QBE matches all 32 on ARM64/RV64, but only one
on x86-64; 31 x86 reference failures are retained and excluded from common
qualification. Reports `cross-fuzz-{arm64,x86,rv64}-raw.json` distinguish the
independent Python/interpreter/LCB results from original-QBE results. x86/RV
execution uses QEMU, and original RV64 QBE uses explicitly recorded non-PIE
linking. Every target's return-corruption control is detected.

## RV64 instruction-selection assertion on generated C (20267003)

The unchanged scalar Csmith seed 20267003, lowered by the pinned cproc frontend,
produces 21,520 QBE IR lines. LCB baseline and optimized modes match native/cross
GCC O0/O2 checksum `1EAFAEB2`; original QBE also matches on ARM64 and AMD64.
The original RV64 backend aborts during compilation with
`Assertion failed: (k == fn->tmp[r0.val].cls), function fixarg, file isel.c, line 80.`
The [identity-bound RV64 report](benchmarks/csmith-rv-cap-fresh-32.json) records
this as LCB-only qualified and leaves the original-QBE comparison unqualified.
Its explicit original-QBE `-no-pie` link profile cannot affect this earlier
compilation failure. No vendored QBE source is changed or corrected oracle used.
The retained IR hash is
`cf029c85e59c76e32cc03ce97dc73799d28d872f800e60e495685f0a20da27ce`.
This is an observed upstream assertion, not a proof about every generated input.

## AMD64 environment flag and variadic overflow offset

Pinned QBE aliases its environment flag with the low bit of the encoded variadic
overflow offset. A definition with an unused environment parameter reads stack
varargs one byte late. The [reduced input and qualification](benchmarks/variadic-markers/README.md)
retain unchanged original failures, independent C checks, and a separately passing
register-only signature. Removing the environment is a diagnostic control only.

## AMD64 word TLS subtraction

The [minimal retained comparison](benchmarks/amd-immediates/minimal-tls-word-sub.json)
uses a word subtraction of one from a TLS address, explicitly widened with extuw.
All three LCB modes match independent C on Linux and macOS x86. Original QBE
emits a Linux TPOFF32 relocation that fails default linking and an Apple
`addq $4294967295,%rax` that fails assembly. The original reference is unchanged;
TLS remains mandatory in the LCB immediate matrix and is excluded only from its
separately qualified original-QBE profile. Oversized constant-shift assembler
failures are also retained separately in that matrix's raw reports.
