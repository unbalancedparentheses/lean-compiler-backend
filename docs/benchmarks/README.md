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
