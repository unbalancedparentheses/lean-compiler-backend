# Explicit variadic-call markers

Compiler `57fc5bc6422b27e130dec860ce564e399dbda062f4b48041c7fb4b0b8e1b6577`
retains `...` independently of anonymous arguments. Previously an empty tail
lost its marker; AMD64 could omit the required AL FP-register count. Call
reconstruction through SSA and optimization now preserves the marker, including
effect-only calls. AMD64 also admits variadic definitions with unused environment
parameters by removing only that binding from its native ABI view. Used
environments and explicit variadic-environment calls remain rejected on AMD64.

Independent assembly probes read AL for zero arguments and named-FP counts
0/1/8/9 through direct/indirect and value/void calls: 20 calls per lowering mode.
Deleting the marker is detected. Twelve LCB environment/empty-marker refusals
are checked per target. The separate variadic suite covers seven GP/FP boundary
signatures, 126 interpreter cases and 315 independent C calls per LCB mode.
Corrupted return values are detected. Linux x86 execution uses QEMU and Apple
x86 uses Rosetta locally.

Unchanged QBE passes the AL probes and the register-only variadic-environment
signature (45 calls), but fails the full seven-signature input. Its AMD64
`argsclass` environment flag occupies bit 12; `selpar` combines the stack offset
shifted by 12, and `selvastart` reads that value shifted back. This adds one byte
to the overflow pointer. The reduced original input expects
`0x123456789abcdef0` and QBE reads `0x00123456789abcde`. Removing the unused
environment from the definition is a diagnostic control, not a replacement
oracle. Original QBE source is unchanged.

Unit regressions preserve three markers through SSA, copies, dead definitions,
CFG cleanup, common-expression elimination and the complete optimizer. Additional
ARM/RV probes keep used environments with named floating arguments and empty or
nonempty variadic tails; their environment registers do not conflict with metadata.
These probes pass all three LCB modes and original QBE on both ARM targets and
Linux RV64 (QEMU).

Ordinary corpus assembly remains byte-identical for 1,305 emissions, with 15
matching refusals. The proof audit retains the same 147 reports; no new native
ABI or optimization theorem is claimed.

## Larger-program regression

The retained cJSON 1.7.19 comparison uses the same pinned cproc and identical IR
for each backend. Current-identity baseline, optimized, unchanged QBE and GCC
complete all 18 executable tests: Unity totals 153 tests, zero failures and one
ignored test per backend. The baseline deep-recursion test requires the documented
64 MiB stack retry after failing at the default stack limit; this is not a
default-stack pass.

All four timed variants produce checksum `342141b63f079083`. Three local native
ARM Linux samples at 1,000 iterations give medians 0.7951s baseline, 0.2379s
optimized, 0.2022s QBE and 0.1626s GCC. This is regression qualification, not a
speedup claim for the variadic fix. Source, identities, per-test results, stack
failure and raw samples are retained in `cjson.json`.

The ARM Linux cproc bootstrap compiles 18 frontend translation units with the
current compiler. Baseline and optimized stage-two compilers reproduce 19 IR
files byte-for-byte and pass all 196 upstream tests. Unchanged QBE fails on
`attr` with exit 139; the separately named corrected QBE oracle passes. Its
external-address correction and original failure remain in the report. This
is not an unchanged-QBE bootstrap pass.

The Linux x86 bootstrap (QEMU) also reproduces all 19 IR files and passes
196/196 upstream tests in baseline, optimized and unchanged QBE builds. This
run requires no corrected x86 oracle; its report remains distinct from ARM.

The RV64 bootstrap (QEMU) passes the same 19-file/196-test checks in baseline,
optimized and corrected-QBE modes. Unchanged QBE fails to link with the known
external-GOT-addend issue; that failure is retained separately.

CI at `43b91b0` exposed an emission-only harness bug: the new negative tests
attempted an unavailable QBE executable when target execution was disabled.
Oracle checks now require both an oracle and executable target qualification.
A guard callback with deliberately nonexistent C/QBE paths verifies both AMD64
emission-only profiles without target tool invocations; executed call counts are
zero in those reports. Existing native comparisons are unchanged.
