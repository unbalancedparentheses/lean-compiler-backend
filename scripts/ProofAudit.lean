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
