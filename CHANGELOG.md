# Changelog

## Unreleased

- Ported integer shifts, signed/unsigned division and remainder, negation,
  sign/zero extensions and all integer comparisons. Independent tests cover
  both result widths, signed boundaries, masked shift counts and undefined
  division exclusions. Mixed-program fuzzing now includes shifts.

- Added generated-program differential fuzzing with reproducible seeds, retained
  failures and an emitted-code corruption control. Its first seed exposed and
  reduced an interpreter bug: execution returned after the first binary operation.
  Fixed it and retained a two-instruction regression.
- Added a source-derived operation/target/module inventory and explicit port status.
- Use Nix's C compiler for Lake output as well as ABI tests, fixing Linux ELF
  interpreter paths. Upstream snapshots remain byte-identical, including whitespace.

## 0.1.0 — initial port checkpoint

- General-purpose Lean 4 backend with a restricted QBE 1.3 integer subset and
  AArch64 macOS leaf-function assembly. This is not the completed QBE port.
- Pinned Nix development, build and test tools; native C comparisons and a
  separately built upstream QBE comparison; parser and resource-limit controls.
- Initial primitive opcode-selection theorem, with explicit scope and axiom audit.
- Full QBE source snapshot and selected Zig references with licenses, per-file
  hashes and adaptation notes. LLVM/Alive2 ideas are documented for later work.
- Full-port-first roadmap: upstream compatibility and differential fuzzing,
  followed by the larger proof effort; Concrete is a future separate consumer.
