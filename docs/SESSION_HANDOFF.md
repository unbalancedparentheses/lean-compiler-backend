# Session handoff — 2026-10-19

This is a shutdown checkpoint, not a full-port or verification completion claim.
The user asked to save, commit and push before restarting Codex with different
permission settings. All agents stopped; no local test processes remain running.

## Repositories and saved checkpoints

- Backend: `https://github.com/unbalancedparentheses/lean-compiler-backend`.
  Main checkout: `/Users/unbalancedparen/projects/lean-compiler-backend`.
- Backend `main` includes `c710dcf29af835ac5d3bfb25cecbe8c3ff7bf886`
  (effect-only constant-size blits), preceded by `a9dee3e` (integer stack
  arguments), `ab83f67` (void calls) and `5fbb21d` (direct integer calls).
  Blit CI passed on Linux and Apple ARM64 macOS:
  <https://github.com/unbalancedparentheses/lean-compiler-backend/actions/runs/39247954651>.
- `feat/global-symbol-operands` at
  `1da26cca9a508edd9f03aba74c4c8e327b0cd2d8` saves the next implementation
  and its tests. Worktree: `/private/tmp/lcb-global-symbols`.
  Full CI was running at shutdown:
  <https://github.com/unbalancedparentheses/lean-compiler-backend/actions/runs/39256581974>.
  Keep this checkpoint separate until its complete CI result is checked.
- The accompanying documentation commit saves the independently edited
  correctness-first roadmap and architecture/community research. Foundations
  specification work is documentary; port implementation has separate user
  authorization. This checkpoint adds no preservation theorem.
- Concrete adapter: `/private/tmp/concrete2-lcb-integration`, branch
  `feat/lean-backend-integration`, published checkpoint `dc82aef8` and draft PR
  <https://github.com/unbalancedparentheses/concrete2/pull/8>.
  That worktree was clean at shutdown. Its adapter remains deliberately restricted.

## Global-symbol checkpoint

Ordinary `$name` operands are admitted in long contexts and lower to Mach-O
`adrp`/`add` PAGE/PAGEOFF address materialization. Definitions may come from the
linker, including C data and functions. Parser and validator restrict names.
The interpreter explicitly refuses symbol evaluation rather than inventing
addresses. GOT/`extern`, TLS, data declarations, relocation addends and indirect
calls remain unsupported.

Local qualification passed:

- Pinned Nix Lean build, unit checks and inventory regeneration.
- 36 native entry functions, including 16 generated cases, with 468 executions
  each for Lean output, original QBE and independent C.
- Every case checks all 288 global bytes; pointer identity is checked relationally.
- 12 static rejection controls, nine explicit interpreter no-model controls and
  a detected address-relocation corruption.
- Whitespace and shell-syntax checks; `scripts/check.sh` includes `symbols.py`.

The extra direct-IR invalid-name injection probe was deferred at shutdown.
Existing parser/name controls do not substitute for that specific probe.
Additional word-context branch/phi/shift-count controls were also deferred.
The full upstream fixture audit has not been rerun with symbol support.
Local log: `/private/tmp/lcb-symbols-tests.log`.

## Upstream fixture qualification at the blit checkpoint

Retained scripts, results and audit notes are in
[`research/checkpoints/2026-10-19`](research/checkpoints/2026-10-19).
They test the blit checkpoint, not the later symbol checkpoint.

- 76 pinned original SSA fixtures; 21 admitted and all 21 emitted assembly.
- 55 explicitly unsupported: 43 parsing failures and 12 admission failures.
- 15 fixtures have original executable harnesses: both original QBE and Lean
  output pass 15/15; captured stdout agrees for all 15.
- Six further admitted fixtures only assemble to objects; they have no original
  executable harness and were not run.
- `puts10.ssa` has void `main`. Its upstream harness checks output only; observed
  process exit differs (QBE 1, Lean 10). This is not complete exit equivalence.

Raw local artifacts remain at
`/private/tmp/lcb-upstream-native-20261019T125845997251Z/`. JSON reports and
reproduction scripts are committed; generated binaries/build trees are not source
artifacts. Original drivers and expected output are reproducible from vendored
fixtures. The failed initial CLI-adapter attempt is separately retained locally
at `/private/tmp/lcb-upstream-native-20261019T115703741467Z/`.

## What remains

This is still a bounded integer/control-flow/memory/direct-call backend on one
partial target. 55/87 public opcode names have some forms implemented; this is
not an overall port percentage. No complete target/ABI or end-to-end preservation
proof is claimed.

Major remaining work includes floating point and full ABIs (aggregates,
variadics, indirect calls, subword arguments), global data/TLS/linkage, dynamic
allocation, SSA construction, optimizations, liveness/spilling/register allocation,
AMD64/RV64 and remaining object conventions, broad upstream fuzz qualification,
and composed preservation proofs. Every SSA value still has a stack slot.

## Resume safely

1. Inspect `git status` and current remote heads; other sessions may advance them.
2. Check full CI for `1da26cca` before integration. Preserve the roadmap/research
   checkpoint when merging it; the feature branch predates those documentation edits.
3. Run the growing original upstream fixture audit against the symbol checkpoint,
   retaining first-blocker and executable-harness results separately.
4. Next bounded compatibility slice can be integer data definitions, with an
   explicit abstract global-memory model; do not silently model host addresses.
5. Follow ROADMAP F00 for the first verified-path specification. Do not claim the
   existing opcode theorem proves lowering, register allocation or emitted code.

Use the pinned Nix environment for builds/tests. Retain QBE provenance, source
hashes, licenses and independent comparison implementations. The user authorizes
agents and frequent commits/pushes, and asks to avoid unnecessary confirmation.
Sandbox permissions are still controlled by the new session's environment.

Other backend feature worktrees (`lcb-void-calls`, `lcb-stack-arguments`,
`lcb-integer-blits`) are committed and published. `/private/tmp/lcb-development`
is an old staging copy with stale Git metadata; do not use its Git state.

The Concrete checkout also contains unrelated local audit/worktree/admin files;
they were not swept into backend commits. A copy of its related untracked
architecture proposal is retained with this checkpoint so the research is saved.
