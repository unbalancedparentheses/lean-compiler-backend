# Native ARM in-process zlib qualification

The reusable runner is `scripts/zlib_inprocess.py`. Raw snapshots retain the
private qualification paths and exact compiler identities.

The driver measures batches of `compress2`, `uncompress` and `crc32` with `clock_gettime(CLOCK_MONOTONIC_RAW)` inside a GCC-built C process. Startup, file/pipe I/O, initial compression, caller-buffer allocation and correctness checks are outside the measured intervals. API-internal work/allocation and common loop bookkeeping remain included. Timed compression level is 6. Each guest process is pinned to CPU 0; guest affinity does not eliminate host/VM scheduling or frequency effects.

## Reuse

Run from the repository root, using a fresh work directory per experiment:

```
python3 scripts/zlib_inprocess.py --work "$PWD/.build/linux-arm64/zlib-inprocess-new" \
  --compiler before=/absolute/immutable-before --compiler after=/absolute/immutable-after --phase build
# Arrange a quiet native CPU window before the separate timing phase.
python3 scripts/zlib_inprocess.py --work "$PWD/.build/linux-arm64/zlib-inprocess-new" \
  --phase time --samples 9 --batch-ms 100 --warmups 2
```

`--root` supports a script run from a separate worktree. `--compiler LABEL=PATH` can repeat. Build refuses an existing work directory; preserve `timing.json` before deliberately repeating a time phase in the same directory. Default operation is build/correctness only.

Build validates the retained `.build/zlib-cse-profit-arm.json` source/configuration/IR bindings, copies immutable LCB snapshots, and freshly compiles all 15 library units for every LCB label, GCC, original QBE and corrected QBE. It reuses original pinned frontend IR without changing source or configuring cproc. Original QBE is built from unchanged locked source. Corrected QBE uses the separately hashed, existing ARM external-address correction; its identity is not substituted for the original. The common driver is compiled once by GCC at O2; GCC library flags are those retained from upstream configure (O3 plus feature defines), without LTO.

Both windows pass five deterministic payloads × levels 1/6/9 for all five labels: exact compressed bytes against fresh GCC, independent Python decompression/CRC and cross-decompression of GCC bytes. Deliberately corrupting the returned CRC is detected. Separate binary/payload hash-mismatch controls reject before execution.

The hardened run checks 485 bound files on host and guest before/after correctness and timing: source/configuration/IR, objects, executable/compiler/oracle files, payloads, caller and probe. Source binding sets and manifest hashes must remain unchanged. Reports use guest→host digest barriers; `qualified/provenance.json` records all four successful phases. All timed sink values agree across labels and rounds.

The leaf-bank change was qualified as an isolated compiler candidate before
integration. These records bind immutable snapshots; they do not assert that
every compiler feature or the full port is complete.

## Results and limits

`report.json` contains compact comparisons; subdirectories retain raw manifests, correctness results, samples and script versions. Full artifacts remain at the `work` paths in that report. Each window has 135 samples: nine randomized paired rounds, three payloads and five labels. Shared per-case loop counts use approximately 100 ms GCC calibration per API. Warmups and calibration are discarded. Summaries contain raw batch ns, per-call ns (hardened run), median/MAD/range/stdev/CV, paired ratios and bootstrap median intervals.

Final leaf/extuw elapsed-time ratios:

| Payload / API | Median | Paired bootstrap 95% interval | Paired CV |
|---|---:|---:|---:|
| Random / compress2 | 0.9077 | 0.8818–0.9314 | 2.33% |
| Mixed / compress2 | 0.9780 | 0.9738–0.9906 | 1.09% |

The first window independently reproduces those directions (0.9082 and 0.9822). Other seven API/payload intervals include 1, so there is no demonstrated general improvement. Final CRC takes approximately 1.72–1.73× original QBE time and 3.93–3.98× GCC time on these inputs; that is a remaining targeted performance gap.

The first window used e68 source identity; the final window used release15ce after explanatory compiler comments changed. Their identities and actual compiler hashes remain separate. All five linked benchmark executables are byte-identical across the two windows, including the leaf executable. First-window post-validation is retained as an independent verifier/report; final-window provenance is integrated into the frozen reusable script. These are local finite-input measurements, not universal speed claims or formal correctness proofs.
