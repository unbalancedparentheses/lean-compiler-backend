# Overnight Csmith campaign

Seeds 20269000–20269063 give 64 new generated C programs under the established
scalar/ordinary aggregate profile. Fifty qualify on each of Linux ARM64, x86-64
and RV64: GCC O0/O2, baseline/optimized LCB and unchanged QBE produce the same
checksums. Fourteen GCC O0 reference timeouts per target remain unqualified;
none are counted as backend passes. No original-QBE-only failure occurred in
this batch. Each target's qualified set contains 478,102 IR lines and 5,173
functions. These are 50 unique common programs executed on three targets, not
150 distinct random programs.

[ARM](arm.json), [x86](x86.json) and [RV](rv.json) initial reports use compiler
identity `81000f96ded3564ff24256c8c736be2f853d88c1c67ce0429ace201fc251c003`.
[Input qualification](cross-target-inputs.json) verifies identical C after removing
only the generator output-path comment. Target-configured IR differs because of
platform details such as plain-char signedness; within each target every backend
receives unchanged identical IR. Pointers, packed structs, bitfields and volatile
accesses remain disabled by this profile.

The [replay harness](../../../scripts/csmith_replay.py) additionally runs all
three modes on identity `49f1c29def2b2df50394c242f67719bc7202ec3208ab6853fd3c3962fb676207`,
checking retained C/IR hashes and the recorded independent-reference checksums:

| Target | Baseline | Allocated | Optimized |
|---|---|---|---|
| Linux ARM64 | [50 passed](arm-baseline.json) | [50 passed](arm-allocated.json) | [50 passed](arm-optimized.json) |
| Linux x86-64 | [50 passed](x86-baseline.json) | [50 passed](x86-allocated.json) | [50 passed](x86-optimized.json) |
| Linux RV64 | [50 passed](rv-baseline.json) | [50 passed](rv-allocated.json) | [50 passed](rv-optimized.json) |

Replays add mode coverage, not unique seeds, and do not rerun GCC/QBE. Every
campaign/replay detects deliberately corrupted return code. ARM execution is
native inside the Linux VM; x86/RV execution uses QEMU. Original RV QBE uses the
explicit `-no-pie` reference profile; all LCB executables use default linking.
No native RV hardware, unrestricted Csmith coverage or preservation proof is claimed.
