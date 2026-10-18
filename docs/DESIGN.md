# Design and assurance boundaries

The first release is a general-purpose QBE 1.3 port in Lean 4, qualified against
upstream before further design changes. The current code is an early subset.
Concrete will consume this backend through a separate adapter; it does not
define the backend's public IR or implementation requirements. Zig's explicit
AIR/MIR split and LLVM's machine IR/pass testing inform later stages.
See [UPSTREAM.md](UPSTREAM.md).

## Implemented pipeline

1. `Parser.lean` parses the supported QBE-style integer syntax.
2. `Validate.lean` checks names, SSA dominance, phi predecessors, widths and limits.
3. `Semantics.lean` executes the supported IR using fixed-width integer semantics,
   signed comparisons/extensions, masked shifts and truncating signed division.
4. `AArch64.lean` selects integer instructions, assigns stack slots and renders
   leaf-function assembly with branches and parallel phi copies for Apple's AArch64 ABI.
5. Nix-provided Clang assembles and links independent C test callers.

The parser treats newlines as whitespace; upstream QBE also uses them as syntax
separators. Tests shared with QBE use its canonical multiline format. This is a
restricted compatible operation subset, not a claim of full QBE compatibility.
Names allow ASCII letters, digits and underscores, with a letter/underscore
first. Integer literals are decimal bit patterns in [-2^63, 2^64-1].

Functions have at most eight integer arguments, 480 instructions/phi nodes and 64 blocks;
programs have at most 64 functions and 1 MiB of input. Frames are 16-byte aligned,
at most 4080 bytes. Every value gets an eight-byte slot; word values access only
the low four bytes. Implicit word-to-long widening is rejected. No calls or
callee-saved registers are used. Scratch registers x9/x10/x11 are caller-clobbered.
Phi sources are staged in separate slots before destinations change, including
loop-carried copy cycles. Temporary definitions must be in SSA form and dominate
their uses; general QBE SSA construction remains unimplemented. The interpreter
executes at most 100,000 block steps and reports exhaustion explicitly. `hlt`
terminates native execution with a target-dependent error and has no return value.

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
