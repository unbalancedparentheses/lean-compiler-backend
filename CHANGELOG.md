# Changelog

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
