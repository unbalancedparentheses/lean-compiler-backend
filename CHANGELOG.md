# Changelog

## Unreleased

- Support positive runtime-sized and non-entry stack allocations on Apple ARM64.
  Dynamic functions keep SSA/phi slots relative to a stable x29 frame base with
  a canonical FP/LR record, allocate outgoing stack arguments at each call, and
  restore SP/FP on return. Repeated loop allocations remain distinct through calls.
  Native tests cover indirect callbacks, stack arguments and explicit frame probes;
  interpreter zero-size/budget refusals do not imply native runtime guards.

- Parse decimal/hexadecimal `s_` and `d_` constants into IEEE bit patterns with
  exact integer arithmetic and one ties-to-even rounding step. Support floating
  data field aliases, signed zero, infinities, canonical NaNs and subnormals.
  Native/interpreter checks compare against libc strtof/strtod and QBE, including
  double-rounding-sensitive boundaries. Floating arithmetic and ABIs remain open.

- Raise compatibility stack frames from the 4080-byte immediate restriction to a
  1 MiB resource limit. Split stack adjustments and allocation address calculations
  into legal AArch64 immediate scales; materialize large incoming argument offsets.
  Six layouts through 128 KiB of allocation pass interpreter/native Lean/QBE/C
  checks, including mixed stack arguments, calls, return addresses and corruption
  controls. The restricted first-path frame bound remains 4080 bytes.

- Scan all 76 retained upstream SSA fixtures and prevent emission regressions in
  CI. The first native compatibility checkpoint emits 35: 27 runnable fixtures
  pass original drivers/output expectations with both Lean and QBE output, and
  eight development fixtures assemble only. The other 41 remain unsupported and
  are reported separately. Preserve artifacts for native failures.

- Support indirect integer/void calls through long operands on Apple ARM64,
  sharing direct-call argument/frame handling through 64 mixed w/l arguments.
  The interpreter resolves defined function identities and rejects unknown targets
  or dynamic signature mismatches. Native qualification covers C callbacks,
  function tables, phi-selected targets, recursion, void effects and a removed-call
  corruption control. Native targets/signatures remain caller responsibilities.

- Match QBE's unquoted identifier grammar, including dots and embedded dollar
  signs, across globals, functions, blocks, parameters and SSA values. Native
  comparisons cover these names through relocations, calls and phi transfers;
  malformed or assembly-significant characters remain rejected.

- Add byte string data initializers with UTF-8, escaped quotes/backslashes, common
  control escapes and octal bytes. Tokenization preserves comments and punctuation
  inside strings; emitted byte directives avoid assembler escape ambiguity.
  Seeded packed-data tests compare exact object bytes, alignment and checksums
  across Python, interpretation, native Lean output and pinned QBE.

- Add module-level packed integer data, zero fill, alignment and 64-bit symbol
  relocations with addends on Apple ARM64. The interpreter initializes globals in
  two phases for forward/self references and preserves them across calls. Support
  data-only modules; reject data/function collisions and calls to data symbols.
  The legacy function-only parser and first-path CLI explicitly reject module data.

- Accept global symbol operands in the compatibility parser and emit Apple ARM64
  GOT address loads, including external data, function addresses and phi inputs.
  Native C/QBE comparisons cover reads, writes, address identity and truncation;
  the interpreter refuses unresolved symbols and the first proof profile rejects them.

- Prioritize full QBE compatibility before further formal proof expansion:
  complete Apple ARM64 language/ABI support, optimizations and register allocation,
  then remaining targets and qualification. Defer C01–C03 and proof expansion;
  retain existing proof checks, executable semantics and regression requirements.
  The next implementation checkpoint is data definitions and symbol references.

- Unified copy, arithmetic and comparison simulation: every successful source
  body step has a matching MIR expansion. Operand availability and destination
  typing are derived from the source step rather than supplied separately.

- Proved source equality and unsigned comparison through their actual four-step
  MIR expansions, including word-sized results for long operands.

- Proved all six arithmetic/bitwise source operations simulate through their
  actual four-instruction MIR expansion, preserving the updated environment
  relation under explicit availability, typing and instruction-position premises.

- Added runtime rejection controls for duplicate phi destinations, missing
  predecessors, unavailable operands, operand width mismatches and invalid
  destinations. Recorded the 123-theorem native qualification checkpoint.

- Strengthened the general source/MIR phi-transfer theorem with caller-context
  preservation: SP, frame metadata, flags, saved entry registers and all registers
  other than the R9 scratch register remain unchanged.

- Proved an actual source copy instruction is simulated by its two emitted MIR
  steps, preserving the complete updated source/frame relation under explicit
  instruction-position, availability and typing premises.

- Instantiated the general source/MIR phi-transfer theorem on an admitted cyclic
  loop with arbitrary compatible values, plus concrete live-frame witnesses.

- Connected the general MIR phi-edge theorem to the source interpreter's actual
  checked transfer loops, including predecessor uniqueness, duplicate-destination
  checks, source reads and typed environment updates.

- Proved arbitrary phi commit and composed emitted-edge execution in exactly
  four MIR steps per phi plus the jump, preserving the relation to values
  resolved simultaneously from the predecessor environment.

- Proved the actual phi staging pass for arbitrary lists, with a frozen source
  environment, correct staged values, frame readiness and preserved locals.

- Proved actual local/literal operand lowering under an explicit source/frame
  relation, including copy-store execution and preservation of every defined
  source value by canonical phi staging writes.

- Prove unbounded divergence of an admitted cyclic-phi loop through source,
  actual MIR lowering and typed AArch64 selection, including valid caller entry
  states and jump terminators. Add reusable positive-cycle divergence lemmas.

- Proved the emitted two-phi cyclic swap executes correctly as eight MIR steps
  for arbitrary word/long values, with frame readiness and non-scratch registers
  preserved. Arbitrary phi-set/source-transfer composition remains open.

- Exposed phi staging/commit phases and proved straight-line MIR execution
  corresponds to actual small steps. Proved the effect of the scratch-register
  load/store pair used by transfers; full simultaneous-transfer correctness
  remains open.

- Proved successful model initialization establishes the entry-state contract,
  valid entry preconditions guarantee initialization succeeds, and the assembly
  entry adapter handles zero-byte frames. Argument register views are proved for
  arbitrary compatible values, including word arguments with dirty high bits.

- Proved same-width frame load-after-store reconstruction and preservation of
  disjoint loads, including uninitialized read failures. The executable loader
  now reconstructs bytes recursively; independent byte fixtures cover byte order,
  mixed widths and partial overlap. These close memory-helper obligations for
  C01, not the composed compilation theorem.

- Implemented F02–F05's first-path baseline: frozen function jobs, explicit ABI/
  frame plans, typed stack MIR and AArch64 assembly, executable frame/register
  models, canonical job/artifact replay and separate SHA-256 dependency identities.
  Artifacts remain uncertified; unavailable evidence requests fail explicitly.
  Added target-helper, layout, store-byte and binding proofs with axiom auditing,
  native/model/mutation qualification and generated cyclic-phi campaigns. The default compatibility pipeline is unchanged.
- Made Linux ARM64, x86-64 and RV64 assembly targets explicit in P10, with
  per-target ABI/native/emulated qualification and separate certification scope.

- Implemented F01's restricted source contract: numbered SSA, 32/64-bit values,
  atomic phi transfers, small-step return/divergence semantics, bounded evaluation
  and explicit profile admission. Added boundary/negative tests and kernel-checked
  source determinism and bounded-return lemmas with axiom auditing. The existing
  CLI remains on the compatibility pipeline; admission and compilation preservation
  are not yet proved. See `docs/SEMANTICS.md`.

- Completed roadmap F00 with the first verified-path specification: restricted
  integer/control-flow semantics, versioned jobs and evidence, stack MIR and
  typed AArch64 contracts, pass proofs and worked loop/phi/frame examples.
  Documentation only; no new compiler feature or preservation theorem is claimed.

- Added effect-only QBE `blit` with constant byte counts in 0..4096. The
  interpreter preserves unknown bytes, rejects partial overlap and accesses
  outside allocated objects, and performs no memory access for zero-byte copies.
  Native output assumes QBE's disjoint-or-identical span contract without bounds
  or overlap guards. The size cap is a compiler resource policy. Blit is tracked
  as syntax support; it does not change the public opcode-name coverage count.

- Added Apple ARM64 integer stack arguments and raised the integer argument
  resource limit to 64. One explicit layout handles caller/callee word/long
  packing. Frames reserve outgoing space below locals, phi copies, saved LR and
  allocations. Native C/QBE comparisons cover both ABI directions, internal
  forwarding and recursion; offset/width corruption controls qualify the checks.
  Register allocation, indirect calls and the remaining ABI classes stay open.

- Added void functions, bare returns and effect-only direct calls, including
  recursion and C APIs. Missing results are represented explicitly rather than
  as fake SSA temporaries or zero. Signature checks reject integer/void result
  mismatches; interpreter `--eval` prints `void` when there is no return value.

- Adopt a correctness-first roadmap: semantic contracts, independent function jobs,
  canonical serialization and typed lowering begin during the QBE port; a first
  composed preservation milestone precedes broader certified coverage. Track
  implemented, tested and proved support separately. QBE remains the compatibility
  baseline without imposing permanent IR compatibility. Documentation only; no
  new implementation or proof coverage is claimed by this roadmap change.

- Added direct integer calls, checked internal signatures, recursion and a
  non-leaf ARM64 ABI slice with saved return addresses and live values retained
  across calls. Interpreter calls share a global block budget and memory, with
  callee stack objects invalidated on return. Unknown external calls have no
  interpreted result. Native C interoperation and generated call graphs are
  compared with Python, original QBE and C; register-clobber corruption controls
  qualify the ABI checks. Indirect calls and full ABI support remain open.

- Added integer loads/stores and bounded entry-block constant stack allocations,
  with explicit store statements, an executable byte-memory model and ARM64
  emission. Dynamic/non-entry allocations and full data support remain open.
- Memory fuzzing reduced a QBE 1.3 partial-store-forwarding discrepancy,
  corroborated by native C. Retain the original snapshot and reproducer, run
  original and explicitly corrected comparison copies separately, and never
  count original mismatches as matching cases.
- Keep register allocation in the full-port sequence and record a compact,
  selective MLIR/LLVM/Zig inspiration policy for improvements after compatibility.

- Added integer SSA basic blocks, conditional/unconditional branches, fallthrough,
  loops, phi nodes and halt. Dominance and phi predecessor checks reject invalid
  inputs. Parallel phi transfers stage every source before writing destinations.
- A 64-seed campaign on `4fcd83b` covered 1,024 generated straight-line functions
  and 16,384 input cases across Python, Lean interpretation and both native backends.

- Ported integer shifts, signed/unsigned division and remainder, negation,
  sign/zero extensions and all integer comparisons. Independent tests cover
  both result widths, signed boundaries, masked shift counts and undefined
  division exclusions. Mixed-program fuzzing now includes shifts.

- Added generated-program differential fuzzing with reproducible seeds, retained
  failures and an emitted-code corruption control. Its first seed exposed and
  reduced an interpreter bug: execution returned after the first binary operation.
  Fixed it and retained a two-instruction regression.
- Added a source-derived operation/target/module inventory and explicit port status.
- Use Nix's C compiler for Lake output as well as ABI tests, fixing Linux ELF
  interpreter paths. Upstream snapshots remain byte-identical, including whitespace.

## 0.1.0 — initial port checkpoint

- General-purpose Lean 4 backend with a restricted QBE 1.3 integer subset and
  AArch64 macOS leaf-function assembly. This is not the completed QBE port.
- Pinned Nix development, build and test tools; native C comparisons and a
  separately built upstream QBE comparison; parser and resource-limit controls.
- Initial primitive opcode-selection theorem, with explicit scope and axiom audit.
- Full QBE source snapshot and selected Zig references with licenses, per-file
  hashes and adaptation notes. LLVM/Alive2 ideas are documented for later work.
- Full-port-first roadmap: upstream compatibility and differential fuzzing,
  followed by the larger proof effort; Concrete is a future separate consumer.
