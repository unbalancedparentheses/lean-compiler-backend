# Roadmap

The first release is a **general-purpose QBE 1.3 port in Lean 4**. Concrete will
use it through a separate adapter. It is not a Concrete-specific backend.
Full compatibility comes before LLVM/Zig/MLIR-inspired enhancements and the large
proof effort. Current implementation: an initial integer/leaf-function subset.

## Phase 1 — working full port

- [x] P01 — Restricted integer IR, parser and validation with explicit failures.
- [x] P02 — Executable fixed-width semantics and AArch64 macOS leaf assembly.
- [x] P03 — Qualify pinned Nix builds, native comparisons and upstream QBE oracle; publish repository checkpoint. Linux and ARM64 macOS CI passed at `17ff48a`.
- [x] P04 — Inventory every upstream opcode, syntax construct, pass, ABI and target; track implementation and test coverage without blanket completion claims. See `docs/PORT_STATUS.md`.
- [ ] P05 — Complete integer operations, conversions, comparisons and control flow, including phi nodes and loops.
- [ ] P06 — Memory operations, data definitions, symbols, linkage and thread-local storage.
  Integer loads/stores and entry-block constant stack allocations are implemented
  as a bounded slice; data, symbols, dynamic allocation, blits and linkage remain.
- [ ] P07 — Calls, variadics, aggregates, floating point and each upstream ABI.
- [ ] P08 — Port SSA construction, CFG/alias analyses and optimization passes.
- [ ] P09 — Port liveness, spilling and register allocation, with native checks.
  Keep live values in registers and spill only when required. Check call clobbers,
  saved registers, parallel copies and spill/reload value preservation. Re-run
  the Concrete factorial baseline after this port to measure the actual gain.
- [ ] P10 — Complete upstream AArch64, AMD64 and RV64 targets and supported object/ABI conventions; native/emulated tests identified explicitly.
- [ ] P11 — Run the complete upstream test suite, ABI generators and differential fuzzing; reduce and retain every mismatch.
- [ ] P12 — Measure compile time, generated-code performance, code size and memory against pinned QBE on the same workloads/toolchain.

Full port means parity across the inventoried source, semantics, supported targets
and passes. A working subset, wrapper around C QBE or matching sample outputs
does not qualify. The upstream C implementation stays a separate test comparison.

## Qualification throughout the port

- Fixed-seed and rotating-seed well-typed SSA generation, bounded execution and
  comparisons among Lean interpreter, Lean backend, QBE and independent references.
- Defined-behavior generators: avoid treating undefined behavior, division by zero,
  uninitialized memory or unsupported inputs as backend correctness evidence.
- Native C ABI stress tests, upstream generators and ABI-specific fixtures.
- Malformed-input/resource-limit checks; explicit unsupported/unvalidated results.
- Mismatch artifacts containing seed, input, target, toolchain identity and outputs,
  with shrinking and permanent regression cases.
- Nix builds/checks in CI; preserve upstream licenses, hashes and source attribution.
- Retain independently corroborated upstream discrepancies and their reduced
  controls. Original-QBE mismatches remain explicit; any corrected test comparison
  is separately named and pinned. See `docs/UPSTREAM_DISCREPANCIES.md`.

## Phase 2 — prove the completed design

The small opcode-selection theorem already in the prototype remains a scoped
experiment. Writing Lean code or passing fuzz tests does not prove the backend.

- [ ] V01 — Precise source IR and target-machine semantics, including UB/traps and memory.
- [ ] V02 — Prove checker invariants and semantic preservation of each lowering/pass.
- [ ] V03 — Prove or independently validate register allocation and spill/reload behavior.
- [ ] V04 — Check the actual emitted assembly, then machine bytes; identify assembler/linker/ABI assumptions separately.
- [ ] V05 — Compose supported-domain theorems and audit all axioms/trusted boundaries; make no whole-compiler claim before composition.

## Phase 3 — improvements and consumers

[BEYOND_QBE.md](docs/BEYOND_QBE.md) records the LLVM/Zig/MLIR ideas to revisit after
the full port: machine IR, pass verification, declarative target legality,
explicit arithmetic policies, direct object emission and isolated pass tests.

- [ ] E01 — Add selected improvements with performance measurements and proof/validation coverage.
- [ ] E02 — Add a separate Concrete adapter that preserves its checked arithmetic,
  effects, overflow/trap and runtime ABI semantics; keep generic QBE behavior intact.
- [ ] E03 — Debug information, reproducible per-function artifacts and safe incremental caches.

No faster-than-QBE or end-to-end correctness claim is made before corresponding
measurements or proofs exist. Keep the compatible baseline available.
