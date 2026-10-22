# Fresh one-level pointer Csmith comparison

Compiler `11be972e96d4fc9de4c6df28cd1fe7f5ddf5c728ff01348bd6d1398eef1748b4`
was tested on seeds 20271000–20271063 with Csmith 2.3.0 and pinned cproc.
Each of Linux ARM64, x86-64 and RV64 qualifies the same 11 programs, totaling
48,116 IR lines per target. GCC O0/O2, LCB baseline/optimized and unchanged QBE
produce matching checksums. Allocated-mode replay passes those same 11 seeds;
it reuses recorded reference checksums and adds no unique random programs.
Corrupted-return controls are detected by each campaign and replay.

Of the 64 attempts per target, 50 encounter known cproc incompatible-pointer
diagnostics before backend IR and three time out in the GCC O0 reference.
These 53 attempts are unqualified, not backend passes. There are no LCB-only
qualified cases or unexpected backend failures. This profile enables one-level
pointers without const qualifiers; packed structs, bitfields and volatile
accesses remain disabled. It is not unrestricted C or pointer qualification.

ARM64 executes natively in the Linux VM; x86-64 and RV64 use QEMU. LCB uses
default linking everywhere. Original RV QBE uses the explicitly recorded
non-PIE link profile. Generated C is unchanged; source-body comparison across
targets removes only the generator's options comment containing its output path.
Each backend comparison receives identical target-specific cproc IR. Reports
retain source/IR hashes, compiler and harness identities, diagnostics and scope.

Reproduce a campaign with `scripts/csmith_compare.py --profile pointers
--seed-start 20271000 --seeds 64`, selecting the target and an isolated work
directory; add `--qbe-no-pie` only for the original RV reference. Replay with
`scripts/csmith_replay.py --mode allocated` using the completed campaign report.
