# Roadmap

Correctness is the first priority. Establish semantic contracts, reproducible
function boundaries and proof structure now; expand implementation and proof
coverage together. Full QBE 1.3 coverage remains the first complete compatibility
milestone, with certification reported separately. QBE is the starting baseline
and a fallible comparison implementation, not a permanent constraint on the IR.

This is a general-purpose backend implemented in Lean 4. Concrete is a consumer
through a separate adapter. The current implementation is a bounded integer,
control-flow, memory and direct-call subset on Apple ARM64. The existing
opcode-selection theorem is limited; the backend is not verified end to end.

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
This foundations workstream is currently documentation and research only. Its
next deliverable is the specification below; its implementation milestones
remain future work. Separately authorized compatibility porting continues.

### Specification gate — current work

- [ ] F00 — Write an implementation-ready specification for the first verified
  compilation path, planned as `docs/research/first-verified-path.md`. Include:
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

### Implement the specified foundations — future work

- [ ] F01 — Semantic decision ledger and supported-domain specification. Define
  arithmetic, memory, traps/divergence and external-call behavior before extending
  transformations that depend on them; state target and environment assumptions.
- [ ] F02 — Pure function compilation and verification boundaries. Freeze the
  function's exact target, ABI, layout, imported contracts and consumed optimization
  facts. Workers cannot inspect undeclared module state.
- [ ] F03 — Versioned canonical job/artifact serialization, stable symbol identities,
  local numbering and replay. Separate code, debug and evidence dependencies.
- [ ] F04 — Minimal typed machine IR and typed assembly around the existing stack
  baseline. Make register aliases, clobbers, stack slots and frame operations explicit;
  validate legality at each boundary before rendering text.
- [ ] F05 — Pass obligation table: invariant, semantic relation, direct proof or
  proved checker, evidence format, failure behavior and composition requirements.

Exit gate: the admitted subset has replayable jobs and documented semantics;
identical code dependencies yield identical code fragments across module order,
unrelated code edits and worker schedules. Debug metadata and evidence obey their
own dependency contracts. These foundations do not by themselves prove codegen.

## Stage 1 — first composed preservation result

- [ ] C01 — Prove a restricted integer/control-flow path through stack lowering,
  including a nontrivial loop, simultaneous phi transfers, frame accesses and
  return behavior. Use explicit source and target semantics and state relations.
- [ ] C02 — Connect the actual typed lowering implementation to that result;
  audit axioms and distinguish kernel-checked evidence from native checker execution.
- [ ] C03 — Publish the exact certified domain and remaining rendering, ISA,
  assembler and linker assumptions. Test those boundaries independently.

Exit gate: one useful restricted pipeline has a composed preservation statement,
not only arithmetic opcode lemmas. Memory and calls already implemented outside
that domain remain explicitly tested but uncertified until covered.

## Stage 2 — expand the QBE baseline and its assurance together

Existing P identifiers and completed checkpoints are retained for traceability.

- [x] P01 — Restricted integer IR, parser and validation with explicit failures.
- [x] P02 — Executable fixed-width semantics and AArch64 macOS leaf assembly.
- [x] P03 — Qualify pinned Nix builds, native comparisons and upstream QBE oracle; publish repository checkpoint. Linux and ARM64 macOS CI passed at `17ff48a`.
- [x] P04 — Inventory every upstream opcode, syntax construct, pass, ABI and target; track implementation and test coverage without blanket completion claims.
- [ ] P05 — Complete integer operations, conversions, comparisons and control flow,
  including phi nodes and loops; extend semantic and preservation coverage with them.
- [ ] P06 — Memory operations, data definitions, symbols, linkage and thread-local
  storage. Integer loads/stores, entry-block constant stack allocations and
  effect-only constant-size blits are implemented as bounded slices. Blits accept
  0..4096 bytes and require disjoint or identical spans; native code adds no bounds
  or overlap guards. Data, symbols, dynamic allocation, TLS and linkage remain.
  Specify lifetime, initialization, access widths, alignment and pointer behavior;
  justify any alias facts used by optimization.
- [ ] P07 — Calls, variadics, aggregates, floating point and each upstream ABI.
  Direct calls with up to 64 w/l register/stack arguments and a w/l or void result,
  recursion and native C interoperation are implemented as an initial slice.
  Indirect calls and the other ABI forms remain open. The Apple ARM64 integer
  stack slice uses natural word/long packing and is checked against native C.
  Add explicit checked ABI plans and call/environment contracts, including callback
  and shared-memory assumptions. Define floating-point profiles before optimizing them.
- [ ] P08 — Port SSA construction, CFG/alias analyses and optimization passes.
  State transformation conditions and invalidate stale analyses. Record proof status
  per pass; certified pipelines enable only covered transformations. Keep a simple
  baseline path for comparison and independently justified fallback.
- [ ] P09 — Port liveness, spilling and register allocation together with value-flow
  checking. Cover register aliases, call clobbers, saved registers, parallel copies,
  spills/reloads and frame constraints. Prove checker soundness for the certified
  domain; structural checks alone are insufficient. Re-run the Concrete factorial
  baseline and broader workloads after allocation to measure the actual gain.
- [ ] P10 — Complete upstream AArch64, AMD64 and RV64 targets and supported
  object/ABI conventions. Identify native/emulated tests and certification scope
  separately for each target; coverage on one ISA does not certify another.
- [ ] P11 — Run the complete upstream test suite, ABI generators and differential
  fuzzing; reduce and retain every mismatch. Run growing subsets throughout the port.
- [ ] P12 — Measure compile time, checker time, generated-code performance, code size
  and memory against pinned QBE on the same workloads/toolchain. Maintain baselines
  throughout development; performance improvements must preserve correctness gates.

Exit gate: full coverage across the inventoried syntax, documented semantics,
targets, ABIs and passes, with known discrepancies explicit. A working subset or
wrapper around C QBE is not the full port. Publish separate compatibility and
certification matrices; full compatibility does not imply full certification.

## Verification workstream — runs through all stages

These V items are no longer deferred to a post-port phase.

- [ ] V01 — Precise source IR and target-machine semantics, including UB/traps,
  memory and external interactions. Begin in F01 and extend with each feature.
- [ ] V02 — Prove checker invariants and semantic preservation of lowering/passes,
  beginning with C01. Keep theorem scope aligned with the actual implementation.
- [ ] V03 — Prove allocation/spill correctness directly or prove the soundness of
  a validator checking proposed results. Develop alongside P09.
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

These stages describe acceptance gates, not a strictly serial implementation
schedule. Compatibility work can continue while foundations and proofs develop;
E03 can begin once job/artifact contracts stabilize, and encoding work can begin
once typed target lowering is stable. Additional optimizations and consumers must
not displace the first composed correctness result. No universal performance or
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
