# Design and assurance boundaries

The first complete compatibility milestone is a general-purpose QBE 1.3 port
in Lean 4. The current code is a bounded subset, not an end-to-end verified backend.
The compatibility module API includes packed integer data, global addresses and
64-bit pointer initializers; the function-only first proof profile excludes these.
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

1. `Parser.lean` parses the supported QBE-style integer syntax.
2. `Validate.lean` checks names, SSA dominance, phi predecessors, widths and limits.
3. `Semantics.lean` executes the supported IR using fixed-width integer semantics,
   signed comparisons/extensions, masked shifts and truncating signed division.
   `Memory.lean` provides byte-addressed objects for integer loads, stores and
   blits; stores, blits and void calls are explicit statements without SSA result
   definitions.
4. `AArch64.lean` selects integer instructions, assigns stack slots and renders
   assembly with branches, parallel phi copies, integer memory accesses, blits and
   direct/indirect calls for Apple's AArch64 ABI.
5. Nix-provided Clang assembles and links independent C test callers.

The parser treats newlines as whitespace; upstream QBE also uses them as syntax
separators. Tests shared with QBE use its canonical multiline format. This is a
restricted compatible operation subset, not a claim of full QBE compatibility.
Unquoted names follow QBE's ASCII grammar, including dots and embedded dollar
signs, with a letter, underscore or dot first. Integer literals are decimal bit patterns in [-2^63, 2^64-1].

Functions have at most 64 integer arguments, 480 instructions/phi nodes and 64 blocks;
programs have at most 64 functions and 1 MiB of input. Frames are 16-byte aligned,
at most 1 MiB in the compatibility backend (4080 bytes in the restricted first
proof profile). Large frame adjustments and allocation addresses use split
AArch64 immediate scales; large incoming stack offsets use a scratch address
register. Every value gets an eight-byte slot; word values access only
the low four bytes. Implicit word-to-long widening is rejected. Scratch registers
x9/x10/x11 and the x16 indirect-call target are caller-clobbered. Dynamic
allocation functions save/restore x29 and use it as a stable frame base.
Direct/indirect calls accept up to 64 typed w/l arguments and a w/l or void result. The
first eight arguments are loaded from stable slots into x0..x7/w0..w7, preserving
permutations. Apple ARM64 places later word arguments in four-byte aligned slots
and long arguments in eight-byte aligned slots. The outgoing area is rounded to
16 bytes. Static-frame functions reserve it below locals, phi staging, saved LR
and allocated objects; its size covers the largest call. Dynamic-frame functions
reserve and release it at each call below the current SP, protecting live objects. Incoming stack arguments are read above the complete local
frame, using offsets from the caller's SP. Caller and callee use the same explicit
argument layout, checked against independent C in both directions. The 64-argument
cap is a resource policy, not an ABI constraint; the frame limit remains separate.
Non-leaf functions reserve a separate slot for x30 and restore it before return.
All values live across calls remain in the caller's frame, outside callee clobbers.
Internal call argument/result signatures must match their definitions exactly.
External signatures are an explicit linking assumption: QBE IL has no external
declaration to check. The interpreter checks dynamically resolved internal call
signatures; native indirect targets must honor the declared ABI. Sub-word/aggregate
ABI types remain unsupported. A first `env` parameter/argument uses x9 without
consuming an ordinary argument register. Callees save it before stack-argument
loads; callers set it after ordinary argument preparation. Integer variadics use
eight-byte stack slots for unnamed arguments and an eight-byte va_list cursor;
floating/aggregate variadic arguments remain unsupported.
Void results are represented by absence of a value in the IR and interpreter;
they are not integer zero. A return with the wrong presence/type of value, an
integer assignment from a void call, or an internal non-void call without a
result temporary is rejected. `--eval` prints `void` for a void return.
Phi sources are staged in separate slots before destinations change, including
loop-carried copy cycles. Temporary definitions must be in SSA form and dominate
their uses; general QBE SSA construction remains unimplemented. The interpreter
executes at most 100,000 block steps across the entire call tree, with a 128-level
call-depth limit, and reports exhaustion explicitly. `hlt`
terminates native execution with a target-dependent error and has no return value.

Stack allocations accept positive constant sizes up to 4096 or long runtime size
operands, in any block. Entry-only constant allocations retain the static-frame
layout. Other functions allocate at the point of execution, including repeated
loop allocations, using a stable x29 base and canonical saved FP/LR record.
Returning restores the fixed-frame SP and caller FP/LR. Objects remain distinct
from SSA/phi slots and outgoing argument areas. Native dynamic allocation assumes
valid sizes and sufficient stack capacity; it adds no size/capacity guard. The
interpreter bounds total live memory and refuses zero-sized runtime allocations.

Interpreter addresses are abstract, not host pointers. Each object tracks byte
initialization. Out-of-bounds, uninitialized and external-pointer accesses have no
interpreted result. Native code has ordinary QBE loads/stores without those
checks. Tests avoid undefined accesses; pointer integer values are not compared
between interpreter addresses and real machine addresses.

Blits have two address operands and a constant byte count in 0..4096, with no
result temporary. The count cap limits generated code size; QBE itself requires
a nonnegative numeric constant and recommends keeping it small. Source and
destination spans must be disjoint or have identical addresses, following the
retained QBE 1.3 `doc/il.txt` contract. Interpretation rejects partial overlap
and requires nonempty spans to lie in allocated objects. It copies each byte's
initialization state, so an unknown source byte remains unknown at the
destination and a subsequent read still fails. A zero-byte copy accesses no
memory. Native output has no overlap or bounds guards; testing within the
defined domain does not establish memory safety or source-to-binary correctness.

Interpreted callees share the caller's memory, so their stores persist on return.
Each return invalidates the callee's stack objects while retaining caller-owned
objects and their mutations. Abstract addresses are not reused. An external call
has no interpreter model and reports an unevaluated result; native C interoperation
is tested separately rather than fabricating an interpreted value.

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
