# Real-program comparisons

The cJSON comparison uses unchanged cJSON 1.7.19 and a pinned cproc frontend.
Both backends receive identical QBE IR, generated once per translation unit.
`scripts/cjson_benchmark.py` fetches sources at fixed commits into ignored build
storage; upstream licenses remain with those sources. No upstream source or IR
is patched. The cproc preprocessing defines in the report supply GCC-header
constants and Unity's explicit LP64 sizes.

Run on an ARM64 host with the Linux test container available:

```sh
LCB_CC=cc python3 scripts/cjson_benchmark.py --docker-container lcb-parity-linux
```

The container must mount `.build/linux-arm64` at `/work` and provide GCC/make.
The script builds cproc in the container and QBE 1.3 with `-O2` on the host.
Compilation times exclude the frontend, assembler and linker; both backends run
on the same host. Timed executable workloads use an internal monotonic clock
inside the native ARM64 Linux VM, excluding Docker startup. Shared-file digests
are checked before crossing the host/VM boundary to avoid stale partial reads.

## Stack-home checkpoint

[Raw report](cjson-stack-homes.json), compiler build identity recorded within.
The library contains 119 functions and 8,319 IR lines (174,676 bytes). All 153
upstream assertions across 18 executable tests pass through our baseline,
optimized backend, QBE and GCC. Unity support is compiled with GCC; each test's
translation unit, including the library implementation, uses the compared backend.

One exception matters: the baseline overflows the default 8 MiB stack in the
10,000-level circular-reference duplication test and needs a 64 MiB retry. The
optimized backend, QBE and GCC pass with the default stack. Our recursive frame
falls from 1,040 to 144 bytes with stack-home reuse.

For 1,000 repetitions parsing and serializing a 200-element JSON document,
three samples per backend produced identical checksums:

| Backend | Median runtime | Library object text bytes | Median backend compile time |
|---|---:|---:|---:|
| Our baseline | 0.7592 s | 94,072 | 0.0683 s |
| Our optimized stack homes | 0.7543 s | 87,472 | 0.0991 s |
| QBE 1.3 | 0.2011 s | 26,220 | 0.0173 s |
| GCC -O2 | 0.1666 s | — | — |

GCC is a separate C-source reference, not an identical-IR backend. These are
local measurements with few repetitions, not general performance claims. The
first QBE compile includes a cold-start outlier; raw samples are retained.
This workload shows why stack reuse alone is insufficient: QBE's memory
promotion, instruction selection and allocation produce much smaller code.


## Callee-saved register checkpoint

[Raw report](cjson-register-homes.json) records the next compiler identity. All
153 assertions still pass, with the same baseline-only default-stack exception.
All four parse/serialize checksums match. Median optimized runtime is 0.4005 s,
versus 0.6630 s for our baseline, 0.1793 s for QBE and 0.1514 s for GCC in this run.
Register homes materially improve this workload, but the result is still slower
than QBE. Cross-run timing variation is visible; compare backends within the same
report and retain the raw samples rather than treating the change as a precise
universal speedup.


## Scalar promotion checkpoint

[Raw report](cjson-scalar-promotion.json) records the compiler with conservative
scalar stack promotion and trivial-phi cleanup. All 153 assertions across 18
executables and all parse/serialize checksums pass, with the same baseline-only
stack exception. Five samples per backend give median optimized runtime
0.3972 s, baseline 0.8751 s,
QBE 0.2148 s and GCC 0.1757 s.
The optimized library's object text is 69,732 bytes, down from 95,436 bytes in
the register-only checkpoint. Other qualification processes were active during
this run; these measurements are comparative evidence for this workload, not an
isolated benchmark or a claim of general performance parity.

## cproc frontend self-compilation

[Raw report](cproc-bootstrap.json) records 18 unchanged frontend translation
units: 293 functions, 32,871 IR lines and 764,079 bytes. A GCC-built, pinned cproc
produces the same IR once for each backend. GCC assembles/links the resulting
objects against Linux libc; the frontend implementation itself is entirely
compiled through the backend under test.

Both our baseline and optimized resulting frontends reproduce all 18 source-unit
IR files plus cJSON byte-for-byte and pass **196/196 original cproc tests**.
Those tests cover generated IR, preprocessing and diagnostics. This goes beyond
compilation success: the resulting compiler performs its normal work.

Original QBE 1.3 compiles and links all units but its resulting frontend crashes
on the first reproduction input. A retained external-GOT-offset regression
isolates the discrepancy. A separately named QBE oracle with the exact test-only
correction reproduces all 19 IR files and passes 196/196 tests. The report keeps
the original failure separate; see [the reduced case and explanation](../UPSTREAM_DISCREPANCIES.md#arm64-elf-external-symbol-offsets-use-the-wrong-got-relocation).

The optimized executable has 315,240 text bytes versus 389,864 for our baseline
and 132,444 for the corrected QBE oracle. These are size measurements, not runtime
performance parity. The report also retains one backend-compilation time per
translation unit; it does not treat that single run as a rigorous speed benchmark.

Reproduce on the same ARM64 Linux container setup:

```sh
LCB_CC=cc python3 scripts/cproc_bootstrap.py
```

This is frontend self-compilation and functional bootstrap checking, not a
bit-identical stage-two/stage-three executable bootstrap or a formal proof.

### Linux x86-64 and RV64 bootstrap qualification

The same runner supports `--target x86_64-linux` and `--target riscv64-linux`.
It builds a native ARM64 stage-one cproc driver configured for the requested
cross target, uses that target's headers/preprocessor and generates its target
ABI IR. Resulting frontends execute under explicitly labeled QEMU user emulation.

- [x86-64 report](cproc-bootstrap-x86_64.json): baseline, optimized and original
  QBE each reproduce 19 IR files and pass 196/196 original tests. No oracle
  correction is used on this target.
- [RV64 report](cproc-bootstrap-riscv64.json): baseline and optimized frontends
  reproduce 19 IR files and pass 196/196 tests. Original QBE fails to link because
  its external-GOT relocation has a forbidden addend. A separately corrected
  oracle passes the same reproduction and tests; the original failure is retained.

The RV64 QBE executables use `-no-pie`, matching the existing target qualification;
Lean output is linked with the compiler driver's default mode. Cross-target runs
are correctness checks and are not native runtime performance measurements.

## Seeded generated C through cproc

[Raw Csmith report](csmith.json) records 16 attempted seeds from Csmith 2.3.0.
Fourteen complete comparisons pass: GCC `-O0` and `-O2`, our baseline and optimized
backend, and unchanged QBE 1.3 produce identical checksums on native ARM64 Linux.
The qualified programs total 9,581 generated C lines and 133,700 QBE IR lines;
the IR also includes Csmith's runtime helper functions. Seeds 20261028 and
20261031 exceed the 15-second GCC `-O0` reference budget and remain explicitly
unqualified, with backend comparison unmeasured for those seeds.

The profile disables direct pointer generation, packed structs, bitfields and
volatile accesses: cproc rejects some incompatible-pointer comparisons emitted
by this Csmith version. Arrays, ordinary structs/unions, arithmetic, loops and
calls remain enabled. Two floating-limit defines supply values expected by the
GCC headers used by Csmith's runtime; generated C and IR are not patched. This
comparison uses original QBE, without the separate bootstrap oracle corrections.

The first run exposed a valid 4,704-byte local array rejected by our old 4 KiB
constant-object bound. Compatibility admission now permits objects through 1 MiB,
subject to the existing fixed-frame and interpreter budgets. Independent target
tests cover entry/nonentry allocation, alignment, page offsets, calls and tails
through 1,047,552 bytes on all five targets.

Install `csmith` and `libcsmith-dev` in the Linux container, then run:

```sh
LCB_CC=cc python3 scripts/csmith_compare.py --seeds 16
```

Package versions, runtime-header hashes, source/IR hashes, compiler identity,
generation options, per-backend checksums and unqualified seeds are retained in
the report. Full generated sources, assembly and logs remain under
`.build/linux-arm64/csmith/<seed>/`. These generated tests are additional evidence,
not exhaustive C/QBE compatibility or semantic preservation proofs.


[An additional 32-seed report](csmith-extended.json), using the same compiler
identity and profile, qualifies 30 more programs; seeds 20261059 and 20261067 time
out in the GCC O0 reference and remain unqualified. Across both batches, **44 of
48 attempted programs** complete all five checksum comparisons, totaling 29,533
generated C lines and 425,809 IR lines including runtime helpers. The four
reference timeouts are not counted as backend passes.


## Direct ARM64 integer register operations

The [cJSON report](cjson-direct-homes.json) records direct use of allocated GP
homes by integer binary operations. All 153 assertions across 18 executables
pass, retaining the baseline-only 64 MiB stack retry. All four parse/serialize
checksums match. Five samples per backend give median runtimes of 0.8051 s for
our baseline, 0.3453 s for our optimized output, 0.2031 s for QBE and 0.1706 s
for GCC. Other qualification processes were active; compare within this run
rather than inferring a precise speedup from earlier measurements.

The optimized cJSON library has 63,500 object text bytes, versus 69,732 at the
scalar-promotion checkpoint. The [cproc bootstrap report](cproc-direct-homes.json)
reduces optimized executable text from 315,240 to 281,892 bytes and retains all
19 byte-identical IR reproductions and 196 original tests for our baseline and
optimized frontends. Original QBE's ARM64 external-offset failure remains
separate from the passing corrected oracle.

A [Csmith rerun](csmith-direct-homes.json) requalifies 14 of the original 16
attempted seeds under this compiler identity; the same two reference timeouts
remain unqualified. These are repeated programs within the 44 unique passing
programs above, not additional unique coverage. The cJSON and Csmith scripts
accept `--compiler PATH` to snapshot and qualify a candidate binary explicitly.


## ARM64 immediate selection

The [cJSON immediate-selection report](cjson-immediates.json) retains all 153
assertions and matching checksums, with the baseline-only stack retry recorded.
Optimized library text is 61,248 bytes versus 63,500 in the direct-home report.
Five-sample median runtimes in this run are baseline 0.7461 s, optimized 0.3202 s,
QBE 0.2002 s and GCC 0.1624 s; concurrent qualification and cross-run variation
prevent interpreting this as a universal speedup.

The [cproc report](cproc-immediates.json) retains 19 identical IR reproductions
and 196 original tests for our baseline and optimized frontends. Optimized
frontend text falls from 281,892 to 267,900 bytes. Original QBE's ARM64 external
offset failure and the separately corrected oracle remain explicitly separated.


## QBE itself as the compiled workload

[The QBE bootstrap report](qbe-bootstrap.json) compiles all 32 unchanged QBE 1.3
translation units through pinned cproc: 725 functions and 81,635 IR lines. Both
our baseline and optimized resulting QBE executables reproduce 455 successful
original-fixture assemblies across QBE's six target settings, plus all 32
self-source IR assemblies, byte-for-byte against GCC-built original QBE. Each
also reproduces the original Windows/TLS rejection and passes the original
ARM64 runner's 58 executable tests. Across our two executables that is 974 exact
successful assembly comparisons and two matching rejections.

These are QBE programs compiled by our ARM64 backend. Their ability to emit
Windows assembly does **not** implement Windows ABI support in our own backend.
Only the ARM64 fixture outputs are executed here; other target outputs are byte
comparisons. The broader direct target suites remain separate evidence.

This workload exposed QBE's 16 MiB global instruction buffer, exceeding our
former 1 MiB data bound. Native admission now allows 256 MiB module data and
emits ordinary zero-only globals into BSS; the interpreter still refuses more
than 1 MiB before allocating its byte arrays. Object size and page/tail accesses
are independently checked on all five targets.

Original QBE compiling itself from this cproc IR produces a broken parser: the
first fixture fails with “missing second operand in copy.” The report retains
that failure. The existing, separately named external-GOT-offset correction
restores all 487 successful assembly reproductions and 58 runner tests. No new
oracle patch is introduced, and neither upstream source nor input IR is edited.

Five samples compiling all 32 self-source IR files to ARM64 assembly in the VM
give these median workload times, including process startup and `/dev/null`
output: GCC-built reference QBE 0.1035 s, our baseline-built QBE 0.7139 s, our
optimized-built QBE 0.2811 s, and corrected-QBE-built QBE 0.1639 s. Optimized
executable text is 662,628 bytes versus 1,070,964 baseline and 352,532 for the
corrected QBE comparison. Local concurrent workloads and few repetitions limit
performance conclusions; original failing QBE is not counted as a timing pass.

Reproduce with `LCB_CC=cc python3 scripts/qbe_bootstrap.py`. The script retains
source/IR hashes, exact compiler identity, original failures, patch hash, native
runner logs and all timing samples. SQLite and Lua were also probed, but cproc
rejects their volatile stores before backend input; SQLite additionally requires
unsupported long-double expressions. Those probes are not backend qualification.


## Direct ARM64 comparison operands

The [cJSON comparison-lowering report](cjson-comparisons.json) retains all 153
assertions and checksums, with the baseline stack retry still explicit. Optimized
text falls from 61,248 to 55,568 bytes. The [QBE rerun](qbe-comparisons.json)
retains all 487 successful assembly reproductions, the expected Windows/TLS
rejection and 58 original runtime tests per passing executable; optimized QBE
text falls from 662,628 to 633,184 bytes. Original QBE's self-compilation failure
remains separate from the corrected oracle.

Host contention increased during these runs: the raw cJSON sample medians are
baseline 1.9613 s, optimized 0.7166 s, QBE 0.4256 s and GCC 0.2623 s. QBE workload
medians are reference 0.1196 s, baseline 0.8357 s, optimized 0.3185 s and corrected
QBE 0.1925 s. These do not establish a runtime improvement over earlier runs;
the code-size reduction and functional comparisons are the stable findings.


## Additional generated-C coverage

[The comparison-lowering Csmith batch](csmith-comparisons.json) tries seeds
20261069–20261084 and qualifies 13 new programs, adding 129,830 IR lines. GCC
O0/O2, our baseline/optimized backend and original QBE agree on each checksum.
Seeds 20261073, 20261075 and 20261077 exceed the GCC O0 reference budget and
remain unqualified; their backend results are unmeasured. Across the three
nonoverlapping batches, **57 of 64 attempted programs** qualify, totaling
555,639 IR lines including runtime helpers. This is corpus evidence, not a
percentage estimate of language compatibility.


## Remaining scalar and FP register transfers

The [cJSON scalar-home report](cjson-scalar-homes.json) retains all 153 assertions
and matching checksums, including the baseline-only stack retry. Optimized text
is 54,536 bytes, down from 55,568. Same-run medians are baseline 0.6474 s,
optimized 0.2617 s, QBE 0.1738 s and GCC 0.1428 s.

The [QBE scalar-home report](qbe-scalar-homes.json) retains 487 successful assembly
reproductions and 58 original tests per passing executable. Optimized text is
628,064 bytes, down from 633,184. Median workload times are reference 0.0906 s,
baseline 0.6779 s, optimized 0.2431 s and corrected QBE 0.1473 s. Original QBE's
self-compilation failure remains separate. Timing changed substantially with
host load; compare within a run and do not infer a precise cross-run speedup.

Independent native matrices now exercise baseline, allocated and optimized output
for all 30,460 integer, 896 floating and 1,228 conversion cases. Added 24-value
single/double pressure tests cover spills, calls, conversions and boolean results;
word-normalization controls retain nonzero high bits in the source value.


## Direct ARM64 memory and call-result transfers

The [cJSON memory-home report](cjson-memory-homes.json) retains 153 assertions
and matching checksums, including the baseline-only stack retry. Optimized text
is 47,232 bytes, down from 54,536. Same-run medians are baseline 0.6622 s,
optimized 0.2556 s, QBE 0.1774 s and GCC 0.1489 s.

The [QBE memory-home report](qbe-memory-homes.json) retains 487 successful
assembly reproductions and 58 original runtime tests per passing executable.
Optimized text is 562,896 bytes, down from 628,064. Same-run medians are
reference 0.0997 s, baseline 0.6993 s, optimized 0.2491 s and corrected QBE
0.1598 s. Original QBE's self-compilation failure remains separate. These local
timings are load-sensitive; code size and functional results are more stable.

Independent memory checks cover 4,209 generated native cases, 1,664 C-owned
buffer cases and 2,208 C-oracle cases in baseline and optimized modes. Targeted
controls cover address/result home aliasing, signed and unsigned narrow loads,
FP call results and callee-save restoration. All 150 baseline ARM64 fixture
assemblies remain byte-identical to the preceding compiler.


## Csmith after direct memory lowering

[The memory-home batch](csmith-memory-homes.json) tries seeds 20261085–20261100.
Eleven programs (114,846 IR lines including runtime helpers) match GCC O0/O2,
our baseline/optimized output and unchanged original QBE. Seeds 20261087, 20261088, 20261090, 20261091, 20261095
exceed the GCC O0 reference budget and remain unqualified. The four independent
batches now total **68 qualified programs out of 80 attempts**, 670,485 IR
lines and twelve unqualified reference timeouts. The earlier rerun is not
counted as additional unique programs. Generation restrictions remain unchanged.


## Compact ARM64 constants

The [cJSON constant-materialization report](cjson-compact-constants.json) retains
153 assertions and matching checksums, including the baseline stack retry.
Optimized text is 47,136 bytes (24 fewer instructions than the memory-home run).
Same-run medians are baseline 0.7939 s, optimized 0.3094 s, QBE 0.2084 s and
GCC 0.1674 s. Concurrent local load makes cross-run speed comparisons unreliable.

Allocated ARM64 functions use MOVZ/MOVN plus necessary MOVK halfwords, including
shifted initial halfwords. The independent instruction matrix now covers 1,274
functions and 10,192 cases per lowering mode, including a corrupted MOVN control.
All 600 baseline/non-ARM fixture assemblies remain byte-identical; an additional
eight-seed campaign passes 512 generated input cases across independent models.


## QBE compiled for Linux x86-64 and RV64

[The x86-64 report](qbe-x86_64.json) and [RV64 report](qbe-riscv64.json) compile
QBE's 32 unchanged translation units through target-specific cproc IR. The
resulting compiler executables run under QEMU user emulation. Each baseline and
optimized executable reproduces 455 successful fixture assemblies across six
QBE targets plus 32 self-IR assemblies, and matches the one upstream Windows/TLS
rejection. Each also passes 58 original tests by generating native ARM64 output.
The output tests do not establish native x86-64/RV64 execution or add Windows
target support to our backend. Reference GCC-QBE runs natively, so its timing is
not a like-for-like performance comparison with the emulated executables.

The original x86-64 QBE-built executable diverges on Apple ARM64 floating labels;
the report retains both assembly hashes. An independently reduced conditional
external-address test exposes overwritten comparison flags. The separately named
oracle correction passes six signed-addend cases and the full bootstrap. Original
RV64 QBE fails to link external GOT addends; its existing separate correction
passes the bootstrap. RV64 oracle executables require `-no-pie`, recorded per
backend. Neither original failure counts as a successful comparison.

Reproduce with `python3 scripts/qbe_bootstrap.py --target x86_64-linux` or
`--target riscv64-linux`, using the documented Linux qualification container.
