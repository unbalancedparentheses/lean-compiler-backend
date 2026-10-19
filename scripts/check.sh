#!/usr/bin/env bash
set -euo pipefail
.lake/build/bin/lcb-tests
python3 scripts/port_inventory.py
audit=$(lake env lean scripts/ProofAudit.lean)
printf '%s\n' "$audit"
grep -Fx "'LeanCompilerBackend.AArch64.select_preserves' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
python3 scripts/test.py "$@"
python3 scripts/integer.py "$@"
python3 scripts/control.py "$@"
python3 scripts/memory.py "$@"
python3 scripts/fuzz.py "$@"
