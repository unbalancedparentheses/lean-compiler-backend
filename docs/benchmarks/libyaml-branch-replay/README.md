# Libyaml replay after ARM branch layout

Compiler identity `de27b459436dbfc15e827f17fbfa30948b2192b598035c40ac5debd2952f33f9`
passes all 52 historical libyaml driver checks in baseline, allocated and optimized
modes on native Linux ARM64. The 21 retained IR units and all original references
remain unchanged. Both GCC O0/O2 references were rerun and bound to historical
results; the compiled wrong-return negative control is detected. See `replay.json`.

`libyaml_corpus.py --replay-report` now accepts these freshly compiled executables
without replacing retained original GCC/QBE binaries. It validates the replay’s
reference hash, source/IR manifests, compiler snapshot, harness snapshot, executable
hashes and historical driver results. It rechecks provenance and corpus hashes after
execution and waits for the guest report digest to synchronize with the host.
A wrong recorded candidate executable hash is rejected before corpus execution.

The pinned 402-input YAML corpus passes on all three new LCB modes and retained
GCC O0/O2, original QBE and separately corrected QBE parser executables: 2,814
executions, of which 1,206 use the new compiler. There are 273 accepted and 129
rejected inputs per backend. Exact exit/stdout/stderr records match GCC. This tests
compiler behavior, not YAML specification goldens or full libyaml conformance.
The original QBE ARM reader failure remains unrelated and unresolved; its parser
passes this corpus. The original no-replay command also passes all 402 inputs per
backend (`original-regression.json`); it uses historical compiler identity 11be972.

The earlier development run before post-execution provenance/digest barriers is
excluded. Current evidence is in `corpus.json`; no runtime speedup is claimed.

```sh
python3 scripts/libyaml_corpus.py --reference .build/libyaml-arm.json \
  --replay-report .build/libyaml-replay-arm-branch.json \
  --output-dir .build/linux-arm64/libyaml-corpus-arm-branch-bound
```
