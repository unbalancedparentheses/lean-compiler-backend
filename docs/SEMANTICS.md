# Semantic decision ledger

F01 establishes the first-path source contract, `ssa-int-v1`. The implementation
is in [Verified/Source.lean](../LeanCompilerBackend/Verified/Source.lean) and
[Verified/Admission.lean](../LeanCompilerBackend/Verified/Admission.lean).
The [F00 specification](research/first-verified-path.md) remains the design for
the later job, target and proof boundaries. This ledger distinguishes decisions
implemented in the restricted source model from compatibility behavior and
future proof obligations. The `Verified` namespace names the workstream; it is
not a certification claim.

## First-path domain

| Topic | Decision and implemented behavior |
| --- | --- |
| Integers | Separate `BitVec 32`/`BitVec 64` values; wrapping add/sub/mul and bitwise and/or/xor. No signed-overflow traps or poison. |
| Comparisons | Equality and unsigned less-than at either width produce a word 0/1. |
| Constants | Reduce modulo 2^width at import; negative literals are bit patterns. Text parsing retains the existing signed/unsigned 64-bit literal bounds. |
| Widths | Exact temporary operand widths. Compatibility-mode implicit long-to-word narrowing is rejected by this profile. |
| State | Block ID, body instruction position and an array of optional typed values. Uninitialized values never default to zero. |
| Control flow | Every body instruction and terminator is a separate step. Word conditions test all bits for nonzero. Phi operands are read from the predecessor environment before any destination changes. |
| Observations | Return with typed bits or divergence. The source model contains no program-memory observations, external calls or admitted traps. |
| Budgets | `run` counts source steps. `exhausted state` is inconclusive, distinct from `returned value` and `stuck fault`. Compatibility evaluation counts blocks and is not compared by equal fuel. |
| Divergence | `Diverges f s` means nonreturning prefixes of every finite length in the deterministic step relation. Finite exhaustion does not prove it. |
| Malformed raw syntax | Missing values/blocks, wrong widths/destinations, bad instruction positions and malformed selected phi transfers produce explicit faults. Raw `Source.Function` is not `CheckedSSA`. |
| Numbering | Parameters first, then block-order phis/instructions. Blocks retain input order. Phi inputs are ordered by predecessor block ID. Names do not survive into this syntax. |
| Admission | Existing SSA/dominance validation plus strict profile filtering, all-block reachability, 0..8 parameters, 1..64 blocks, at most 480 definitions, and the planned 4080-byte stack-frame bound. |
| Failure classes | Invalid input, unsupported feature and resource limit are explicit constructors. Validation can reject malformed unsupported constructs as invalid before profile filtering. No failure is a source return or divergence observation. |

The planned frame size is `alignUp(8*(N+P),16)`, where N includes parameters and
all definitions and P is the maximum block phi count. Admission checks this
resource policy now, but no frame storage or target lowering is implemented in
this new path. First-path memory is only an array of source SSA values; it is not
the byte-memory model needed for proving target frame accesses.

## Excluded behavior and compatibility boundaries

| Feature | Existing compatibility behavior | First-path decision |
| --- | --- | --- |
| Shifts | Mask count to width minus one; signed right shift follows the documented fixed-width model. | Reject all shifts until their source/target lemmas are added. |
| Division/remainder | Zero divisor and signed-minimum/-1 are outside the defined equivalence domain; interpreter rejects. | Reject all division and remainder; no undefined arithmetic in this profile. |
| Conversions/unary operations | Explicit sign/zero extension and negation are implemented; long-to-word uses may narrow. | Reject, including implicit narrowing. |
| Source memory | Abstract little-endian byte objects track initialization/lifetime; bad accesses and external pointers are unevaluated. Native output adds no safety checks. | Reject load/store/alloc/blit, including zero-byte blit. Pointer provenance, aliasing and source-memory simulation remain outside this theorem domain. |
| Calls | Internal interpreter calls share memory and budgets; return invalidates callee allocations. External calls have no interpreter model. Native callees must honor the declared ABI. | Reject all calls; no imported contracts or external interactions. |
| `hlt` | Native target-dependent error; interpreter reports no value. | Reject. No mapping from host signals to a modeled trap is claimed. |
| Void, stack arguments, aggregates, FP, TLS | Supported slices or explicit rejections as recorded in the port inventory. | Reject all; exactly one integer result and at most eight integer parameters. |
| Concurrency, callbacks, unwind, nonlocal exit | No general semantic/preservation contract. | Excluded, not silently modeled as sequential ordinary operations. |

These exclusions prevent new transformations from relying on unspecified memory,
call or trap behavior. Extending the profile requires updating the ledger,
semantics, admission, tests and applicable proofs together. None of these
restrictions removes existing CLI compatibility support.

## Target and environment assumptions

The intended target remains little-endian Apple AArch64, integer leaf ABI, with
arguments in W0/X0 through W7/X7 and result in W0/X0. The later target proof will
assume aligned SP, exclusive available frame space, no address wrap and a valid
return address, and require restored SP, preserved callee-saved registers and
unchanged memory outside the frame. Source operations cannot observe frame
addresses. There is no target-machine execution relation in F01 yet; these
conditions are specified in F00, not proved by the source interpreter.

Parser/importer correctness, admission soundness/progress, correspondence with
the existing interpreter, frame lowering, assembly selection/rendering and the
assembler/linker/native environment remain separate obligations. The source model is now also exercised by `--first-path-eval` alongside the
[F02–F05 target models](FOUNDATIONS.md). `--first-path` emits explicitly
uncertified typed-baseline assembly; `--require-proof` refuses unavailable
evidence. The default CLI retains the compatibility pipeline.

## F01 assurance report (source scope)

- **Implemented:** restricted numbered source syntax, bit-vector operations,
  atomic edge transfers, initial/step relations, return/divergence predicates,
  bounded evaluator and profile admission. Subsequent target/job/artifact implementation is reported separately in [F02–F05](FOUNDATIONS.md).
- **Tested:** independent expected arithmetic results at both widths; agreement
  with the compatibility interpreter for returning fixtures; F00 loop/swap/frame
  source examples and a mixed word/long phi loop; branch value 2, same-successor edges, canonical numbering,
  zero/eight parameters, zero-fuel and spin exhaustion, frame-boundary rejection,
  malformed SSA, excluded operations and deliberate raw-state/phi corruption.
  These checks run in `lcb-tests` through `Verified/Tests.lean`.
- **Proved:** `Source.step_deterministic`; `Source.run_return_sound` shows a
  successful bounded run has a return witness in the unbounded small-step model.
  Both currently depend only on `propext` and `Quot.sound`, checked by
  `scripts/ProofAudit.lean` and enforced by `scripts/check.sh`. Neither proves
  admission soundness or compiler preservation. The preexisting primitive
  opcode-selection theorem is unchanged.
- **Remaining assumptions:** adequacy of this source contract and Lean's kernel/
  audited foundational axioms for those source facts. Executed tests additionally
  trust the compiler/runtime/toolchain. The later native theorem needs the
  target/environment boundaries above. The subsequent [F02–F05 report](FOUNDATIONS.md) tracks the implemented foundations; C01–C03 remain open.

## Qualification for this increment (2026-10-19)

`lake build lcb lcb-tests` and a subsequent build in `nix develop` passed;
linkers reported bundled Lean-runtime macOS deployment-version warnings.
`nix develop -c bash scripts/check.sh --require-native` passed the new source
checks, axiom audit and complete existing compatibility/native suite on Apple
ARM64. This includes 120,000 arithmetic vectors, 20,000 ABI/width checks, the
integer/control/memory/blit/call/stack-argument matrices, and four fuzz seeds
(32 generated functions, 256 inputs). The existing 616 original-QBE overlap
mismatches were retained and reported separately, not counted as agreement.
After adding the final mixed-width phi fixture, `lcb-tests` was rebuilt and
passed again. No target-emission code changed. This was a development-shell
regression run, not a fresh sandboxed `nix flake check` or a new certified target.

## Compatibility module data

Module data has packed little-endian integer fields, zero fill and explicit
power-of-two alignment in 1..64 (default 8, matching the pinned QBE parser).
Integer initializers truncate to their field width. Byte strings preserve UTF-8,
common control escapes, escaped quotes/backslashes and one-to-three-digit octal
byte escapes; they add no implicit terminator. Multiline strings and other escape
forms currently reject explicitly. Long pointer initializers
resolve symbols plus signed addends; all objects are allocated before resolving
references, so forward and self references work. Each evaluation starts with
fresh initialized globals, whose contents persist through calls within that run.
Function addresses are opaque, non-memory interpreter identities. Unresolved
external symbols have no interpreter result; native assembly delegates their
resolution to the linker. Numeric pointer values are not compared across models.
Data/function name collisions and direct calls to data definitions are rejected.
The module has a 1 MiB initialized-data resource limit. These features are outside
the restricted first-path proof domain and remain explicitly uncertified.

## Compatibility indirect calls

Indirect calls use a long address operand and the same bounded integer ABI as
direct calls. The native backend uses x16 as call scratch after preparing argument
registers and stack arguments. It preserves live SSA values and the return address
in the caller frame. The interpreter resolves module-defined function identities,
checks the dynamic argument/result signature, and rejects unknown or non-function
addresses. External C callbacks are tested natively and have no interpreter model.
Native code does not add dynamic target or signature guards: the caller must supply
a valid callable address with the declared ABI. Calls remain outside the restricted
first-path proof domain.

## IEEE constant bit patterns

The compatibility parser accepts decimal and hexadecimal `s_`/`d_` constants in
operand and data contexts. Constants are untyped bits: single precision occupies
the low 32 bits of the 64-bit blob, and the context truncates as needed. `s`/`d`
data field tags select four/eight bytes without introducing floating operations.
Conversion uses exact integer ratios and a single round-to-nearest, ties-to-even
step, including subnormals, signed zero, overflow to infinity and canonical quiet
NaNs. It is independent of host floating-point arithmetic or rounding mode.
Explicit resource limits are 4096 significand digits and exponent magnitude 10000.
NaN payload syntax is not supported. This does not add floating instructions,
conversions, argument registers or ABI support.

## Runtime stack allocation

Compatibility allocation accepts long size operands in any block. Constant sizes
retain the 1..4096 per-object admission bound; runtime sizes are positive and
limited by the interpreter's total 1 MiB live-memory budget. Zero-sized runtime
allocations have no interpreter result. Native code rounds allocation size to
16-byte stack alignment, keeps each allocation until function return, and restores
the entry stack/frame pointers. It does not insert size, overflow or stack-capacity
guards; callers must provide valid sizes and sufficient stack space. Escaped stack
objects remain invalid after return in the interpreter. The 1 MiB fixed-frame
resource limit does not bound the native function's cumulative dynamic allocation.
Calls in dynamic functions allocate their outgoing argument area below the live
objects, and fixed SSA/phi slots are addressed relative to x29. The restricted
first-path domain continues to exclude source allocations and calls.

## Apple ARM64 integer variadics

Function/call `...` markers separate named arguments from a typed w/l variadic
tail. Named arguments retain ordinary register/natural-stack packing; unnamed
arguments use eight-byte aligned stack slots. `vastart` writes the first unnamed
argument address into a caller-supplied eight-byte va_list object. `vaarg` loads
its declared width and advances the cursor by eight bytes. The interpreter keeps
only caller-supplied bytes initialized, rejects reads beyond the supplied tail,
and restores the parent invocation's variadic context across nested calls.
CLI evaluation accepts the named parameters only; use typed IL wrappers to supply
variadic arguments. Dynamic native targets and vaarg types must match the actual
call ABI; native code does not add type or bounds guards. Floating/aggregate
variadics and the restricted first-path profile remain unsupported.

## Environment arguments

A first `env` parameter/argument is a long value passed in x9, independently of
the ordinary x0..x7 argument sequence. It must precede named/variadic arguments.
Callees that declare an environment require it; QBE permits a caller to supply an
environment when the callee ignores it, so signature checking and interpretation
discard that extra value for such callees. The native caller loads x9 after stack
argument preparation, and an environment callee spills x9 before loading incoming
stack arguments. Environment parameters remain outside the first proof profile.

### Floating SSA execution profile

Compatibility SSA distinguishes integer and floating values even when they share
32-bit or 64-bit storage. Implicit integer/float mixing and float precision changes
are rejected; `cast` transfers bits between matching-size integer and float classes.
Single/double arithmetic uses IEEE binary32/binary64 primitives, with each operation
rounded separately. The tested profile is round-to-nearest, ties-to-even, gradual
underflow, and nontrapping exceptions. Native code inherits FPCR; it does not reset
rounding, flush-to-zero, or exception controls. No fast-math reassociation is applied.
Arithmetic NaNs are compared by classification, not payload; copy, cast, memory,
phi and negation preserve payload bits (negation flips only the sign). Comparisons
handle unordered operands explicitly: `ne` and `uo` are true for NaNs; ordered
relations and `o` are false. The interpreter uses Lean's native Float32/Float
primitives as an executable testing model, not a new formal correctness claim.
Floating function signatures use independently allocated GP and FP register banks
on Apple ARM64. Named spilled scalars use natural 4/8-byte stack packing; variadic
tails always occupy 8-byte slots. Frontends remain responsible for C default
argument promotions: C float varargs are passed as double, while typed QBE s tails
are also supported. Scalar return values use w0/x0 or s0/d0. The CLI interpreter
accepts/returns raw IEEE bits for floating values. Numeric conversions use the same default IEEE execution profile. Integer-to-float
interpretation rounds exact integer magnitudes once to the destination precision;
it does not convert through double first. Float-to-integer interpretation decodes
the bits, truncates toward zero, and rejects non-finite values or a truncated
integer outside the destination range. Native code emits `fcvtzs`/`fcvtzu` and
inherits target behavior outside that interpreted domain. Precision changes emit
AArch64 `fcvt`, matching pinned QBE and C under default round-to-nearest; the
name `truncd` does not change FPCR or request a separate rounding mode.

### Mutable temporaries and SSA construction

The compatibility CLI normalizes repeated temporary assignments before validation,
interpretation and emission. Uses refer to the current assignment within a block;
block-entry values are resolved through predecessors, introducing phis at joins
and closing loop backedges with cached placeholders. Explicit phi operands are
resolved at the end of their named predecessor. All incoming phi sources are
still read before destination updates. Assignments must keep a consistent width
and integer/floating class. Missing incoming definitions, duplicate parameters,
malformed CFGs and resource exhaustion are rejected. Existing SSA is unchanged.
The resulting SSA must pass the existing validator. This is an executable pass
with differential test coverage, not a proof of transformation correctness.
First-path evaluation, job creation and compilation validate the original input
and never silently normalize mutable input into the restricted profile.
