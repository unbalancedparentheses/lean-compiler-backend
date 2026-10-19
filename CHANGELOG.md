# Changelog

## Unreleased

- Added void functions, bare returns and effect-only direct calls, including
  recursion and C APIs. Missing results are represented explicitly rather than
  as fake SSA temporaries or zero. Signature checks reject integer/void result
  mismatches; interpreter `--eval` prints `void` when there is no return value.

- Added direct integer calls, checked internal signatures, recursion and a
  non-leaf ARM64 ABI slice with saved return addresses and live values retained
  across calls. Interpreter calls share a global block budget and memory, with
  callee stack objects invalidated on return. Unknown external calls have no
  interpreted result. Native C interoperation and generated call graphs are
  compared with Python, original QBE and C; register-clobber corruption controls
  qualify the ABI checks. Indirect calls and full ABI support remain open.

- Added integer loads/stores and bounded entry-block constant stack allocations,
  with explicit store statements, an executable byte-memory model and ARM64
  emission. Dynamic/non-entry allocations and full data support remain open.
- Memory fuzzing reduced a QBE 1.3 partial-store-forwarding discrepancy,
  corroborated by native C. Retain the original snapshot and reproducer, run
  original and explicitly corrected comparison copies separately, and never
  count original mismatches as matching cases.
- Keep register allocation in the full-port sequence and record a compact,
  selective MLIR/LLVM/Zig inspiration policy for improvements after compatibility.

- Added integer SSA basic blocks, conditional/unconditional branches, fallthrough,
  loops, phi nodes and halt. Dominance and phi predecessor checks reject invalid
  inputs. Parallel phi transfers stage every source before writing destinations.
- A 64-seed campaign on `4fcd83b` covered 1,024 generated straight-line functions
  and 16,384 input cases across Python, Lean interpretation and both native backends.

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
