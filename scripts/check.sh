#!/usr/bin/env bash
set -euo pipefail
.lake/build/bin/lcb-tests
audit=$(lake env lean scripts/ProofAudit.lean)
printf '%s\n' "$audit"
grep -Fx "'LeanCompilerBackend.AArch64.select_preserves' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
python3 scripts/test.py "$@"
