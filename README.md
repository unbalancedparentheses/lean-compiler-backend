# Lean Compiler Backend

A native compiler backend written in **Lean 4**, developing QBE 1.3 compatibility
on five Linux/macOS targets. It accepts QBE-style IR and emits assembly for
integer and floating-point code, control flow, memory, TLS, and scalar/aggregate
calls. It is a backend implemented in Lean, **not a compiler for the Lean language**.

```text
QBE-style IR → parsing / SSA construction / validation → optional optimization
             → allocation / instruction selection → assembly → system toolchain
```

The compiler builds and runs substantial C programs through cproc, including QBE
and cproc themselves. **Full QBE parity is still in progress; the compiler is not
verified end to end.** Compatibility and useful optimization come before broader
proof coverage. Windows AMD64 is explicitly deferred. See the [roadmap](ROADMAP.md)
and [port inventory](docs/PORT_STATUS.md) for the remaining work.

Generated programs do not inherit Lean's runtime or a garbage collector. They use
only the runtime required by their own source language and linked libraries.

## Build and run

The pinned Nix environment supplies Lean 4.34.1, C/LLVM tools, Python and Make;
there is no separate elan or QBE installation requirement.

```sh
nix build
nix run . -- examples/arithmetic.ssa -o arithmetic.s
nix run . -- --eval examples/arithmetic.ssa add32 4294967295 2
nix flake check -L
```

To work on the compiler:

```sh
nix develop
lake build lcb lcb-tests
bash scripts/check.sh
```

CI runs the pinned checks on Linux ARM64, Linux x86-64 and Apple ARM64, including
native execution, proof auditing and independent C/QBE comparisons. Local
qualification additionally uses QEMU for Linux RV64 and Rosetta for Apple x86-64.
Reports identify native, emulated and emission-only results separately.

## Targets and command line

| Target | QBE alias | Execution qualification |
|---|---|---|
| `aarch64-linux` | `arm64` | Native Linux ARM64 |
| `x86_64-linux` | `amd64_sysv` | Native CI; local QEMU |
| `riscv64-linux` | `rv64` | QEMU; native hardware remains open |
| `aarch64-macos` | `arm64_apple` | Native Apple ARM64 |
| `x86_64-macos` | `amd64_apple` | Rosetta; native Intel Mac remains open |

The compatibility driver defaults to its supported host architecture and OS.
Use `-t` or `--target` to cross-compile; assembly still needs the corresponding
assembler, linker and runtime. Unknown hosts require an explicit supported target.

```sh
# Generate Linux ARM64 assembly from stdin.
nix run . -- -t arm64 -o linux.s < examples/arithmetic.ssa

# Optimize two independent input modules into one assembly output.
nix run . -- --optimize -t amd64_sysv first.ssa second.ssa -o combined.s

# With cproc, lcb and an ARM64 Linux C toolchain available:
cproc -emit-qbe -o - tests/regressions/frontend-pipeline.c | lcb --optimize -t arm64 -o pipeline.s
cc pipeline.s -o pipeline
./pipeline
```

Options may precede or follow inputs. `-` reads stdin, `-o -` writes stdout,
`-tTARGET`/`-oPATH` are accepted, and `--` ends option parsing. `--help` documents
the command line. QBE's internal `-d` debugging interface is not implemented.

| Mode | Behavior |
|---|---|
| Default | Stack-slot baseline, retained as a differential reference |
| `--allocate` | Callee-saved allocation, restricted leaf caller-saved homes and reusable spills |
| `--optimize` | Optimization pipeline followed by allocation and target selection |

## Implemented scope and remaining work

The compatibility path supports `w`/`l`/`s`/`d` values, mutable-temporary SSA
construction, branches/loops/phis, arithmetic and conversions, typed loads/stores,
aligned stack allocation, constant-size `blit`, packed data and relocations,
direct/indirect calls, aggregates, variadics and target-specific TLS/linkage.
Optimizations include constant/copy propagation, dead-definition and CFG cleanup,
scalar stack promotion, conservative memory forwarding, common-expression
elimination and target-specific addressing/branch simplifications.

This is a **bounded** implementation. Current compatibility limits include 4,096
functions, 4,096 data definitions, 4,096 blocks per function, 70,000
instructions/phis per function, 1,024 arguments, 1 MiB fixed frames and 256 MiB
native module data. Parsing and interpreter execution have separate budgets.
Accepted opcode names are not a measure of complete semantic or ABI coverage.

Remaining work includes syntax/linkage and ABI boundaries, broader alias/CFG
analyses, general caller-saved and floating-point register allocation, live-range
splitting/coalescing, native RV64/Intel Mac qualification and workload-specific
performance improvement. Assembly is the output format; direct object emission
is not implemented. Consult [semantics and defined domains](docs/SEMANTICS.md),
[the port inventory](docs/PORT_STATUS.md) and [the roadmap](ROADMAP.md) for details.

## What has been tested

The retained upstream fixture suite emits 75 of 76 inputs on each supported
target. Its original runtime/assembly-only split and the refused fixture are
recorded in [upstream coverage](docs/UPSTREAM_COVERAGE.md); this is not a full-parity
percentage. Generated tests add independent arithmetic, byte-level memory,
C ABI, guard-page and corruption-detection checks.

Larger-program evidence includes:

- **[QBE and cproc](docs/benchmarks/amd-data-bootstrap/README.md):** fresh builds on
  all three Linux targets. Each LCB baseline/optimized QBE build reproduces 487
  assemblies and passes 58 ARM-output runtime tests; each cproc build reproduces
  19 IR files and passes 196 original tests.
- **[zlib](docs/benchmarks/README.md):** target-specific builds, original drivers,
  exact compression streams and independently checked API results. Recent
  [five-label ARM correctness checks](docs/benchmarks/arm-scaled-load/combined-correctness/README.md)
  preserve separate GCC, LCB predecessor/current and original/corrected QBE builds.
- **[libyaml](docs/benchmarks/libyaml/README.md)** and
  **[LZ4](docs/benchmarks/lz4/README.md):** library and upstream-driver qualification
  on all three Linux targets, with bounded test profiles and recorded identities.
- **[Mixed Lua](docs/benchmarks/lua-mixed/README.md):** 30 of 33 production units
  compiled through LCB on Linux ARM64. Three volatile-containing units use unchanged
  GCC objects because the pinned frontend rejects them. Reduced upstream suites
  retain their exclusions; this is not a complete LCB-built Lua qualification.

Every report binds its compiler/source/toolchain identity; historical reports are
not silently relabeled as tests of today's source. Original QBE discrepancies
remain separate from explicitly corrected comparison oracles and independent C
checks. See [benchmark evidence](docs/benchmarks/README.md) and
[upstream discrepancies](docs/UPSTREAM_DISCREPANCIES.md). Runtime performance varies
by workload and target; static code savings alone do not establish a speedup.

## Proof scope and trust

Existing proofs cover restricted source/machine semantics, primitive ALU
selection and parts of a separate typed first path. The 147-statement proof audit
records exact theorem dependencies. It does **not** prove the complete
compatibility pipeline, optimizer, allocator, ABI lowering, assembly rendering,
assembler or linker correct. Execution tests and structural checkers do not
replace those proofs.

The opt-in first path uses frozen per-function jobs, typed stack MIR, typed
AArch64 assembly and versioned replay:

```sh
nix run . -- --first-path examples/arithmetic.ssa -o arithmetic.s
nix run . -- --write-job examples/arithmetic.ssa add32 add32.job
nix run . -- --replay-job add32.job -o replay.s
```

It retains its own restricted admission rules and Apple ARM64 output.
**Artifacts remain uncertified**; `--require-proof` explicitly fails. The
[foundations](docs/FOUNDATIONS.md) and [design](docs/DESIGN.md) describe its
contracts and trusted boundaries. The interpreter is a bounded testing model,
not native memory-safety enforcement; undefined-domain operations and unmodeled
external effects are not portability guarantees.

## Repository guide

| Location | Purpose |
|---|---|
| `Main.lean` | Command-line entry point |
| `LeanCompilerBackend/` | IR, parser, validation, SSA, semantics and target backends |
| `LeanCompilerBackend/Optimize/` | Optimization passes and focused tests |
| `LeanCompilerBackend/Verified/` | Restricted typed path, replay and proofs |
| `Tests.lean` and module `Tests.lean` files | Lean unit/regression tests |
| `scripts/` | Build identity, proof audit, independent execution and workload harnesses |
| `tests/`, `examples/` | Retained fixtures, regression inputs and small programs |
| `docs/` | Design, semantics, roadmap evidence and reproducible qualification records |
| `third_party/` | Pinned upstream references with original licenses |

After changing compiler sources, run `python3 scripts/build_identity.py --write`
before rebuilding. Checks reject stale build identities. Keep independent
execution oracles and the baseline when changing optimization or allocation;
benchmark reports must distinguish correctness from performance claims.

## Sources and license

QBE 1.3 supplies the primary IL, backend and ABI baseline. Zig, LLVM and MLIR
inform selected design choices; they are not runtime dependencies. Provenance,
exact revisions and adaptation notes are recorded in [upstream sources](docs/UPSTREAM.md)
and [upstream-lock.json](upstream-lock.json). Concrete is a separate consumer,
not a dependency of this backend.

Original project code is [MIT licensed](LICENSE). Retained upstream code and
configuration keep their respective licenses; see `LICENSES/` and `third_party/`.
