# Leanprof phi grouping and data emission qualification

Reviewed 2026-10-25. Baseline `fe10368`; candidate `d5bebeb`, containing:

- `510bee8`: group generated phis by block once in SSA construction.
- `d5bebeb`: collect data-emission lines in an array instead of repeatedly
  appending to a list.

The commits were imported from leanprof's `lcb.bundle`, branch
`leanprof-dogfood-2026-10-25`, without changing their compiler code.
Candidate compiler source identity:
`1a55463b8b6e0f00a4b4729c73c6544cc4eaaa7f713549d9ff41c8f7284f9e20`.

## Review

Phi grouping uses the CFG's unique label-to-position map. Construction preserves
block order and labels; reversing the generated list and pushing into each
bucket preserves the previous filter's per-block ordering. Explicit phis remain
before generated phis. Cached CFG callers retain the documented requirement that
labels, terminators, and block order match the function. This is source review,
not a new preservation theorem. The out-of-range comment is justified only within
that valid-graph contract; malformed supplied graphs are not newly supported.

Data emission preserves line order, directives and the trailing newline. The
change avoids repeated traversal of accumulated list prefixes. No optimization
semantics, ABI, or assembly format is intentionally changed.

## Independent validation

A clean isolated checkout passed:

```sh
nix build .#checks.aarch64-darwin.backend --no-link
```

This built `lcb` and `lcb-tests` and ran the complete
`bash scripts/check.sh --require-native` gate. The check phase took 17 minutes
13 seconds. It includes build identity, units, exact proof-dependency checks,
SSA/promotion/phi regressions, data/relocation matrices, ABI cases, upstream QBE
comparisons, native execution, optimized fuzzing and missing-tool execution guards.

The full [Nix log](nix-check.log.gz) retains each test's execution status and
limitations. A passing macOS host gate is not a claim of fresh full Linux CI
qualification. Some cross-target/final guard cases intentionally emit without
execution; some optional before-snapshot comparisons are skipped. These remain
explicit in the log. No new proof coverage is claimed.

Uncompressed log SHA-256:
`d275a0a521820928f78ea5e76777f5c1d54898b307437acb07fa75a017a9a9b4`.

## Performance evidence from the originating session

The leanprof handoff, `docs/case-studies/dogfood-lcb-concrete.md` in that project,
reports paired measurements on an 18-CPU Apple M5 Max under its benchmark lock:

| Workload | Reported compiler-time reduction | Pairs |
|---|---:|---:|
| Four zlib units: deflate, inflate, trees, crc32 | 8.19% (interval 7.60–8.68%) | 40 |
| All 17 zlib inputs | 6.50% (interval 5.81–7.51%) | 30 |

The four-unit command used `--target aarch64-macos --optimize --allocate`.
The originating session also reports 540 identical output/diagnostic/status
comparisons for each commit and focused tests. Those measurements were not
rerun in this review, and their raw timing data is not archived here. These are
attributed workload-specific compiler-time results, not generated-program
speedups or a universal performance claim. The older leanprof 99-stage report
for `ac8324e` concerns an earlier optimization series, not these commits.
