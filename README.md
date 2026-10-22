# Lean Compiler Backend

A general-purpose native compiler backend written in Lean 4, starting with a
full QBE 1.3 port. Full compatibility is the immediate priority: complete language,
ABI, optimization and target support before expanding formal proof coverage.
Executable semantics, existing proofs and regression tests remain required checks;
tested and certified coverage are reported separately. The current implementation
supports a bounded QBE-compatible IR with integer/floating-point operations,
control flow, memory, scalar/aggregate ABIs, TLS and direct/indirect calls.
Optimization and target coverage remain partial. Concrete is a consumer, not a dependency.

The [upstream fixture checkpoint](docs/UPSTREAM_COVERAGE.md) records 58 native
passes, 17 assemble-only fixtures and one unsupported input out of 76 on Apple ARM64.
Linux ARM64 also has 58 native passes, 17 assembly-only fixtures and one
unsupported fixture; see the target-specific coverage record.

Implemented targets are **AArch64 macOS** and a partial **AArch64 Linux ELF** target
(`--target aarch64-linux`), plus **Linux x86-64 System V**
(`--target x86_64-linux`), **macOS x86-64** (`--target x86_64-macos`)
and **Linux RISC-V LP64D** (`--target riscv64-linux`). Input is a restricted QBE-style SSA
language; output is assembly. This is a backend implemented in Lean, not yet a
backend for compiling the Lean language itself.

```text
QBE-style SSA → checked IR → target assembly → assembler/linker → native program
```

Lean's reference-counted runtime belongs to the compiler executable. Emitted
programs do not acquire the Lean runtime or a garbage collector. A generated
program may still use whatever runtime its own source language requires.

## Build and run with Nix

Nix supplies Lean 4.34.1, the C compiler, LLVM inspection tools, Python and Make.
Both Nixpkgs and the official Lean release archives are pinned. No elan,
Homebrew compiler, Python installation or separately installed QBE is required.

```sh
nix build
nix run . -- examples/arithmetic.ssa -o arithmetic.s
nix run . -- --eval examples/arithmetic.ssa add32 4294967295 2
nix flake check -L
```

For development:

```sh
nix develop
lake build lcb lcb-tests
bash scripts/check.sh
```

CI builds and checks proofs on Apple ARM64, Linux ARM64 and Linux x86-64,
including native target execution and comparison with retained QBE 1.3.
Development runners also qualify Linux RV64 under QEMU and macOS x86-64 through
Rosetta; reports distinguish native, emulated and unmeasured execution.

## QBE-style command-line use

Compatibility compilation accepts options before or after inputs, stdin (`-` or
no input in a pipeline), stdout (`-o -`) and multiple independent input modules:

```sh
nix run . -- -t arm64 -o linux.s < examples/arithmetic.ssa
nix run . -- --optimize -t amd64_sysv first.ssa second.ssa -o combined.s
```

| QBE target alias | Existing target name |
|---|---|
| `arm64_apple` | `aarch64-macos` |
| `arm64` | `aarch64-linux` |
| `amd64_sysv` | `x86_64-linux` |
| `amd64_apple` | `x86_64-macos` |
| `rv64` | `riscv64-linux` |

Use `-t` or `--target` to cross-compile. Without a target, the compatibility
driver selects the architecture and OS of its Lean runtime: ARM64/x86-64 macOS
or ARM64/x86-64/RV64 Linux. Unknown hosts require an explicit supported target.
The restricted first-path interface still emits `aarch64-macos`. Attached `-tTARGET`
and `-oPATH` forms work, and `--` marks remaining arguments as input paths.
`-h`/`--help` and an interactive invocation without arguments show help. These
options support frontend pipeline conventions; Windows AMD64 and QBE's internal
`-d` debugging interface remain unsupported. First-path/job commands retain
their separate options and proof boundary.

With cproc and an ARM64 Linux assembler/linker, the retained C pipeline smoke
program prints `pipeline 42 2.5`:

```sh
cproc -emit-qbe -o - tests/regressions/frontend-pipeline.c | lcb --optimize -t arm64 -o pipeline.s
cc pipeline.s -o pipeline
./pipeline
```

## First-path foundations

An opt-in integer/control-flow path now uses frozen per-function jobs, typed stack
MIR, typed AArch64 assembly and versioned replay:

```sh
nix run . -- --first-path examples/arithmetic.ssa -o arithmetic.s
nix run . -- --write-job examples/arithmetic.ssa add32 add32.job
nix run . -- --replay-job add32.job -o replay.s
```

Its source and target models are tested together. Proofs now cover entry and frame
helpers, conditional copy/phi-transfer simulation, and an admitted loop's unbounded
divergence through all three models. Whole-pipeline preservation remains open.
**Artifacts remain uncertified**; `--require-proof` explicitly fails.
The default compiler retains its broader compatibility subset. See the
[foundations, replay contract and proof obligations](docs/FOUNDATIONS.md).
After changing compiler sources, run `python3 scripts/build_identity.py --write`
before rebuilding; the checks reject stale source/build identities.

## Current scope

- Scalar `w`/`l`/`s`/`d` and void functions with up to 64 typed arguments.
- Integer arithmetic/bitwise operations, masked shifts, signed/unsigned
  division and remainder, negation, all integer comparisons and byte/half/word extensions.
- Defined 32/64-bit modular arithmetic, including narrowing `l` operands to `w`.
- Mutable-temporary SSA construction, type/name/dominance validation, and explicit
  rejection of unsupported constructs.
- Conditional/unconditional branches, fallthrough, loops, phi nodes and `hlt`.
  Phi transfers use parallel copies; cross-block uses are checked for dominance.
  Indexed CFG/SSA validation supports up to 4096 blocks and 70000 instructions/phis (600000 module tokens),
  with large native frame-slot addressing. The restricted proof profile keeps its
  smaller independent limits.
- Integer byte/half/word/long loads and stores, including signed loads and
  unaligned accesses. Nonnegative constant/runtime `alloc4`/`alloc8`/`alloc16`
  allocations in any block, with constant objects admitted through 1 MiB (subject
  to fixed-frame limits); QBE's `loadw`/`loadl` and `alloc1`/`alloc2` aliases.
- Effect-only `blit source, destination, count` copies, with constant byte counts
  in 0..1 MiB. Copies above 128 bytes use compact loops. The source and destination spans must be disjoint or have identical
  addresses, as required by QBE. The byte-count cap is a compiler resource limit.
- Direct and indirect calls with up to 64 typed scalar arguments and a scalar or void result,
  including recursion and external C symbols. Internal signatures are checked;
  external definitions must honor the declared ABI. Non-leaf frames save the
  return address and preserve live values across calls.
- Single/double arithmetic, comparisons, casts, numeric conversions, memory, phi values
  and scalar calls/returns.
- Apple ARM64 thread-local data and addresses, including external TLS and C threads.
- Named aggregate record/union/opaque storage layouts with nesting and repetition;
  inspect sizes and field offsets with `lcb --type-layout INPUT.ssa`. Passing these
  types by value is supported on Apple ARM64 through GP/FP registers, stack
  fallback and private indirect copies, including aggregate returns and variadics.
- Signed/unsigned byte and short ABI arguments/results, including packed stack slots.
- QBE `env` parameters/arguments in x9, including indirect and variadic calls.
- Integer/floating variadic functions/calls, `vastart` and w/l/s/d `vaarg` on Apple ARM64.
  Unnamed arguments use eight-byte stack slots, including indirect calls.
- Apple ARM64 uses independent banks of eight named integer and floating argument
  registers, then uses
  naturally aligned stack arguments: four bytes for words and eight for longs.
  The 64-argument cap is a compiler resource limit; the frame limit still applies.
- A small Lean theorem for primitive arithmetic opcode selection. A separate
  first-path model additionally proves source execution facts, target ALU,
  register/flag/frame helper facts and artifact binding. Admission soundness
  and composed compilation preservation are not proved.
- Independent Python arithmetic, native C ABI tests and upstream QBE comparison.

The default baseline uses stack slots for every value. Optional optimization
promotes eligible scalar stack objects to SSA and assigns callee-saved registers
with reusable spill slots. Broader linkage/debug forms, optimization and allocation
passes, and object emission remain. Packed data, strings, symbol relocations
and IEEE constant bit patterns are implemented. A separate restricted Concrete consumer is available in
[Concrete draft PR #8](https://github.com/unbalancedparentheses/concrete2/pull/8);
it does not close full compatibility. Concrete's checked-overflow operations must lower
to explicit checks; wrapping QBE arithmetic does not implement them by itself.

Larger-program qualification includes cproc self-compilation (18 frontend units,
byte-identical IR reproduction and 196 original tests), QBE itself (32 units,
725 functions and 487 exact successful assembly reproductions), and zlib with its
original example/minigzip programs (17 units, 271 functions, upstream static tests
and 12 exact gzip streams per qualified build). All three Linux targets have
these workload checks; local x86-64/RV64 execution uses QEMU. Original upstream
failures remain separate from corrected test oracles, and performance still trails
QBE on the measured workloads. See [real-program comparisons](docs/benchmarks/README.md).

[The port inventory](docs/PORT_STATUS.md) lists every upstream public/internal
opcode, target/ABI and compiler source module, including unimplemented areas.
Special syntax such as `blit` is tracked separately from the public opcode-name
count, which does not measure overall port completion.
Generated-program fuzzing compares independent Python arithmetic, the Lean
interpreter, Lean native output and QBE native output. Failures retain the seed,
input and outputs under `.build/fuzz-failures/`; use `nix develop -c python3
scripts/fuzz.py --seed 20261018 --require-native` to replay a seed. Each native
campaign also checks that a deliberately corrupted emitted return is detected.
For a longer campaign, use `nix develop -c python3 scripts/fuzz.py --seeds 64
--functions 16 --steps 96 --samples 11 --require-native`.

Integer division by zero and signed minimum divided by -1 are outside the
defined equivalence domain; the interpreter reports them explicitly. Native
behavior for those inputs is not a portability or safety guarantee.
The interpreter has a block-step budget; exhausting it reports an unevaluated
result. Mutable temporaries are renamed into SSA with phi insertion before compatibility
validation; the restricted first path still requires original SSA input.

The memory interpreter uses abstract byte-addressed objects and rejects external,
out-of-bounds and uninitialized accesses. This is a testing model, not native
runtime memory-safety enforcement. Native checks also exercise actual C-owned
memory. Allocations accept constants in 0..1 MiB or runtime sizes in any block, subject
to the total fixed-frame limit.
The compatibility backend limits fixed frames to 1 MiB; the interpreter limits
allocated memory to 1 MiB. Native runtime allocation assumes a valid nonnegative
size and sufficient stack space. Zero-sized allocations retain requested alignment. Memory fuzzing found a
[QBE 1.3 load-forwarding discrepancy](docs/UPSTREAM_DISCREPANCIES.md). Original
QBE mismatches are retained and reported separately from a declared corrected
test comparison; native C references corroborate generated overlap cases.

Blit interpretation copies initialization state as well as bytes: copying an
uninitialized byte leaves its destination uninitialized. Partial overlap or a
span outside an allocated object reports an unevaluated result. A zero-byte blit
accesses no memory. Native blits do not add bounds or overlap checks; their
defined-domain requirement is a caller obligation, not a memory-safety guarantee.
Blit checks compare interpretation and native output with independent byte-array
references and pinned QBE, including unchanged neighboring bytes.

Call tests compare generated programs against Python, native C and original QBE,
including recursion, parallel argument moves, values live across calls and
callee writes to caller-owned memory. Native ABI tests deliberately clobber
caller-saved registers and check callee-saved registers and stack balance.
The interpreter shares a 100,000-block budget across calls, limits call depth
to 128 and invalidates each activation's stack objects at return. External
calls have no interpreter model and report an unevaluated result.
Void functions and effect-only calls have no invented result or SSA definition;
`--eval` reports `void` when an interpreted function returns no value. Calls must
agree with the defined function's integer or void result type.
Stack-argument tests cover C callers/callees, internal forwarding, mixed widths
and recursion with local stack objects. Wrong incoming offsets and stores wider
than their outgoing argument slots must fail the native comparisons. Passing
arguments in registers is separate from the still-unimplemented register allocator.

**The backend is not verified end to end.** The current theorems do not prove
parsing, admission, full stack lowering, assembly rendering, the assembler or the linker correct.
See [the design and trust boundaries](docs/DESIGN.md) and [the roadmap](ROADMAP.md).

## Sources and credit

QBE 1.3 is the main porting baseline: its IL, AArch64 instruction selection and
ABI organization. Zig 0.17.0 is a reference for analyzed/machine representations,
explicit arithmetic modes and native target handling. LLVM provides design
references for machine IR, isolated pass tests and verification between passes.
MLIR supplies references for explicit conversion legality and operation
verification. We plan a small set of Lean representations and pass interfaces,
with additions justified by correctness or measured workloads. MLIR is not a
build or runtime dependency. This project is independent of those projects.

The complete QBE release and selected Zig reference files are retained under
`third_party/`, with their original licenses. Every retained file has a SHA-256
entry in [upstream-lock.json](upstream-lock.json). Adapted modules name their
sources in comments. [Upstream provenance](docs/UPSTREAM.md) records exact
versions, archive hashes, licenses and the distinction between copied code,
ported behavior and design inspiration. [Beyond QBE](docs/BEYOND_QBE.md) explains
which Zig/LLVM ideas we plan to adopt and why.

Original project code is MIT licensed; upstream files and the Concrete-derived
Nix configuration retain their respective licenses. See [LICENSE](LICENSE).

## Research and proposed architecture

[Backend architecture research](docs/research/backend-architecture.md) collects
the QBE, CompCert, MLIR, Cranelift, Zig, MIR, Stogov IR, libFirm and LLVM
comparison, reproducible per-function compilation design, verification
strategy and design proposals. The [roadmap](ROADMAP.md) prioritizes full QBE compatibility:
complete Apple ARM64 language/ABI coverage, optimization and register allocation,
then the remaining targets and qualification. Formal proof expansion follows;
the first composed preservation result is no longer a prerequisite. The [first verified path specification](docs/research/first-verified-path.md)
defines the restricted integer/loop proof domain, job and artifact schemas,
stack/typed-assembly representations and worked traces. F00 is complete as a
design deliverable. [F01 source semantics](docs/SEMANTICS.md) now implement its
restricted integer/control-flow model and admission profile, with two source-model
lemmas. [F02–F05](docs/FOUNDATIONS.md) add independent jobs, typed target lowering,
versioned artifacts/replay and pass obligations. Compilation preservation remains open. The [community review](docs/research/community-discussions.md) records
discussion evidence, primary-source checks and remaining coverage gaps.

Correctness is the primary goal from the current port onward. QBE is the current porting baseline
and comparison implementation, not a permanent constraint on the backend's IR
or semantics. The full-port milestone remains in place; future evolution may
retain QBE support through an explicit import boundary. Performance improvements
must preserve the applicable correctness contract, and tested support remains
distinct from proved support.

Use `--optimize` with compatibility compilation to enable bounded constant
propagation, integer folding, same-width copy propagation and conservative
dead-definition removal, constant-branch simplification and unreachable-block
removal and dominance-aware common integer-expression elimination. The default
preserves the stack baseline.
The pipeline repairs phi edges, remaps debug locations after removal and
retains potentially effectful or trapping operations. It does not expand the
certified path. `--optimize` also allocates callee-saved GP register homes and
reusable spill slots on all five targets; `--allocate` enables
that allocation without the other optimization passes. `--allocation INPUT.ssa`
prints target-independent diagnostic colors and liveness. Every plan is checked
for live-value overwrites and symbolic value flow before emission. Default and certified compilation keep unique slots.

Use `--liveness INPUT.ssa` to print diagnostic JSON for each SSA function,
including block, instruction and phi-edge live sets. This analysis prepares
register allocation; it does not change emitted assembly or add proof coverage.

A [real-program cJSON comparison](docs/benchmarks/README.md) runs unchanged
upstream tests and records correctness, stack-limit exceptions, compile time,
object size and native runtime against pinned QBE and GCC.
