# Roadmap

Full QBE 1.3 compatibility is the immediate development priority. Complete the
language, ABIs, optimization pipeline and targets before expanding formal proof
coverage. Preserve executable semantics, reproducible function boundaries, existing
proofs and strong testing throughout. Certification is a separate later milestone
and is not a prerequisite for compatibility work. QBE is the starting baseline
and a fallible comparison implementation, not a permanent constraint on the IR.

This is a general-purpose backend implemented in Lean 4. Concrete is a consumer
through a separate adapter. The current implementation is a bounded scalar
integer/floating, control-flow, memory, TLS and aggregate-call backend on Apple
ARM64 and Linux ARM64/x86-64/RV64. The existing
opcode-selection theorem is limited; the backend is not verified end to end.

## Active execution order

1. Complete QBE language and ABI coverage on Apple ARM64 (P05–P07): full syntax,
   data and symbols, allocation, floating point and conversions, aggregates,
   indirect calls and variadics. Grow upstream and native ABI tests with each slice.
2. Implement SSA construction, analyses, optimization, liveness, spilling and
   register allocation (P08–P09), measuring against the existing stack baseline.
3. Complete the remaining QBE targets and ABI configurations (P10), including
   Linux ARM64, Linux x86-64 and Linux RV64 assembly and execution qualification.
4. Close full-suite and performance qualification (P11–P12). These checks start
   now and grow throughout the port; they are not deferred until feature completion.
5. Resume C01–C03 and expand V01–V05 proof coverage against the established
   implementation. Full compatibility and full certification have separate gates.

The current compatibility slice includes scalar integer/floating arithmetic and
conversions, global data, indirect calls, variadics, env arguments and dynamic
allocation on Apple ARM64 and Linux ARM64, x86-64 and RV64. Mutable-temporary
SSA construction and aggregate arguments/results are implemented on all four
configurations. Native Apple ARM64, Linux ARM64 and Linux x86-64 qualification
is available; RV64 execution is emulated. Next address remaining syntax and
linkage, broader ABI edge cases, optimization passes and register allocation.
Use the compatibility inventory to choose subsequent bounded feature slices.
C01 is paused as an active workstream; its existing results remain checked.
New preservation proofs and proved validators are not prerequisites for adding
features to the explicitly uncertified compatibility pipeline. Keep semantics and
invariants documented so later verification remains feasible. Commit and push
validated, coherent checkpoints frequently.

## Current compatibility gaps

The requested Linux architectures now generate executable assembly: ARM64,
x86-64 and RV64, alongside Apple ARM64 and x86-64. Each current target emits 75/76 retained
upstream fixtures; the remaining fixture omits a required aggregate argument.
This fixture count does not mean the full port is complete.

Next bounded work, before proof expansion:

1. Close remaining syntax/linkage coverage, with quoted globals now implemented, and
   review implementation limits (4096 functions, 64 arguments, bounded object/frame
   sizes) against real frontend workloads. Add reduced cases for every gap.
2. Extend the optional constant/copy/dead-definition and basic CFG pipeline with
   alias analysis, broader CFG transforms and the remaining QBE optimization passes.
3. Implement liveness, spilling and register allocation with value-flow checks;
   retain the current stack baseline as a differential oracle.
4. Complete the remaining QBE ABI configuration (`amd64_win`),
   broaden boundary tests on existing targets and obtain native RV64 qualification.
5. Run broader differential fuzzing and performance benchmarks, then resume
   proof expansion against the completed compatibility implementation.

## Acceptance and reporting rules

Every milestone reports **implemented**, **tested**, **proved**, and **remaining
assumptions** for its supported domain. These are separate dimensions; completing
an implementation checkbox does not certify it. Keep compatibility coverage in
[PORT_STATUS.md](docs/PORT_STATUS.md) and assurance boundaries in
[DESIGN.md](docs/DESIGN.md).

A requested certification level must fail explicitly when the relevant evidence
is unavailable. Within the certified domain, transformations require an applicable
preservation proof or acceptance by a sound, proved validator. Validation failure
must reject the result or use a separately justified baseline. Passing tests,
structural validation and deterministic output do not establish preservation.

Preserve documented source semantics rather than reproducing known upstream bugs.
Retain original and corrected comparison results separately, with reduced controls
and explicit deviations. See [UPSTREAM_DISCREPANCIES.md](docs/UPSTREAM_DISCREPANCIES.md).

## Stage 0 — contracts and independent function jobs

These foundations start during the current port, not after compatibility.
F00–F05 now establish the restricted source contract, independent jobs,
versioned replay, typed stack baseline and pass obligations. These are
implementation/design milestones, not a composed compilation proof. Compatibility porting can continue alongside this work.

### Specification gate — completed design

- [x] F00 — Write an implementation-ready specification for the first verified
  compilation path: [first verified path](docs/research/first-verified-path.md). Includes:
  - The exact integer/control-flow subset, AArch64 target and calling convention,
    source/target states, observable behavior and a proposed preservation statement.
    Distinguish compiler-owned frame accesses from source-program memory operations;
    memory, calls and other excluded features remain outside this first theorem.
  - Concrete `FunctionJob`, `AbiPlan`, `FunctionArtifact` and verification-result
    schemas, including versions, dependencies, code/debug/evidence identities and
    explicit unsupported or uncertified outcomes.
  - Checked SSA, stack-baseline machine IR and typed assembly definitions, with
    invariants and execution meaning. Virtual-register allocation is not required
    for this first stack-based proof.
  - A pass-by-pass proof plan: state relations, preservation lemmas, checker
    soundness obligations, composition and the exact remaining trusted boundaries.
  - Worked examples tracing a loop, a cyclic parallel phi transfer and frame
    setup/access/teardown through every representation, with expected behavior
    and negative cases that expose broken transfers or offsets.

Exit gate: the examples agree with the semantic contract; all decisions needed
for this restricted path are recorded, and unresolved questions are either resolved
or explicitly excluded from its domain. The specification identifies future code,
proof and test changes without making them. Completing F00 does not complete any
implementation or proof milestone.

### Implement the specified foundations — first-path baseline complete

- [x] F01 — [Semantic decision ledger](docs/SEMANTICS.md) and supported-domain
  specification for `ssa-int-v1`, with executable source semantics and admission.
  Arithmetic/control flow are modeled; memory, calls and traps are explicitly
  excluded from this first domain. Target/environment assumptions are recorded.
  Source step determinism and bounded-return soundness are proved; admission
  soundness, interpreter correspondence and compilation preservation remain open.
- [x] F02 — Pure function compilation and verification boundaries. Freeze the
  function's exact target, ABI, layout, imported contracts and consumed optimization
  facts. Workers cannot inspect undeclared module state.
- [x] F03 — Versioned canonical job/artifact serialization, stable symbol identities,
  local numbering and replay. Separate code, debug and evidence dependencies.
- [x] F04 — Minimal typed machine IR and typed assembly around the existing stack
  baseline. Make register aliases, clobbers, stack slots and frame operations explicit;
  validate legality at each boundary before rendering text.
- [x] F05 — Pass obligation table: invariant, semantic relation, direct proof or
  proved checker, evidence format, failure behavior and composition requirements.

The [implemented foundations and obligation table](docs/FOUNDATIONS.md) record
exact schemas, validation, proof scope, tests and remaining assumptions. All
first-path artifacts are explicitly uncertified; requested certification fails.

Exit gate: the admitted subset has replayable jobs and documented semantics;
identical code dependencies yield identical code fragments across module order,
unrelated code edits and worker schedules. Debug metadata and evidence obey their
own dependency contracts. These foundations do not by themselves prove codegen.

## Stage 1 — complete QBE compatibility (active priority)

Existing P identifiers and completed checkpoints are retained for traceability.

- [x] P01 — Restricted integer IR, parser and validation with explicit failures.
- [x] P02 — Executable fixed-width semantics and AArch64 macOS leaf assembly.
- [x] P03 — Qualify pinned Nix builds, native comparisons and upstream QBE oracle; publish repository checkpoint. Linux and ARM64 macOS CI passed at `17ff48a`.
- [x] P04 — Inventory every upstream opcode, syntax construct, pass, ABI and target; track implementation and test coverage without blanket completion claims.
- [ ] P05 — Complete integer operations, conversions, comparisons and control flow,
  including phi nodes and loops; extend executable semantics and regression coverage.
- [ ] P06 — Memory operations, data definitions, symbols, linkage and thread-local
  storage. Integer loads/stores, constant and runtime stack allocations and
  effect-only constant-size blits are implemented as bounded slices. Blits accept
  0..4096 bytes and require disjoint or identical spans; native code adds no bounds
  or overlap guards. Packed integer data, zero fill, alignment and global symbol references are now
  implemented and tested, including pointer initializers with addends and byte
  strings and IEEE floating constant initializers. Runtime-sized and non-entry
  allocations now pass native call/frame tests. Apple ARM64 TLS data/address access
  is tested with concurrent C threads. Apple custom code/data sections and common
  zero-fill definitions now pass native section/coalescing tests; quoted globals,
  additional section forms and other target TLS conventions remain.
  Local single/double arithmetic, comparisons, casts, memory and phi values are
  implemented, including numeric conversions, scalar floating calls/returns and
  variadics. Float-to-integer interpretation rejects non-finite/out-of-range inputs.
  Specify lifetime, initialization, access widths, alignment and pointer behavior;
  justify any alias facts used by optimization.
- [ ] P07 — Calls, variadics, aggregates, floating point and each upstream ABI.
  Direct and indirect calls with up to 64 w/l/s/d register/stack arguments and a scalar or void result,
  recursion and native C interoperation are implemented as an initial slice.
  Function tables, native C callbacks, env arguments and integer/floating variadics
  (vastart/vaarg) are also tested. Subword ABI arguments/results and packed byte/short stack slots are tested;
  Apple ARM64 aggregate arguments/results now include GP/FP registers, stack fallback,
  private indirect copies, opaque values, aggregate variadics and exact short tails.
  Other target ABIs remain open. The Apple ARM64 integer
  stack slice uses natural word/long packing and is checked against native C.
  Aggregate implementation/qualification checklist:
  1. Parse named record, union and opaque types with repetition, nesting and explicit
     alignment. Storage parsing/layout and independent C sizeof/alignof/offsetof
     probes, aggregate signatures and Apple ARM64 ABI integration are implemented.
  2. Implemented aggregate argument/result plans: homogeneous single/double aggregates,
     small GP-register aggregates, stack fallback and caller-owned indirect copies;
     include x8 result pointers alongside x9 environments and variadic boundaries.
     Use pinned arm64/abi.c classification, including its alignment restrictions,
     as the compatibility reference rather than silently broadening the ABI.
  3. Implemented by-value argument copies and caller-owned result storage before releasing
     callee objects. Preserve uninitialized padding; do not invent defined bytes or
     read beyond a short aggregate when filling a final register fragment.
  4. abi1–abi9 and mem1–mem3 pass their original drivers. Independent C
     boundary tests cover exhausted GP/FP banks, nested calls, callbacks, dynamic
     frames and guarded short objects. Pinned QBE discrepancies for tail overreads,
     padded float classification and Darwin aggregate variadics are retained separately. dark.ssa is explicitly skipped upstream
     on Apple ARM64 and must not be counted as a native execution pass.
  Keep ABI plans and call/environment contracts explicit, including callback and
  shared-memory assumptions. Preserve the established floating execution profile
  when later adding optimization passes.
- [ ] P08 — Port SSA construction, CFG/alias analyses and optimization passes.
  Mutable input now receives deterministic renaming and on-demand phi insertion;
  constructed output passes the existing type/dominance validator. Undefined
  incoming values and inconsistent mutable types are explicitly rejected.
  Indexed CFG/predecessor tables, packed-set dominance, definition/reaching-value
  caches and large native SSA-slot addressing are implemented. Compatibility now
  admits 4096 blocks and 16384 instructions/phis, independently of first-path limits.
  Module parsing is iterative and admits 4096 functions with indexed direct-call
  validation; a 4096-function call chain executes across all four targets.
  The retained _bf99 fixture (266 blocks/2001 assignments) and _bfmandel fixture
  (2060 blocks/4581 assignments) emit and assemble. Exhaustive small-graph tests
  compare the indexed analysis with the preserved reducible validator; large
  native frame/phi tests cover scaled-offset boundaries. Optional `--optimize`
  now propagates known constants through SSA and folds defined integer operations,
  propagates same-width temporary copies and removes dead pure definitions,
  remapping debug locations while retaining reachable potential effects/traps.
  Constant branches use word semantics; unreachable blocks and obsolete phi
  edges are removed, with bounded rounds to expose newly constant phis.
  Independent arithmetic and optimized upstream/ABI suites pass on all four targets
  (AMD64/RV64 emulated). Next implement broader CFG transformations, remaining analyses and
  optimization passes; this is not full P08 completion.
  State transformation conditions and invalidate stale analyses. Record proof status
  per pass; certified pipelines enable only covered transformations. Keep a simple
  baseline path for comparison and independently justified fallback.
- [ ] P09 — Port liveness, spilling and register allocation together with value-flow
  checking. Cover register aliases, call clobbers, saved registers, parallel copies,
  spills/reloads and frame constraints. Test value-flow checking now; defer its
  soundness proof to certification. Structural checks alone do not establish
  certified correctness. Re-run the Concrete factorial
  baseline and broader workloads after allocation to measure the actual gain.
- [ ] P10 — Complete upstream AArch64, AMD64 and RV64 targets and supported
  object/ABI conventions, explicitly including Linux AArch64 (ARM64 ELF),
  Linux AMD64 (x86-64 ELF/System V) and Linux RV64 (64-bit RISC-V ELF), alongside
  the Apple targets. Generate assembly for each target; object emission remains
  a separate milestone. Track native and emulated Linux execution, ABI tests,
  assembler/linker qualification and certification scope separately per target.
  Linux ARM64 ELF now emits 75/76 upstream fixtures, with 58 executable drivers
  and 17 assembly-only fixtures passing on native Linux ARM64, including variadic
  functions and TLS. Custom ELF sections and init-array constructors are implemented;
  Linux AMD64 scalar/aggregate/variadic lowering and TLS now emit 75/76 fixtures
  (58 executable and 17 assembly-only passes under QEMU), with native x86-64 CI
  passing at `6823743`. Linux RV64 scalar/aggregate/variadic/TLS lowering also
  reaches 75/76 fixtures (58 executable and 17 assembly-only passes under QEMU).
  macOS AMD64 now reaches 75/76 fixtures (58 executable and 17 assembly-only
  passes through Rosetta), sharing SysV classification with Mach-O/TLV emission.
  Native Linux ARM64 CI is enabled; native RV64 and Intel macOS qualification
  remain, alongside the Windows AMD64 implementation.
  Coverage on one ISA or OS ABI does not certify another. 32-bit ARM/x86/RISC-V
  are outside the QBE baseline and require separately scoped target work.
- [ ] P11 — Run the complete upstream test suite, ABI generators and differential
  fuzzing; reduce and retain every mismatch. The current all-fixture scan emits
  75/76 inputs: 58 original executable fixtures pass natively, 17 development
  fixtures assemble only, and dark.ssa remains unsupported (it is skipped upstream
  on Apple ARM64 and deliberately omits a required argument). CI prevents emission
  regressions and tests newly accepted fixtures; see [coverage](docs/UPSTREAM_COVERAGE.md).
- [ ] P12 — Measure compile time, checker time, generated-code performance, code size
  and memory against pinned QBE on the same workloads/toolchain. Maintain baselines
  throughout development; performance improvements must preserve correctness gates.

Exit gate: full coverage across the inventoried syntax, documented semantics,
targets, ABIs and passes, with known discrepancies explicit. A working subset or
wrapper around C QBE is not the full port. Publish separate compatibility and
certification matrices; full compatibility does not imply full certification.

## Stage 2 — resume formal certification after QBE compatibility

- [ ] C01 — Prove a restricted integer/control-flow path through stack lowering,
  including a nontrivial loop, simultaneous phi transfers, frame accesses and
  return behavior. Source/target execution relations are defined; initializer
  soundness/completeness and concrete entry witnesses are proved. Target-helper
  lemmas, store-span preservation/initialization, same-width load-after-store and
  disjoint load preservation are proved. Arbitrary phi staging/commit now connects
  the source interpreter's checked transfer to actual MIR edges, including jumps,
  under explicit availability, destination and edge-membership premises. Source
  copies simulate as two MIR steps; arithmetic and comparison expansions are
  proved, with a uniform simulation theorem for successful source body steps.
  An admitted cyclic loop has unbounded
  divergence witnesses through source, MIR and typed assembly. Checker soundness,
  instruction-position and block-membership derivation, general control-flow
  simulation, caller-state preservation,
  typed-assembly expansion and whole-pipeline return/divergence remain open.
- [ ] C02 — Connect the actual typed lowering implementation to that result;
  audit axioms and distinguish kernel-checked evidence from native checker execution.
- [ ] C03 — Publish the exact certified domain and remaining rendering, ISA,
  assembler and linker assumptions. Test those boundaries independently.

Exit gate: one useful restricted pipeline has a composed preservation statement,
not only arithmetic opcode lemmas. Memory and calls already implemented outside
that domain remain explicitly tested but uncertified until covered.

## Verification workstream — proof expansion deferred until after compatibility

Maintain existing proofs and executable semantics during the port. The following
proof expansion and composition obligations resume after full QBE compatibility;
they do not block implementation milestones in the uncertified pipeline.

- [ ] V01 — Precise source IR and target-machine semantics, including UB/traps,
  memory and external interactions. Begin in F01 and extend with each feature.
- [ ] V02 — Prove checker invariants and semantic preservation of lowering/passes,
  beginning with C01. Keep theorem scope aligned with the actual implementation.
- [ ] V03 — Prove allocation/spill correctness directly or prove the soundness of
  a validator checking proposed results. Reuse the invariants and validation
  infrastructure established in P09.
- [ ] V04 — Cover rendered assembly, then actual encoding and relocations. Separate
  model validity, encoder correctness and assembler/linker assumptions explicitly.
- [ ] V05 — Compose supported-domain results and audit trusted boundaries. Plan
  interfaces now, compose the first slice in C01, and extend to open functions,
  compatible environments and linking as coverage grows. No whole-compiler claim
  before the corresponding composition exists.

## Stage 3 — expand certified output and composition

Extend V04/V05 toward concrete machine-code artifacts, beginning with the baseline
target. Direct encoding, object construction, relocations and final linking are
separate obligations. Define open-component contracts for recursion, callbacks and
external libraries; concurrent contexts require additional semantics and proofs.

Exit gate: a published theorem for the exact input/output domain, tied to delivered
artifacts, with all remaining toolchain and environment assumptions named. A typed
assembly theorem or successful decoding alone does not close the machine-code gap.

## Stage 4 — measured improvements and evolution beyond QBE

- [ ] E01 — Add selected optimizations and target features with performance
  measurements and proof/validation coverage. The foundational typed IR, legality
  checks and replay work have moved to F04/F05 rather than waiting for this stage.
- [ ] E02 — Add a separate Concrete adapter preserving its arithmetic, effects,
  overflow/trap and runtime ABI semantics. Evolve native IR deliberately; preserve
  QBE import semantics on its declared supported domain where compatibility is retained.
- [ ] E03 — Parallel execution, persistent caches and richer debug information over
  F02/F03. Check cached input/output binding and required evidence; test invalidation
  and corruption. Maintain deterministic release layout independently of any
  history-dependent incremental-linking mode.

These stages describe acceptance gates. The active execution order above takes
priority: complete compatibility before resuming formal proof expansion;
E03 can begin once job/artifact contracts stabilize, and encoding work can begin
once typed target lowering is stable. Beyond-QBE optimizations and consumers must
not displace full QBE compatibility. No universal performance or
end-to-end correctness claim precedes its measurements or proof.

## Qualification throughout development

- Fixed-seed and rotating-seed well-typed generation; compare Lean interpretation,
  baseline and optimized native output, pinned QBE and independent references.
- Restrict comparisons to the common defined domain; do not treat UB, uninitialized
  accesses or interpreter-budget exhaustion as evidence of equivalence.
- Exercise C ABI boundaries in both directions; extend fixtures with supported
  aggregates, stack arguments, indirect calls and callbacks.
- Reject malformed inputs and invalid certificates. Mutate edge copies, clobbers,
  spill locations, frame offsets and cache bindings to test checker sensitivity.
- Test function order, unrelated edits, schedules, fresh processes, cache states
  and normalized paths. Check code/debug dependency invalidation separately.
- Retain replayable mismatch artifacts and shrink failures without losing validity.
  Measure supported-input success rates and resource usage as well as soundness.
- Keep specification tests and independent machine/toolchain tests after proofs.
  Preserve upstream provenance, source hashes and explicit discrepancy controls.
- Run pinned Nix checks in CI and identify unmeasured platforms honestly.

Design rationale: [architecture research](docs/research/backend-architecture.md),
[community evidence](docs/research/community-discussions.md), and
[selected upstream ideas](docs/BEYOND_QBE.md).

Debug-location checkpoint: `dbgfile`/`dbgloc` now survive SSA and emit native
line tables. All 87 public opcode names accept some forms; remaining syntax,
operation domains, optimizations and other targets still prevent full QBE support.
