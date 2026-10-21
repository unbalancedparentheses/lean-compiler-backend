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
retain the 0..4096 per-object admission bound; runtime sizes are nonnegative and
limited by the interpreter's total 1 MiB live-memory budget. Zero-sized objects
are aligned and grant no accessible bytes. Native code rounds allocation size to
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
call ABI; native code does not add type or bounds guards. Floating and aggregate
variadic extensions are described below. Variadics remain outside the restricted
first-path profile.

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

### Subword scalar ABI

The `sb`, `ub`, `sh` and `uh` types are ABI annotations over base-type w values.
They are accepted for function parameters/results and call arguments/results,
not ordinary arithmetic or phis. Apple callers and returns extend the low 8/16
bits according to signedness; named stack arguments use 1/2-byte natural packing,
and variadic slots remain eight bytes (holding extended word values). The
interpreter chooses the same extended word representation for subword parameters
and results. Portable QBE code must still explicitly extend subword values before
using their unspecified upper bits. C default variadic promotions remain a
frontend responsibility. Known and indirect-call ABI signatures include subword
annotations. The first-path profile rejects subword signatures.

### Apple ARM64 TLS and word-result consumption

`thread data` defines Darwin thread-local initializers and TLV descriptors;
`thread $symbol` (including explicit `extern thread`) resolves the current thread's
address through the platform runtime. The baseline preserves live GP/FP scalar
arguments, scratch registers and LR across a resolver call, with a temporary
aligned stack area. Repeated resolution is not optimized. Known TLS objects
require the thread annotation; TLS addresses are not static pointer initializers.
The interpreter initializes one execution thread's TLS objects per module run.
It does not model pthreads, concurrent scheduling or externally defined TLS;
concurrent isolation is qualified only by native C/QBE tests.

Known internal word-returning functions may be consumed by a long-return call on
Apple ARM64: writing w0 clears the upper half of x0. Both direct and interpreted
indirect calls model that zero extension. Floating, subword and void result
annotations still require exact matching. This rule records the current target's
behavior and must be requalified when adding another target ABI.

## Aggregate storage layouts

Named record, union and opaque declarations are accepted in the compatibility
pipeline. `lcb --type-layout INPUT.ssa` reports byte sizes, alignments and the
offset, stride and repetition count of each field in each variant. Aggregate
parameters, call results and returns use the Apple ARM64 ABI described below.
The restricted first path rejects modules containing type declarations.

References resolve in declaration order; duplicate names, forward references and
recursive by-value types are rejected. Record members align naturally, including
zero repetitions; record size rounds up to the maximum member/explicit alignment.
Unions use the maximum variant extent, rounded to the maximum alignment. Explicit
alignment is a lower bound, following pinned QBE's parser. Opaque types require
explicit alignment and retain their exact size without rounding. Repeated nested
opaque members therefore use that exact size as their stride. Padding is layout
information and does not define or initialize memory bytes.

Resource limits are 1024 named types, 1024 variants per type, 4096 fields per
variant, 1048576 repetitions, 1 MiB computed size and power-of-two alignment up to
65536. These bounds and rejection of non-power-of-two alignments are explicit
admission restrictions; they do not assert full QBE type compatibility. Storage
layout acceptance does not imply a target can pass the type by value.
`scripts/aggregate_layout.py` compares 80 generated record/union/nested layouts
against independent C sizeof/alignof/offsetof probes and checks QBE-specific
opaque, zero-repetition and minimum-alignment cases. No layout theorem is claimed.

## Apple ARM64 aggregate ABI

An aggregate-typed parameter or call result is represented by an integer long
pointer in the function body. Its ABI type name remains explicit on function and
call signatures; known direct and interpreted indirect calls check those names.
Types must precede their uses. ABI admission currently limits aggregate size to
4096 bytes and alignment to at most 8, independently of the larger storage-layout
limits. The existing 64-argument, function and instruction limits still apply.

Homogeneous single/double aggregates use up to four FP registers; small other
aggregates use one or two GP registers. An aggregate that does not fit is passed
entirely on the stack and exhausts the relevant register bank. Large or opaque
aggregates use a pointer to a private caller-owned copy. Indirect results use x8;
environments continue to use x9. Unnamed Darwin variadic aggregates use the stack,
with an indirect pointer for large/opaque values. Native calls and definitions
use the same argument plan. Over-aligned float structs with tail padding are not
misclassified as extra floating members; see the retained QBE discrepancies.

The callee gets private by-value parameter storage. Every aggregate call site has
one caller-owned result buffer per activation, reused when that same call site
executes again (including in a loop), matching the stack baseline. Distinct call
sites and recursive activations have distinct buffers. The interpreter copies
result bytes before releasing callee objects and preserves unknown padding bytes
as unknown; reading them still fails. Native transfers copy only the declared
object extent and never round a final short fragment into an out-of-object read.
Neither emitted code nor these tests add runtime object bounds or initialization
guards. In particular, the upstream abi9 fixture reads a larger aggregate than
its source allocation; its original native output check is not evidence that the
whole input has defined memory behavior.

After compatibility SSA construction, an unused scalar result assigned from a
known void function is discarded. This supports upstream abi1/abi4 without
inventing an observable result. Used void-call results, indirect signature
mismatches and aggregate/scalar type mismatches remain errors. This normalization
is not enabled on the restricted first path.

`scripts/aggregate_abi.py` checks 22 layouts against native C and pinned QBE,
including both call directions, callbacks, register-bank exhaustion and dynamic
frames. Lean/C-only protected-page cases detect short-object overreads, with a
corrupted full-width-load control. `scripts/aggregate_edges.py` checks result
buffer reuse, distinct sites, padding, opaque values, x8+x9 and aggregate variadics.
Three retained upstream discrepancies are tested separately, not counted as QBE
matches. Aggregate lowering is tested and explicitly uncertified.

## Scalable compatibility CFG and frame limits

The compatibility parser admits up to 4096 blocks and 16384 instructions/phis per
function, with 8 MiB input and 500000 tokens. Block bodies, block lists and phi
incoming lists and top-level definitions parse iteratively. Modules admit 4096
functions and 16384 top-level parsing items; the 64-argument bound remains.
Function definitions and direct-call signatures use an indexed lookup. Native/
emulated tests execute a 4096-function forward-call chain and reject oversized
modules, late duplicate definitions and late call-signature mismatches.
The restricted first path independently retains 64 blocks, 480 definitions, eight
parameters and its 4080-byte frame bound.

Compatibility validation uses indexed CFG edges, hash-indexed definitions and a
work-list dominance fixed point over packed finite sets. The original list-based
validator remains the reducible small-profile path used by existing kernel-checked
examples. Both retain the previous conservative behavior for disconnected regions:
predecessor-free nodes dominate only themselves; closed unreachable SCCs can retain
vacuous dominators. Unreachable incoming edges are not silently removed. All 4096
four-node graphs compare the two algorithms, with node-deletion reachability as
an additional oracle on fully reachable graphs. This is regression testing, not
a soundness proof of the new analysis.

SSA construction indexes block predecessors, temporary types and reaching-value
caches. A repeated unresolved read in a single-predecessor cycle fails explicitly.
Native frame loads/stores use scaled immediate addresses when encodable, otherwise
compute the address in reserved scratch x15. This covers word/long and floating
slots, parameter saves, phi staging/commits and saved LR. Dynamic-frame base x29
and ordinary SP-based frames share the same addressing helper.

`scripts/large_cfg.py` exercises the exact compatibility caps, a 3000-block mutable
program, large static/dynamic W/X frames, incoming stack arguments and cyclic phi
transfers against native C and QBE. Corrupting a high frame-address component is
detected. The retained _bf99 and _bfmandel development fixtures now emit and
assemble; they remain assembly-only tests, matching upstream's test policy.

## Debug source locations

`dbgfile "path"` selects the source filename for subsequent functions. `dbgloc`
records a nonnegative line and optional column (both below 2^29), before an
instruction or terminator. A preceding filename is required. Filenames must be
UTF-8 without NUL. They are quoted as octal UTF-8 bytes during assembly emission,
so quotes and backslashes cannot introduce assembler directives.

Locations are ordered block metadata, preserved by the current SSA renaming and
unused-void-result normalization. They do not execute or consume interpreter
steps. Future passes that insert, remove or reorder instructions must remap these
indices. Debug locations before phi definitions are rejected, matching QBE's
requirement that phis precede ordinary instructions. Native Apple ARM64 output
contains `.file` and `.loc` directives; this provides line tables, not source-level
variable descriptions or full debugger support. `scripts/debug_locations.py`
checks emitted object-file line tables and execution against pinned QBE and C.

## Apple sections and common data

`section "__SEGMENT" "__section"` selects a Mach-O section for a function or data
object. A combined comma-separated string and supported type/attribute suffixes
are also accepted. Segment and section names are 1..16 ASCII name characters;
validation rejects assembler delimiters, control characters and unknown types or
attributes. Ordinary functions explicitly restore `.text` after custom code
sections. Thread-local data retains its dedicated ABI sections and rejects custom
sections or common linkage.

`common data` accepts only `z` initializers and emits a linker-coalesced `.comm`
symbol. On Darwin its alignment operand is log2(bytes), including align 64 -> 6.
The interpreter models the declared zero-filled object; merging definitions from
multiple translation units belongs to the native linker, tested independently.
Common linkage is incompatible with a custom section and is data-only. The native
matrix compares the shared two-string section syntax and common data with QBE,
then independently checks Lean's 64-byte common alignment against C.

## Linux ARM64 target

`--target aarch64-linux` selects ELF symbol spelling/relocations, function type
and size records, a non-executable stack note and AAPCS64 eight-byte scalar stack
slots. Independent GP/FP banks and aggregate classification are shared with the
Apple target, but Linux unnamed call arguments continue to use available argument
registers. Variadic entry saves the eight GP registers and eight 128-bit SIMD
registers in a 192-byte frame area. `vastart` initializes the AAPCS64 32-byte
va_list (stack pointer, GP/FP tops and signed offsets); `vaarg` consumes the
appropriate register bank before switching to eight-byte stack slots. Source
storage for native Linux va_list must cover 32 bytes, versus eight on Darwin.
The abstract interpreter models argument consumption rather than either concrete
ABI representation. First-path jobs remain Apple-only.

Linux TLS uses ELF TLSDESC relocations and `tpidr_el0`, preserving live argument
and scratch registers around the resolver. Native tests cover private/exported
TLS, external C TLS, eight concurrent threads, and executable/shared-library
linkage. Custom ELF sections accept dot-prefixed names and optional `a`, `w`,
`x` flags; `.init_array` pointer definitions run native constructors. Section
syntax is checked against the selected object format. First-path admission
rejects custom sections rather than discarding their placement requirements.

Private module symbols use direct PC-relative address formation. External or
exported symbols use GOT relocations. This distinction matters: GNU assembler can
fold a private-symbol GOT relocation into a section symbol plus addend, while the
linker does not preserve that addend as the desired symbol address. The original
abi5, abi8 and queen fixtures catch this issue. Common symbol alignment is in bytes
on ELF, versus log2(bytes) on Darwin. Interpreter evaluation is target-independent
and does not certify either native ABI lowering.

## Linux AMD64/System V target

`--target x86_64-linux` uses six GP and eight SSE argument registers with
independent banks, eight-byte stack slots, 16-byte call-site alignment and
frame-pointer-relative SSA storage. All results are stored in normalized
64-bit slots; scalar floating values retain their IEEE bits. Dynamic allocations
and outgoing call areas live below the fixed frame. Phi transfers stage all
incoming values before committing destination slots.

Variadic functions save GP/SSE argument banks and initialize the 24-byte System V
va_list. Calls set AL to the used SSE-register count. Environment calls pass their
special pointer in RAX; mixing an environment with variadics is rejected, as in
pinned QBE's System V ABI. Aggregate classification merges integer/SSE classes
per eightbyte, recursively accounting for nested field offsets and unions. Empty
padding chunks consume no register. Failed aggregate register allocation rolls
back both banks; memory-class arguments are copied onto the call stack and
large returns use a hidden RDI pointer. Callee parameters and caller result sites
have private canonical frame objects. Exact short-tail transfers avoid overreads.
The bounded aggregate ABI admits sizes through 4096 and alignment through 16.

AMD64 TLS uses TLSDESC and the FS thread pointer, preserving live caller registers
around resolution. Executable and shared-library tests cover eight concurrent C
threads. The shared ELF data renderer emits object type/size metadata.

SSE comparisons explicitly handle unordered operands. Integer/floating conversion
code uses the independently tested defined-range source domain, including unsigned
64-bit cases. Integer division uses hardware traps outside the source's defined
nonzero/nonoverflow domain. No register allocation or preservation proof for the
new emitter is claimed.


## Linux RV64 LP64D target

`--target riscv64-linux` uses eight GP and eight FP argument registers, with
named floating arguments falling back to GP/stack locations after FP exhaustion.
Word ABI values are sign-extended to XLEN at call boundaries and normalized to
32-bit SSA bit patterns internally. Scalar integer/floating instructions,
conversions, control flow, phi transfers, memory and dynamic allocation use
stable frame slots. Environment pointers use t5.

Small aggregates use one or two GP chunks, or eligible flattened floating/mixed
fields. Register allocation falls back to integer classification when either
required bank is exhausted; two-chunk integer values may split across the last
GP register and the stack. Large/opaque aggregates use private caller copies and
indirect results. Exact fragment transfers avoid short-object overreads. ABI
aggregate limits are 4096 bytes and alignment 16, independently of storage types.
Variadic aggregates with 16-byte alignment start at an even GP pair; variadic
scalars use GP registers then stack, with a saved bank contiguous with incoming
stack arguments. General-dynamic TLS preserves live argument and scratch
registers across `__tls_get_addr` and supports shared-library definitions.

This target is compatibility lowering, not certified lowering. Current execution
evidence is QEMU plus independent C and pinned-QBE comparisons; native RV64
qualification and broader syntax/ABI coverage remain open.

Zero-sized stack allocations return an address with the requested alignment,
both in the entry block and dynamically in loops. They grant no readable or
writable bytes; dereferencing one remains outside the interpreted domain. Pointer
identity between zero-sized objects is unspecified by the compatibility contract.
The abstract interpreter may assign distinct addresses while native targets may
reuse the current stack address. Tests assert alignment and preservation of live
nonempty objects, not equality or uniqueness of zero-sized allocation addresses.


## Optional compatibility optimization

`--optimize` enables at most eight monotone discovery sweeps over validated SSA.
Facts record normalized bit patterns from copies, casts, defined integer unary/
binary/division/comparison operations, and phis whose incoming constants all
agree. Unknown or unfinished chains remain unchanged. Undefined division by zero
and signed overflow are not folded; floating arithmetic/conversions are not
folded. Runtime allocation operands retain their original form so propagation
does not accidentally change the constant-size admission limit.

Same-width/class temporary copies are propagated before folding. A mark/sweep
cleanup removes unused pure integer definitions and phis, including dead cycles.
Calls, loads, divisions, allocations, conversions, floating operations, vaarg and
symbol/TLS materialization remain conservative roots. Debug instruction indices
are remapped to surviving positions, including the terminator.

Four bounded fold/CFG rounds replace constant branches using normalized 32-bit
conditions, remove blocks unreachable from entry and filter phi incoming edges
to the remaining predecessors. Later rounds can discover constants in pruned
phis. Dynamic edges and reachable loops remain; unreachable effects/traps can
be removed. The pipeline does not reorder memory, remove reachable potential
traps, allocate registers or claim formal preservation.

After CFG cleanup, common-expression elimination traverses reachable blocks in
reverse postorder and reuses only an identical definition that dominates the
current instruction. Structural keys include operand order, operation/input
comparison width and result width/class. Same-block definitions must precede the
use. Rewritten uses expose further identical expressions during the scan. Only
integer unary/binary/comparison operations and bit casts are eligible; memory,
calls, TLS/symbol materialization, floating arithmetic, conversions and divisions
remain excluded. This is conservative expression elimination, not full QBE GVN
or memory/alias optimization. The rewritten
module is validated before target lowering. Default compilation and all
first-path/certified job operations remain outside this optional pipeline.


## Quoted global names

Quoted `$"name"` globals retain their assembler spelling, including escapes;
these are not decoded like data strings. On Darwin, ordinary `$name` symbols
receive the platform underscore, while quoted names are exact and receive no
prefix. Consequently `$name` and `$"name"` may name different symbols. Functions,
call targets, address constants, data relocations and TLS share these rules.
Compiler-generated block/edge labels encode quoted names into safe identifiers,
and Darwin TLS initialization suffixes are placed inside the quotes.

The current quoted-name domain is nonempty, single-line names without control
characters, bounded to 4096 characters. Temporaries, block labels and aggregate
type names retain unquoted identifier syntax. The restricted first-path importer
rejects quoted function names; these changes add no certification claims.


## macOS AMD64 target

`--target x86_64-macos` shares QBE's AMD64 System V scalar, aggregate and
variadic classification. Mach-O emission uses Darwin global-name rules, local
labels, custom sections, common alignment and TLS descriptors. TLS addresses
load the TLV descriptor through `@TLVP`, invoke its resolver with the descriptor
in RDI and preserve live integer/floating call arguments. The compiler emits
assembly for an external assembler/linker; this target has no new proof claims.

`scripts/macos_x86.py` distinguishes native Intel execution from Rosetta on ARM
hosts and emission-only checks elsewhere. It compares original upstream fixtures
and C scalar/aggregate/variadic harnesses with pinned QBE, and checks TLS, quoted
symbols, Mach-O objects, independent optimization cases and large modules.
