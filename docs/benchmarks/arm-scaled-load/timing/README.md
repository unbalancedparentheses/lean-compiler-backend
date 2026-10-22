# ARM scaled-load timing

**Qualification corrected: noisy diagnostics under uncontrolled background load.** See `qualification-correction.json` and the copied post-window process evidence. Compiler-team jobs were held, but machine-wide quiet was not established. Process elapsed times overlap both windows; historical CPU usage was not sampled, so exact per-window load and causal attribution are unknown. Earlier README/summary/manifest are preserved under `superseded-quiet-qualification/`. Raw window artifacts remain unchanged.

Two separate windows, 9 randomized paired rounds per payload, 250 ms GCC calibration, 2 warmups, five labels. All 135 records/window agreed on sinks; each window passed its own 485-file host/guest postvalidation. Ratios below compare elapsed scaled / names; lower is faster. Intervals are descriptive bootstrap 95% intervals, without multiple-comparison correction. Raw per-label comparisons including GCC, original QBE and corrected QBE remain in summary.json and each timing.json.

The first archive wrapper expected status `passed` instead of the protocol’s `completed` and exited after successful measurement postvalidation. Its error is retained separately; a new wrapper finalized the archive and ran window 2 without changing protocol or binaries. No samples were removed or rerun for this wrapper error.

| Window | Payload | API | Ratio | Interval | Paired CV |
|---|---|---|---:|---|---:|
| 1 | repeated | compress | 0.9757 | 0.9381–1.0171 | 0.084 |
| 1 | repeated | uncompress | 0.9995 | 0.9568–1.0230 | 0.132 |
| 1 | repeated | crc32 | 0.8297 | 0.7549–0.8908 | 0.214 |
| 1 | random | compress | 0.9855 | 0.8055–1.0934 | 0.222 |
| 1 | random | uncompress | 1.0248 | 0.9141–1.1774 | 0.115 |
| 1 | random | crc32 | 0.8971 | 0.7535–0.9315 | 0.206 |
| 1 | mixed | compress | 0.9757 | 0.9202–1.3820 | 0.206 |
| 1 | mixed | uncompress | 1.0088 | 0.9485–1.0456 | 0.135 |
| 1 | mixed | crc32 | 0.8879 | 0.8590–1.0870 | 0.190 |
| 2 | repeated | compress | 1.0351 | 0.9880–1.2538 | 0.150 |
| 2 | repeated | uncompress | 1.0046 | 0.8118–1.1580 | 0.137 |
| 2 | repeated | crc32 | 0.8680 | 0.7836–0.9669 | 0.098 |
| 2 | random | compress | 0.9706 | 0.9021–1.1704 | 0.130 |
| 2 | random | uncompress | 1.0072 | 0.7742–1.1098 | 0.165 |
| 2 | random | crc32 | 0.9037 | 0.8291–0.9747 | 0.095 |
| 2 | mixed | compress | 0.9946 | 0.9773–1.0886 | 0.140 |
| 2 | mixed | uncompress | 0.9990 | 0.9009–1.0244 | 0.201 |
| 2 | mixed | crc32 | 0.8337 | 0.6450–0.9109 | 0.162 |

Compiler labels are immutable historical snapshots (neither is the later aggregate-alias or mutable-width main compiler):

- `names`: source base b246312, identity ce3e8012b7d5a57f7d37cbe435b1078bea1a3f70bbaa4f7f41764399f3c1ef92; binary SHA256 cebcfe1c2a1f9f1307770e588f5f8d7b3c45ceadb30cc98f8ef57c987e0b96c9.
- `scaled`: the same base plus the isolated AArch64 scaled-load patch, identity 96c8fae6d984f3af804b7c50fa1b3dc25af59a5cf8be60d0dfa663c54b8bf841; binary SHA256 2d6185fc03efe1666218a49a7de67425734f821f564f6e1c072242af089490b3. AArch64 source SHA256 9a82cd512c368813524b66262c8a0bf79effd09cd64f3c870d245436ecdfbfe6.
- `gcc`, `qbe-original`, and `qbe-corrected` are separately built and bound reference labels; corrected QBE is not the unchanged upstream oracle. Exact source/configuration/object/executable hashes are retained in each window manifest and provenance.

Measured on native Linux ARM in the Docker VM, not macOS native execution or QEMU. The displayed CRC ratios are descriptive observations under uncontrolled load, not qualified clean speed evidence. Compression/decompression intervals overlap parity, but these noisy windows also do not establish performance equivalence or exclude regressions. No causal claim is made that background maintenance alone explains any change. Independent correctness and the 312-byte optimized zlib text reduction remain valid; they support a bounded merge with clean performance explicitly unresolved. No pooled aggregate or post-hoc sample removal is used.

Publication hygiene: `background-load-observation-reduced.json` retains only relevant pack-objects process fields, timestamp, classification, scope, and the full raw observation SHA256. The former raw binding `scaled-load-background-observation.json` was removed from this package and retained privately; unrelated filesystem/cwd listings are excluded. Timing and compiler evidence were not changed.
