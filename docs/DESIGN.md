# Design and assurance boundaries

The first complete compatibility milestone is a general-purpose QBE 1.3 port
in Lean 4. The current code is a bounded subset, not an end-to-end verified backend.
The [roadmap](../ROADMAP.md) starts semantic contracts, independent function jobs,
typed lowering and proof composition during the port. These are planned foundations;
the implemented pipeline and existing assurance scope are described below.
Concrete consumes the backend through a separate adapter and does not define
its public IR. QBE is the initial baseline, not a permanent semantic constraint.
See [UPSTREAM.md](UPSTREAM.md) and the
[architecture research](research/backend-architecture.md).

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
   direct calls for Apple's AArch64 ABI.
5. Nix-provided Clang assembles and links independent C test callers.

The parser treats newlines as whitespace; upstream QBE also uses them as syntax
separators. Tests shared with QBE use its canonical multiline format. This is a
restricted compatible operation subset, not a claim of full QBE compatibility.
Names allow ASCII letters, digits and underscores, with a letter/underscore
first. Integer literals are decimal bit patterns in [-2^63, 2^64-1].

Functions have at most 64 integer arguments, 480 instructions/phi nodes and 64 blocks;
programs have at most 64 functions and 1 MiB of input. Frames are 16-byte aligned,
at most 4080 bytes. Every value gets an eight-byte slot; word values access only
the low four bytes. Implicit word-to-long widening is rejected. Scratch registers
x9/x10/x11 are caller-clobbered; no callee-saved integer register is modified.
Direct calls accept up to 64 typed w/l arguments and a w/l or void result. The
first eight arguments are loaded from stable slots into x0..x7/w0..w7, preserving
permutations. Apple ARM64 places later word arguments in four-byte aligned slots
and long arguments in eight-byte aligned slots. The outgoing area is rounded to
16 bytes and reserved below locals, phi staging, saved LR and allocated objects.
Its size covers the largest call in the function, so nested calls cannot clobber
live caller values. Incoming stack arguments are read above the complete local
frame, using offsets from the caller's SP. Caller and callee use the same explicit
argument layout, checked against independent C in both directions. The 64-argument
cap is a resource policy, not an ABI constraint; the frame limit remains separate.
Non-leaf functions reserve a separate slot for x30 and restore it before return.
All values live across calls remain in the caller's frame, outside callee clobbers.
Internal call argument/result signatures must match their definitions exactly.
External signatures are an explicit linking assumption: QBE IL has no external
declaration to check. Indirect calls, sub-word/aggregate
ABI types, environment arguments and variadics remain unsupported.
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

Stack allocations currently have positive constant sizes at most 4096 and must
occur in the entry block, which cannot be revisited. This makes one frame object
per allocation faithful for the admitted domain. Allocations in loops and dynamic
sizes are explicitly refused until dynamic stack lifetime/restoration is ported.
Objects are disjoint from value slots and phi staging and honor their required
alignment; the overall frame limit still applies.

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

The planned machine IR will make stack accesses, registers, immediates and
prologue/epilogue operations explicit. Each lowering stage needs a verifier and
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
