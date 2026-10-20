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
