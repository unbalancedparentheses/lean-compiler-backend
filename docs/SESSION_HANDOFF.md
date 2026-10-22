# Session handoff — 2026-10-22

This is a continuation checkpoint, not a full QBE compatibility or verification
completion claim. QBE compatibility and useful, independently tested optimization
remain the priority; broader certification is deferred. The active compatibility
scope is the five existing Linux/macOS targets. Windows AMD64 is explicitly
deferred at the user’s request and is not a current completion blocker.

The user has now authorized focused proofs alongside compatibility work (roughly
20% of effort), with agents. The first checkpoint adds three universal
[fresh-name collision facts](proofs/FRESH_NAMES.md) and fourteen
[local algebra facts](SEMANTICS.md#local-algebra-proof-checkpoint), including
thirteen actual zero/one rewrite branches. All 164 exact proof-dependency checks
pass; the preceding 147 remain unchanged. Fresh build and full unit tests pass,
including 156 new interpreter cases. Runtime sources and compiler identity remain
unchanged. Proof modules are imported by the test target and excluded from runtime
identity like existing proof-only modules. No whole-pass or end-to-end claim.
The refactor CI completed successfully on all three runners; new proof-checkpoint
CI has not yet completed. The subsequent [ELF excluded-section checkpoint](benchmarks/elf-exclude/README.md) is a separate compatibility change.

Ordinary ELF section flags now admit `e` with `a/w/x/R`; TLS and Apple rules stay
unchanged. Actual-main identity `803fc0258d24899011d3f26fdf23b3c3e4cd6f9721ee25722f7a4ad4c012c759`
passes all six GNU/LLVM assembler/three-Linux profiles and two Apple preservation
profiles, fresh build/units, 164 identical audit statements, 1,305 identical corpus
assemblies/15 identical refusals and the complete missing-tool execution guard.
LLVM assembly uses GNU target linking; x86/RV runtime is QEMU. Early harness
failures, original-QBE bindings and expected excluded-symbol link refusals are
retained. Full host/Linux gates were not rerun on this identity; CI is pending.

The user subsequently requested an updated README and safe code organization.
README and the design pipeline now reflect current capabilities, target scope and
proof limits; generated port inventory no longer reports completed features as
missing. The [AArch64 extraction](refactors/aarch64-modules/README.md) moves
unchanged ALU/proof and scalar-layout helpers behind the stable public facade.
New identity `c1178a9e4b10ea5d318ef8e6b5d498ea0c85e677d5d58eddcc29f1ed383effd9`
passes build, units, 147 identical audit statements, 1,305 identical corpus
assemblies/15 identical refusals, 192 identical zlib/mixed-Lua assemblies and
focused native ABI/scaled-load/floating-variadic tests. Exact moved-body and
inverse-facade reconstruction pass. Full gates below remain bound to pre-extraction
e095ed59; no wholesale rerun or new proof/performance claim. Refactor CI passed on all three runners.

A [fresh five-label ARM zlib build](benchmarks/arm-scaled-load/combined-correctness/README.md)
passes all fifteen correctness profiles per label on combined e095ed59 versus
retained-TLS predecessor, fresh GCC, original QBE and corrected QBE. All source
and 485-file guest/host bindings pass. No timing phase has run. After the full host gate passed, the [monitored readiness preflight](benchmarks/arm-scaled-load/monitored-readiness/README.md) refused to start timing: outside-host load was about 15.2 cores versus the fixed 0.25-core limit; the guest was idle. No unrelated jobs were changed. A clean performance claim remains deferred.

The first combined full-host rerun hit an AMD helper output-directory collision
after the preceding Linux gate. The helper now permits reuse and passes two
consecutive emission/Rosetta profiles; failure and exact helper versions are
retained in [repeatability evidence](benchmarks/amd-folded-loads/repeatability/README.md).
Compiler identity is unchanged; complete full host v2 passed with the fixed helper, whose three CI runners also pass (a2c061d/run39789252298). Its full log is retained in benchmarks/data-definition-limit/gates/full-host-v2.log.

[Data-definition admission](benchmarks/data-definition-limit/README.md) now allows
4,096 definitions. Combined identity `e095ed5999bf703a2f710ec2edb3aead02704c051dda196a0daeb310ad2e839e`
passes fresh units, 147 unchanged audit statements and all five actual-main
matrices: 92,175 LCB object checks, 51,210 original-QBE checks, 65 rejection/budget
controls and five corrupted-final-object controls. The unchanged cproc catalog
also passes all three ARM modes. Actual combined AMD/zlib replay and corpus audit also pass: 102 audited pairs,
204 private/main assembly matches, six examples and 72 exact streams. All three complete Linux gates pass. [Fresh QBE/cproc qualification](benchmarks/amd-data-bootstrap/README.md) also passes
on all three Linux targets: 2,922 exact assemblies/348 runtime tests and 114 exact
IR reproductions/1,176 upstream tests. Original/corrected references remain
separate. The complete final host gate passed. Combined-source CI run39786374097 passes Linux ARM64, Linux x86-64 and macOS. No timing claim.

[AMD64 folded loads](benchmarks/amd-folded-loads/README.md) remove redundant EAX
self-copies after word loads. Integrated identity `7e441df0` exactly matches the
qualified private candidate; fresh main build, units and 147 unchanged audit
statements pass. Both AMD matrices, zlib and corpus delta audit pass privately.
Combined-main replay and all full local gates now pass as recorded above.
No runtime speed claim.

[ELF assembler profiles](benchmarks/elf-section-assembler-profiles/README.md) correct
the GNU-only section-name expectation that failed both Linux Clang CI jobs.
Six GNU/LLVM profiles pass on all three Linux targets using committed identity4b41;
LLVM preserves quoted escapes literally and original QBE keeps two extra raw
spellings. Exact header/symbol/runtime checks remain. All three CI runners passed on
`a32fc5c` (run39777689834); scaled source `8ec0f00` also passes all three CI runners (run39778647834).
[ARM scaled loads](benchmarks/arm-scaled-load/README.md) are integrated on identity
`210a515a50b54c9b78a824349deea8e4a78cc0d0b26f9bde5f61a886f8e6b2b5`.
All three complete Linux gates, native ARM matrices/high-spill checks, units,
147 unchanged exact audit statements, exhaustive corpus delta audit and fresh
zlib/Lua/QBE/cproc campaigns pass. The complete local host gate passed; all three pinned Nix CI runners pass on
`8ec0f00`.
Zlib loses 312 text bytes per ARM target, mixed Lua 292 bytes. Timings remain
diagnostic under unrelated background load; clean performance is unresolved.
This combined Linux gate also covers preceding aliases, mutable widths and retained TLS.

[Retained writable TLS](benchmarks/retained-tls/README.md) is integrated on identity
`4b41bddbd06b27174a3729ad2eca3888525a2f6e3e31d737a1057c18d22287bc`.
Optional R now composes with awT. All three Linux C/original-QBE thread/metadata/GC
matrices, Apple refusal/equivalence, emission/CLI controls, units and 147 exact
audit statements pass. Corpus and all 432 workload assemblies remain identical.
Complete Linux/host gates are queued for the forthcoming combined checkpoint.
Scaled ARM loads are next, supported by correctness and static code-size savings;
performance samples are diagnostic under uncontrolled external background load.

[Mutable integer widths](benchmarks/mutable-integer-widths/README.md) are integrated
on identity `1902411287790994d88c0700305e3916b276da8ea01b7d57ccb26fcfea7887d9`.
All five original-QBE/C matrices, fresh units, 147 exact audit statements, existing
SSA regression and missing-tool/CLI controls pass. Corpus and all 432 workload
assemblies remain identical. Complete regression gates are pending the upcoming
combined checkpoint. Retained TLS follows in the checkpoint above; scaled ARM loads passed
two timing windows, but external background CPU activity invalidates a quiet-window
interpretation. Those timings are diagnostics only; clean performance remains
unresolved. Correctness/static savings support further bounded review.

[Exact aggregate signature aliases](benchmarks/aggregate-signature-aliases/README.md)
are integrated on identity `859f5c81657dcdb85c13513a19c5c3635e6e3ef55f600e9e2adaaa20f5e2963d`.
Five original-QBE/C matrices, all three full Linux gates, fresh units and 147 exact
audit statements pass. Corpus output and all 432 workload assemblies are identical.
Full host qualification has not yet run on this identity. The mixed-width checkpoint above follows this identity; retained TLS and scaled
ARM loads remain private until subsequent integration.

[Printable ELF section names](benchmarks/elf-section-name-bytes/README.md) are integrated
on identity `ce3e8012b7d5a57f7d37cbe435b1078bea1a3f70bbaa4f7f41764399f3c1ef92`.
Names preserve 1–128 printable ASCII bytes with explicit quote/backslash escaping.
All 15 combined matrices, three complete Linux gates, fresh units and 147 unchanged
audit statements pass. All 1,305 corpus assemblies, 15 refusals and 432 workload
assemblies remain identical. The workload bridge reuses prior exact-output runtime
qualification, including QBE self-compilation on predecessor identity5e174. Full
host/Rosetta gate also passes; aggregate signature aliases were integrated in the subsequent checkpoint above. Unqualified stale-comparison/wrong-IR-path
harness attempts are retained separately from fresh successful reruns.

[Fresh QBE bootstrap qualification](benchmarks/qbe-elf-refresh/README.md) uses historical identity `5e174e1d424aa154ed5fda916ad507a3a9dceb625b28774a2c1356dcaf0b235e`: all three Linux targets pass 487 exact comparisons and 58 ARM-output runtime tests per LCB mode. The applied helper adds isolated work, provenance barriers and a shared upstream-runner lock. All overlapping v1 attempts remain unqualified; sequential v2 and final locked v3 evidence are distinct, as are original/corrected QBE outcomes. No compiler rebuild, timing claim or Windows-support extension.

[Octal escape boundary](benchmarks/octal-escape-boundary/README.md) now records
assembler-dependent original-QBE behavior, including the accepted Linux `\378`
byte discrepancy. Reduced exact-length object/C probes replace an unqualified
mixed-fixture overread preflight. No compiler/parser change was made.

[ELF custom TLS and retained sections](benchmarks/elf-custom-sections/README.md)
are integrated on identity `5e174e1d424aa154ed5fda916ad507a3a9dceb625b28774a2c1356dcaf0b235e`.
Fresh build/units and 147 unchanged audit statements pass. Separate TLS/R matrices
pass all three Linux targets against unchanged QBE; Apple refusal/emission
behavior is preserved. Ten emission-only controls, two CLI checks, nine combined
flag-context refusals, source/snapshot/guest provenance barriers and all three
complete Linux gates and the full host/Rosetta gate pass. All 1,305
corpus assemblies, 15 refusals and 240 zlib/Lua/cproc workload assemblies remain
identical; the workload bridge reuses prior exact-output runtime qualification.

[Fresh cproc self-compilation](benchmarks/cproc-aggregate-refresh/README.md) now
passes on aggregate identity `a23afe3b…`: all three Linux targets, both LCB modes,
18 frontend units, 19 identical stage-two IR files and 196 original tests each.
Original ARM/RV QBE failures remain separate from corrected references. The
new `--work` option isolates fresh source/configuration/build directories, and
all source/binary/IR provenance barriers pass. Compile times are diagnostic only.

[Large aggregate copying](benchmarks/large-aggregate-abi/README.md) is now integrated
on identity `a23afe3b4889b9da79c50d5ddf5b7e3e4affe2ba26d1e2c5072ed14c73cbdaaa`.
Fresh build/units and all 147 unchanged proof-audit statements pass. All five
independent matrices, 30 maximum-copy executions, 45 resource refusals, five
corruption controls and all three complete Linux gates pass. Full host/Rosetta
qualification also passes. The corpus keeps 1,305 identical assemblies and 15
identical refusals; all 132 zlib/Lua workload assemblies remain identical to
previously executed output. The 1 MiB object bound does not remove frame/outgoing
area limits; original-QBE comparison stops at 65,537 bytes, larger guards use C.

[Unused scalar return captures](benchmarks/unused-call-results/README.md) are now
removed on compiler identity `77ea0aaf88b3ede106fce810658fddb41546fe2b85b78cfb9125dae6129eb1a4`.
Calls and all operands remain; live results and aggregate hidden storage remain.
Fresh units, all 147 audit statements, 10,080 independent five-target C groups,
five dropped-call controls, emission-only checks and all three full Linux gates
pass, as does the complete host/Rosetta regression gate. The original RV QBE signed
subword result discrepancy remains explicit; the reduced reference omits only
64 returned-value comparisons and retains every call/effect check. All 132
zlib/mixed-Lua workload assemblies match the privately executed candidate;
private workload identities and two failed Lua harness attempts are preserved.
Optimized ARM text drops 596 bytes for zlib and 1,596 for mixed Lua; no speed claim.

[Typed custom sections](benchmarks/section-names/README.md) now preserve the two
QBE section fields, first qualified on combined scalar/section identity `f159cc758be1a944534240d32728bb47d7f8e7f6abe77b0e2d1fd9446106b8f6`.
Bounded ELF bare/hyphen/literal-comma names and optional awx flags pass all five
target matrices (252 independent C checks each), existing linkage/ELF helpers,
five emission-only controls, fresh units and all 147 proof-audit statements.
Apple's existing unquoted names, 16-byte capacity and attributes are retained;
original QBE's literal section-name quote bytes and boundary assembler refusal
are recorded separately. The private candidate `4d77c3de…` was qualified before
the combined scalar change and is not the main qualification identity. No new
proof-path feature or Windows support is claimed; arbitrary section escapes and
assembler suffixes remain outside the bounded qualification. All three complete
Linux regression gates now pass on this combined identity. Full host/Rosetta
qualification also passes.

[LZ4 1.10.0](benchmarks/lz4/README.md) now passes native Linux ARM64 and QEMU x86/RV qualification:
all six original C units, 370 functions / 64,135 IR lines, upstream unit/fixed-seed
tests and 15 exact compression/cross-decompression profiles per backend. All three
LCB modes, GCC O0/O2, original and corrected QBE pass. RV has 364 functions /
63,137 IR lines. Its first whole-probe timeout remains explicitly unqualified;
the fresh bounded retry passes final provenance checks.
The [Lua attempt](benchmarks/lua-preflight/README.md) remains unqualified because
cproc rejects three required volatile stores before any backend invocation.
A separate [mixed Lua qualification](benchmarks/lua-mixed/README.md) now passes:
30/33 production units, 968 functions / 76,174 IR lines use LCB/QBE; three
unchanged GCC objects are shared across all mixed builds. Seven binaries pass
an independent probe and two reduced official suite profiles each. Internal
API/opcode, locale and soft/portable exclusions remain; 944 files are bound.

[Supplementary original development fixtures](benchmarks/upstream-development/README.md)
now execute unchanged `_gcm1`, `_fix3` and `_fix4` against independent arithmetic/
sieve callers on all five targets, all three LCB modes and original QBE. All
60 executions and five corruption controls pass. They remain separate from the
58 original upstream drivers; original underscore fixtures are deliberately
excluded by QBE's normal suite glob.

[Global-address placement](benchmarks/symbol-address-placement/README.md) now
introduces repeated addresses at first use in straight-line functions and caps
entry hoisting elsewhere at eight addresses. The 512-global disjoint-use stress
case drops from 515 live values / 502 spills to 4 / 0; this is not a universal
pressure bound. All five independent target matrices pass 8,320 C checks and
five corruption controls. All three Linux gates, fresh strict units, emission
checks and unchanged 147-report audit pass. Full host gate also passes (native Apple ARM, Rosetta Apple x86, emission-only
Linux wrappers). Fresh zlib replay passes; all 102 assembly pairs are unchanged.

[Indexed-load diagnostics](benchmarks/arm-indexed-load/diagnostics/README.txt)
now retain two targeted object-hybrid windows. Both reproduce the slowdown;
deflate-only is about 6.1–6.3% slower, trees-only near parity. Layout/cache controls
also shift, so this is localization evidence, not an instruction-level causal
proof. Two function-body timing windows now complete provenance checks: longest_match
alone stays near parity; the remaining deflate mixture retains slowdown. A v1
summary-script failure is retained unqualified; two fresh v2 windows are separate.
[Width-specific fallbacks](benchmarks/arm-width-fallbacks/README.md) now pass two
compression-only windows: halfword fallback gains 2.6–3.0% on mixed compression
with about a 0.3% repeated-payload cost. All width candidates remain unmerged;
these are exploratory tradeoffs, not universal policy wins.

[Scalar-result discard](benchmarks/scalar-result-discard/README.md) now accepts
effect-only calls to defined scalar-return functions, preserving effects and
rejecting aggregate-return omission. Fresh integrated five-target execution
passes 6,400 C checks and five corruptions; units/emission and the unchanged
147-report audit pass. Corpus assemblies/refusals are all unchanged. Existing
native call/indirect/variadic gates pass after correcting a stale rejection test.
The subsequent combined scalar+section identity passes all three Linux gates;
its full host gate also passes. Preceding
Symbols full gates passed. No native emitter or ABI layout was changed.

## Repository and current compiler

Work in `main` at `https://github.com/unbalancedparentheses/lean-compiler-backend`.
The current compiler source/build identity is
`60ffdd4c56bf26efa0eb8593923ccb094808ab4d91e6739d03bb360bea99c8bf`.

[ARM leaf registers](benchmarks/arm-leaf-bank/README.md) admit x16/x17/x8 only
for bounded call/TLS-free functions. Both native ARM independent ABI matrices,
full native Linux ARM gate and full host gate pass; baseline and non-ARM corpus
output stay identical. The 147-report proof audit is unchanged. Optimized zlib
text shrinks another 1,196 bytes. The retained assembly-only _chacha20 fixture
now has independent executable caller coverage on both ARM targets; it executes
one double-round, as dictated by its original counter, not the full cipher.

[Paired in-process zlib timings](benchmarks/zlib-inprocess/README.md) are committed
with 485-file provenance checks, five fresh compiler/oracle builds, exact
correctness profiles and two quiet windows. The leaf change reduces random-data
compression time about 9% and mixed-data compression about 2% on these inputs;
seven other API/payload comparisons show no demonstrated change. CRC remains
about 1.72x original QBE / 3.95x GCC time at the leaf checkpoint.
[Typed phi identities](benchmarks/arm-phi-identity/README.md) now remove redundant
same-width same-home transfers. Both native ARM matrices and full Linux ARM gate
pass; 147 proof reports stay unchanged. Zlib loses another 5,460 text bytes per ARM
target. Two new quiet timing windows show about 25% less CRC32 time relative to
leaf, though CRC remains about 1.28–1.29x QBE. [Restricted AMD leaf registers](benchmarks/amd-leaf-bank/README.md) now use r8/r9
only when calls/TLS are absent and the actual incoming ABI GP count is at most 4.
Both full x86 gates and fresh units pass; target-configured zlib shrinks 672 bytes
and its executed candidate assemblies exactly match this main identity. The
private stale-unit claim is explicitly retracted; corrected main units were
rebuilt and executed.
[ARM indexed loads](benchmarks/arm-indexed-load/README.md) now combine adjacent
sole-use address sums with loads. Both native ARM independent matrices and the
full Linux ARM gate pass; a separate 4,200-live-value fixture executes actual
33,520/33,536/33,528-byte input/result spills on both ARM targets. Zlib loses
another 584 optimized text bytes per ARM target, with six upstream examples and
72 exact streams passing. The broader full host gate now passes, including native Apple ARM and Rosetta
x86 execution. Five-label in-process correctness/provenance passes. Two initial
100 ms timing windows show CRC improvement but a possible mixed-compression
regression, with substantial first-window noise. Two longer 500 ms windows also
pass provenance; all four mixed-compression medians remain 3.6–4.6% slower (two
intervals exclude parity). CRC improves, but no general speedup claim is made.
Diagnostic object combinations will investigate the regression.
CI through bbea3aa is green; 1d23647 and 86979e1 remain in progress.

[ARM typed extuw](benchmarks/arm-extuw/README.md) omits same-home unsigned
word extensions only for declared word sources. Both native ARM matrices, full
Linux ARM gate, units and unchanged 147-report audit pass. Zlib/libyaml/LZ4
before/after executable checks pass, with 1,012/8/500 fewer optimized text bytes
per ARM target. Baseline and ordinary emission corpus are unchanged. CI through
a3778f4 is green; later runs remain pending. Leaf allocation and in-process zlib
timing are under investigation, with no speed claim yet.

[AMD64/RV64 fallthrough](benchmarks/branch-fallthrough/README.md) omits jumps to
the immediately following block after preserving phi transfers. All three full
target gates and independent C/QBE matrices pass; strict diff admits only jump
deletions. Zlib saves 4,012 AMD64 / 4,176 RV64 text bytes with GCC/Python executable
comparisons passing. CI through 7ef289c is green; newer runs are pending.

[Signed division/remainder by normalized +1](benchmarks/signed-division-one/README.md)
now becomes a width-preserving copy/zero in optimized code. All five target
matrices and original-QBE comparisons pass; zero/-1 guards and side effects
remain. The ordinary emission corpus is entirely unchanged; actual zlib/libyaml
sites shrink, with executable comparisons passing. No new proof is claimed.
The previous de27 compiler completed the full host gate successfully (Apple ARM
native, Apple x86 Rosetta, Linux wrappers emission-only); 147 audit reports remain
unchanged. CI through f38c2b1 is fully green; later checkpoints are pending.

[ARM64 empty branch layout](benchmarks/arm-branch-layout/README.md) now removes
empty conditional trampolines under a conservative expanded-assembly range bound.
Both native ARM matrices, original QBE, >1 MiB fallback, complete Linux ARM gate,
unit suite and unchanged 147-report audit pass. Optimized zlib text shrinks another
8,480 bytes per ARM target (~6.4%); executable comparisons pass, timing unmeasured.
CI through e07d3da is fully green; newer checkpoints remain pending.
The new ARM compiler also passes [libyaml driver and 402-input corpus replay](benchmarks/libyaml-branch-replay/README.md) in all three modes, against bound GCC references.

[ARM64 same-register unsigned load extensions](benchmarks/arm-load-extensions/README.md)
now avoid redundant instructions in allocated/optimized code, preserving baseline
and debug/alias/register-pressure fallbacks. Both native ARM matrices, full Linux
ARM gate, unit/proof-audit checks and before/after zlib profiles pass. Optimized
zlib text shrinks 412 bytes; runtime speed remains unmeasured.

[RV64 result normalization](benchmarks/rv-result-normalization/README.md)
removes redundant masks only from already-normalized operations. The complete
RV gate, independent integer/FP/conversion matrices, unchanged 147-report audit
and before/after zlib executable checks pass. Optimized zlib text shrinks 0.52%.
CI for e837ce3 and 991f463 is fully green; newer checkpoints remain pending.
The pinned 402-input YAML corpus also passes all three LCB modes on all three
Linux targets: [scope and original-reference distinctions](benchmarks/libyaml-corpus/README.md).

[AMD64 immediate selection](benchmarks/amd-immediates/README.md) now passes
153,900 independent C checks per mode/target and both full AMD gates. Optimized
17-unit zlib text falls another 6.28%; exact compressed-byte and decompression
comparisons pass. Original QBE shift/TLS failures remain separately qualified.
The exact 991f463 full host gate completed successfully (native Apple ARM and
Rosetta execution; Linux wrappers emission-only). Newer CI remains pending.

[Libyaml 0.2.5](benchmarks/libyaml/README.md) now qualifies all 21 original
translation units (351 functions, 70,576 IR lines) in all three LCB modes on all
three Linux targets, with 52 checks per mode against GCC O0/O2. Original QBE
ARM reader and RV link failures remain separate from corrected-reference passes.
A [fresh pointer Csmith campaign](benchmarks/csmith-pointers-overnight/README.md)
qualifies 11/64 attempts per Linux target; 50 frontend refusals and three GCC
reference timeouts are explicitly unqualified. Allocated replays pass.

AMD64 omits redundant word normalization after operations that already write EAX.
The [fresh qualification](benchmarks/amd-word-normalization/README.md) passes both
full AMD target gates and 112,672 independent C checks per mode/target. Seventeen
zlib units shrink by 5,322 text bytes (2.12%); executable stream checks pass.
No timing improvement or new formal proof is claimed. Current CI is pending;
prior 991f463 full host gate has passed independently.

Decimal integer magnitudes through UINT64_MAX now accept QBE modular negation
across operand, data, layout and debug contexts. The
[five-target qualification](benchmarks/integer-patterns/README.md) preserves
resource refusals and independently checks returned bits and packed layout.

RV64 now selects encodable arithmetic/bitwise immediates and modulo-width
immediate shifts. The [current-identity qualification](benchmarks/rv-immediates/README.md)
passes 109,440 independent C cases per mode and the full RV gate. Zlib object
text drops by 6,696 bytes (2.52%); exact stream/roundtrip checks pass, with no
runtime speedup claim. Four other targets retain byte-identical corpus assembly.
The earlier marker checkpoint full Rosetta gate also completed successfully.

Hexadecimal data-string escapes and either/repeated extern/thread annotation
order now pass [five-target independent byte/TLS checks](benchmarks/syntax-edges/README.md).
Original QBE Linux ARM/RV combined-annotation refusals and assembler escape
limitations remain separate from the passing LCB profiles.

Explicit variadic markers now survive empty anonymous tails through SSA and
optimization; AMD64 initializes AL even when only named FP arguments are present.
Unused environment bindings are removed from AMD64 variadic definition ABI views.
Used environments and explicit variadic-environment calls remain rejected there.
See [marker and C-ABI qualification](benchmarks/variadic-markers/README.md);
original QBE overflow-pointer failures are separate from successful register-only
comparisons. Existing proof-audit reports remain unchanged.

Symbol initializers now retain `b/h/w/l/s/d` storage widths and addends. The
[relocation qualification](benchmarks/data-relocations/README.md) records packed
interpreter layouts, independent native C checks and unchanged QBE comparisons
on all five targets. Linker/range refusals are retained separately; 102 of 240
link profiles execute successfully. Ordinary corpus assembly is unchanged.

Calls may omit a declared environment parameter when it is unused in retained
SSA operands. The interpreter removes the unused binding instead of inventing
an environment value. Known used-environment omissions remain errors; native
unresolved indirect/external ABI assumptions are unchanged. The
[retained suite](benchmarks/unused-environment/README.md) passes interpreter,
independent C and unchanged QBE comparisons on all five targets, with full target
gates, unchanged ordinary assembly and proof-audit results. AMD64
variadic definitions with a used environment remain a separate limitation.

The [fresh overnight Csmith batch](benchmarks/csmith-overnight/README.md) qualifies
50 of 64 new seeds per Linux target against GCC O0/O2 and unchanged QBE, with 14
reference timeouts excluded. All three modes replay those 50 programs successfully
on identity 49f1c29d…; baseline/optimized initial reference campaigns retain
the preceding 81000f96… identity. Target IR is identical within each comparison,
not across ISAs; replay counts are not new unique programs.

## Preceding RV64 load-normalization checkpoint


RV64 omits redundant normalization after zero-extending unsigned memory loads;
signed word-result loads and ordinary word-copy narrowing remain unchanged.
The [retained qualification](benchmarks/rv-load-normalization/README.md) passes
9,216 independent C bit cases per mode, two corruption controls, the complete
RV gate, 1,305 precisely expected corpus assemblies and 15 matching refusals.
Zlib's 17 units pass upstream tests, exact gzip streams and roundtrips with the
original/corrected QBE distinction preserved. Optimized object text falls by
3,572 bytes; no runtime speedup or new proof is claimed.

## Preceding argument-boundary checkpoint


Compatibility now admits 1024 typed parameters/arguments, including aggregates,
while retaining the eight-parameter certified profile and 1 MiB frame/outgoing
area bounds. Large AArch64 outgoing scalar/narrow stores use reserved x15
addressing when scaled immediates cannot encode the offset. Independent C
boundary tests cover seven signatures, all three lowering modes and five call
paths; see [argument-limit evidence](benchmarks/argument-limits/README.md).
The additional dynamic-outgoing suite passes 515-HFA calls with live runtime
allocations, TLS and direct/indirect/environment paths across all five targets.
Original QBE's narrow-call and RV aggregate-address failures are retained and
excluded explicitly from oracle profiles, never from independent LCB/C checks.

## Preceding lookup-map compilation checkpoint


SSA binding updates and all three emitters now use lookup-only hash maps.
No map enumeration determines output order; home tables preserve first-match
lookup semantics. This removes repeated linear scans on large functions while
retaining 1,305 byte-identical corpus assemblies and 15 matching refusals.
Fresh units, independent C binding/prefix cases, all three optimized Linux gates
and the unchanged large-structure GCC/original-QBE comparison pass.
See the [lookup-map evidence](benchmarks/lookup-maps/README.md) for exact
identities, paired timings and validation limits. No new proof is claimed.

## Preceding generated-prefix correctness checkpoint

The current implementation fixes generated-name selection in SSA construction,
scalar memory promotion and symbol-address hoisting. A sparse deeply underscored
name could exhaust the old bounded prefix search. In promotion this merged a
source value with a generated mutable variable and silently changed a result
from 110 to 6; in symbol hoisting it rejected a valid program as duplicate SSA.
The new shared helper scans matching names once and chooses the shortest
underscore prefix that cannot prefix any original name. Allocation order,
normal program output and certified-profile bounds are unchanged.

The [minimal retained reproduction](benchmarks/prefix-collision/sparse.ssa),
[independent C caller](benchmarks/prefix-collision/caller.c) and
[old current-compiler result](benchmarks/prefix-collision/before-current.json)
show the pre-existing wrong-code case. The generated independent regression
covers sparse local/parameter names, a second promoted object, deep names,
mutable SSA and symbol hoisting; it is integrated into the host and target gates.
[Current-identity validation](benchmarks/prefix-collision/validation.json) passes
fresh build/units, 2,560 independent C cases per mode on all five targets, and the
three complete optimized Linux gates. Apple ARM/Linux ARM are native; Apple x86
uses Rosetta and Linux x86/RV use QEMU. Original-QBE prefix comparisons pass on
the two Apple targets. The ordinary corpus retains 1,305 byte-identical assemblies
and 15 matching refusals; the known old collision cases intentionally change.
No new preservation theorem is claimed.

## Preceding CSE profitability checkpoint

The [unchanged large-structure program](benchmarks/large-struct-cse-profit.json)
passes GCC O0/O2, unchanged QBE and all three LCB modes with checksum
`b424c67700bbdde0`. Optimized ARM64 executable text falls from 756,699 to 396,415
bytes. The [native phase probe](benchmarks/large-function-profile/cse-phases-report.json)
uses the same probe source and exact current CLI objects; the common-expression
phase now keeps maximum liveness at 6 instead of increasing it to 8,197. Its
[object manifest](benchmarks/large-function-profile/cse-native-objects.json) is
retained. A new unit regression checks a repeated-expression workload's liveness
bound and results against independently calculated UInt64 values.

[Zlib](benchmarks/zlib-cse-profit-arm.json) passes 17 unchanged translation units,
12 exact gzip streams, independent decompression/roundtrips and upstream tests.
Optimized text is 128,854 bytes versus the corrected QBE oracle's 119,110 bytes.
Original and corrected QBE distinctions remain in the report. Concurrent-load
large-structure emission was 75.768 seconds optimized; no whole-compile speedup
is claimed. Promotion was expensive in that checkpoint; the current lookup-map change
addresses its repeated binding scans. The same zlib workload also passes x86/RV QEMU
checks; optimized text increases slightly there (242,571 / 261,360 bytes versus
240,395 / 258,460 before). This heuristic is not a universal code-size win.

The [fresh cJSON comparison](benchmarks/cjson-cse-profit.json) passes 153 assertions
across 18 executables with the existing baseline-only 64 MiB recursion-stack
retry. Optimized text is 34,156 bytes versus unchanged QBE's 26,220; five native
Linux ARM64 samples give median runtime 0.2589 s optimized, 0.2189 s QBE and
0.1773 s GCC, all with checksum `342141b63f079083`. These are local measurements,
not a general performance/parity claim.

The initial CSE regression source used equality on `Except`, which failed a
clean test build; the earlier unit executable was stale. The test now unwraps
the result explicitly, `lake build lcb-tests` and the freshly rebuilt unit suite
pass, and the compiler executable hash is unchanged. Runtime/benchmark evidence
is unaffected. A separately discovered pre-existing sparse generated-name
collision can change optimized output (baseline/QBE 110 versus optimized 6);
the correction and dedicated regression are described above.

## Debug records and instruction budgets

Debug directives no longer consume the instruction/phi allowance. Previously,
70,000 copies with one `dbgloc` each failed halfway through parsing, although
original QBE admitted the unchanged input. Parsing now has a separate token-based
iteration bound and explicitly checks the instruction/phi count. New boundary
cases cover 70,000 copies with debug records, 70,001 rejection, phi accounting,
trailing debug records and implicit fallthrough; phi-after-debug stays rejected.
[Native validation](benchmarks/debug-boundary-native.json) confirms that both
LCB and original QBE preserve all 70,000 `.loc` directives, retain the final line
in object DWARF and run successfully. Both yield an empty linked dSYM without
a debug compile unit; this does not establish a LCB-specific dSYM regression.
The normal fixture corpus still emits 1,305 byte-identical assemblies and retains
15 identical refusals. The complete local regression gate and proof audit pass.
This does not change the certified profile.

The [previous large-structure comparison](benchmarks/large-struct-65537-timed.json)
retains compiler, harness and original-QBE hashes and separates compile/link,
IR emission and execution timings. The unchanged 65,537-byte structure workload
passes GCC O0/O2, original QBE and all LCB modes. On this single concurrent run,
ARM64 emission took 9.941 s baseline, 10.856 s allocated, 60.770 s optimized and
2.452 s original QBE. Optimized compilation is still substantially slower;
execution timings include Docker launch overhead and are too short for a runtime
performance conclusion.

[Additional original-QBE cross-checks](benchmarks/large-struct-65537-cross-original-qbe.json)
match the same checksum on x86 with default linking and RV64 with explicit
`-no-pie`. Original RV64's default-link relocation failure is retained separately;
all LCB cross-target runs use default linking. These checks use unchanged QBE,
not the corrected oracle.

## Previous native profile motivating this work

The [native structural probe](benchmarks/large-function-profile/structural-summary.json)
and [phase probe](benchmarks/large-function-profile/phases-report.json) reuse the
then-current CLI's exact object files; source probes, object manifest and logs are
retained alongside the reports. The reports below precede the CSE profitability change.
For the unchanged large structure function, maximum live values grow from 8
before optimization to 8,197 afterward, requiring 8,197 colors / 8,187 spill homes
with ten ARM64 registers. The `main` function grows only from 9 to 14 live values.

The phase composition `Common.eliminate(Optimize.function f)` raises the live set
from 6 to 8,197; later forwarding, extension and dead-definition passes retain
that pressure. Separately, `Memory.promote` took 18.822 seconds in the phase probe
while reducing maximum live values from 8 to 7. The CSE checkpoint above addresses the measured pressure increase. Next work
will integrate the isolated promotion-pass cost fix,
with the unchanged program/checksum and independent allocation checks retained.
These are single native-probe observations under concurrent load, not a new
compiler speedup claim. The interpreted probe timed out and the first native
attempt linked a stale package archive; both are explicitly excluded. Native
reproduction must use the current `lcb.rsp` object list excluding `Main`, not that
archive. Existing full-pipeline proof limitations remain unchanged.

## Compiler scaling without emission changes

Interference construction retains only lower-index neighbors consumed by greedy
coloring; independent allocation/home-flow checks remain unchanged. All three
emitters buffer chunks and flatten once, avoiding repeated growing-list copies.
The retained [equivalence report](benchmarks/scaling-emission-equivalence.json)
compares 88 inputs across five targets and three modes: 1,305 byte-identical
assemblies and 15 identical refusals. This is output-equivalence evidence, not
an end-to-end proof. The complete local regression gate and proof audit pass.
Admission bounds are unchanged in this checkpoint.

### Isolated large-function scaling measurements

Two detached variants of base `c970d9c`, both with the proposed 70,000/600,000
bounds, isolate the graph/buffering changes. These are single host compilation
observations, not runtime speedups or a general benchmark. The reports bind each
variant to its own compiler identity and input hash:
[before](benchmarks/scaling-cap-original.json),
[after](benchmarks/scaling-cap-buffer.json).

| Unchanged input / emission mode | Before | Graph + chunk buffer |
| --- | ---: | ---: |
| 65,537-byte structure / baseline | 69.823 s | 9.308 s |
| Structure / allocated | 19.513 s | 9.728 s |
| Structure / optimized | timeout at 180 s | 60.757 s |
| Csmith 20265033 / optimized | 11.885 s | 4.078 s |

The three completed before/after assemblies are byte-identical; the optimized
structure assembly is identical to the intermediate graph-only variant, since
the original optimized run timed out. All completed binaries match independent
checksums. Peak optimized structure RSS after both changes was 434,667,520 bytes;
the original timed-out run has no comparable peak-RSS measurement. Large dense
allocation remains costly and is a follow-up opportunity.

## AMD64 adjacent memory offsets

AMD64 also folds adjacent sole-use constant address calculations into signed32
load/store displacements, preserving original allocation, word normalization,
FP bits, TLS scratch values and debug locations. Linux x86/QEMU and macOS
x86/Rosetta suites pass 14,944 independent memory cases per mode, signed32 endpoint
and just-outside fallback tests, spill/shared/phi exclusions and wrong-offset
corruption. Native Apple ARM64 runs the same expanded byte-level oracle. The
full local gate passed in `.build/amd-adjacent-full-check.log`.

`zlib-amd-adjacent.json` retains all qualified upstream/12-stream checks;
optimized text is 240,395 bytes, 15,763 below the preceding x86 branch result.
`qbe-amd-adjacent.json` retains 455 fixture/32 self-IR reproductions and 58 original
ARM64 runtime tests; optimized object text is 596,476 bytes (35,685 fewer), linked
text 618,329. Original QBE's x86 self-compilation mismatch remains separately
unqualified, with the corrected oracle passing.

At the preceding identity, x86 Csmith seeds 20265032–20265063 yielded 23 common
matches, eight GCC O0 timeouts and one 16,384-instruction admission refusal
(seed 20265033). Historical reports `csmith-amd-adjacent-refusal.json` and
`csmith-amd-adjacent-rest.json` retain that failure. After the resource increase,
[the same complete 32-seed batch](benchmarks/csmith-amd-cap-32.json) yields 24
common matches / 268,328 IR lines, eight reference timeouts and no LCB failures.
The previously refused 43,227-line program now matches GCC O0/O2 and unchanged
original QBE with checksum `534A8C01` in baseline and optimized LCB modes. The corrupted-return
control is detected. Replayed seeds are not new independent random samples.
A separate [fresh x86 batch](benchmarks/csmith-x86-cap-fresh-32.json), seeds
20267000–20267031, qualifies 24 common cases / 238,899 IR lines against GCC O0/O2 and
unchanged QBE, with baseline and optimized LCB matching. Eight GCC reference
timeouts remain excluded; the corrupted-return control is detected. No new
proof scope. The [native ARM replay](benchmarks/csmith-arm-cap-fresh-32.json)
qualifies the same 24 cases / 238,899 IR lines. The
[RV64 replay](benchmarks/csmith-rv-cap-fresh-32.json) qualifies all 24 with LCB
against GCC, but only 23 / 217,379 IR lines with original QBE. Seed 20267003
(21,520 IR lines) makes unchanged QBE abort in `rv64/isel.c:fixarg`; LCB baseline
and optimized match GCC checksum `1EAFAEB2`. This is separately recorded as
LCB-only qualified, not a QBE match. Eight GCC timeouts remain excluded on each
ISA, and cross-target replays do not add new unique seeds. All 32 C sources
match across targets after excluding the generator's output-path comment.
Target-configured cproc IR is not byte-identical across ISAs: the CRC helper's
plain-char load is signed on x86 and unsigned on ARM/RV. Within each target,
LCB and original QBE consume the same unchanged IR. RV64's original-QBE
link profile is explicitly `-no-pie`; LCB keeps default linking.

## RV64 adjacent memory offsets and cross-target generated C

RV64 fuses adjacent sole-use long address adds/subtracts into signed12 memory
operands. It retains baseline lowering, original homes/lifetimes, word-result
normalization, FP raw bits, TLS scratch preservation and memory debug locations.
The expanded address matrix passes 14,688 independent byte-level cases per mode,
including -2048/2047 boundaries, rejected offsets, spills and wrong-offset
corruption. Branch coverage now includes word comparisons of long operands with
differing high halves (178,360 cases per mode). Linux ARM/x86/RV execution suites
pass with actual mode counts. The full local gate passed in
`.build/rv-adjacent-full-check.log`, including native Apple ARM64 and macOS x86
Rosetta execution of the expanded matrices.

`zlib-rv-adjacent.json` retains all qualified upstream tests/12 gzip streams;
optimized linked text is 258,460 bytes, 7,856 fewer than the RV64 branch checkpoint.
`qbe-rv-adjacent.json` retains 455 exact fixture and 32 self-IR assemblies plus
58 original ARM64 runtime tests. Optimized object text is 653,424 bytes (17,600
fewer) and linked text 678,027 bytes. Original RV64 QBE link failures remain
separate from the corrected oracle; RV64 execution is QEMU.

The Csmith runner now accepts Linux ARM64/x86/RV targets, private cross-target
cproc configurations and retained failure reports. `csmith-rv-no-pie.json` tries
fresh seeds 20265000–20265031: 28 common matches / 261,621 IR lines, with four
GCC O0 timeouts excluded. Only original QBE uses explicitly requested `-no-pie`;
LCB retains default linking. `csmith-rv-default.json` separately retains default
link failures for the first four seeds while both LCB modes match GCC (44,540
IR lines). The same first four seeds qualify unchanged QBE and LCB on Linux
ARM64 and x86, recorded in `csmith-cross-arm64.json`/`csmith-cross-x86.json`.
These cross-target/link-profile reruns do not multiply unique seed totals or join
the earlier default native-ARM batches. Every executable campaign detects changed
returns. Injected backend failure persists its seed/traceback; an all-timeout
campaign records `no_qualified`/`not_run` and exits nonzero.
A separate pointer-generation profile, seeds 20266000–20266015, qualifies only
two small programs / 5,131 IR lines (including runtime helpers); 13 cproc pointer
diagnostics and one GCC timeout remain excluded in `csmith-rv-pointers.json`.
This is limited pointer evidence, not broad pointer-program coverage. Proof scope
is unchanged.

## RV64 comparison branches

RV64 also selects final sole-use integer comparisons directly into inverse
conditional branches. Signed word comparisons preserve zero normalization followed
by scratch-register sign extension; phi-edge effects occur only after the branch.
Baseline lowering is unchanged. Independent review found no defect. The Linux
RV64/QEMU suite passes 176,400 independent cases per mode, all ten predicates,
width/constant boundaries, live/shared/phi/spilled operands and an inverted-branch
negative control, with actual lowering-mode counts. Raw cross-target seeds
20263000–20263031 pass all LCB modes, Python/interpreter and unchanged QBE
(256 functions / 3,328 inputs); this is a rerun of existing seeds on the RV64
selection identity, not 32 additional unique seeds. A disjoint fresh campaign
20264000–20264031 also passes all paths and its corruption control (another
256 functions / 3,328 inputs), retained in `cross-fuzz-rv-branch-fresh-32.json`.

`zlib-rv-branch.json` retains upstream static tests and 12 exact gzip streams
per qualified backend. Optimized linked text falls from 288,552 to 266,316 bytes
(22,236 fewer) against the preceding RV64 extension measurement with identical
source. `qbe-rv-branch.json` qualifies 455 exact fixture assemblies across six
output targets, 32 self-IR assemblies and 58 original ARM64 runtime tests;
optimized object text is 671,024 bytes and linked text 695,623 bytes. Original
RV64 QBE link failures remain unqualified and separate from the corrected oracle.
Execution is QEMU for the RV64 programs, not native RV64 hardware. Proof scope
is unchanged. The complete local gate passed in
`.build/rv-branch-full-check.log`.

## AMD64 comparison branches

AMD64 now uses final sole-use integer comparison flags directly, matching the
ARM64 selection boundary. Existing width-specific scratch loads remain intact;
shared/phi uses, earlier comparisons and floating comparisons retain explicit
booleans. The common `Selection` queries are exact extractions of ARM64 logic.
Independent review found no correctness defect. Both Linux x86 QEMU and macOS
x86 Rosetta suites pass 176,400 C cases per mode and detect an inverted branch;
all five target suites pass with distinct lowering-mode counts. The full local
regression gate passed in `.build/amd-branch-full-check.log`.

`zlib-amd-branch.json` retains upstream static tests and 12 exact gzip streams
for all qualified x86 backends. LCB linked text is 256,158 bytes, down 16,145
from the preceding extension checkpoint's identical-source x86 measurement.
`qbe-amd-branch.json` also qualifies the x86-hosted compiler: 455 exact fixture
assemblies across six output targets, 32 self-IR assemblies and 58 original
ARM64 runtime cases. Original x86 QBE's self-compilation assembly mismatch
(`arm64_apple` / `abi8.ssa`) is retained separately; the corrected oracle passes.
This is a code-size result; execution remains QEMU, not native x86 hardware.
Fresh native fuzz seeds 20261493–20261524 pass (256 functions / 3,328 inputs).
New raw cross-target fuzzing covers seeds 20263000–20263031: all 32 qualify
against Python/interpreter in every LCB mode on Linux ARM64/x86/RV. Unchanged
QBE qualifies all 32 ARM64/RV seeds and one x86 seed; 31 x86 assembler failures
from oversized immediate shifts remain excluded and documented separately.
Reports `cross-fuzz-{arm64,x86,rv64}-raw.json` preserve both denominators and
negative controls. The separate explicit-shift-mask profile preserves the Python
oracle and sends identical masked IR to every backend. On the same AMD64
checkpoint identity it qualifies all 32 x86 seeds (256 functions / 3,328 inputs)
against unchanged QBE, plus two-seed ARM64/RV64 sanity checks. Reports
`cross-fuzz-{x86,arm64,rv64}-masked.json` retain raw/transformed hashes and mask
counts. These are additional profiles of existing seeds, not new unique seeds;
they do not erase the raw reference failures. Proof scope is unchanged.

## Redundant extending-load extensions

Matching same-width unary extensions of integer extending-load SSA values now
become copies. Loads and intervening stores/calls stay intact. Cross-width,
mismatched, plain-load, mixed-phi and floating cases remain explicit. Independent
review found no semantic defect. Lean structural/evaluation units and 60,480
independent C cases per mode pass; all corrected target suites pass with actual
mode counts. Fresh fuzz seeds 20261461–20261492 pass, 256 functions / 3,328 inputs.
The complete local gate passed in `.build/extensions-full-check.log`.
A separate native campaign, `fuzz-extensions-256.json`, qualifies seeds
20262000–20262255: 2,048 functions / 26,624 inputs against independent Python,
the interpreter, baseline/optimized native LCB and unchanged QBE, including a
caught corrupted return. Its private compiler is the extension checkpoint
identity `004162d26e502368fbb845947b6fd48fc089bc36c55b0b0b1da61b52a35fd496`,
not a later branch-selection build. Reported provenance limitations are explicit.

Identity-bound `zlib-extensions.json`, `zlib-extensions-x86.json` and
`zlib-extensions-rv.json` retain upstream static tests and 12 exact gzip streams
on native Linux ARM64 and QEMU x86/RV. Original RV64 QBE's link failure remains
unqualified; the isolated corrected oracle is reported separately. ARM64 zlib
text is 135,770 bytes, 1,868 below the branch-selection checkpoint.
`qbe-extensions.json` retains all qualified reproductions and 58 original runtime
cases, with object text 367,156 (1,908 fewer) and linked text 396,048 bytes.
`cproc-extensions.json` reproduces 19 stage-two IR files and passes 196/196
original tests; original QBE's attr crash remains separate.
`cjson-extensions.json` retains the 153 upstream assertions, 18 test executables
and checksum `342141b63f079083`; only the baseline needs the existing deep-stack
retry. Timings are local
measurements, and proof scope is unchanged.
`csmith-extensions.json` qualifies 26/32 new seeds 20261325–20261356,
196,320 IR lines; six reference timeouts remain excluded. Twelve disjoint
default-profile batches total 272/336 attempts, 2,469,958 qualified IR
lines and 64 reference timeouts.

## Final integer comparison branches

Allocated ARM64 emits a conditional branch directly from a final integer
comparison when its boolean result has exactly one whole-function use in that
terminator. Shared/phi uses, earlier comparisons and floating comparisons retain
materialized booleans. Independent review found no concrete defect. The C matrix
passes 176,400 cases per mode on Apple ARM64 and catches an inverted branch;
32 fresh fuzz seeds 20261429–20261460 pass, 256 functions / 3,328 inputs.
Zlib's original tests and 12 exact streams pass; linked text is 137,638 bytes,
4,764 below the earlier adjacent-address checkpoint. QBE bootstrap retains all
qualified fixture/self-IR reproductions and original runtime cases; object text
is 369,064 bytes (12,052 below the adjacent-address checkpoint), linked text
397,956 bytes. Identity-bound `zlib-branch-selection.json`,
`qbe-branch-selection.json` and `csmith-branch-selection.json` preserve results.
Csmith seeds 20261293–20261324 qualify 27/32, 225,632 IR lines, with five
reference timeouts excluded. Eleven disjoint default-profile batches total
246/304 attempts, 2,273,638 qualified IR lines and 58 reference timeouts. No proof
coverage is enlarged. The full local regression gate passed in `.build/branch-selection-full-check.log`.
The optimized target suites passed; corrected mode coverage is recorded below.

The target runners' global optimization flag was found to override individual
helper mode requests. Earlier optimized target invocations therefore did not
independently distinguish helper baseline/allocated modes; standalone/default
runs were unaffected. The runner correction preserves each matrix's explicit
mode while retaining optimized upstream fixtures and single-mode ABI helpers.
Actual compiler commands are counted by mode and each target suite requires
nonzero baseline, allocated and optimized counts. Guard-page copy tests add
27 sizes and 162 start/end boundary cases per mode; deliberately widening a
one-byte tail read faults as required. They passed native Apple/Linux ARM64,
Linux x86/RV QEMU and macOS x86 Rosetta with explicitly distinct mode flags.

## Active window: conservative memory forwarding

The optional optimizer now reuses exact loads and matching just-stored values
within a single SSA block. All stores invalidate previous facts, and calls,
variadic state, blits and allocations clear both load and store facts. No pointer
disjointness, cross-block memory facts or dead-store elimination is assumed.
The new C oracle passes 95,232 cases per mode across all five targets and detects
a deleted store. Lean units pass, as do 32 fresh fuzz seeds 20261365–20261396
(256 functions / 3,328 inputs). Full local gate completed successfully in `.build/memory-forward-full-check.log`.
The inventory gate additionally passes after synchronizing its source manifest. Independent review found
no concrete bug and requested additional stored-fact/variadic barrier coverage.

New identity-bound reports: `zlib-memory-forward.json`, `qbe-memory-forward.json`,
`cproc-memory-forward.json`, `cjson-memory-forward.json` and
`csmith-memory-forward.json`. Zlib retains upstream tests and 12 exact gzip streams;
QBE retains all qualified assembly reproductions and 58 original runtime tests;
cproc reproduces 19 stage-two IR files and passes 196/196 tests; cJSON retains 153
assertions and only the baseline deep-stack retry. QBE object text falls 5,752
bytes to 390,092; zlib linked text falls 696 bytes to 146,734. Timings remain local
measurements under concurrent test load, not controlled speedup claims.
Csmith seeds 20261229–20261260 qualify 29/32, 220,985 IR lines; three reference
timeouts remain unqualified. Nine disjoint scalar-profile batches total 195/240
attempts, 1,854,065 qualified IR lines and 45 reference timeouts. The restricted
pointer profile remains separate. Previous reports below retain older identities.

ARM64 adjacent constant-offset load/store selection is now committed in `b5886af`;
`df1f34d` adds current-identity Csmith evidence. The full local gate passed in
`.build/address-selection-full-check.log`, and 32 seeds 20261397–20261428 passed
(256 functions / 3,328 inputs). `zlib-address-selection.json` retains all original
checks with linked text 142,402 bytes; `qbe-address-selection.json` retains all
qualified checks with object text 381,116 and linked text 410,012 bytes. The latest
Csmith batch qualifies 24/32, 193,941 IR lines; eight reference timeouts are excluded.
Ten disjoint scalar batches total 219/272 attempts, 2,048,006 qualified IR lines
and 53 reference timeouts. Pointer-profile results remain separate.
Independent review found no codegen defect and requested more address-selection
pressure/FP-store/phi-use tests; those are being added before the next implementation.
Constant blits now accept 0..1 MiB (previously 4096), with compact eight-byte
copy loops above 128 bytes on ARM64, AMD64 and RV64. Zero-sized RV64 copies
also avoid resolving unused symbols. The independent matrix covers 22 sizes,
264 aligned/unaligned, disjoint/identical full-byte cases per mode, repeated loops,
retained pointer values and unresolved zero-copy symbols. Original QBE's routine
matrix stops at 65537 bytes; the separate native comparison includes all 1 MiB
cases with unchanged QBE. RV64 original QBE needs an explicitly logged non-PIE
link retry; LCB remains tested with the default link configuration.
The full local gate passed before the aligned-pair coverage correction; the final
matrix passed natively and on all five target suites. Independent emitter review
found no correctness defect. Aggregate-call and interpreter memory limits are
unchanged, and these loops are not formally proved.

Identity-bound reports `large-blit-compact.json`, `large-struct-8193.json` and
`large-struct-65537-refusal.json` preserve the exact qualification boundaries.
The complete direct-copy matrix produces 15,082 optimized assembly bytes versus
56,693,708 from original QBE's expansion; this deliberately large-copy workload
is a code-size observation, not a general performance claim.

The generated 8193-byte C structure assignment workload passes both GCC levels,
original QBE and all three LCB modes with checksum `154a4b0ba4aa02e0`. Pinned
cproc expands these assignments into scalar loads/stores, so this is separate
from direct blit qualification. The unchanged 65537-byte workload now passes GCC O0/O2, original QBE and all
three LCB modes with checksum `b424c67700bbdde0`; see
[the initial cap qualification](benchmarks/large-struct-65537-qualified.json).
The same unchanged IR also executes correctly in all three modes under
[RV64/QEMU](benchmarks/large-struct-65537-rv.json) and
[x86/QEMU](benchmarks/large-struct-65537-x86.json). These cross-target runs use
the native GCC reference checksum; they do not rerun original QBE for those ISAs.
Its 98,622-line IR has 566,849 tokens and functions with 65,607/32,934 instructions.
The old `large-struct-65537-refusal.json` preserves the previous admission failure.
Compatibility now admits 70,000 instructions/phis per function and 600,000 module
tokens. Exact boundary tests cover single-block parser limits, two-block total
function limits and module token limits, retaining earlier 16K/4096-block and
mutable-SSA cases. The full local regression gate and proof audit pass; the
resource increase also preserves 1,305 fixture assemblies and 15 expected
refusals byte-for-byte. Certified 480-definition/64-block limits remain unchanged.
Dense liveness, mutable SSA and other independent limits still constrain inputs;
this is not a guarantee that every program within these two bounds is cheap.
No Windows implementation or new proof was added.

## Changes in the preceding window

- Integer identities and power-of-two multiplication become width-correct copies
  and shifts. Narrow entry-stack promotion handles initialized byte/halfword
  objects, explicit store truncation and load signedness.
- Unsigned division/remainder by a nonzero power of two becomes a logical
  shift/mask; normalized-zero divisors and signed operations retain their handling.
- ARM64 stationary phi homes avoid staging. Acyclic register transfers are
  scheduled without overwriting pending inputs; cycles and stack/symbol moves
  retain simultaneous staging. Fall-through jumps are omitted.
- Existing allocation color groups are ranked by static read/write counts before
  assigning the callee-saved register bank. Bounded natural-loop weights now
  prefer loop accesses, saturate at three nesting levels and retain uniform
  weights above 512 blocks. Independent interference/home-flow
  checks run on the final assignment. This substantially reduced zlib spilling.
- ARM64 logical immediates handle repeated rotated masks, with independent
  exhaustive encoding and native execution checks.
- Repeated addresses of module-defined, non-TLS data can share an entry
  definition. External/TLS resolution stays in place, and memory contents are
  never cached. Calls may mutate referenced globals normally.
- Compatibility CLI default target now follows the compiler host on all five
  implemented configurations. First-path output remains Apple ARM64. Old
  architecture-specific refusal tests now request their intended target explicitly.
- Previous large-data/BSS, multiline-string, multi-module CLI and independent
  original-QBE discrepancy regressions remain in place.

These optional compatibility optimizations have execution evidence, not new
preservation proofs. No Windows target or end-to-end certification was added.

## Validation and larger workloads

All five targets retain 75/76 upstream fixture admission: 58 executable drivers
and 17 assembly-only fixtures. `dark.ssa` intentionally omits a required argument.
Linux ARM64 runs natively; local Linux x86/RV and macOS x86 runs use QEMU/Rosetta.
Linux x86 and ARM also have native CI. This is bounded coverage, not a parity percentage.

Latest target suites pass with common-address checks: 8,192 independent cases
per lowering mode, including calls that mutate globals, narrowing/phi uses,
loops and name collisions. The ARM64 wrong-address control must fail. Full
integer/FP/conversion matrices retain 30,460 / 896 / 1,228 cases per lowering mode.
The immediate matrix now covers 3,106 functions / 24,848 cases per mode. The
logical-encoding unit oracle checks 190,980 cases, including all 1,302 word and
5,334 long encodings. Phi tests cover 79 permutations / 5,372 cases per mode;
narrow-promotion tests cover 16,896 loop cases plus 1,024 scalar cases.

The full gate passed after allocation ranking and host-native CLI changes
(`.build/ranked-full-check.log`, `.build/host-default-full-check.log`). The common-address full run passed
(`.build/symbol-hoist-full-check.log`). The loop-weight full run also passes
(`.build/loop-priority-full-check.log`). Current unsigned-strength full validation
completed successfully in `.build/unsigned-final-full-check.log`, including the
proof audit, native Apple ARM64 and Rosetta suites and final differential fuzz. All five target suites pass, including 216 unsigned division/
remainder functions and 2,592 independent cases per mode. Fresh differential
fuzz seeds 20261333–20261364 pass: 256 functions / 2,048 input cases. The earlier
`.build/unsigned-strength-full-check.log` was stopped during a size investigation
and is not a completed gate. The rebuilt final executable is byte-identical
to the independently qualified all-target/32-seed candidate (SHA-256
`5723d0ed232061cab4155dcaa120c1c729efb7f72a21b02404033236692fd7f4`).
Existing proof audits remain unchanged in scope.

Latest published reports in `docs/benchmarks`:

- `zlib-unsigned-strength.json` and `qbe-unsigned-strength.json` qualify their preceding
  identity with all original tests and exact stream/assembly reproductions.
  zlib text remains 147,430 bytes. QBE input-object text falls 448 bytes to 395,844;
  default-linked text is 432,940 because the default Cortex-A53 erratum workaround
  adds more layout-dependent overhead. `qbe-link-size-diagnostic.json` isolates
  that effect with hash-bound objects and diagnostic relinks. Production flags
  remain unchanged; disabling the workaround is not a qualification or recommendation.

- Loop-weight reports `zlib-loop-priority.json`, `cjson-loop-priority.json` and
  `qbe-loop-priority.json` retain every qualified test below on that
  loop-weight compiler. zlib text grows slightly to 147,430 bytes; median round trip is
  9.37 ms versus original QBE 7.88 ms. cJSON text is 37,916 bytes, runtime
  0.2104 s versus QBE 0.1686 s. Compiled QBE text is 425,188 bytes, self-IR
  runtime 0.1856 s versus corrected QBE 0.1612 s. These local samples show a
  speed/size tradeoff, not controlled cross-workload performance parity.

The preceding identity-bound reports retain their own measurements:

- `zlib-symbol-hoist.json`: 17 unchanged C units / 271 functions, original static
  tests and 12 byte-exact gzip streams plus independent decompression/round trips.
  Native optimized text is 145,190 bytes. Same-run round-trip medians: optimized
  10.27 ms, original QBE 8.01 ms, corrected QBE 8.15 ms, baseline 68.92 ms and
  GCC 3.91 ms. Earlier text was 206,102 bytes / about 32 ms in the algebra report;
  cross-run timings are not controlled speedup claims. Optimization parity remains
  incomplete. `zlib-ranked-x86.json` and `zlib-ranked-rv.json` retain successful
  QEMU qualification and the original RV64 QBE link failure separately.
- `qbe-symbol-hoist.json`: 32 unchanged C units / 725 functions. Qualified builds
  reproduce 455 fixture assemblies across six QBE targets and 32 self-IR assemblies,
  one matching rejection, and 58 original tests generating native ARM64 output.
  Optimized text 420,484 bytes; median self-IR compile 0.1934 s versus corrected-QBE
  0.1672 s and GCC reference 0.0996 s. Original ARM64 QBE's parser failure remains
  unqualified. Compiled QBE emitting Windows assembly does not add Windows to LCB.
- `cjson-symbol-hoist.json`: 153 assertions across 18 executables, matching
  checksums; baseline alone needs a 64 MiB deep-recursion stack retry. Optimized
  library text 37,876 bytes; median 0.2267 s versus QBE 0.1798 s and GCC 0.1462 s.
- `cproc-symbol-hoist.json`: 18 C units, 19 exact IR reproductions, 196 original
  tests per qualified backend on the address-sharing identity. Original QBE-built cproc
  crashes on `attr`; that failure remains separate from the corrected oracle.
- `csmith-unsigned-strength.json` adds 25/32 qualified programs and 210,295 IR lines
  on the current compiler: aggregate 166/208 unique attempts, 1,633,080 qualified
  IR lines including runtime helpers, 42 reference timeouts across eight disjoint
  default-profile batches. Generator restrictions exclude pointers, packed structs,
  bitfields and volatile accesses because of frontend limits; this is not
  unrestricted whole-C coverage.

The separate `csmith-pointers.json` profile enables one-level pointers without
const qualifiers: 8/32 attempts qualify, with 49,596 IR lines. Twenty-one known
frontend pointer-type rejections and three reference timeouts remain unqualified;
these are separate from the default-profile corpus and not backend pass claims.

Reports retain their exact compiler/source/configuration hashes. Original QBE
and separately corrected oracle copies remain distinct; vendored QBE is unchanged.
See [benchmarks/README.md](benchmarks/README.md) and
[UPSTREAM_DISCREPANCIES.md](UPSTREAM_DISCREPANCIES.md).

Historical CI notes: CI was green through the previous `2532f6d` checkpoint (run `39711219361`),
including the Linux ARM64, Linux x86-64 and macOS jobs. The CSE profitability
checkpoint passes units, proof audit, the three optimized Linux gates and a fresh
64-seed native differential fuzz campaign (512 functions / 4,608 input cases,
including a detected corruption control). Its complete host regression gate subsequently finished successfully. CI for
the corrected test checkpoint `b1164ec` (run `39716100341`) is fully green on Linux ARM64, Linux x86-64 and macOS. The prefix-fix CI was not yet known at that historical checkpoint; current combined-source CI is green as recorded above.
No proof scope is expanded.

## Next work

1. Use measured workloads to guide broader memory/CFG transformations and
   allocation improvements: caller-saved/FP banks,
   live-range splitting/coalescing. Current bounded loop-weight ranking remains a heuristic.
2. Close remaining syntax/linkage/resource/ABI boundary cases on the five existing
   Linux/macOS targets. Windows AMD64 is deferred. Host-native default-driver
   behavior is now implemented.
3. Obtain native RV64 and Intel macOS qualification; local evidence is emulated.
4. Keep the [roadmap](../ROADMAP.md) full-port-first ordering. Existing proofs cover
   restricted source/machine semantics, primitive ALU selection and first-path
   helpers/body steps. The new optimization passes, actual machine instruction
   effects, ABI and complete compatibility pipeline lack an end-to-end proof.
   Source/home checkers and execution tests do not establish that proof.

## Environment and continuation safety

The host is Apple ARM64, Lean 4.34.1. Linux tests use `lcb-parity-linux` with
`.build/linux-arm64` mounted at `/work`; it has native ARM64 GCC, x86/RV cross
compilers, QEMU and Csmith. Keep shared-file hash barriers for host-authored
source/assembly and guest-produced IR to avoid stale Docker Desktop reads.

Benchmark/target scripts snapshot the compiler. Do not rebuild while an older
nonsnapshot integration script uses `.lake/build/bin/lcb`, and do not edit tests
partway through a full run. Do not concurrently configure/build the same cproc
working directory. zlib's target directories are isolated; its configure-generated
Makefile/zconf.h live in a copy of the pristine pinned source. QBE's original
runner uses fixed temporary names: run its bootstrap target jobs sequentially.
Other user projects may compile concurrently; do not stop their processes.
