# RV64 load normalization

RV64 unsigned byte/half/word loads already zero-extend into the full register.
The emitter now omits its redundant shift-left/right mask pair after these
loads, including adjacent-address folding and raw single-precision loads.
Signed word-result loads and general word copies retain their normalization.

Compiler identity: `81000f96ded3564ff24256c8c736be2f853d88c1c67ce0429ace201fc251c003`.
[Independent C cases](load-cases.json) cover 9,216 integer/FP bit cases per mode,
direct/folded addresses, high bits and signedness. Both deliberately corrupted
signed/unsigned opcodes are detected. [Validation](validation.json) records fresh
build/units, unchanged 147 proof-audit reports and the complete optimized RV gate.
Execution is QEMU, not native RV hardware.

[Assembly comparison](assembly-comparison.json) covers 1,320 attempts: 1,305
successful emissions and 15 matching refusals. The other four targets remain
byte-identical; RV output changes only by the expected unsigned-load mask pairs.
The [comparison harness](expected_emission.py) records exactly that permitted
transformation. This is corpus evidence, not a preservation proof.

The [zlib comparison](zlib.json) passes 17 translation units, the upstream static
test recipe, 12 exact gzip streams and independent decompression/roundtrips per
qualified backend. The original QBE link failure and corrected oracle remain
separate. [Paired object measurements](zlib-object-comparison.json) use unchanged
benchmark IR, immutable before/after binaries and all 17 units:

| Mode | Removed instruction pairs | Total object `.text` before → after |
|---|---:|---:|
| Baseline | 695 | 589,120 → 584,944 bytes |
| Optimized | 595 | 268,868 → 265,296 bytes |

All 34 after-assemblies match the separate completed benchmark byte-for-byte.
These totals include example/minigzip objects and differ from linked executable
text. No generated-program runtime speedup or end-to-end proof is claimed.
