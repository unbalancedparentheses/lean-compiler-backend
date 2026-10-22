# Actual-main aggregate ABI qualification

Compiler identity: `a23afe3b4889b9da79c50d5ddf5b7e3e4affe2ba26d1e2c5072ed14c73cbdaaa`.

This is a fresh actual-main qualification, distinct from private candidate `69c2f3…`. It includes main's intervening unused-return elimination. The supplied `.build/lcb-aggregate-main` binary was copied before testing; no compiler rebuild occurred in this campaign.

The five-target matrix covers macOS ARM64/x86-64 and Linux ARM64/x86-64/RV64. Each target executes baseline, allocated, and optimized LCB output plus unchanged original QBE for 22 aggregate sizes from 127 through 65,537 bytes. Independent C checks verify caller-byte preservation, incoming parameter mutation isolation, by-value aliasing, hidden returns, all loop-tail residues, FP/GP arguments both preceding and following aggregates, inbound/outbound variadics, and explicit environments. Named and quoted numeric globals test loop-label collisions. Start/end guard pages bound copies; zeroing compact stores must fail the oracle.

Separate maximum-size cases execute 1 MiB minus one and exactly 1 MiB hidden-return copies in all three LCB modes. One-past layout, excessive frame, and excessive outgoing area are refused in each mode. Maximum cases use independent C and ABI thunks; **original-QBE scope ends at 65,537 bytes**. RV reference-only `-no-pie` retries are recorded separately from default-link failures. No corrected QBE source is used or newly qualified. Disjoint and identical addresses are covered; partial overlaps have no memmove claim.

The supplement runs all five targets in emission-only mode with nonexistent C/QBE paths and rejects any attempted external execution. It also executes the default native CLI with `--require-native`.

`campaign.json` records the original compiler/source/helper/core/hook hashes, copied snapshot hashes, target reports, and per-artifact hashes. Snapshot and original bindings were checked after the run. Linux artifacts additionally passed a bounded guest-to-host digest barrier, including reference outputs and executables. `publication-manifest.json` binds the published subset; omitted binaries and full assembly retain hashes and original locations in the campaign. Source IR, C callers, ABI thunks, exact runner/helper dependencies, commands, and reports are included.

This campaign makes no timing or runtime-speed claim. The separate private package records assembly-source size comparisons and earlier superseded attempts. Main's full target/host gates, proof audit, and workload bridge are parent-owned evidence, not results of this runner.
