#!/usr/bin/env bash
set -euo pipefail
python3 scripts/build_identity.py --check-binary
.lake/build/bin/lcb-tests
python3 scripts/port_inventory.py
audit=$(lake env lean scripts/ProofAudit.lean)
printf '%s\n' "$audit"
grep -Fx "'LeanCompilerBackend.AArch64.select_preserves' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.run_return_sound' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.step_deterministic' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.normalize_idempotent' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.read_write_same' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.word_write_long_read' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.write_preserves_other' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.enter_leave' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.subtract_zero_iff_equal' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.subtract_borrow_iff_less' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.alu_preserves' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.verifyArtifact_binds' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.compile_refuses_unavailable' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.run_return_sound' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.run_exhausted_prefix' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.value_offset' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.stage_offset' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.frame_aligned' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.frame_covers_slots' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.slot_aligned' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.distinct_slots_disjoint' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.value_stage_disjoint' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.value_access_in_frame' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.stage_access_in_frame' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.scaled_offset_encodable' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.writeBytes_size' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.writeBytes_outside' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.writeBytes_initializes' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.address_in_frame' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.store_in_frame' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.writeBytes_byte' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.readBytes_writeBytes' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.readBytes_congr' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.readBytes_writeBytes_disjoint' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.load_store_same' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.load_store_disjoint' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.argumentBits_read' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.initialRegisters_size' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.initial_arg' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.initialState_entry' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.initial_complete' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.initial_sound' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.assemblyEntry_sound' depends on axioms: [propext]" <<< "$audit" >/dev/null
python3 scripts/test.py "$@"
python3 scripts/integer.py "$@"
python3 scripts/control.py "$@"
python3 scripts/first_path.py "$@"
python3 scripts/first_path_fuzz.py "$@"
python3 scripts/memory.py "$@"
python3 scripts/blit.py "$@"
python3 scripts/calls.py "$@"
python3 scripts/stack_args.py "$@"
python3 scripts/fuzz.py "$@"
