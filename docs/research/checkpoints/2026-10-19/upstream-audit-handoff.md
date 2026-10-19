# Pinned QBE fixture audit handoff

The audit is frozen. No tests or audits remain running.

- Original SSA fixtures: 76 total; 21 accepted by `--check`, and all 21 emit assembly. The other 55 are explicitly unsupported: 43 parsing rejections and 12 admission rejections.
- Original native harnesses: 15 eligible fixtures. Original QBE passes 15/15; LCB passes 15/15. Six admitted underscore fixtures compile to objects for both compilers but have neither an original driver nor exported main; they were not executed.
- Captured stdout agrees between both compilers for all 15 native fixtures. Both output fixtures match the original expected output. `puts10.ssa` has void `$main`, and its original harness checks output only: observed process exit codes were QBE 1 and LCB 10. This is not complete process exit equivalence.
- Source fixtures, vendored QBE and compiler source were unchanged. The copied upstream shell harness changes only its temporary file prefix. The LCB adapter answers `-t?` and reorders QBE's `-o OUT INPUT` to LCB's `INPUT -o OUT`.
- Tested binary SHA256: `d5c17558fa362c9ca9e6c436f047f238ba4d9d437c98d5b4adb56f2c5f2f9524`.
- Host: Apple ARM64, macOS 26.6.2. Pinned Nix clang 21.1.8: `/nix/store/vl936sd1vj8s008akm3gibkgyqk30qhz-clang-wrapper-21.1.8/bin/clang`.

Portable files to preserve:

- `/private/tmp/lcb-upstream-fixture-audit.py`
- `/private/tmp/lcb-upstream-native-audit.py`
- `/private/tmp/lcb-upstream-fixture-audit.json`
- `/private/tmp/lcb-upstream-audit-portable.json`

Raw native artifacts, including drivers, expected outputs, assembly, executables and compiler logs:

- `/private/tmp/lcb-upstream-native-20261019T125845997251Z/report.json`
- `/private/tmp/lcb-upstream-native-20261019T115703741467Z/report.json`: first attempt with the incorrect CLI adapter, retained as an audit harness failure rather than a compiler failure.

The scripts accept `--root`; the native script also accepts `--admission-report`. Their defaults refer to this disposable worktree and `/private/tmp`, so pass those options when copying them into another location. Native qualification requires an Apple ARM64 host and the pinned Nix development shell with `LCB_CC`. It creates disposable compiler builds and per-fixture harness artifacts under `/private/tmp`.

Next first blockers: 12 global symbol operands, 12 aggregate type declarations, 11 repeated definitions needing SSA construction, seven floating-point types, six dot/numeric names, two data declarations, two variadic signatures/calls, one TLS declaration, one environment argument and one nonentry allocation. These are first encountered errors and may hide additional unsupported features.
