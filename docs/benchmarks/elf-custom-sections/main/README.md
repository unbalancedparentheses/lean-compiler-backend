# Actual-main ELF custom sections: TLS and retention

Compiler identity: `5e174e1d424aa154ed5fda916ad507a3a9dceb625b28774a2c1356dcaf0b235e`.

This fresh campaign qualifies the combined actual-main TLS and `R` changes. It is separate from both private candidates. The supplied compiler was snapshotted; no build or source edit occurred during testing. Before identity is `a23afe3b4889b9da79c50d5ddf5b7e3e4affe2ba26d1e2c5072ed14c73cbdaaa`.

## Results

Both helpers passed separate five-target matrices. Each Linux target executed baseline, allocated, optimized, and unchanged original-QBE output. Linux ARM ran natively in the VM; x86-64 and RV64 used QEMU user mode. All 24 Linux executables were independently confirmed ELF DYN PIE. No corrected QBE or timing result is included.

The TLS matrix checks initialized, zero-initialized, local, and ordinary TLS; exact object section flags/type/alignment and TLS symbol mapping; direct independent C access; fresh initialization in four sequential child threads; and isolation from main-thread writes. Each backend performs 512 child-thread read/write rounds: 4,608 LCB round groups and 1,536 QBE round groups across Linux targets. Wrong-section and wrong-value controls are retained. The tested `.lcb_tls.zero` is PROGBITS; this is not a claim about special assembler names such as `.tbss`.

The retention matrix links with `--gc-sections`. Independent C references only `anchor` and `ref_data`; retained-only addresses are supplied as numeric anchor-relative offsets after linking, creating no linker roots. Unreferenced `awR`/`aR` data and an `axR` function survive and return expected contents, while non-R controls disappear. Removing R from optimized LCB and QBE fixtures fails metadata/linked-symbol checks. A retained-value mutation fails the C oracle.

Apple scope is deliberately different: TLS custom sections are refused, and ordinary-TLS fixture emission matches the before snapshot in all three modes. Retention fixtures also emit byte-identically to before; an Apple second field such as `aR` is a literal section name. There is no new Apple runtime or GNU-retention claim.

Ten emission-only controls (both helpers, all five targets) passed with nonexistent C/QBE tools and an execution guard. Both default native CLIs passed their Apple emission/refusal scope. Nine additional combined-context controls reject TLS flags `awTR`, ensuring ordinary R admission does not expand the independent TLS whitelist.

## Provenance and scope

`campaign.json` records exact compiler/before/helper/core/hook and pinned-QBE-source bindings, frozen snapshot/runner bindings, and 419 artifact hashes. These bindings were checked before/after the run and rechecked during publication. Guest QBE's executable hash matched before and after; it was reused unchanged, not rebuilt here.

Each successful guest output-producing command passed an immediate guest-to-host hash barrier before a helper could read its output. Completed Linux target trees also required identical host/guest path sets and hashes. `publication-manifest.json` binds this published subset; binaries and full assembly are omitted, with their hashes and original artifact paths retained in the campaign. IR, C callers, exact helpers/dependencies, runner, commands, reports, and post-run ELF headers are included.

Hook review confirms both helpers coexist with aggregate-copy registrations in the native check and all target runners, and both are registered in the global emission-only suite. Hook syntax checks passed. Parent-owned full Linux/host gates, proof audit, corpus, and workload results are separate evidence and are not claimed by this runner.
