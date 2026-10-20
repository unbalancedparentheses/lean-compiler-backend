# First verified compilation path (F00)

Status: specification v1, 2026-10-19. This is the F00 design in
[the roadmap](../../ROADMAP.md). F01 subsequently implemented the restricted
source model and admission in the [semantic ledger](../SEMANTICS.md).
[F02–F05](../FOUNDATIONS.md) now implement independent jobs, typed lowering,
models and versioned replay; that report records the implemented schema refinements
and helper/binding proofs. CheckedSSA soundness and composed preservation remain
open. All generated artifacts are uncertified and required certification is
explicitly refused. The validation record at the end is historical F00 evidence.

## 1. Scope and semantic decisions

The first theorem starts at a checked, locally numbered SSA function and ends
at typed AArch64 assembly. It covers one sequential, leaf integer function,
including loops and simultaneous phi assignments. Its target profile is
`aarch64-apple-darwin-leaf-int-v1`, little endian, with 16-byte stack alignment.
This is a deliberately narrower domain than the existing compatibility backend.

| Decision | Admitted v1 domain |
| --- | --- |
| Values | `BitVec 32` and `BitVec 64`; no pointers, poison or undefined values. |
| Signature | Zero through eight `w`/`l` parameters; exactly one `w`/`l` result. |
| Operations | `copy`, wrapping `add`, `sub`, `mul`, `and`, `or`, `xor`; comparisons `eq` and unsigned `lt` at either width, producing `w` 0 or 1. |
| Operand widths | Temporary widths match the operation exactly. Constants are reduced modulo 2^width at import. No implicit narrowing/widening. |
| Control | Explicit jump, word-valued nonzero conditional branch, return; simultaneous phi nodes, including cyclic backedge transfers. |
| CFG | 1..64 blocks, all reachable from entry; entry has no predecessors or phis. Every block has one terminator. Identical conditional successors are allowed and represent one predecessor relationship. |
| Definitions | Unique SSA definitions; parameters dominate all uses; other ordinary uses are dominated by their definition and ordered within a block. Phi operands are available at the end of their named predecessor. |
| Limits | At most 480 instruction/phi definitions, plus at most eight parameters; frame at most 4080 bytes. Resource-limit rejection is not source behavior. |
| Observations | Return with result bits, or divergence. Internal steps are silent. No modeled traps occur on admitted inputs. |
| Exclusions | Division, shifts, unary operations, other comparisons, conversions, void results, `hlt`, source loads/stores/allocations/blits, symbols as values, calls, stack arguments, floating point, data, TLS, exceptions, concurrency, inline assembly and optimization facts. |

Arithmetic wraps modulo 2^32 or 2^64; unsigned comparison uses the natural
representative. Branches test all 32 bits, not just bit zero. Overflow is total
and does not trap. An infinite execution is divergence, not undefined behavior.
The existing interpreter's fuel exhaustion is inconclusive; it is never a
semantic result or a certificate. Import rejection, compilation resource
exhaustion, execution budget exhaustion and semantic divergence are distinct.

The checked input boundary deliberately excludes proof of the textual parser.
A future importer must preserve the meaning of the accepted QBE forms, resolve
fallthrough to explicit jumps, and refuse all excluded forms. Canonical constants
and local numbering do not authorize arithmetic transformations. A refinement
lemma relating the existing interpreter to the new source relation is required
before reusing interpreter results as executable specification tests.

### Source states and steps

Use a small-step relation with state
`(block : BlockId, phase : body InstructionIndex | terminator, env : ValueId ⇀ Bits)`.
The initial state is entry/body/0 with only parameters initialized. Definitions
write their value in the environment each time the instruction executes; SSA
uniqueness is static and does not prohibit repeated dynamic loop iterations.
Each instruction advances one body position. A branch/jump chooses a successor,
evaluates *all* incoming phi operands in the old environment, then installs all
phi destinations and enters successor/body/0 in one step. Return produces
`Returned(width, bits)`. Entry needs no phi step. No step reads a missing value
on a reachable well-formed execution; that is a proof obligation, not a default
zero convention.

The environment may retain obsolete values from previous loop iterations.
The simulation relates only values currently available by dominance and position,
plus the predecessor's values needed for the selected edge. In particular,
future definitions in a revisited block need not agree with stale slot contents.

### Target entry and observation contract

The target state is `(pc, X[0..30], SP, NZCV, bytes, initialized)` with a separate
terminal `Returned` state. `Wn` aliases the low 32 bits of `Xn`; writing `Wn`
zeroes the upper half of `Xn`. Code addresses and labels belong to the immutable
code map, not writable data. An invalid instruction or uninitialized/out-of-frame
load is stuck in the model and must be proved unreachable.

At entry, `SP = S`, S is 16-byte aligned, `X30 = returnPC`, and parameter i
occupies the low width bits of Xi. High bits of word arguments are unconstrained.
The environment supplies exclusive readable/writable stack bytes `[S-F,S)`,
with `S >= F`, no address wrap, and no intersection with code. Their initial
contents are arbitrary and may be uninitialized. The caller cannot observe
these scratch bytes as preserved values after return. Memory outside this
interval must remain unchanged. Stack availability is an environment assumption;
the compiler does not probe or grow the stack.

On return, result bits are in W0/X0, SP is S, X30 is returnPC, and X19..X29 are
unchanged. The only permitted writes to architectural registers are X0, X9, X10, SP
and NZCV; all other integer registers, including X18, are unchanged. No floating-point/vector registers are used
or modified. Caller-saved scratch contents and flags are unobserved. Typed `ret`
checks the designated return address and produces the result observation; the
native return-to-caller interpretation is part of the ISA/ABI boundary.

Compiler-owned frame accesses implement SSA storage and are included in the
proof. They are not source-program memory operations: the source has no addresses
and cannot access or expose this frame. Adding source memory later requires a
new state relation, lifetime/alias rules and interference proof; the current
memory interpreter does not discharge those obligations.

## 2. Frozen jobs, artifacts and verification results

All schemas reject unknown versions, duplicate fields, unknown enum tags and
out-of-range numeric fields. The following records define required information;
`Bytes` means an immutable finite byte sequence, not a filesystem path.

```text
FunctionJobV1 {
  schema = 1
  sourceSemantics = "ssa-int-v1"
  targetSemantics = "a64-leaf-v1"
  target = "aarch64-apple-darwin-leaf-int-v1"
  pipeline = "stack-baseline-v1"
  compilerBuild : Digest
  symbol : { namespace : Bytes, name : AsciiIdentifier, exported : Bool }
  body : CanonicalSSA                  // local IDs, signature, ordered blocks
  abi : AbiPlanV1
  imports = []                        // mandatory empty in v1
  consumedFacts = []                  // mandatory empty in v1
  debug : { policy : none | origins, sources : Array SourceRecord,
            origins : Array (OriginId, SourceId, line, column) }
  evidenceRequest : none | kernelTypedAssembly
  proofProfile : { libraryDigest, leanVersion, allowedAxioms }
}
AbiPlanV1 {
  schema = 1
  profile = "apple-arm64-leaf-integer-v1"
  parameters : Array (Width, registerIndex) // exactly [(width_i, i)]
  result : (Width, registerIndex = 0)
  wordInputHighBits = unconstrained
  wordResultHighBits = zero
  stackAlignment = 16
  incomingStackBytes = 0; outgoingStackBytes = 0
  hiddenParameters = []; calls = []; savedRegisters = []
  mayWrite = [X0, X9, X10, SP, NZCV]
  mustPreserve = [X18, X19, ..., X30]   // unused registers also unchanged
}
FunctionArtifactV1 {
  schema = 1
  codeInput : Bytes                    // exact canonical code dependency record
  codeInputId : Digest
  checkedSSA : CanonicalSSA
  stackMIR : CanonicalStackMIR
  assembly : CanonicalTypedAssembly
  layout : { valueSlots, stageSlots, frameBytes }
  fragment : Bytes                    // deterministic assembly text, not object bytes
  localLabels : Array LabelId
  externalSymbols = []; relocations = [] // no object-format relocation claims
  codeId : Digest                     // binds all code products above
  debug : { dependencyId, codeId, originMap, payload }
  verification : VerificationResultV1
}
VerificationResultV1 =
  Uncertified { requested = none, established = [structuralChecks] }
| Certified { requested = kernelTypedAssembly, codeInputId, codeId,
              exactStatement, theoremTerm, libraryDigest, leanVersion,
              auditedAxioms, established = [ssaToTypedAssembly],
              excluded = [parser, renderer, encoding, linking, executionPlatform] }
CompileResultV1 =
  Success FunctionArtifactV1
| InvalidInput { stage, localOrigin?, reason }
| Unsupported { feature, localOrigin?, profile }
| ResourceLimit { resource, measured, limit }
| CertificationUnavailable { requested, missingObligation }
| VerificationFailed { stage, localOrigin?, reason }
```

`Digest` is SHA-256 with a domain tag and schema version. Hashes are lookup
identities, not proofs of equal inputs. Kernel evidence must bind the decoded
SSA, ABI, MIR and typed assembly values themselves; do not prove a statement
only about two equal digest strings. Cache acceptance compares canonical bytes
with the requested inputs and reconstructs/checks the theorem's exact statement.
If an implementation uses digest-only equality, collision resistance becomes a
new explicit assumption and it is outside this v1 contract.

`SourceRecord = (SourceId, logicalPath, contentDigest)`; paths are supplied logical
UTF-8 paths with `/` separators and no `.`/`..` components. Absolute host paths
and timestamps are forbidden. Origin IDs are structural `(block, phi/body/term,
index)` identifiers; a phi edge additionally includes its predecessor ID.
Sources are sorted by SourceId and origins by structural ID. This metadata does
not affect v1 code selection or labels. Debug payloads bind to codeId and cannot
be attached to a different code product merely because local IDs happen to match.

### Canonicalization and dependencies

The v1 wire format is a tagged binary tree: fixed record field order as listed
above, constructor tags assigned in the order specified in the schema, natural
numbers and collection byte/element counts as little-endian unsigned 64-bit
integers, booleans as one byte 0/1, and byte strings prefixed by byte count.
Width tags are 0 for word and 1 for long. Bit-vector literals use exactly four
or eight little-endian bytes; no signed literals survive import. Optional values
use one byte 0/1 followed by the payload when present. Unknown tags, trailing
bytes, noncanonical lengths and overflowing sizes are rejected before allocation.
Derived enum tables must be published with the codec implementation; their
ordering in this document is normative. Generic record field names are not
serialized. No platform-dependent `Repr` or JSON object ordering is permitted.

Preserve block array order, with entry numbered 0; then number parameters first,
followed by each block's phis and instructions in order, matching `Function.locals`.
Sort each phi's incoming entries by predecessor ID after resolving names.
Repeated branch successors form a set for predecessor checking. Labels are
structural `(body, BlockId)` and `(edge, predecessor, successor)` variants.
Local names are debug data. Renaming SSA temporaries has no code effect; reordering
blocks *may* change code, and is not promised invariant. Module ordering is not
an input. Module-global counters must never enter local labels.

The rendering symbol uses the supplied ASCII name (the v1 name grammar is the
existing letter/underscore followed by letters/digits/underscores). Namespace
is a stable user/planner identity, not an emitted prefix; the module driver must
reject two jobs that resolve to the same emitted symbol. Render local labels with
the symbol's length and spelling plus structural IDs to avoid collisions.

Code dependencies are schema/semantic versions, target, pipeline, compiler build,
symbol, canonical body, ABI, imports and consumed facts. Debug dependencies are
codeId plus debug policy and source/origin records. Evidence dependencies are
exact code products, proof profile and requested coverage. The complete job
identity binds all three dependency records; codeInputId excludes debug and
evidence choices. Changing proof libraries alone may change evidence, not code.
Changing the compiler build conservatively invalidates code dependencies.

`compileFunction` receives this value only; it does not read module tables, files,
environment variables, current directories, time or caches. The driver resolves
the symbol and freezes the job. Planning correctness remains outside the first
SSA-to-assembly theorem: users must be able to inspect/replay the exact checked
input. A later theorem must connect module declarations to jobs.

Structural validation alone produces `Uncertified`, never `Certified`. If
`kernelTypedAssembly` is requested, unavailable proofs, an axiom-policy failure
or failed kernel replay return an error, with no successful uncertified fallback.
Native execution of a proved checker is not kernel replay and cannot satisfy
this request. V1 has no binary-level or end-to-end certification request; such a
request must be rejected explicitly. It must not be silently downgraded.

## 3. Representations and lowering

### Checked SSA

The raw canonical SSA consists of the operations in section 1, typed operands,
ordered blocks and explicit terminators. `CheckedSSA` packages it with evidence
for typing, definition uniqueness, bounds, reachability, dominance and exact phi
predecessor coverage. A Boolean checker needs `checkSSA = true → WellFormed` in
Lean before it can construct this package in a certified path. The existing
`validateFunction` is useful implementation input, not an existing proof of this
implication. Reject unreachable blocks rather than proving properties of reads
in unreachable code for v1.

### Stack baseline MIR

No virtual registers or allocator are introduced. The finite instruction set is:

```text
EnterFrame F; LeaveFrame F
ReadArg width index slot
LoadConst width scratch bits
LoadSlot width scratch slot
StoreSlot width slot scratch
Alu width (add|sub|mul|and|or|xor) dst lhs rhs
Compare width (eq|ult) wordDst lhs rhs
Jump label; BranchNonzero wordScratch yes no
Return width resultScratch
```

Scratch IDs are physical roles R0, R9, R10, with typed width views; aliases are
explicit. Entry parameter stores use `ReadArg` without clobbering other arguments.
ALU operations load operands into R9/R10 and write R9. `Compare` reads the selected
width and writes the Boolean word into R9. Return loads R0. Each assignment stores
its result before the next source instruction. Branches load the condition in
word R9 *before* selecting an edge block. Each edge block first stages every phi
source in index order, then commits every destination in that same order, then
jumps to the successor body. Even an empty transfer is followed by a jump.

MIR state has a PC, aliased scratch/argument registers, SP, initialized byte
memory and an entry-SP/return-address ghost snapshot. Its load/store semantics
are byte-level little-endian operations, not an abstract map that would conceal
offset or width errors. `EnterFrame`/`LeaveFrame` adjust SP; only the entry and
return paths may execute them. Prove frame access legality, initialization and
no escape to arbitrary memory. Ghost snapshots are proof state, not instructions.

For N definitions including parameters and P the maximum phi count of any block:

```text
valueSlot(i) = 8*i                      (0 <= i < N)
stageSlot(j) = 8*N + 8*j                (0 <= j < P)
F = alignUp(8*(N+P), 16); require F <= 4080
```

Slots have a width and ownership (`value i` or `stage j`). Access only four bytes
for a word and eight for a long. Unwritten upper bytes of word slots are never
read. A word operand cannot be loaded as a long. Stage slots may be reused with
different widths on different edges, but every read must be dominated on that
edge by its same-width stage write. Stage and value intervals are disjoint;
padding is inaccessible. With F=0, omit both SP adjustments. There is no saved-LR
slot because no calls occur and X30 is never written.

### Typed assembly

Represent labels and registers as constructors, not strings. The admitted
instructions are `sub/add SP,SP,#F`, `str/ldr Wn|Xn,[SP,#offset]`, `movz`, `movk`,
width-specific `add/sub/mul/and/orr/eor`, `cmp`, `cset W9,eq|lo`, `cbnz W9,label`,
`b label`, and `ret X30`. For a MIR branch, emit `cbnz ... yes; b no`; both targets
are edge blocks. `LeaveFrame F` expands to the SP restoration (omitted for F=0);
`Return` expands only to `ret`, after R0 has been loaded and the frame left.

Immediate constants start with `movz` for the low 16-bit chunk, including zero,
then `movk` for nonzero higher chunks in ascending shift order. Legal shifts are
0,16 for words and 0,16,32,48 for longs. `movk` preserves the other bits within
its width; all W writes clear X's high bits. Stack adjustments use the unshifted
12-bit immediate (0..4095). Frame offsets use unsigned scaled 12-bit addressing:
offset is divisible by access width, offset/width < 4096, and offset+width <= F.
V1's stricter frame bound makes these forms sufficient.

`cmp` sets NZCV from subtraction without storing a result; `cset eq` tests Z and
`cset lo` tests not-C (unsigned borrow). These flag semantics must be defined
independently of the source comparison helper. Prove the flag-to-Boolean lemmas.
Prove `movz/movk` reconstruction and byte load/store laws. The existing
`select_preserves` theorem can assist six ALU cases, but must be bridged to the
bit-vector/alias model and does not justify selection or the full pipeline alone.

Assembly legality checking includes branch target existence, access bounds,
register/width forms, immediate encoding, allowed clobbers and proper frame
lifecycle on every path. Structural legality cannot establish value flow:
changing an in-bounds slot offset may remain legal yet be semantically wrong.
Typed assembly execution uses the target state from section 1. Renderer output
is a deterministic text product with a separate identity, outside the theorem.

## 4. Preservation statement and proof obligations

For every successfully certified artifact A for job J, every argument vector
matching J's signature and every target entry state satisfying the ABI/frame
preconditions, the proposed theorem is:

```text
BehaviorsSSA(J.checkedBody, args)
  = projectABI(BehaviorsTypedA64(A.assembly, entryState))
```

The behavior set contains `Return(width,bits)` and `Diverges`; target stuckness
is excluded by a separate safety conclusion. On return the memory/frame and
register preservation postconditions hold. During infinite execution every
memory write remains inside the owned frame. This is not merely “if both runs
return, the results agree.” It includes termination correspondence and divergence.
Determinism of each admitted semantics and progress, plus finite positive target
segments per source step and bounded administrative stuttering, establish the
two directions. A source step may take many target steps; no lockstep claim is
made. A fuel-indexed evaluator is a test helper, not the theorem statement.

| Boundary | Relation/invariant and required proof | Evidence and failure |
| --- | --- | --- |
| Import → canonical raw SSA | Name resolution, constant reduction, explicit edges preserve admitted text meaning. Outside first theorem. | Uncertified importer; reject unknown constructs. |
| Raw SSA → CheckedSSA | Soundness of type, availability/dominance, reachability and phi checks; progress of reachable source execution. | Kernel proof from sound checker or direct proof; reject failed checks. |
| Job signature → AbiPlan | Parameter i is in register i with correct low bits; result is R0; no hidden dependencies. | Proved plan constructor and equality check against supplied plan; reject mismatch. |
| CheckedSSA → StackMIR | Available source values equal initialized bytes in their assigned slots; PC maps to source boundary; fixed SP and frame ownership. Prove operands, assignment, branch, staged simultaneous transfer, entry and return. | Direct theorem for actual `lowerStack` function, with layout lemmas; fail rather than return a certificate for an unrelated hand-written lowering. |
| StackMIR → typed assembly | PC expansion map, register aliases, byte memory and frame snapshots agree; flags/scratch may differ only between matching boundaries. Prove each expansion terminates and has its specified effect. | Direct theorem for actual `selectA64`; legality checker soundness is separate. |
| Composition | Compose relations at instruction/edge boundaries; prove prologue/epilogue, progress, non-stuckness, no infinite administrative-only runs and matching return/divergence. | Kernel-checked `compile_preserves` instantiated with exact job/output values. |
| Typed assembly → text → binary | Faithful rendering, assembler instruction encoding, symbol/branch relocation, linking, native ISA and ABI interpretation. | Explicitly outside C01/C02; native/decoding tests only until V04 closes each gap. |

For a phi transfer, use a three-phase relation: before staging, source env equals
value slots; after k staging writes, the first k stage slots equal incoming
operands evaluated in the *old* env and all value slots are unchanged; after k
commits, the first k destinations equal the staged values while uncommitted
values retain their old contents. On completion this matches the atomic source
edge. Stage reads cannot depend on partially updated destination slots.

A well-founded rank for administrative stuttering is the number of remaining
instructions in the current fixed expansion/prologue/epilogue. Each ordinary
source step and each edge has a finite, nonempty expansion. Edge-only cycles
therefore represent actual source control steps, never silent administrative
loops. The rank resets only when a source step is matched. Show return cannot
occur in an intermediate expansion and branches cannot enter its interior.

C02 must audit the transitive axioms of the composed theorem, initially permitting
only Lean's standard `propext`, `Quot.sound` and `Classical.choice` if actually
used and reported. No `sorryAx`, opaque external assertion, unchecked native
checker result or `native_decide` trust shortcut may satisfy kernel replay.
The existing primitive theorem has its own narrower measured axiom list; this
proposal does not change that result. Evidence includes the actual audit, not
just the configured allowlist.

Trusted boundaries remaining at this endpoint: Lean kernel and foundational
axioms; adequacy of the specified source and typed target semantics; selection
of the intended checked function/job; and, for delivered native code, renderer,
assembler, linker, OS/ABI, hardware and stack preconditions. Native compilation
of the compiler is not an alternative proof checker: the consumer must kernel
check the exact produced artifact. Hashing and transport must not substitute a
different artifact after checking. Timing, debug accuracy, unwinding, stack
confidentiality, speculative behavior and concurrency are not theorem claims.

## 5. Worked examples and rejection controls

These are specification traces. Their QBE source can be exercised by the current
backend, but the proposed MIR, typed assembly and proofs do not yet exist. All
slot offsets below are relative to SP after `EnterFrame`.

### A. A counting loop with two simultaneous phis

```text
export function w $sum(w %n) {
@entry
    jmp @loop
@loop
    %i =w phi @entry 0, @body %next
    %s =w phi @entry 0, @body %sum
    %more =w cultw %i, %n
    jnz %more, @body, @exit
@body
    %sum =w add %s, %i
    %next =w add %i, 1
    jmp @loop
@exit
    ret %s
}
```

Checked IDs: blocks entry=0, loop=1, body=2, exit=3; values
n=0, i=1, s=2, more=3, sum=4, next=5. Slots are respectively
0,8,16,24,32,40; stage slots are 48 and 56; F=64. The loop edge phis in
canonical predecessor order are `i=[0:0,2:next]`, `s=[0:0,2:sum]`.

MIR entry is `EnterFrame 64; ReadArg w 0 slot0`, then the entry edge writes
constants 0 to stage48/56, commits to slot8/16 and jumps to loop. Loop loads
slot8/slot0 to R9/R10, compares unsigned, writes slot24, reloads it and branches
to body or exit edges. Body loads slot16/8, adds and writes slot32; loads slot8
and constant1, adds and writes slot40. The backedge stages slot40→48 and
slot32→56, commits 48→8 and 56→16, then returns to loop. Exit loads slot16 into
R0, leaves 64 bytes and returns.

Typed expansion of the comparison is `ldr w9,[sp,#8]; ldr w10,[sp,#0];
cmp w9,w10; cset w9,lo; str w9,[sp,#24]`. The branch reloads w9 and uses
`cbnz w9,bodyEdge; b exitEdge`. Each MIR word copy slotA→slotB expands to
`ldr w9,[sp,#A]; str w9,[sp,#B]`. The prologue is `sub sp,sp,#64;
str w0,[sp,#0]`; the exit is `ldr w0,[sp,#16]; add sp,sp,#64; ret`.
Labels in this shorthand refer to the structural body/edge IDs defined above.

For n=4, source loop-entry `(i,s)` states are `(0,0),(1,0),(2,1),(3,3),(4,6)`;
the same pairs appear in slots8/16 at each MIR and assembly loop boundary.
The result is 6 and SP returns to S. For n=0, it returns 0 immediately; n=1
also returns 0. In general it returns the sum of 0..n-1 modulo 2^32, including
wrapping sums. For maximal n it terminates mathematically even though practical
interpreter budgets are exhausted. No runtime bound is part of the theorem.

Negative controls: use signed `lt` instead of unsigned (n=0x80000000 gives a
wrong immediate exit); stage old i instead of next (n=1 fails to progress);
swap the true/false edges (n=4 returns 0); interpret a condition as bit zero
(use a separate `jnz 2` control). All can be structurally legal and require
semantic evidence or independent tests to detect.

### B. Cyclic parallel transfer

```text
export function w $swap(w %count) {
@entry
    jmp @loop
@loop
    %a =w phi @entry 11, @body %b
    %b =w phi @entry 22, @body %a
    %i =w phi @entry 0, @body %next
    %more =w cultw %i, %count
    jnz %more, @body, @exit
@body
    %next =w add %i, 1
    jmp @loop
@exit
    ret %a
}
```

Checked values count=0,a=1,b=2,i=3,more=4,next=5 have offsets
0,8,16,24,32,40. Stages are 48,56,64; F=80 (eight bytes of padding).
The body→loop source edge atomically sets `(a,b,i):=(old b,old a,next)`.
The MIR edge is the following ordered sequence of word slot copies, then a jump:

```text
16 → 48; 8 → 56; 40 → 64       // all reads see the old values
48 → 8; 56 → 16; 64 → 24      // commits
Jump loop
```

Typed assembly expands each arrow to `ldr w9,[sp,#source];
str w9,[sp,#destination]`; there are twelve transfer instructions and a branch.
Entry stages 11,22,0 before committing; the prologue stores count after subtracting
80. The comparison/body lowering follows example A. Exit loads offset8 into
w0, adds 80 to SP and returns. For count=1, the source, MIR and assembly boundary
pairs change `(11,22,0) → (22,11,1)`, so return is 22. For count=2 they next
become `(11,22,2)` and return is 11. Count=0 returns 11 without a swap.

Negative controls: naive `16→8; 8→16` produces `(22,22)` and count=2 returns
22; staging after the first destination write has the same defect. Aliasing
stage48 with value8 must fail the layout checker. Selecting the entry phi values
on the backedge resets i and fails to terminate for count=1. A duplicated/missing
incoming predecessor must fail SSA checking before lowering.

### C. Frame setup, mixed widths, constant materialization and teardown

```text
export function l $frame(w %unused, l %x) {
@entry
    %wide =l copy 4294967297
    %r =l add %x, %wide
    ret %r
}
```

Checked values unused=0,x=1,wide=2,r=3 occupy 0,8,16,24; no stages; F=32.
The word parameter is deliberately unused to expose the mixed-width layout.
MIR: enter32; store word arg0→slot0; store long arg1→slot8;
constant long R9=0x0000000100000001; store R9→slot16;
load slot8→R9 and slot16→R10; long add R9; store R9→slot24;
load slot24→R0; leave32; return long R0.

The corresponding typed instruction stream (labels omitted) is:

```asm
sub sp, sp, #32
str w0, [sp, #0]
str x1, [sp, #8]
movz x9, #1
movk x9, #1, lsl #32
str x9, [sp, #16]
ldr x9, [sp, #8]
ldr x10, [sp, #16]
add x9, x9, x10
str x9, [sp, #24]
ldr x0, [sp, #24]
add sp, sp, #32
ret
```

With x=0xffffffffffffffff the result is 0x0000000100000000 in all three
semantics. Bytes0..3 contain the word argument; bytes4..7 need not be initialized
and are never read. Bytes8..15 contain x; bytes16..23 and 24..31 become initialized
before their loads. SP=S-32 throughout the body and S at return; X30 and memory
outside `[S-32,S)` stay unchanged.

Negative controls: load x from offset0 (reads uninitialized upper word-slot bytes);
store the word parameter with `str x0` (wrong access width, reject even if unused);
load r from offset16 (legal address but wrong result); use `movk ... lsl #16`
(wrong constant); restore SP by16 (wrong return stack). Misaligned SP, unavailable
stack space or S<32 fail the entry preconditions and are not counterexamples to
the conditional theorem. The layout checker must reject offset32 for a long
access, overlaps, and F>4080.

### D. Divergence and empty frame

`@entry jmp @spin; @spin jmp @spin` in an integer-result function with no
parameters/definitions is admitted; no path returns. Checked SSA has N=P=0,
F=0. MIR and assembly have no SP adjustments and repeatedly execute the spin
edge/body jumps. All three semantics diverge with unchanged memory/SP. An
implementation must not replace fuel exhaustion by a return or trap. For a
separate zero-frame returning control, `ret 7` loads constant7 into R0 and
returns with SP unchanged. Neither example needs a fabricated result slot.

## 6. Implementation and qualification handoff

The original F00 handoff follows. F01 source semantics/admission and source tests
are now implemented as recorded in the ledger; source checker soundness and the
interpreter refinement lemma remain open. F02–F05 implementation and remaining proof work are recorded in the foundations
report. This list is retained as the original design handoff:

1. F01: add `Verified/Source.lean` (bit-vector semantics, availability, behaviors)
   and a profile-admission checker; relate admitted arithmetic to `Semantics.lean`.
2. F02/F03: add `Verified/Job.lean`, `Abi.lean`, `Codec.lean` and artifact/result
   definitions. Implement pure entry points plus exact input/evidence binding.
   Keep the existing compatibility path available and explicitly uncertified.
3. F04: add `Verified/StackMIR.lean`, `TypedA64.lean`, `Layout.lean` and lowering
   functions. Define semantics before proving their executable transformations.
4. F05/C01: add checker soundness, load/store, constant, compare, parallel-transfer,
   frame, step-simulation and composition proofs. Reuse primitive lemmas only
   after relating their models. C02 connects the executable path and evidence
   replay; C03 publishes the exact boundary and native qualification results.
5. Tests: turn A–D into source/MIR/assembly fixtures with traces at boundaries;
   cover w/l overflow, both comparisons, every ALU operation, signed-literal
   normalization, word high bits, zero/eight parameters, same-target branches,
   mixed-width phi staging, maximal frames and all rejection controls above.
   Add randomized independent arithmetic/CFG comparisons inside this profile.
6. Binding/replay tests: reorder unrelated functions, rename temporaries, shift
   source lines, vary paths and worker schedules; code is stable when its declared
   dependencies are equal. Mutate body, ABI, target, widths, frame offsets, stage
   ordering, code bytes, theorem statement and proof-library identity. Reject
   substituted/truncated/stale artifacts. Altering debug input changes only debug
   identities; altering proof inputs changes only evidence when code inputs match.
7. Native boundary tests: assemble/run with the pinned toolchain on Apple ARM64,
   use C/assembly ABI probes and independently calculated expected values; retain
   original QBE comparisons separately. Inspect instruction decoding and branch
   targets. Record non-native hosts as not measured. These tests do not upgrade
   the typed-assembly theorem to binary certification.

F00 acceptance: the subset, failure modes, schemas, local numbering, layout,
representations, state relations, theorem endpoint, proof obligations and traces
are specified here. Broader memory/call/ABI/ISA issues are explicitly excluded,
not left as implicit implementation decisions. Codec implementations still need
their concrete Lean types and tag tables, and every proposed lemma remains work.

Historical F00 reporting (before the F01 follow-up): **implemented** — specification only; **tested** —
source examples checked against the current interpreter/emitter as recorded
below, not execution of the proposed pipeline; **proved** — no new theorems;
**remaining assumptions** — the entry/environment and trusted boundaries in
sections 1 and 4. F01–F05, C01–C03 and compatibility coverage remain open.

### F00 validation record (2026-10-19)

`lake build lcb` succeeded with Lean 4.34.1. The local linker reported bundled
runtime minimum-macOS-version warnings; this was not a pinned Nix qualification
run. An initially stale preexisting binary rejected a fixture; all measurements
below use the rebuilt binary, SHA-256
`077ae21f9289cac5cd1123e1bbf0656c6d9a48573a32d2ece59f872acc69e9ba`.

The three fenced QBE examples were extracted into temporary files and passed
`--check` and assembly emission. Emitted frame adjustments matched 64, 80 and
32 bytes respectively. `--eval` returned the expected results for sum inputs
0,1,4,100; swap inputs 0,1,2,3; and frame input x=2^64-1 (unused=123).
The zero-frame return control returned 7. The spin control emitted without SP
adjustments and reported interpreter budget exhaustion, not a divergence proof.
Ten returning evaluations passed in total. Temporary fixtures were removed;
no compiler, proof or test implementation files changed. Native execution,
mutation controls and the proposed typed pipeline were not measured by F00.
