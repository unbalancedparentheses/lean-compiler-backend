# Lookup-only SSA and storage-home maps

The SSA constructor replaces linear binding lookup/update with hash maps. The
three assembly emitters replace repeated linear storage-home lookups with hash
maps. They never enumerate these maps to choose output order. Home-map creation
reverses the original list to preserve its first-match lookup semantics.

[Paired report](paired-report.json) uses the unchanged 65,537-byte structure
workload, three alternating before/after rounds on the same Apple ARM host,
and exact compiler identities. All before/after assembly bytes match in every
mode and round. Median whole backend compilation times, including checks:

| Mode | Before (seconds) | After (seconds) |
|---|---:|---:|
| Baseline | 11.792 | 0.628 |
| Allocated | 12.295 | 1.302 |
| Optimized | 57.506 | 2.550 |

Unchanged original QBE's median is 2.217 seconds. These are local measurements
on this particular large scalar-expanded-copy IR, not general speed or parity
claims. The timed campaign ran without other heavy jobs from this worker;
unrelated host work was not controlled. [Harness](paired_compile.py) retains
all individual samples, input/assembly hashes and binary identities.

The before identity is `6d5042d15a30f932da7a92ad5e0c5aaaf1f76df5445e84419ae31036b7bcb685`;
after is `aa20e5ffce15827dcb8e6a489cadbb089fd6dc1bbd08879077f9a823cc730759`.
The [separate real-program comparison](large-struct.json) passes GCC O0/O2,
original QBE and all three LCB modes with checksum `b424c67700bbdde0`.
It does not qualify a direct large `blit`: the frontend expanded the copies.

[Validation](validation.json) records fresh build/units, 600 independent C
binding cases and 2,560 sparse-prefix cases per mode on native Apple ARM,
plus all three optimized Linux target gates. Linux ARM executes natively;
Linux x86/RV execute through QEMU. The new binding test detects a deliberately
corrupted return and is integrated into host and cross-target gates.
[Corpus comparison](assembly-equivalence.json) retains 1,305 byte-identical
assemblies across all five targets and 15 matching refusals. This checkpoint
adds no native Intel Mac/RV qualification or preservation proof. The 147
printed proof-audit axiom reports are unchanged.
