/- Arbitrary phi staging reads the frozen predecessor environment. -/
import LeanCompilerBackend.Verified.OperandProofs

namespace LeanCompilerBackend.Verified.Machine

/-- Incoming operands selected by the actual lowering, resolved in one frozen
    source environment. Admission must additionally establish predecessor uniqueness. -/
def PhiInputs (pred : Nat) (env : Source.Environment) : List (Source.Phi × Source.Value) → Prop
  | [] => True
  | (phi, value) :: rest => ∃ operand,
      phi.incoming.find? (·.1 == pred) = some (pred, operand) ∧
      Source.read env phi.width operand = .ok value ∧ PhiInputs pred env rest

/-- Values already stored in consecutive canonical staging slots. -/
def Staged (d : Data) (valueCount index : Nat) : List (Source.Phi × Source.Value) → Prop
  | [] => True
  | (phi, value) :: rest =>
      load d phi.width (8*(valueCount+index)) = .ok value.toNat.toUInt64 ∧
      Staged d valueCount (index+1) rest

/-- The actual staging pass works for any phi list, including cyclic and
    overlapping destinations: all reads still see the predecessor environment.
    Its writes also preserve every byte span below the first staging slot. -/
theorem stagePhis_correct (f : StackMIR.Function) (source : Source.Function)
    (env : Source.Environment) (d : Data) (pred index : Nat)
    (inputs : List (Source.Phi × Source.Value))
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size)
    (capacity : index + inputs.length ≤ phiCapacity source)
    (ready : FrameReady d) (related : LocalsMatch f env d) (selected : PhiInputs pred env inputs) :
    ∃ code after,
      StackMIR.stagePhis pred index (inputs.map Prod.fst) = .ok code ∧
      executeMIRList f code d = .ok after ∧ FrameReady after ∧
      after.frameBytes = (planFrame source).frameBytes ∧ LocalsMatch f env after ∧
      Staged after source.valueWidths.size index inputs ∧
      (∀ width offset, offset + width.bytes ≤ 8*(source.valueWidths.size+index) →
        load after width offset = load d width offset) := by
  induction inputs generalizing d index with
  | nil =>
    exact ⟨[], d, rfl, rfl, ready, frame, related, trivial, fun _ _ _ => rfl⟩
  | cons input rest ih =>
    obtain ⟨phi, value⟩ := input
    obtain ⟨operand, found, read, restSelected⟩ := selected
    have inside : index < phiCapacity source := by simp only [List.length_cons] at capacity; omega
    have access : 8*(source.valueWidths.size+index) + phi.width.bytes ≤ d.frameBytes := by
      rw [frame]
      exact stage_access_in_frame source index phi.width inside
    let middle := copied d phi.width (8*(source.valueWidths.size+index)) value.toNat.toUInt64
    have middleReady : FrameReady middle := copied_ready _ _ _ _ ready
    have middleFrame : middle.frameBytes = (planFrame source).frameBytes := frame
    have middleRelated : LocalsMatch f env middle :=
      localsMatch_stage f source env d index phi.width value.toNat.toUInt64
        layout frame size inside ready related
    obtain ⟨tailCode, after, tailLowered, tailExecuted, afterReady, afterFrame,
        afterRelated, afterStaged, tailPreserved⟩ :=
      ih middle (index+1) middleFrame (by simp only [List.length_cons] at capacity; omega)
        middleReady middleRelated restSelected
    let headCode := [StackMIR.loadOperand phi.width .r9 operand, .store phi.width (.stage index) .r9]
    have headExecuted : executeMIRList f headCode d = .ok middle :=
      operand_copy f env d phi.width operand value (.stage index) _ ready related read
        (planned_stage f source layout index inside) access
    refine ⟨headCode ++ tailCode, after, ?_, ?_, afterReady, afterFrame, afterRelated, ?_, ?_⟩
    · simp [StackMIR.stagePhis, found, tailLowered, headCode, bind, Except.bind, pure, Except.pure]
    · rw [executeMIRList_append, headExecuted]
      exact tailExecuted
    · refine ⟨?_, afterStaged⟩
      rw [tailPreserved phi.width (8*(source.valueWidths.size+index)) (by
        have bytes : phi.width.bytes ≤ 8 := by cases phi.width <;> decide
        omega)]
      have stored := copied_load_same d phi.width (8*(source.valueWidths.size+index))
        value.toNat.toUInt64 ready access
      have width := (Source.read_ok env phi.width operand value read).1
      rw [← width, value_normalized] at stored
      simpa only [middle, width] using stored
    · intro width offset below
      rw [tailPreserved width offset (by omega)]
      exact copied_load_disjoint d width phi.width offset (8*(source.valueWidths.size+index))
        value.toNat.toUInt64 ready (by omega) access (Or.inl below)

end LeanCompilerBackend.Verified.Machine
