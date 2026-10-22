# Retained libyaml IR replay

The new [`libyaml_replay.py`](../../../scripts/libyaml_replay.py) recompiles the
21 retained, target-specific cproc IR units for libyaml 0.2.5 and its 13 upstream
drivers. It does not fetch sources, rebuild cproc or GCC references, or rewrite
any retained input. Each run snapshots the requested compiler and writes all
candidate artifacts into a new Docker-mounted directory.

| Report | Target / execution | Compiler source identity | Candidate results |
| --- | --- | --- | --- |
| [ARM](arm.json) | Linux ARM64 VM, native | `a2e10e57113b6cadafcca6a59c5206bde2a51282bd1ef55206e4079ed1121043` | 52 checks × baseline/allocated/optimized passed |
| [RV64](rv.json) | Linux RV64, QEMU user | `f9998cdd7f047ad5ac6ce1234797f2a68ecf71a84bdd911427a472cc9f4cc135` | 52 checks × baseline/allocated/optimized passed |

Both runs first reran the retained GCC O0 and O2 executables and required all
52 exit-status, stdout/stderr SHA-256 and byte-count records to match the
[original qualification](../libyaml/README.md). These include the reader/version
assertions, generated YAML fixtures, parser/emitter event roundtrips, example
drivers and three invalid inputs. Candidate records must equal the same
historical records. This is finite executable qualification, not a full upstream
test-suite or proof claim.

The reports bind the source/header, IR and fixture hashes; compiler source
identity and binary hash; replay harness snapshot; helper hashes; and all new
assembly, object and executable hashes. The original reports did not hash GCC
executables: replay hashes them now, verifies their historical behavior, and
checks these hashes again after execution. Retained source/IR/fixtures, the
reference report, compiler snapshot and candidate executables also receive
post-execution checks. Guest-generated execution JSON is read only after a
bounded guest-to-host SHA-256 synchronization check.

Both runs detected an intentionally corrupted compiled `test-version` return.
The input validator also rejected a wrong IR hash; the separate
[wrong-hash report](wrong-ir-hash.json) demonstrates pre-compilation refusal
through the command-line path. The retained IR itself was never mutated.
Earlier runs without the JSON synchronization barrier remain local development
artifacts and are excluded from these published results.

Original QBE and separately corrected QBE statuses are carried from the old
reference reports as historical provenance only. Neither QBE backend was rerun
by this helper; these results do not turn an original-QBE failure into a common
differential pass. Subprocess wall times in the raw reports are observations
under concurrent load; no runtime speed claim is made.

Reproduction with the retained local artifacts:

```sh
python3 scripts/libyaml_replay.py \
  --reference-report .build/libyaml-rv.json \
  --compiler .build/lcb-rv-result-normalization \
  --work .build/linux-arm64/libyaml-replay-rv-f999-barrier \
  --report .build/libyaml-replay-rv-f999-barrier.json

python3 scripts/libyaml_replay.py \
  --reference-report .build/libyaml-arm.json \
  --compiler .build/lcb-arm-load-extensions \
  --work .build/linux-arm64/libyaml-replay-arm-a2e-barrier \
  --report .build/libyaml-replay-arm-a2e-barrier.json
```

The work directory must not already exist; choose a fresh name for another run.
Original fixture paths are retained in driver arguments because filenames can
appear in upstream output. Exact commands, diagnostics, hashes and local paths
are included in the JSON reports.
