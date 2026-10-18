# Upstream sources and licenses

Pinned 2026-10-18. The project's name is **Lean Compiler Backend** because QBE is
the starting point, while Zig, LLVM and other work can contribute ideas or code.
There is no affiliation with those projects.

## QBE — principal porting baseline

- Official [QBE project](https://c9x.me/compile/).
- Release **1.3**, source commit `c0818978acec60ebb6167fade60fb7012cbf20ca`.
- [Official release archive](https://c9x.me/compile/release/qbe-1.3.tar.xz).
- Archive SHA-256: `d587905d620dc5e1d2bfa7c2cc642b9b837aa89a3188c6e37b53d756cf66e320`.
- Full release retained unchanged in `third_party/qbe/`, including
  [its MIT-style license](../third_party/qbe/LICENSE), copyright Quentin Carbonneaux.

The Lean IR/parser/semantics port a restricted part of `all.h`, `ops.h`, `parse.c`
and `doc/il.txt`. AArch64 mnemonic selection and leaf ABI organization draw from
`arm64/emit.c` and `arm64/abi.c`. This is an incremental reimplementation in Lean,
not a completed line-for-line port. The original C backend is compiled separately
in a temporary directory as a test comparison. The Lean compiler does not call it.

## Zig — additional architecture and target reference

- Official [Zig project](https://ziglang.org/) and
  [source repository](https://codeberg.org/ziglang/zig).
- Release **0.17.0**, published 2026-10-01 according to the official download index.
- [Official source archive](https://ziglang.org/download/0.17.0/zig-0.17.0.tar.xz).
- Archive SHA-256: `b6c7f1728f043700d6529bac980800792f824256a9d2f1839b3d62beed0b8abd`.
- Selected files retained unchanged: `LICENSE`, `README.md`, `src/Air.zig`,
  `src/codegen/aarch64.zig`, `src/codegen/aarch64/Mir.zig` and
  `src/codegen/aarch64/abi.zig`.
- [MIT license](../third_party/zig/LICENSE), copyright Zig contributors.

These files inform separation of analyzed IR, target code generation, machine
representation and ABI data. No Zig implementation executes in this compiler.
The release archive and hashes identify the source; no unverified Git commit is
invented for this snapshot. Copying more implementation requires corresponding
license retention, module attribution and lock updates.

## LLVM and Alive2 — design references so far

[BEYOND_QBE.md](BEYOND_QBE.md) records specific references for machine IR,
legalization, declarative target descriptions, pass verification, isolated tests
and translation validation. No LLVM/Alive2 source is currently vendored or ported.
LLVM inspection tools and Clang are supplied by pinned Nixpkgs as build/test
dependencies; that does not make LLVM the code-generation backend of `lcb`.

## Concrete and Lean toolchain

The Nix setup adapts Concrete's pinned official Lean archive approach and uses
the same Lean 4.34.1 release hashes and Nixpkgs revision. Concrete's Apache 2.0
license is retained in [LICENSES/Apache-2.0.txt](../LICENSES/Apache-2.0.txt) for
the adapted Nix configuration. Lean itself is an external toolchain dependency;
its own release contains its licenses. The compiler executable uses Lean's
runtime; the target assembly contains no automatically inserted Lean runtime.

## Reproducibility and attribution rule

[upstream-lock.json](../upstream-lock.json) lists every retained upstream file
and its SHA-256. Checks reject any missing, extra or modified vendored file.
Do not edit those snapshots as if they were original project code. Keep adapted
implementations in project modules, attribute their sources and document which
behavior is preserved, changed or unsupported. Original project code uses the
root MIT license; upstream material keeps the license stated above.
