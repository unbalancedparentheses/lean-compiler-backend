# Compiler backend discussions: evidence and design consequences

Reviewed 2026-10-18. Companion to [the architecture proposal](backend-architecture.md).
This is qualitative research, not a benchmark or a popularity ranking. Community
comments identify problems to investigate; project documentation, source and
papers establish technical facts. Our design recommendations are inferences.

## Method and coverage

Searched Reddit, Lobsters and Hacker News by project name, repository name and
specific topics: integration, correctness, code quality, incremental compilation
and maintenance. Read accessible discussion bodies, including corrections and
disagreements. Some Reddit pages failed direct fetching; their indexed discussion
text was available through search. These are marked below. Sparse results do not
establish absence of users or poor project quality.

| Project | Material examined | Evidence status |
|---|---|---|
| QBE | Reddit client/testing and backend-selection discussions; Lobsters integration experience; HN 1.3 discussion | Discussion bodies or indexed comments read; target claims checked against the vendored 1.3 source. |
| MIR (vnmakarov) | Lobsters MIR thread; upstream MIR-versus-QBE discussion; Reddit backend comparisons | Discussion content read; historical performance reports are not current measurements. |
| Stogov IR | HN QBE thread naming IR; primary README | Specific HN anecdote found; dedicated Reddit/Lobsters discussions were not located in these searches. |
| libFirm | Lobsters backend thread and Reddit performance question | Lobsters body and indexed Reddit comments read; benchmark not reproduced. |
| CompCert | HN testing thread, Lobsters historical bug thread, Reddit verification discussion | Read comments and their corrections; followed the historical bug to its issue and checked primary verification references. |
| Cranelift | Reddit ISLE discussion and Lobsters comparison with LLVM | Indexed Reddit comments and Lobsters body read; checked ISLE author's explanation. |
| Zig | Reddit, Lobsters and HN incremental-compilation discussions | Read relevant comments and maintainer article; checked official devlog. |
| MLIR | Reddit learning discussion, Lobsters primer discussion, HN custom-IR debate | Indexed Reddit comments and accessible thread contents read; checked official pass and IR documentation. |
| LLVM | Lobsters compile-time discussion, Reddit undef/Alive2 discussion | Relevant comments/indexed text read; checked official UB manual and Alive2 documentation. |
| CakeML | Reddit CakeML/verification discussion; Lobsters bootstrapping search result | Indexed Reddit content read. Lobsters body unavailable; primary CakeML documentation provides technical grounding. |
| Alive2 | Lobsters optimization/semantics discussions and Reddit verification discussion | Accessible indexed comments read; project README checked. |
| Sail | HN ISA-model discussion | Body read and RISC-V model repository checked; no substantive Reddit/Lobsters result used. |
| lean-mlir | Targeted social searches and primary README | No substantive discussion for the exact opencompl project located. Similar names refer to other projects. |
| TB/Cuik | Lobsters LLVM discussion mentioning Tilde/Cuik | Indexed comments read; primary repository checked. Supplemental comparison, not a new implementation dependency. |

## Findings by project

### QBE: simplicity must include usability

A developer integrating QBE with Myrddin praised the experience while asking for
debug information, inlining and symbol deduplication. This is a 2016 experience,
not a current feature inventory. The 2026 HN discussion includes reports of
difficulty reading and extending the compact C implementation. A Reddit qbe-wasm
author asks for runnable examples from external frontends after passing substantial
existing test coverage. [Lobsters integration report](https://lobste.rs/s/j1sadh/qbe_compiler_backend),
[HN 1.3](https://news.ycombinator.com/item?id=48373442),
[Reddit client-test request](https://www.reddit.com/r/Compilers/comments/1vna7lp/anyone_using_qbe/)

Design consequence: optimize for understandable semantic units, documented APIs
and reproducible failures, not minimum source-line count. Maintain a corpus from
multiple frontend shapes alongside generated tests. Keep source origins through
lowering even before complete debugger support.

An older Reddit claim that QBE lacks Windows support is stale for our pinned
release: `third_party/qbe/main.c` registers `T_amd64_win` and its Makefile includes
the Windows ABI implementation. Do not turn historical comments into current
limitations. [Older discussion](https://www.reddit.com/r/Compilers/comments/1mke2uw/),
[QBE project](https://c9x.me/compile/)

### MIR and Stogov IR: integration contracts matter as much as algorithms

The MIR Lobsters thread values its C API and interpreter/JIT combination, but
also contains a correction to a claim about interpreter dispatch. The upstream
MIR/QBE comparison is useful author context, not an independent current benchmark.
[Lobsters MIR](https://lobste.rs/s/zaevwg/mir_lightweight_jit_compiler_based_on_mir),
[upstream comparison](https://github.com/vnmakarov/mir/discussions/273)

One HN commenter reports favorable IR performance in their own tests, while
choosing QBE for C interoperability. That anecdote lacks enough methodology to
rank implementations. Stogov's README supplies the more useful engineering facts:
compact indexed nodes, declarative folding, a short pipeline, and inspection tools.
[HN comparison](https://news.ycombinator.com/item?id=48373442),
[IR README](https://github.com/dstogov/ir)

Design consequence: offer a checked builder plus a stable textual/serialized
boundary. Share semantics between interpretation and folding, while retaining
independent tests capable of finding a shared mistake. Adopt small rule libraries;
do not require a JIT or sea-of-nodes representation for those benefits.

### libFirm: measure the whole configuration

A Reddit user reports a modest improvement from optimization on their workload;
a skeptical reply explicitly admits no firsthand experience. The Lobsters thread
also distinguishes a stable, deliberately bounded project from an abandoned one.
Neither thread supports a universal performance or maintenance verdict.
[Reddit performance question](https://www.reddit.com/r/ProgrammingLanguages/comments/1e8qwis/),
[Lobsters discussion](https://lobste.rs/s/ijhl0w/libfirm_compiler_backend)

Design consequence: benchmark exact configurations and full pipelines, preserve
graph/pass inspection, and judge maintenance by reproducible builds, responsive
failure handling and clear contracts rather than commit frequency.

### CompCert and CakeML: check what the theorem actually covers

The HN testing discussion emphasizes specifications and trusted boundaries. The
linked authors' TAP paper explicitly combines tests and proofs. The older Lobsters
bug thread is particularly instructive: initial parser/grammar explanations were
corrected to elaboration/scoping after inspection. We should preserve the correction,
not repeat the headline. [HN discussion](https://news.ycombinator.com/item?id=36018300),
[authors' conference abstract](https://conf.researchr.org/details/tap-2023/tap-2023-papers/7/Testing-a-Formally-Verified-Compiler),
[Lobsters corrections](https://lobste.rs/s/qlrh1u/runtime_error_formally_verified),
[original issue](https://github.com/AbsInt/CompCert/issues/211)

Reddit discussion distinguishes proving a compiler from checking individual
compilation results and points to CakeML. Some comments overstate completeness or
reduce the trusted base to a kernel alone; those are not adopted here. CakeML's own
documentation establishes its concrete-machine-code backend result.
[Reddit verification discussion](https://www.reddit.com/r/ProgrammingLanguages/comments/n5pf7y/),
[CakeML](https://cakeml.org/), [CompCert scope](https://compcert.org/man/manual001.html)

Design consequence: publish exact theorem domains, test the specification against
independent behavior, measure compilation success separately from soundness, and
track parser/importer, ABI, encoding and linker assumptions individually.

### Cranelift and LLVM: declarative rules help inspection, not just speed

The ISLE Reddit discussion calls out the difficulty of adding formal semantics
late. The author's explanation describes a rule language that makes lowering
explicit and amenable to analysis. A Lobsters user reports improved code-generation
latency after adopting Cranelift, while another explains why disabling optimization
can leave more work for LLVM's code generator. These are workload reports, not
portable speed ratios. [Reddit ISLE](https://www.reddit.com/r/rust/comments/10h4gd5/),
[ISLE author article](https://cfallin.org/blog/2023/01/20/cranelift-isle/),
[Lobsters compile-time discussion](https://lobste.rs/s/ftk8xs/10_20x_faster_llvm_o0_back_end)

Design consequence: declarative rules should include types, conditions, deterministic
priority and preservation evidence. Benchmark allocation, lowering, encoding and
checking separately as well as end to end. A simple optimization may reduce total
compile time by reducing later work; decide by measurement.

LLVM's undef/poison discussions show how hard it is to reason about implicit
semantic permissions. The official UB manual is the authority for LLVM behavior.
Our inference is to use explicit arithmetic policies and conservative initial
memory assumptions, rather than importing every LLVM semantic mechanism.
[Reddit Alive2/undef](https://www.reddit.com/r/Compilers/comments/i1sbnt/),
[LLVM UB manual](https://llvm.org/docs/UndefinedBehavior.html)

### Zig: dependencies and debug information are observable inputs

The maintainer's incremental article separates type/layout/value dependencies and
function-body analysis, with inlining introducing additional source dependencies.
The Lobsters comments make a crucial point: whitespace can change line/column
debug information even if machine instructions stay the same.
[Maintainer article](https://mlugg.co.uk/posts/incremental-compilation-internals/),
[Lobsters discussion](https://lobste.rs/s/rmzzdb/inside_zig_s_incremental_compilation),
[Reddit discussion](https://www.reddit.com/r/Compilers/comments/1v951kq/inside_zigs_incremental_compilation_mlugg/)

Design consequence: separate code and debug dependencies, with a checked mapping
between them. An unrelated source edit is not necessarily unrelated to an artifact
that contains absolute line numbers. Specify code-fragment, debug-artifact and
final-binary reproducibility separately.

Do not repeat the Reddit claim that incremental compilation simply does not work
with LLVM: Zig's official April 8, 2026 devlog documents LLVM incremental support.
That does not imply every LLVM/linking stage is incremental.
[Lobsters pointer](https://lobste.rs/s/tbud4j/incremental_compilation_with_llvm),
[official devlog](https://ziglang.org/devlog/2026/)

### MLIR: preserve the contracts, control the number of representations

The Reddit learning thread describes substantial onboarding friction, including
from users who value MLIR in production. The HN debate contains both ecosystem
benefits and concerns about conversion/phase-ordering costs. An early Lobsters
discussion asks whether interpretation and optimization can share one IR.
[Reddit learning discussion](https://www.reddit.com/r/Compilers/comments/1pwabrz/starting_with_mlir_seems_impossible/),
[HN design debate](https://news.ycombinator.com/item?id=37157451),
[Lobsters primer](https://lobste.rs/s/vnzdpr)

Design consequence: a few semantically necessary stages, strong verifiers,
reproducers and operation interfaces are worthwhile. Every additional IR needs a
specific obligation it simplifies. Add an end-to-end contributor example showing
an operation's semantics, lowering, proof, fixture and final instruction sequence.
Use the official [pass contracts](https://mlir.llvm.org/docs/PassManagement/) rather
than inferring isolation guarantees from the word “dialect.”

### Supporting projects: use the actual theorem and tool boundary

Alive2 discussions motivate declarative transformations instead of manually
transcribing supposedly proved examples into unrelated implementation code.
Its project documentation describes LLVM refinement checking and explicitly
excludes interprocedural transformations. It is not a general proof kernel for
our backend. [Lobsters discussion](https://lobste.rs/s/pdivx4/my_impressions_hare),
[Alive2](https://github.com/AliveToolkit/alive2)

Sail's HN thread includes firsthand use of the RISC-V model and distinguishes ISA
behavior from microarchitecture. Use an ISA-model connection to justify target
semantics; it does not supply a timing model or prove the physical processor.
[HN Sail](https://news.ycombinator.com/item?id=44696543),
[RISC-V model](https://github.com/riscv/sail-riscv)

The opencompl lean-mlir README names a semantic rewrite theorem and core axiom
audits. Evaluate exactly those reusable pieces rather than assuming it already
proves arbitrary CFG, memory and machine lowering. [lean-mlir](https://github.com/opencompl/lean-mlir)

TB/Cuik appears in a Lobsters discussion of compile-time costs. The linked
benchmark is itself qualified by a commenter; the primary repository labels the
compiler early. Study representation and phase costs without using that discussion
as evidence of a universally superior backend.
[Lobsters](https://lobste.rs/s/uoprsr/how_bad_is_llvm_really),
[Cuik](https://github.com/RealNeGate/Cuik)

## Corrections and decisions carried into the architecture

1. A small implementation needs inspectable invariants and a usable integration
   surface. Source size alone is an inadequate objective.
2. Testing remains necessary after proofs: specifications and external boundaries
   can be wrong, and a compiler that rejects everything can satisfy conditional
   soundness while being useless.
3. Separate code identity from source/debug identity. State the exact reproducibility
   product instead of promising invariance for metadata affected by an edit.
4. Per-function proofs need open-component reasoning for callbacks and shared
   memory. CompCertO supplies a more specific reference than a generic linking slogan.
5. No social performance claim becomes a numerical target without reproducing a
   comparable workload. No popularity claim determines the proof architecture.
6. QBE is a fallible comparison implementation. The project's own
   [documented discrepancy](../UPSTREAM_DISCREPANCIES.md) reinforces the need for
   independent references; this research did not rerun that experiment.

## Remaining limits

This review sampled substantive discussions; it did not exhaust every archive or
reproduce external benchmarks. Dedicated Stogov IR and opencompl lean-mlir community
coverage remains sparse. The CakeML Lobsters body was unavailable. Current behavior
must still be tied to pinned revisions before implementation decisions or adoption
claims. The separate Claude Code review remains pending authentication.
