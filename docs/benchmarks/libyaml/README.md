# Libyaml 0.2.5 qualification

Compiler `11be972e96d4fc9de4c6df28cd1fe7f5ddf5c728ff01348bd6d1398eef1748b4`
compiles all eight libyaml library units and all thirteen original driver units:
351 functions and 70,576 cproc IR lines per target. The pinned source commit is
`2c891fc7a770e8ba2fec34fc6b545c672beb37e6`; original C/header sources and IR are
unmodified. Four version definitions substitute upstream's CMake config template,
with static-library and GCC-header compatibility defines recorded in the reports.
This directly compiles the original units; it does not invoke the upstream build
system or claim its complete external YAML suite.

Each of Linux ARM64, x86-64 and RV64 passes all three LCB modes against both GCC
O0 and O2: 52 executable checks per mode, comparing complete stdout, stderr and
exit status. Checks include upstream version and UTF-8 reader assertions, all
thirteen drivers, seven generated documents, scanner/parser/loader execution,
upstream emit/dump/reparse assertions, and three malformed-input refusals.
A deliberately corrupted compiled driver return is detected. GCC compiles the
original C directly; LCB and QBE receive identical target-specific cproc IR.

Original QBE passes the x86 profile. On ARM it fails the upstream reader check;
on RV it fails to link a data-address relocation even with the recorded reference
non-PIE profile. Separately corrected QBE passes all 52 checks on each target.
Original and corrected results remain distinct, including build and execution
status. Every LCB executable uses default linking. ARM runs natively in the Linux
VM; x86 and RV execute through QEMU. These measurements establish finite workload
qualification, not full QBE parity or formal correctness. Runtime speed was not
measured.

Reproduce with `LCB_CC=cc python3 scripts/libyaml_compare.py --target TARGET
--compiler PATH --report PATH`. The script pins source/frontend revisions,
snapshots the compiler, records hashes and diagnostics, clears previous backend
outputs, and only executes freshly completed builds.

An initial harness preflight incorrectly expected unresolved aliases to fail at
the parser stage; aliases are valid parser events and resolution belongs to the
loader. That excluded preflight was replaced with a verified malformed sequence.
Review also tightened stale-output handling and mandatory-backend checks before
the fresh three-target runs published here. No compiler or upstream-source change
was required for this workload.
