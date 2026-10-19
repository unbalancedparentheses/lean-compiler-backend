# What to learn from LLVM, Zig and MLIR

Decision dated 2026-10-18. These are candidates for after the full general-purpose
QBE port and its qualification, not requirements for a Concrete-specific first
release. Start with QBE as a working port; add features only
when they have a clear semantic model and measurable value. The goals are useful
code generation, small reviewable components and an increasingly checked chain
from input to actual emitted code.

| Source | Adopt | Benefit and first concrete step |
| --- | --- | --- |
| Zig AIR and AArch64 MIR | Separate checked operations from machine instructions | Add a typed machine representation for registers, immediate encodings, stack accesses and returns; render assembly from it. |
| Zig AIR arithmetic tags | Distinguish wrapping, checked and saturating arithmetic | Keep the QBE port modular. Add checked operations with explicit overflow/trap outcomes for the Concrete adapter; never infer semantics from a host-language operation. |
| LLVM MIR and `-run-pass` testing | Save and replay individual compiler stages | Add deterministic machine-IR dumps and stage-specific fixtures, so a register/stack bug can be reproduced without the frontend. |
| LLVM `-verify-each` | Verify invariants after every transformation | Reject bad widths, undefined values, invalid stack offsets, damaged calling conventions and unsupported target features immediately. Structural verification alone is not equivalence. |
| LLVM GlobalISel legalizer | Make target support explicit | Describe legal width/opcode/feature combinations. Unsupported operations fail or enter a documented checked expansion; never silently weaken semantics. |
| LLVM TableGen | One declarative description of supported instructions | Start with small Lean tables for operands, widths and encoding constraints. Generate coverage checks and reduce emitter/checker disagreement. Keep the semantic checker independent enough to catch a wrong table. |
| MLIR conversion targets | Declare exactly which operations and types may remain after lowering | Require complete lowering to the next representation before native emission. Keep a small explicit legality predicate; structural legality still needs separate semantic preservation evidence. |
| MLIR operation definitions and verifiers | Central operation constraints and verification hooks | Use Lean data types and small pass interfaces to keep operand/result/effect rules visible, with focused negative controls. |
| Zig native backends | Clear ABI and object-format boundaries | Separate target/ABI data from instruction selection. Later emit Mach-O/ELF and relocations directly, tested against external tools. Direct object emission does not itself establish correctness. |
| Alive2 (a separate LLVM-oriented project) | Validate transformations, retain counterexamples | Develop bounded translation validation for our own supported semantics. Alive2 can help with LLVM→LLVM checks in Concrete, but cannot validate this native backend out of the box. |

The highest-value additions are **typed machine IR, verifiers between stages,
explicit overflow/trap behavior and validation of emitted output**. They reduce
the chance that adding an optimization quietly changes what a function means.

Register allocation should come after a working stack-based baseline. The first
allocator can be simple; independently check where every live value resides,
which registers calls clobber and whether each spill/reload preserves its value.
This allows a fast allocator without making its entire heuristic trusted.

Keep reproducible per-function artifacts (input hash, target, ABI, toolchain,
pass configuration and validation result). Incremental compilation is useful
later, but a cached result must bind all those inputs and the exact emitted
artifact. Source locations should survive lowering before debug information
becomes expensive to retrofit. Benchmark compile time and generated code against
QBE before adding complex optimization pipelines.

## Order

1. Complete and qualify the QBE 1.3 port: operations, control flow, memory,
   calls/ABIs, passes, allocation and upstream targets. Fuzz throughout this work.
2. Carry out the larger proof effort over the completed design, with explicit
   source/machine semantics and assembler/linker boundaries.
3. Evaluate typed machine IR, stronger pass verifiers, dumps and allocation
   validation as improvements to the compatible baseline.
4. Add arithmetic policies and a separate Concrete adapter only as consumer work.
5. Add direct object emission, debugging and measured optimizations where useful.

This adopts specific ideas rather than LLVM's entire architecture. SIMD, aggressive
loop optimization, exceptions, general-purpose JIT support and a custom linker
are deferred until workloads justify their complexity.

## Compactness policy

Keep QBE's general-purpose scalar scope as the compatible baseline. Organize the
implementation around a few explicit representations and small pass interfaces;
reuse target descriptions instead of duplicating the pipeline for each ISA.
Register allocation, calls/ABIs, memory and useful scalar optimization are baseline
features, not optional substitutes for a tiny demonstration.

After that baseline, adopt improvements individually when they reduce a measured
failure mode, compilation cost, generated-code cost or maintenance burden. Record
that evidence, code-size/build-dependency impact and semantic boundary with the
change. MLIR informs explicit lowering and verification; importing its C++ framework
or its whole collection of dialects is not part of this plan. No fixed line-count
target or smaller-than-QBE promise is made before equivalent functionality exists.

## Primary references

- [QBE IL](https://c9x.me/compile/doc/il.html), also retained under `third_party/qbe/doc/`.
- Zig 0.17.0 [`Air.zig`](../third_party/zig/src/Air.zig),
  [AArch64 MIR](../third_party/zig/src/codegen/aarch64/Mir.zig) and
  [ABI definitions](../third_party/zig/src/codegen/aarch64/abi.zig), pinned in the lock.
- [LLVM MIR](https://llvm.org/docs/MIRLangRef.html).
- [LLVM GlobalISel legalizer](https://llvm.org/docs/GlobalISel/Legalizer.html).
- [LLVM `opt`, including `-verify-each`](https://llvm.org/docs/CommandGuide/opt.html).
- [LLVM TableGen](https://llvm.org/docs/TableGen/index.html).
- [MLIR dialect conversion and legality](https://mlir.llvm.org/docs/DialectConversion/).
- [MLIR operation definitions and verification](https://mlir.llvm.org/docs/DefiningDialects/Operations/).
- [Alive2 scope and limitations](https://github.com/AliveToolkit/alive2).

No LLVM, MLIR or Alive2 implementation code is currently copied. If that changes, pin
the source, retain its license and record the affected modules before merging.
