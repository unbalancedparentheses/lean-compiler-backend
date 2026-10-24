# Long-term architecture: multiple inputs, one verified backend core

Status: research proposal, 2026-10-24. This records the architecture discussion,
upstream research, and independent Claude review. It is not a claim that the
architecture, importers, or proofs below are implemented. The user prioritizes
long-term correctness, reuse, and maintainability over preserving today's design.

The implementation baseline for this document is `ac8324e`. Earlier code-review
findings were made before that baseline and need reproduction before being treated
as current defects. See [current design](../DESIGN.md),
[implementation roadmap](../../ROADMAP.md), and the earlier
[architecture research](backend-architecture.md) for existing work and evidence.
This proposal does not silently change the roadmap's execution queue.

## 1. Product and intended guarantee

Build a practical, language-independent native backend in Lean. Its distinguishing
goal is a composed guarantee about the actual production compilation path, with
manageable proof and maintenance costs. Being written in Lean, having many
theorems, or outperforming one benchmark is insufficient to establish that goal.

Proposed certified-mode contract:

> For every admitted core program successfully compiled in certified mode,
> the generated target program refines its specified behavior, under the declared
> target, external-call, resource, and execution-environment assumptions.

The initial theorem may end at structured target instructions. That is not a
theorem about assembled bytes or linked executables. Extend the endpoint only
when the corresponding encoding, relocation, and linking obligations are covered.

Keep three claims separate: tested compatibility, certified core compilation,
and preservation from an external format into the core. An unproved importer
does not invalidate a core theorem, but leaves the complete input-to-output path
uncertified. A successful importer or structural verifier is not itself a
semantic-preservation certificate.

QBE is the first external format and compatibility baseline, not the permanent
definition of the internal IR. Preserve its interface through an explicit adapter.
Do not make a particular source language's ownership or contract system part of
the generic backend. Language design is outside this document's scope.

## 2. Proposed architecture

```text
QBE text ------------ QBE parser and semantic importer -----------+
Selected external IR - format-specific lowering/importer ---------+
Typed construction API ------------------------------------------+
                                                                  |
                                                       Core structural verifier
                                                                  |
                                                        Core SSA + semantics
                                                                  |
                                                   Proved/validated optimization
                                                                  |
                                                     ABI legalization/lowering
                                                                  |
                                               Target machine IR + constraints
                                                                  |
                                               Allocation, spills, frame layout
                                                                  |
                                                 Located machine IR + checker
                                                                  |
                                                    Structured target assembly
                                                                  |
                                                 Rendering / eventual encoding
                                                                  |
                                                 External assembler and linker
```

Multiple inputs share the middle and back ends. They need semantic translators,
not just syntax wrappers. Each importer must document a supported version/profile,
target-layout assumptions, required runtime, and explicit refusal behavior.

Use a few purposeful representations:

* **External ASTs:** preserve source-format details and diagnostics until their
  meaning has been accounted for. They are outside the core operation vocabulary.
* **Core SSA:** typed computation, control flow, memory, calls, and explicit
  exceptional behavior. A candidate design uses numeric value/block identities,
  explicit block parameters and edge arguments, and a closed operation set.
* **Machine IR:** virtual registers, instruction forms, register classes,
  fixed/tied operands, clobbers, symbolic stack objects, and calling constraints.
* **Located machine IR:** physical locations and every inserted move, spill,
  reload, call clobber, and parallel-copy expansion that code generation consumes.
* **Structured assembly:** instructions, labels, sections, and relocations before
  textual rendering. Share representation with located MIR where semantics allow;
  do not add a new datatype solely to add a pipeline stage.

Separate semantic layers for operations, memory, and observable events, while
avoiding a different SSA datatype for every pass. Legality predicates can express
pre/post-lowering invariants. Aggregate/variadic ABI lowering may be an SSA-to-SSA
pass; physical argument placement belongs closer to machine lowering. The exact
ordering must preserve ABI classification information and be measured.

Prefer ordinary executable data plus proved well-formedness checks as the initial
production design. Fully indexed dependent SSA is an alternative to evaluate,
particularly when assessing lean-mlir reuse, rather than reject categorically.
Numeric identities need explicit scope and renaming laws; dense storage IDs are
not automatically stable identifiers for caching across edits.

Sequential block order can represent effects initially. Use a conservative effect
classification with proved properties for optimizations. Effect tokens or a
graph-scheduling IR need a demonstrated scheduling/proof benefit before adoption.

## 3. Semantic foundation: the most consequential decision

The existing compatibility interpreter and restricted verified source model have
different representations and coverage. Consolidate them or prove a translation
between them; do not accumulate a third disconnected semantic model. Executable
and relational semantics should have explicit correspondence theorems.

### Values, memory, and pointers

Specify integer widths and casts, floating-point results and environment,
allocation identity/lifetime, byte initialization, alignment, aliasing, and
pointer-to-integer observations. Memory optimizations require the same assumptions
that the semantics actually supplies.

A provenance-aware block/offset model is a strong candidate, not a settled choice.
It must account for QBE's integer-like pointer representation, address arithmetic,
pointer storage/reconstruction, external C interactions, and address observations.
Model physical addresses separately when lowering to a machine. Do not assert
that LLVM automatically fits this model or that all Wasm requirements disappear
when its linear memory is represented by one block.

Distinguish copying indeterminate bytes (including padding) from interpreting
them as scalar values. Define the accepted behavior explicitly instead of making
every uninitialized byte read either silently zero or universally undefined.
Reproduce an alias/promotion counterexample before declaring an optimizer bug;
also audit whether the stated input domain already excludes it.

### Outcomes and observations

Keep semantic traps, undefined behavior, divergence, and successful execution
distinct. Interpreter fuel exhaustion and unmodeled externals are limitations of
an evaluator, not evidence that the program traps or diverges. Prefer a fuel-free
step/trace specification with an adequate bounded executable interpreter.

Define external calls through explicit contracts and traces, including accessible
memory, allocation, callbacks where supported, and ABI assumptions. Account for
stack exhaustion and finite machine resources in the preservation statement.
Separate compilation and linking need contracts too; a theorem for a closed
function does not establish arbitrary external interoperability.

Wrapping arithmetic, checked arithmetic, and operations with undefined inputs
cannot be silently conflated. Importers can lower a checked operation into an
operation plus a condition and trap when that lowering is proved appropriate.
LLVM poison/undef and optimization flags need a justified refinement treatment,
not blind removal. Floating-point NaNs, signed zero, rounding, and exception
behavior require a declared model and target agreement.

## 4. Verification strategy and trust boundaries

**Direct proofs:** stable arithmetic rules, instruction-selection patterns,
parallel-copy algorithms, layout calculations, and simple structural lowerings.
Prove statements about evaluating the transformed production operation, not only
separate equations for a rewrite function and an arithmetic identity.

**Proved validators:** suitable heuristic results such as allocation, spilling,
and selected global rewrites. Acceptance must imply preservation against the
actual input/output and semantics. Validators are not generic equivalence oracles:
each supported transformation class needs sufficient evidence and explicit limits.
The checker should cover the located machine code, not merely an allocation plan
derived from the allocator's own potentially incorrect liveness analysis.

**Fallback:** optional rejected optimizations retain the input. Certified lowering
may use a separately proved stack baseline for its supported domain. This does
not promise that every input compiles: resource limits, unsupported operations,
and target restrictions still cause explicit refusal. No uncertified fallback
may satisfy a request for certified output.

Track per-stage assurance: structural checks, execution tests, direct proofs,
or proved semantic validation. Bind evidence to exact inputs, outputs, target,
options, dependency identities, and checker versions. Hashes and receipts identify
evidence; they do not establish semantic correspondence.

Keep proof automation and compiler execution separable. Importing theorem modules
does not by itself prove a runtime size problem: measure linkage, initialization,
build dependencies, and elaboration costs before restructuring packages for speed.
For native checkers, name Lean compilation/runtime trust; kernel replay of proof
objects can change that boundary but has its own cost and engineering requirements.

Target semantics need an independent ISA justification. A target evaluator that
restates source arithmetic is useful scaffolding but not evidence of hardware
agreement. Investigate existing ISA models rather than invent every instruction
semantics. Decoding emitted output can validate encoding correspondence, but
round trips alone do not prove instruction execution, relocations, or linking.

Functional correctness does not imply constant-time execution. Security work
needs a separate leakage model, paired-execution reasoning, and preservation
through lowering. Secret-dependent traps, memory addresses, calls, and intentional
output disclosure all matter. Keep this a separately scoped future capability.

## 5. External IR landscape and importer policy

| Input | Opportunity | Semantic/integration cost | Position |
|---|---|---|---|
| [QBE IL](https://c9x.me/compile/doc/il.html) | Existing users, compact native interface, current corpus | Width rules, pointers, aggregate/variadic calls, linkage | First adapter; supported compatibility remains explicit |
| [LLVM IR](https://llvm.org/docs/LangRef.html) | Broad frontend ecosystem | Poison/undef, pointers, intrinsics, vectors, atomics, exceptions, layout and versioning | Consumer-driven, versioned subset; never advertise full LLVM from parser coverage |
| [MLIR dialects](https://mlir.llvm.org/docs/Dialects/) | Specialized compiler ecosystem and upstream lowering infrastructure | Each dialect has semantics; regions, memory and runtime requirements vary | Select dialects and legal operations; not limited to the LLVM dialect |
| [CLIF](https://cranelift.dev/) | Low-level general-purpose native IR | Traps, calls, target features, importer maintenance | Evaluate only with a concrete consumer |
| [Makarov MIR](https://github.com/vnmakarov/mir) | Compact low-level IR and interpreter/JIT ecosystem | SSA construction, machine-dependent details and runtime conventions | Possible adapter, not a JIT commitment |
| [WebAssembly](https://webassembly.github.io/spec/core/intro/introduction.html) | Portable modules with specified execution behavior | Bounds/traps, tables, imports, memory growth and runtime | Separate product-sized integration; choose a feature profile |
| [Rust MIR](https://rustc-dev-guide.rust-lang.org/mir/index.html) | Rust compiler integration | Layout, monomorphization, drops, unwinding and compiler internals | Dedicated frontend project, distinct from Makarov/LLVM MIR |
| [SPIR-V](https://www.khronos.org/spirv/) | Graphics and parallel compute | GPU execution, synchronization and memory spaces | Outside current CPU-backend scope |

Support multiple importers architecturally, without promising to implement all of
them. Start with QBE plus a typed construction API and a canonical, versioned core
serialization. Pick additional adapters through consumer demand and measured
maintenance cost. A structural verifier still checks builder-created programs.

An external format need not have an official formalization before we can define
one and prove importer preservation. However, correspondence to its intended
specification and ecosystem is then an additional obligation; differential tests
help but do not prove it. The QBE importer should not be the sole circular
definition of what correct QBE translation means.

## 6. Reuse and prior art

The proposal combines established ideas. Do not claim invention of shared IRs,
translation validation, verified backends, or Lean-based SSA rewriting.

| Project | Relevant contribution | Reuse decision / boundary |
|---|---|---|
| [QBE](https://c9x.me/compile/) | Small native backend, C ABI, SSA, practical optimization selection | Retain fixtures and differential oracle; do not infer complete parity from fixture counts |
| [MIR](https://github.com/vnmakarov/mir) | Lightweight compilation, splitting/coalescing, embedding | Study allocator algorithms; JIT/runtime scope is optional |
| [Cranelift](https://cranelift.dev/) | Production JIT/AOT, explicit constraints, validation, fuzzing | Borrow engineering and testing methods; selected proofs are not full pipeline certification |
| [CompCert](https://compcert.org/doc/index.html) | Semantic preservation, intermediate languages, validation and linking work | Reference for behavior/refinement and proof composition; evaluate reuse with licensing and language costs |
| [CakeML](https://cakeml.org/) | Verified backend to machine code and verified bootstrapping | Reference for endpoint and trusted-base completeness |
| [Jasmin](https://jasmin-lang.readthedocs.io/en/latest/compiler/passes/index.html) | Proved passes and validators for crypto compilation | Study machine constraints and separate security preservation; not a general timing guarantee |
| [Axon](https://github.com/rinard/Axon) | Lean translation-validation architecture and corrupted-certificate tests | Study actual checker soundness and structured emission; respect disclosed trust assumptions |
| [lean-native](https://github.com/Th0rgal/lean-native) | Rejected-optimization fallback, lightweight core and experiments | At reviewed `69d1269`, generic gate theorem assumes soundness; bounded production checks do not establish universal refinement |
| [lean-mlir](https://github.com/opencompl/lean-mlir) | Lean SSA calculus and semantic-preservation infrastructure for rewrites | Highest-priority reuse evaluation before building generic SSA rewriting ourselves |
| [iris-lean](https://github.com/leanprover-community/iris-lean) | Separation-logic proof mode, resources and memory reasoning | Evaluate on our actual byte-memory/frame proof; not automatically a compiler proof |
| [Vellvm](https://github.com/vellvm/vellvm) | Formal LLVM-inspired semantics and interpreter | Study memory/undefined behavior and executable/formal correspondence; not proof of all LLVM |
| [Alive2](https://github.com/AliveToolkit/alive2) | Bounded LLVM translation validation | Potential independent oracle where a faithful translation exists; not a Lean proof of our IR |
| [Dafny](https://github.com/dafny-lang/dafny) | Modular specifications and proof diagnostics | Lessons for obligation isolation and reporting, not a competing native backend |

The [lean-mlir paper](https://arxiv.org/abs/2407.03685) provides verified generic
peephole rewriting, including regions and domain-specific examples. It does not
provide our complete ABI-facing CPU backend. The
[Iris in Lean paper](https://arxiv.org/abs/2609.24252) and
[proof-mode interface](https://github.com/leanprover-community/iris-lean/blob/master/docs/proofmode.md)
support an incremental evaluation, including a simpler separation logic before
full Iris adoption. Check actual supported constructs, licenses, dependency size,
Lean-version compatibility, and axiom dependencies before importing code.

MLIR versus Lean is not a binary choice. Compare:

1. Our existing Lean infrastructure, consolidated around one semantic foundation.
2. A core using lean-mlir's reusable theory and rewriting machinery.
3. MLIR upstream, lowering a declared profile into a small Lean backend core.

MLIR provides substantial IR/pass tooling but does not automatically prove our
transformations. A Lean implementation can make the executed checker the exact
function a theorem references, but that advantage is lost if a second unconnected
model is what the proof actually covers. Avoid a universal dialect framework
unless concrete requirements justify its permanent cost.

## 7. Independent Claude review and unresolved findings

Claude completed a read-only review on 2026-10-23. It did not run tests or builds.
Its main useful observations were separate compatibility/verified semantics,
fused production emission, allocation checks above the emitted-instruction level,
and the need to distinguish evaluator limitations from semantic outcomes.

It also raised a potential mismatch between flat integer-address memory and
scalar-promotion non-aliasing assumptions. Treat this as a research hypothesis:
reproduce a defined-domain counterexample and inspect current code before claiming
a confirmed bug. New upstream implementation commits postdate that review.

We do not adopt every recommendation verbatim:

* QBE can have an independently defined semantics even without an official one.
* MLIR integration can use non-LLVM dialects.
* A block/provenance model is not automatically sufficient for LLVM or Wasm.
* A proved stack fallback cannot promise compilation of unsupported inputs.
* A narrow pilot need not prove every branch of the existing algebra optimizer.
  Keep unsupported transformations explicitly outside its certified domain.
* Dependent IRs, Iris, and object/JIT work should be evaluated, not universally
  mandated or permanently forbidden.

The comparison favors reuse and lifetime costs, not theorem count, line count,
marketing labels, or sunk implementation effort. No overall performance or
assurance superiority has been established.

## 8. Research experiments and acceptance criteria

### R1: Shared-semantics and reuse experiment

Pin candidate revisions. Implement the same representative slice using existing
infrastructure and lean-mlir: word/long arithmetic, one conditional/edge transfer,
and a small loop where supported. Include a memory/call boundary analysis even if
those features cannot yet be implemented. A straight-line identity alone cannot
settle long-term architecture.

Require a theorem connecting any imported representation to our actual evaluator;
identify unsupported CFG/effect constructs rather than masking them. Compare
proof effort, integration glue, build/check time, execution cost, dependency
stability, and effort to add a new operation. Record direct reuse, adaptation, or
rejection with evidence. Prefer upstream contributions for generic missing pieces.

### R2: Production integer-rewrite validation pilot

Define a small admitted fragment, initially literal zero/one identities at word
and long widths. Expose a pure evaluator used by the actual interpreter, or prove
its correspondence. Define a checker over the actual before/after operation and
prove that acceptance preserves evaluation on its declared domain. State whether
failed operand resolution or faults are preserved or excluded by hypotheses.

Wire it to the production transformation for that fragment. Reject mutated
operands, widths, constants and opcodes; retain original input on rejection.
Test word truncation and boundary values. Existing broader rewrites remain
explicitly uncertified until covered. Normalized constants, powers of two, and
division rules are separate extensions, not silently implied by literal proofs.

Audit exact theorem dependencies and prohibit new proof placeholders/trust axioms.
Compare corpus output with validation enabled/disabled and measure compile-time
and memory overhead. Report accepted/rejected/unsupported counts. This proves
neither constant-propagation facts nor whole-pass preservation by itself.

### R3: Memory-model and Iris experiment

Specify allocation, pointer exposure, byte copying and external-call cases first.
Prove a store/load property plus preservation of disjoint memory over the actual
candidate model, with and without Iris infrastructure. Include aliasing and
padding examples. Adopt a library only if its total integration and maintenance
cost beats the simpler alternative without weakening the claim.

### R4: Machine boundary and allocation validation

Choose one target and a small integer/control-flow/internal-call profile.
Represent fixed operands, clobbers, all generated moves and frame accesses.
Check the located MIR that rendering consumes and prove its checker sound.
Establish the baseline fallback separately. Mutation tests must include wrong
reloads, clobbered live values, overlapping slots and broken parallel copies.
An eventual ISA-model connection is a separate obligation, not inferred from
agreement with the source evaluator.

## 9. Migration, measurements, and open decisions

Research sequence: R1 and semantic contracts inform the core choice; R2 provides
a bounded production proof; R3 resolves memory choices; R4 establishes a machine
boundary. This is not an instruction to rewrite the entire backend at once.
Preserve tested behavior during migrations, keep the old path as a differential
reference, and remove duplicate implementations once correspondence and coverage
justify doing so. Never retire a semantics solely because finite tests agree.

Keep pure function jobs, dependency snapshots, deterministic output, replay,
versioned serialization, and precise error locations from earlier research.
Independent tests include original QBE, C callers, real libraries, cross-target
execution, malformed inputs, resource pressure, and malicious certificates.
Benchmark compilation, checking, peak memory, generated runtime, and code size
separately, including enabled/disabled pass comparisons and pinned identities.

AOT assembly is the current deployment boundary. Direct objects, decoder checks,
JIT support, SIMD, GPU targets, and constant-time certification remain separately
justified capabilities. Windows remains outside the user's current scope.

Open decisions to resolve before a major migration:

1. Which lean-mlir components can we directly reuse for our CFG/effect domain?
2. Consolidate the two source representations or retain a proved translation?
3. Which pointer/integer observations, undefined inputs, and external effects does
   the core admit, and how do importers preserve their meanings?
4. Which ABI operations remain in Core versus target machine lowering?
5. What exact target/operation profile forms the first composed certified path?
6. Native validator execution, kernel proof replay, or both, at which boundaries?
7. Which consumer justifies the second external importer?
8. When does encoding/linking verification deliver enough value to expand scope?

Success means reusable guarantees about production behavior with sustainable cost.
It does not mean accepting the most formats or inventing the most infrastructure.
