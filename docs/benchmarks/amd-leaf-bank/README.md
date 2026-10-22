# Restricted AMD64 leaf registers

Combined compiler identity `1fb34f883f3d1b0a8cec71544974df3fc5a9b4a23c7c300a144677eae3e4bcfc` admits r8/r9 after the existing five callee-saved homes only for call/TLS-free functions whose incoming ABI plan consumes at most four GP registers. Hidden result pointers, aggregate rollback and environment normalization participate in admission. Variadic incoming banks are saved before home writes. An independent physical-bank validator recomputes the incoming ABI plan; it shares the effect scan and is not a formal proof. Original callee-save slots remain separate from the enlarged allocation bank.

The independent C suite exercises 6,144 cases per mode on Linux x86 QEMU and Apple x86 Rosetta, including GP-boundary arguments, aggregate/FP rollback, hidden returns, environment, variadics, spills, phi cycles, frames, blit and calls. Corrupted caller-home and fifth/sixth-argument home writes are detected. No native x86 timing claim is made.

Target-specific zlib qualification uses all 17 x86-configured units: baseline text remains 507,643 bytes, allocated shrinks 308,755→307,930 and optimized 225,861→225,189 (672 fewer bytes). Six before/after upstream examples and 72 exact target-GCC/Python profiles pass. All 51 combined-main assemblies match the private candidate and its retained executed assembly hashes. This establishes the workload connection without claiming a fresh executable rerun or fresh QBE run. The accidental ARM-configured-IR preflight failed even on the unchanged compiler and remains explicitly excluded.

The corpus contains 1,267 identical assemblies, 15 matching refusals and 38 changed x86 allocated/optimized assemblies. All baseline/ARM/RV output is byte-identical. The 147-report proof audit is unchanged. See the main gate record for executable regression coverage.

## Qualification correction

The private candidate originally claimed fresh unit tests passed. That claim was wrong: the newly added Lean test had a syntax error and an older test executable was run afterward. The original logs/report and explicit retraction are preserved under `qualification-correction`. Integration fixed the source using ordinary string concatenation, successfully rebuilt `lcb-tests`, and ran the actual AMD bank suite, whose identifying output appears in the retained main unit log. Compiler binary/source identity and independent C/workload provenance were audited separately and matched. This correction does not expand proof coverage or establish full QBE parity.
