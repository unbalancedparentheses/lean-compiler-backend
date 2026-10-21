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
