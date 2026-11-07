# Integer conversions validation

The concrete-int-conv change adds zero/sign extension 32→64 and truncation
64→32 to the first verified path. QBE spellings are extuw, extsw and a word
copy of a long temporary. Numbered jobs use Source.Operation.convert with an
explicit conversion tag. Input/result widths are checked independently;
existing 8-parameter, 64-block, 480-definition, 488-value and 4080-byte frame
bounds remain in force.

Wire packets now use version 3 and ssa-int-v3/a64-leaf-v3. Source operation tag 4,
MIR instruction tag 9 and assembly instruction tag 14 append conversions.
Conversion tags 0/1/2 mean zeroExtend/signExtend/truncate. Version-2 jobs are
rejected, as are version-1 jobs. Jobs bind compiler identity and complete replay
output, so this change does not migrate old jobs.

## Proofs

- Machine.convert_preserves: mixed-width counterpart of alu_preserves.
- Machine.conversion_expansion: actual operand load, register conversion and store.
- conversion_instruction: source evaluation and preservation of the updated
  locals/frame relation.
- conversion_steps: one source step is simulated by three actual MIR steps.
- instruction_correct, instruction_length and simulate_instruction include the
  conversion case.

The 178-declaration audit and all 178 exact dependency checks from scripts/check.sh
passed. The first two new theorems use propext and Quot.sound; the latter two
also use Classical.choice. No sorry, native_decide or bv_decide was added.

## Checks run on Linux x86-64

All commands were bounded with timeout; builds were sequential.

- lake build lcb lcb-tests: passed.
- lcb-tests: passed, including conversion boundary values, sign bit/all ones,
  independent expected constants, composed conversions, typed literals and
  malformed numbered widths/uses/destinations.
- scripts/build_identity.py --check-binary: passed.
- lake env lean scripts/ProofAudit.lean and all pinned dependency checks: passed.
- scripts/cli_protocol.py: passed.
- scripts/first_path.py: passed; 48 job/artifact roundtrips, dependency hashes,
  conversion model expectations, renderer checks and version rejection.
- scripts/first_path_fuzz.py: passed seeds 20261019 and 20261020, 168 cases each,
  including 12 generated mixed-width chains per seed alongside 12 cyclic-phi loops.
- Clang -target arm64-apple-darwin assembled the rendered UXTW, SXTW and W MOV
  functions successfully.

## Deliberate mutations

Each mutation was planted individually, checked, and restored before the next.
Exit status 1 meant a proof or expected-value failure, never a timeout.

| Mutation | Check that rejected it |
| --- | --- |
| Machine.signExtend returns zero-extension | MachineProofs build: convert_preserves unsolved |
| Machine.truncate returns a >>> 32 | MachineProofs build: convert_preserves unsolved |
| MIR lowering loads at outputWidth instead of inputWidth | ConversionProofs build: conversion_instruction expansion mismatch |
| Admission maps signedWord to zeroExtend | Rebuilt lcb-tests: wrong source result on signed boundary value |

Mutation logs are retained locally in .build/conversion-mutations. The restored
sources were rebuilt and the checks above rerun.

## Limits

Native Apple ARM64/QBE execution was not measured on this host. The full
cross-platform scripts/check.sh suite was not run; its complete axiom-check
section and relevant tests listed above were run. Whole-function preservation,
admission/checker soundness, assembly selection/rendering and conformity to the
ARM ISA remain unproved, as in the existing first path. Artifacts remain
uncertified and --require-proof still refuses them.
