#!/usr/bin/env bash
set -euo pipefail
python3 scripts/build_identity.py --check-binary
.lake/build/bin/lcb-tests
python3 scripts/cli_protocol.py "$@"
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
grep -Fx "'LeanCompilerBackend.Verified.Machine.bounded_entry_exists' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.EntryExamples.empty_entry' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.EntryExamples.loop_entry' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.EntryExamples.cyclic_entry' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.EntryExamples.maximum_entry' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.EntryExamples.maximum_frame_bytes' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.copied_ready' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.executeMIRList_append' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.execute_copy' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.executeMIRList_steps' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.copied_load_same' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.copied_load_disjoint' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.copied_other_reg' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.phi_swap_exec' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.lowerEdge_swap' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.phi_swap_steps' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.cycle_admitted' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.cycle_lowered' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.cycle_legal' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.cycle_layout' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.cycle_edge' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.cycle_transfer' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.steps_append' does not depend on any axioms" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.steps_take' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.cycle_diverges' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.prefix_diverges' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.source_cycle' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.source_diverges' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.mir_entry_run' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.mir_cycle_run' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.mir_diverges' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.assembly_selected' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.assembly_legal' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.assembly_entry_run' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.assembly_cycle_run' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.assembly_diverges' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.cycle_behavior' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.read_ok' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.loadOperand_correct' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.localsMatch_registers' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.value_normalized' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.operand_copy' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.planned_value' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.planned_stage' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.localsMatch_stage' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.stagePhis_correct' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.localsMatch_store' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.staged_store' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.commitPhis_correct' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.phi_phases_correct' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.commitPhis_length' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.stagePhis_length' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.mir_jump' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.lowerEdge_steps' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.transfer_loops' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.transferInputs_selected' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.collectPhi_ok' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.collectPhis_ok' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.write_ok' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.transferTargets_valid' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.commitPhis_ok' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.transfer_assigns' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Source.transfer_correct' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.swap_inputs' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.swap_targets' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.swap_simulation' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.loop_related' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.PhiExamples.loop_ready' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.source_instruction_step' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.copy_instruction' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.copy_steps' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.copyContext_refl' does not depend on any axioms" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.copyContext_trans' does not depend on any axioms" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.copyInstruction_context' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.copyList_context' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.loadOperand_copy' does not depend on any axioms" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.commitPhis_copy' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.stagePhis_copy' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.phi_context' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.lowerEdge_context' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.sourceView_width' does not depend on any axioms" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.sourceView_bits' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.sourceView_value' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.assignedReg_ready' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.assignedReg_locals' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.writeReg_assigned' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.assignedReg_same' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.assignedReg_other' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.binary_expansion' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.binary_instruction' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.binary_steps' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.value_bits_toNat' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.boolValue_width' does not depend on any axioms" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.boolValue_bits' does not depend on any axioms" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.comparison_source' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.load_operands' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.Machine.comparison_expansion' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.comparison_instruction' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.comparison_steps' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.source_write_sound' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.instruction_correct' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.instruction_length' depends on axioms: [propext]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.source_instruction_invert' depends on axioms: [propext, Quot.sound]" <<< "$audit" >/dev/null
grep -Fx "'LeanCompilerBackend.Verified.simulate_instruction' depends on axioms: [propext, Classical.choice, Quot.sound]" <<< "$audit" >/dev/null
python3 scripts/test.py "$@"
python3 scripts/integer.py "$@"
python3 scripts/control.py "$@"
python3 scripts/ssa.py "$@"
python3 scripts/large_cfg.py "$@"
python3 scripts/liveness.py "$@"
python3 scripts/allocation.py "$@"
python3 scripts/instruction_selection.py "$@"
python3 scripts/unsigned_strength.py "$@"
python3 scripts/memory_promotion.py "$@"
python3 scripts/first_path.py "$@"
python3 scripts/first_path_fuzz.py "$@"
python3 scripts/symbols.py "$@"
python3 scripts/global_addresses.py "$@"
python3 scripts/memory_forward.py "$@"
python3 scripts/data.py "$@"
python3 scripts/data_matrix.py "$@"
python3 scripts/float_constants.py "$@"
python3 scripts/floating.py "$@"
python3 scripts/conversions.py "$@"
python3 scripts/float_abi.py "$@"
python3 scripts/float_variadic.py "$@"
python3 scripts/aggregate_layout.py "$@"
python3 scripts/aggregate_abi.py "$@"
python3 scripts/aggregate_edges.py "$@"
python3 scripts/subword.py "$@"
python3 scripts/tls.py "$@"
python3 scripts/names.py "$@"
python3 scripts/quoted_names.py "$@"
python3 scripts/debug_locations.py "$@"
python3 scripts/linkage.py "$@"
python3 scripts/upstream_suite.py "$@"
python3 scripts/linux_arm64.py
python3 scripts/linux_targets.py
python3 scripts/linux_targets.py --target riscv64-linux
python3 scripts/macos_x86.py
python3 scripts/memory.py "$@"
python3 scripts/large_frames.py "$@"
python3 scripts/large_objects.py "$@"
python3 scripts/large_data.py "$@"
python3 scripts/dynamic_alloc.py "$@"
python3 scripts/zero_alloc.py "$@"
python3 scripts/module_scale.py "$@"
python3 scripts/control_flow.py "$@"
python3 scripts/constant_fold.py "$@"
python3 scripts/blit.py "$@"
python3 scripts/calls.py "$@"
python3 scripts/indirect.py "$@"
python3 scripts/variadic.py "$@"
python3 scripts/environment.py "$@"
python3 scripts/stack_args.py "$@"
python3 scripts/fuzz.py --optimize "$@"
