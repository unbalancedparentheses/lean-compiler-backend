import LeanCompilerBackend.Verified.ArithmeticProofs
import LeanCompilerBackend.Verified.PhiContextProofs
import LeanCompilerBackend.Verified.InstructionProofs
import LeanCompilerBackend.Verified.SourceTransferProofs
import LeanCompilerBackend.Verified.CommitProofs
import LeanCompilerBackend.Verified.StagingProofs
import LeanCompilerBackend.Verified.OperandProofs
import LeanCompilerBackend.Verified.PhiExamples
import LeanCompilerBackend.Verified.PhiSwapProof
import LeanCompilerBackend.Verified.TransferProofs
import LeanCompilerBackend.Verified.EntryExamples
import LeanCompilerBackend.Verified.EntryProofs
import LeanCompilerBackend.Verified.FrameProofs
import LeanCompilerBackend.AArch64
import LeanCompilerBackend.Verified.Source
import LeanCompilerBackend.Verified.MachineProofs
import LeanCompilerBackend.Verified.BindingProofs
import LeanCompilerBackend.Verified.LayoutProofs

-- Primitive selection only; README/docs/DESIGN.md state the larger unproved edges.
#print axioms LeanCompilerBackend.AArch64.select_preserves

-- Source-model facts only: no claim about admission, lowering or native code.
#print axioms LeanCompilerBackend.Verified.Source.run_return_sound
#print axioms LeanCompilerBackend.Verified.Source.step_deterministic

-- Actual target helper facts; no composed lowering theorem yet.
#print axioms LeanCompilerBackend.Verified.Machine.normalize_idempotent
#print axioms LeanCompilerBackend.Verified.Machine.read_write_same
#print axioms LeanCompilerBackend.Verified.Machine.word_write_long_read
#print axioms LeanCompilerBackend.Verified.Machine.write_preserves_other
#print axioms LeanCompilerBackend.Verified.Machine.enter_leave
#print axioms LeanCompilerBackend.Verified.Machine.subtract_zero_iff_equal
#print axioms LeanCompilerBackend.Verified.Machine.subtract_borrow_iff_less
#print axioms LeanCompilerBackend.Verified.Machine.alu_preserves

#print axioms LeanCompilerBackend.Verified.verifyArtifact_binds
#print axioms LeanCompilerBackend.Verified.compile_refuses_unavailable
#print axioms LeanCompilerBackend.Verified.Machine.run_return_sound
#print axioms LeanCompilerBackend.Verified.Machine.run_exhausted_prefix

-- Actual frame-plan arithmetic; byte-memory simulation remains open.
#print axioms LeanCompilerBackend.Verified.value_offset
#print axioms LeanCompilerBackend.Verified.stage_offset
#print axioms LeanCompilerBackend.Verified.frame_aligned
#print axioms LeanCompilerBackend.Verified.frame_covers_slots
#print axioms LeanCompilerBackend.Verified.slot_aligned
#print axioms LeanCompilerBackend.Verified.distinct_slots_disjoint
#print axioms LeanCompilerBackend.Verified.value_stage_disjoint
#print axioms LeanCompilerBackend.Verified.value_access_in_frame
#print axioms LeanCompilerBackend.Verified.stage_access_in_frame
#print axioms LeanCompilerBackend.Verified.scaled_offset_encodable

#print axioms LeanCompilerBackend.Verified.Machine.writeBytes_size
#print axioms LeanCompilerBackend.Verified.Machine.writeBytes_outside
#print axioms LeanCompilerBackend.Verified.Machine.writeBytes_initializes
#print axioms LeanCompilerBackend.Verified.Machine.address_in_frame
#print axioms LeanCompilerBackend.Verified.Machine.store_in_frame
#print axioms LeanCompilerBackend.Verified.Machine.writeBytes_byte
#print axioms LeanCompilerBackend.Verified.Machine.readBytes_writeBytes
#print axioms LeanCompilerBackend.Verified.Machine.readBytes_congr
#print axioms LeanCompilerBackend.Verified.Machine.readBytes_writeBytes_disjoint
#print axioms LeanCompilerBackend.Verified.Machine.load_store_same
#print axioms LeanCompilerBackend.Verified.Machine.load_store_disjoint

#print axioms LeanCompilerBackend.Verified.Machine.argumentBits_read
#print axioms LeanCompilerBackend.Verified.Machine.initialRegisters_size
#print axioms LeanCompilerBackend.Verified.Machine.initial_arg
#print axioms LeanCompilerBackend.Verified.Machine.initialState_entry
#print axioms LeanCompilerBackend.Verified.Machine.initial_complete
#print axioms LeanCompilerBackend.Verified.Machine.initial_sound
#print axioms LeanCompilerBackend.Verified.Machine.assemblyEntry_sound

#print axioms LeanCompilerBackend.Verified.Machine.bounded_entry_exists
#print axioms LeanCompilerBackend.Verified.EntryExamples.empty_entry
#print axioms LeanCompilerBackend.Verified.EntryExamples.loop_entry
#print axioms LeanCompilerBackend.Verified.EntryExamples.cyclic_entry
#print axioms LeanCompilerBackend.Verified.EntryExamples.maximum_entry
#print axioms LeanCompilerBackend.Verified.EntryExamples.maximum_frame_bytes

#print axioms LeanCompilerBackend.Verified.Machine.copied_ready
#print axioms LeanCompilerBackend.Verified.Machine.executeMIRList_append
#print axioms LeanCompilerBackend.Verified.Machine.execute_copy
#print axioms LeanCompilerBackend.Verified.Machine.executeMIRList_steps

#print axioms LeanCompilerBackend.Verified.Machine.copied_load_same
#print axioms LeanCompilerBackend.Verified.Machine.copied_load_disjoint
#print axioms LeanCompilerBackend.Verified.Machine.copied_other_reg
#print axioms LeanCompilerBackend.Verified.Machine.phi_swap_exec
#print axioms LeanCompilerBackend.Verified.Machine.lowerEdge_swap
#print axioms LeanCompilerBackend.Verified.Machine.phi_swap_steps

#print axioms LeanCompilerBackend.Verified.PhiExamples.cycle_admitted
#print axioms LeanCompilerBackend.Verified.PhiExamples.cycle_lowered
#print axioms LeanCompilerBackend.Verified.PhiExamples.cycle_legal
#print axioms LeanCompilerBackend.Verified.PhiExamples.cycle_layout
#print axioms LeanCompilerBackend.Verified.PhiExamples.cycle_edge
#print axioms LeanCompilerBackend.Verified.PhiExamples.cycle_transfer

-- Nonempty cycles prove unbounded behavior, rather than inferring it from fuel.
#print axioms LeanCompilerBackend.Verified.Machine.steps_append
#print axioms LeanCompilerBackend.Verified.Machine.steps_take
#print axioms LeanCompilerBackend.Verified.Machine.cycle_diverges
#print axioms LeanCompilerBackend.Verified.Machine.prefix_diverges
#print axioms LeanCompilerBackend.Verified.PhiExamples.source_cycle
#print axioms LeanCompilerBackend.Verified.PhiExamples.source_diverges
#print axioms LeanCompilerBackend.Verified.PhiExamples.mir_entry_run
#print axioms LeanCompilerBackend.Verified.PhiExamples.mir_cycle_run
#print axioms LeanCompilerBackend.Verified.PhiExamples.mir_diverges
#print axioms LeanCompilerBackend.Verified.PhiExamples.assembly_selected
#print axioms LeanCompilerBackend.Verified.PhiExamples.assembly_legal
#print axioms LeanCompilerBackend.Verified.PhiExamples.assembly_entry_run
#print axioms LeanCompilerBackend.Verified.PhiExamples.assembly_cycle_run
#print axioms LeanCompilerBackend.Verified.PhiExamples.assembly_diverges
#print axioms LeanCompilerBackend.Verified.PhiExamples.cycle_behavior

-- Source operand simulation under the frame-value relation.
#print axioms LeanCompilerBackend.Verified.Source.read_ok
#print axioms LeanCompilerBackend.Verified.Machine.loadOperand_correct
#print axioms LeanCompilerBackend.Verified.Machine.localsMatch_registers
#print axioms LeanCompilerBackend.Verified.Machine.value_normalized
#print axioms LeanCompilerBackend.Verified.Machine.operand_copy
#print axioms LeanCompilerBackend.Verified.Machine.planned_value
#print axioms LeanCompilerBackend.Verified.Machine.planned_stage
#print axioms LeanCompilerBackend.Verified.Machine.localsMatch_stage

#print axioms LeanCompilerBackend.Verified.Machine.stagePhis_correct

-- Arbitrary phi commit and emitted-edge execution, including the jump.
#print axioms LeanCompilerBackend.Verified.Machine.localsMatch_store
#print axioms LeanCompilerBackend.Verified.Machine.staged_store
#print axioms LeanCompilerBackend.Verified.Machine.commitPhis_correct
#print axioms LeanCompilerBackend.Verified.Machine.phi_phases_correct
#print axioms LeanCompilerBackend.Verified.Machine.commitPhis_length
#print axioms LeanCompilerBackend.Verified.Machine.stagePhis_length
#print axioms LeanCompilerBackend.Verified.Machine.mir_jump
#print axioms LeanCompilerBackend.Verified.Machine.lowerEdge_steps

-- Actual source transfer loops compose with the actual emitted MIR edge.
#print axioms LeanCompilerBackend.Verified.Source.transfer_loops
#print axioms LeanCompilerBackend.Verified.Source.transferInputs_selected
#print axioms LeanCompilerBackend.Verified.Source.collectPhi_ok
#print axioms LeanCompilerBackend.Verified.Source.collectPhis_ok
#print axioms LeanCompilerBackend.Verified.Source.write_ok
#print axioms LeanCompilerBackend.Verified.Source.transferTargets_valid
#print axioms LeanCompilerBackend.Verified.Source.commitPhis_ok
#print axioms LeanCompilerBackend.Verified.Source.transfer_assigns
#print axioms LeanCompilerBackend.Verified.Source.transfer_correct

-- Admitted-loop instantiation and concrete relation witnesses.
#print axioms LeanCompilerBackend.Verified.PhiExamples.swap_inputs
#print axioms LeanCompilerBackend.Verified.PhiExamples.swap_targets
#print axioms LeanCompilerBackend.Verified.PhiExamples.swap_simulation
#print axioms LeanCompilerBackend.Verified.PhiExamples.loop_related
#print axioms LeanCompilerBackend.Verified.PhiExamples.loop_ready

-- Source instruction step and actual copy expansion.
#print axioms LeanCompilerBackend.Verified.source_instruction_step
#print axioms LeanCompilerBackend.Verified.copy_instruction
#print axioms LeanCompilerBackend.Verified.copy_steps

-- Phi context non-clobbering, including the actual emitted edge.
#print axioms LeanCompilerBackend.Verified.Machine.copyContext_refl
#print axioms LeanCompilerBackend.Verified.Machine.copyContext_trans
#print axioms LeanCompilerBackend.Verified.Machine.copyInstruction_context
#print axioms LeanCompilerBackend.Verified.Machine.copyList_context
#print axioms LeanCompilerBackend.Verified.Machine.loadOperand_copy
#print axioms LeanCompilerBackend.Verified.Machine.commitPhis_copy
#print axioms LeanCompilerBackend.Verified.Machine.stagePhis_copy
#print axioms LeanCompilerBackend.Verified.Machine.phi_context
#print axioms LeanCompilerBackend.Verified.Machine.lowerEdge_context

-- Actual four-instruction arithmetic expansion and source simulation.
#print axioms LeanCompilerBackend.Verified.Machine.sourceView_width
#print axioms LeanCompilerBackend.Verified.Machine.sourceView_bits
#print axioms LeanCompilerBackend.Verified.Machine.sourceView_value
#print axioms LeanCompilerBackend.Verified.Machine.assignedReg_ready
#print axioms LeanCompilerBackend.Verified.Machine.assignedReg_locals
#print axioms LeanCompilerBackend.Verified.Machine.writeReg_assigned
#print axioms LeanCompilerBackend.Verified.Machine.assignedReg_same
#print axioms LeanCompilerBackend.Verified.Machine.assignedReg_other
#print axioms LeanCompilerBackend.Verified.Machine.binary_expansion
#print axioms LeanCompilerBackend.Verified.binary_instruction
#print axioms LeanCompilerBackend.Verified.binary_steps
