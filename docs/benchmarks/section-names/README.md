# Typed section fields and bounded ELF names

The combined scalar-result-discard + section compiler has source/build identity
`f159cc758be1a944534240d32728bb47d7f8e7f6abe77b0e2d1fd9446106b8f6`
and native binary SHA-256
`d9d12aa3af4f0763e64a1320688a998a3471a17ec052a29fba7cffb59877026f`.
The immutable qualification snapshot is `.build/section-main/lcb`.
The earlier private section candidate was identity
`4d77c3deef6c16f193e52af8031448a94de6179cd836b7d333ce492ebd9228a6`
on base `fdacae9`; it did not contain the later scalar change. Its report is
retained separately and is not substituted for combined-main qualification.

`SectionSpec` preserves the first section string and optional second string.
ELF accepts bounded 1–128-byte ASCII names, including bare names, hyphens and
literal commas, with optional `a`/`w`/`x` flags. Thus `section "foo,ax"` names a
literal `foo,ax` section, while `section "foo" "ax"` supplies flags for `foo`.
Both fields are quoted separately in ELF assembly. Target-independent validation
admits the union of the bounded grammars; the selected target validates its own
format. It no longer infers the format from a leading dot. The latter two-string
example is explicitly tested on all five targets, including as an Apple
segment/section pair. Unit assertions check that parser fields retain these
boundaries for data and functions.

Apple emission retains LCB's established unquoted combined directive semantics,
including its 16-byte segment/section names and allowed types/attributes. This
is deliberately different from unchanged QBE on the tested assembler: QBE's
`.section "__DATA","__foo"` produces section-name bytes `"__foo"`, including
quote bytes, whereas LCB produces `__foo`. Exact object inspection records the
difference. The matrix checks 14-byte original-QBE names and separately records
original-QBE assembly refusal at 16 bytes while LCB succeeds. The retained
private assembler probe establishes the immediate boundary: 14 bytes succeeds,
15 and 16 fail because the two quote bytes count toward the Mach-O field limit.
These section-name cases are not claimed as identical original-QBE object
semantics; the independent C runtime checks pass for both backends. Apple's
one-/two-string combined attributes remain an LCB convention.

Fresh actual-main build and units passed, including the parser-field assertions.
All 147 expected proof-audit statements matched. The first-path custom-section
exclusion remains unchanged; this is not a new certified feature. Each of the
five target reports records **252 independent C checks**: 63 checks per LCB
baseline/allocated/optimized mode and 63 for unchanged QBE. Checks cover initial
data values, calls into executable custom sections, updates, wraparound,
and a wrong-initial-value corruption control. ELF runtime fixtures explicitly
request `aw`/`ax`; unflagged names are qualified by assembly/object inspection
only. Linux ARM64 executes natively in Docker; Linux x86/RV use QEMU; Apple ARM64
is native and Apple x86 uses Rosetta. No emulated runtime performance claim is
made. Existing native Apple linkage/coalescing/alignment and Linux ELF
constructor/common helpers passed. All five emission-only cases passed with
missing C/QBE paths and a guard rejecting any attempted external-tool execution.

The default native helper is wired into `scripts/check.sh`; all three target
runners invoke it with their existing compiler/CC/runner and preserve its three
mode flags. The helper and hook hashes are bound in `manifest.json`. Reports
retain compiler/QBE binary hashes, commands, source/caller hashes, diagnostics
and object-section observations. QBE binaries were reused unchanged; the
retained source manifest compares the guest source files with pinned sources.

Remaining limits are explicit: this does not admit arbitrary assembler suffixes,
flags outside `awx`, arbitrary section characters, or promise raw escaped-token
compatibility. Existing section-string decoding remains in place. The early
flat-field prototype and the experiment changing Apple quoting are superseded;
partial/failing artifacts remain under `/tmp/lcb-section-names/.build/section-review`.
Windows AMD64 remains deferred.
