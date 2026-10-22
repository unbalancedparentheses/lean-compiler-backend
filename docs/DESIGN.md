# Design and assurance boundaries

The first complete compatibility milestone is a general-purpose QBE 1.3 port
in Lean 4. The current code is a bounded subset, not an end-to-end verified backend.
The compatibility module API includes packed integer data, global addresses and
width-aware symbol initializers (native relocation support depends on the linker); the function-only first proof profile excludes these.
The [roadmap](../ROADMAP.md) prioritizes full QBE compatibility before further
formal proof expansion. Existing semantic contracts, independent function jobs,
typed lowering and proofs remain maintained; C01 composition is deferred.
The implemented pipeline and existing assurance scope are described below.
Concrete consumes the backend through a separate adapter and does not define
its public IR. QBE is the initial baseline, not a permanent semantic constraint.
See [UPSTREAM.md](UPSTREAM.md) and the
[architecture research](research/backend-architecture.md).

The [F00 specification](research/first-verified-path.md) fixes the proposed first
proof domain: leaf integer functions with loops, simultaneous phi transfers and
compiler-owned frame accesses, ending at typed AArch64 assembly. It specifies
job/artifact contracts and pass obligations. This is a completed design deliverable;
the [F02–F05 implementation](FOUNDATIONS.md) now adds the typed target pipeline
and replayable jobs. Checker soundness and the composed proof remain open.
[F01](SEMANTICS.md) adds numbered raw source syntax, executable bit-vector
semantics, profile admission and two source-model lemmas. The result of admission
is not proof-carrying `CheckedSSA`. The CLI defaults to the compatibility path;
`--first-path` opts into the narrower typed baseline with explicit uncertified output.
Source memory, calls and native binary certification remain outside that domain.

## Implemented pipeline

The compatibility path and the restricted typed first path are separate. The
compatibility driver in `Main.lean` composes these stages:

1. `Parser.lean` reads the supported QBE-style scalar, floating, aggregate, data,
   linkage and debug syntax. `SSA.lean` converts mutable temporaries into SSA.
2. `Validate.lean` checks types, names, dominance, phi predecessors, internal
   signatures and resource limits. Validation is an executable check, not a
   proof-carrying admission theorem.
3. Optional `Optimize.lean` passes simplify values/control flow, promote eligible
   scalar objects and perform conservative memory/common-expression transforms.
   `CFG.lean`, `Liveness.lean`, `Selection.lean` and `Allocation.lean` supply shared
   analyses, selection facts, checked register allocation and reusable spill homes.
4. `AArch64.lean`, `AMD64.lean` and `RV64.lean` lower functions and render assembly
   for the five supported Linux/macOS configurations. Target ABI planners classify
   scalar/aggregate parameters and results, variadics and outgoing storage.
   `Assembly.lean` shares symbol/data rendering. The default stack baseline remains
   available independently of optional optimization/allocation.
5. External assemblers/linkers produce native programs. Test harnesses compile
   independent C callers and compare behavior with platform C and retained QBE;
   these toolchains remain outside the proved boundary.

`Semantics.lean`, `Floating.lean` and `Memory.lean` provide a bounded testing
interpreter alongside this compilation path. Abstract byte-addressed objects
track initialization and activation lifetime. Uninitialized, out-of-bounds and
unmodeled external accesses report an unevaluated result; native output does not
inherit those checks. External calls are tested through native C interoperation,
not assigned invented interpreted values.

Compatibility limits are explicit resource policies: 4,096 functions and data
definitions, 4,096 blocks and 70,000 instructions/phis per function, 1,024
arguments, 1 MiB fixed frames/outgoing areas and 256 MiB native module data.
Parsing retains its 8 MiB input, 600,000-token and 16,384-top-level-item budgets.
The interpreter has a 1 MiB memory budget, 100,000 shared block steps and a
128-level call-depth limit. The restricted first path retains its independent
smaller admission bounds. The source definitions and validators are authoritative
when extending these policies.

Static/dynamic stack objects preserve requested alignment, including zero-size
allocations. Constant objects and blits are admitted through 1 MiB, subject to
frame limits; larger copies use compact loops. Blit spans must be disjoint or
identical, and a zero-byte blit accesses no memory. Native dynamic allocation
assumes valid nonnegative sizes and sufficient stack capacity. There is no
runtime memory-safety guarantee.

Internal call signatures are checked, including exact structural aggregate
aliases; native external/indirect targets must honor their declared ABI.
Effect-only scalar calls may discard a result while retaining the call's effects.
Aggregate return storage remains explicit. ABI details differ by target: Apple's
packed scalar stack arguments and variadic cursor are not universal Linux rules.
Parallel phi transfers preserve cycles, and allocation keeps live values outside
caller clobbers using supported homes; broader allocation remains open.

The parser's accepted grammar, assembler-dependent string/section behavior,
undefined arithmetic domains and independent test exclusions are recorded in
[SEMANTICS.md](SEMANTICS.md), [PORT_STATUS.md](PORT_STATUS.md),
[UPSTREAM_DISCREPANCIES.md](UPSTREAM_DISCREPANCIES.md) and the linked qualification
reports. Neither accepting a public opcode name nor passing a fixture establishes
full QBE compatibility.

## What is proved

`AArch64.select_preserves` relates each supported source binary operation to an
abstract target ALU operation for every pair of UInt64 inputs and either width.
Its proof is by cases and reduction. `scripts/ProofAudit.lean` prints its axiom
dependencies; the Nix checks require the measured standard Lean dependencies
`propext` and `Quot.sound`, with no additional axioms or admitted goals.

That theorem concerns an abstract ALU specification we wrote. It does not connect
the assembly text or machine bytes to the ARM architectural specification. It
does not establish source-to-binary correctness, memory safety, compiler-runtime
safety or correctness of the compiler's generated C.

`Verified.Source.step_deterministic` proves uniqueness of source successor states.
`Verified.Source.run_return_sound` connects a successful fuel-bounded source run
to a return witness in the unbounded small-step relation. Both have the measured
axioms `propext` and `Quot.sound`, enforced by the proof audit. Neither connects
source semantics to machine code, proves admission soundness, or proves agreement
with the compatibility interpreter. See the [semantic ledger](SEMANTICS.md).

The [foundations report](FOUNDATIONS.md) lists new target-helper and binding proofs,
their exact axioms and the remaining simulation obligations. Artifact binding
proves equality with the recomputed baseline; it does not prove that the baseline
preserves source behavior. No requested certification is silently downgraded.

## What is tested

The checks exercise malformed inputs, interpreter arithmetic, native arithmetic
against independent unsigned C, C argument/return conventions and the absence
of imported Lean runtime symbols. The same valid fixture is compiled by QBE 1.3
and run with the same C caller. QBE is an independent comparison implementation,
not a trusted proof oracle. Random testing is evidence for the exercised cases.
Memory checks additionally compare native C byte-array references and C-owned
buffers with neighboring guard bytes. A measured QBE 1.3 load-forwarding bug is
handled through explicitly separate original and corrected comparisons; see
[the discrepancy and its reduced controls](UPSTREAM_DISCREPANCIES.md).

Blit tests compare fixed and generated copies with independent byte-array
references and original QBE, check neighboring guard bytes and preserve the
distinction between unknown-byte copies and initialized reads. Invalid counts,
undefined spans and partial overlap have separate rejection controls. Deliberate
copy corruption must be detected by native comparisons.

Call tests compare fixed and generated multi-function programs among Python,
Lean interpretation, Lean native code, original QBE and independent native C.
They exercise integer/void recursion, argument order, loop/branch calls,
caller-owned memory, effect-only C calls and mixed word/long results.
An assembly C-ABI probe checks stack alignment,
stack balance and callee-saved registers while an external callee clobbers
caller-saved registers and flags. Deliberate live-value and callee-saved-register
corruptions must fail their respective checks.
Stack-argument qualification covers counts from eight through 64, word/long
packing patterns, internal/external calls and non-leaf incoming parameters.
Recursive cases retain each caller's local stack object. Deliberately widened
outgoing word stores and displaced incoming loads must change native results.

`scripts/argument_limits.py` additionally checks seven signatures: scalar mixtures
at 64/65/128/1024 arguments, narrow/aggregate mixtures at 65/1024, and 1024
all-aggregate arguments. Sixteen seeds and five call paths give 560 independent C
checks per lowering mode and target. Baseline, allocated and optimized output
passed on Apple ARM64 and Linux ARM64 natively, Apple x86-64 through Rosetta,
and Linux x86-64/RV64 through QEMU. Unchanged QBE matches seven profiles on both
ARM64 targets and Linux x86-64, five on Apple x86-64, and four on RV64. Apple
x86-64 excludes the two narrow mixtures; RV64 excludes both narrow mixtures and
the all-aggregate case. The retained upstream narrow-call and large positive
aggregate-address failures do not weaken the independent LCB/C checks. Only the
RV64 QBE reference uses `-no-pie`; LCB retains default linking. Refusal controls
cover 1025 arguments, oversized incoming/outgoing frames, and the separate
certified eight-parameter limit; a corrupted return must fail the C oracle.

The first-path machine IR now makes stack accesses, registers, immediates and
prologue/epilogue operations explicit; its typed assembly has legality checks and
an owned-frame execution model. Each lowering stage needs a verifier and
an executable semantics before optimization or register allocation grows. Actual
emitted assembly and eventually object bytes need independent decoding and
validation; checking only the pre-emission representation leaves an emitter gap.

## Compiler runtime versus generated programs

Building the compiler: Lean source → Lean's C output → compiler executable
(with Lean runtime). Running the compiler: supported SSA → assembly → native
target program. The second chain does not insert Lean runtime calls. Adding
language runtimes, stack checks, sanitizer hooks or helper calls is a separate,
explicit backend/ABI decision.

Nix pins the build and testing tools. It does not prove those tools correct.
The assembler, linker, host OS, hardware and Lean kernel remain trust boundaries.
Concrete's own checked IR and runtime semantics are a future integration boundary.

### Scalar floating compatibility path

Compatibility values carry both a storage width and an integer/floating class;
the restricted integer proof model retains its original Width type. Validation
checks the class at every use, including phi edges, memory stores, call arguments
and return values. Explicit conversion/cast operations are the only class changes.
The baseline keeps raw bits in stack slots, using caller-saved FP scratch registers
for arithmetic. ABI lowering allocates GP and FP argument banks independently.
The executable floating model and differential tests are compatibility evidence;
first-path admission rejects floating types and operations.

### Compatibility SSA construction

`SSA.constructModule` runs only in the compatibility CLI load path. Each definition
gets a fresh deterministic name; a per-block last-definition table resolves uses
across edges. Join placeholders are cached before recursive predecessor reads so
loop-carried references terminate. Phis are introduced only when a variable is
read across a join. A collision-free prefix keeps generated names separate from
user identifiers. The pass checks stable variable types and validates the complete
result; optimizing trivial phis and the remaining QBE analyses/passes are separate
work. The restricted job/admission path consumes the original parsed module.
