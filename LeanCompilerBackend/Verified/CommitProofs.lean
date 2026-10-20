/- Commit staged phi values while maintaining the source/frame relation. -/
import LeanCompilerBackend.Verified.StagingProofs
import LeanCompilerBackend.Verified.DivergenceProofs
import LeanCompilerBackend.Verified.PhiContextProofs

namespace LeanCompilerBackend.Verified.Machine

/-- Updating an SSA destination and its canonical frame slot preserves the
    relation for all locals, including different-width neighboring slots. -/
theorem localsMatch_store (f : StackMIR.Function) (source : Source.Function)
    (env : Source.Environment) (d : Data) (dest : Nat) (value : Source.Value)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : dest < env.size)
    (ready : FrameReady d) (related : LocalsMatch f env d) :
    LocalsMatch f (env.set! dest (some value)) (copied d value.width (8*dest) value.toNat.toUInt64) := by
  intro id v found
  have destBound : dest < source.valueWidths.size := by omega
  by_cases same : id = dest
  · subst id
    have equal : value = v := by
      simpa [Array.getElem?_setIfInBounds_self_of_lt inside] using found
    subst v
    refine ⟨8*dest, planned_value f source layout dest destBound, ?_⟩
    rw [copied_load_same d value.width (8*dest) value.toNat.toUInt64 ready
      (by rw [frame]; exact value_access_in_frame source dest value.width destBound), value_normalized]
  · have old : env[id]? = some (some v) := by
      simpa [Array.getElem?_setIfInBounds_ne (Ne.symm same)] using found
    have idBound : id < source.valueWidths.size := by
      have h := Array.getElem?_eq_some_iff.mp old |>.1
      omega
    obtain ⟨offset, lookup, loaded⟩ := related id v old
    have canonical := planned_value f source layout id idBound
    rw [canonical] at lookup
    cases lookup
    refine ⟨8*id, canonical, ?_⟩
    rw [copied_load_disjoint d v.width value.width (8*id) (8*dest) value.toNat.toUInt64 ready
      (by rw [frame]; exact value_access_in_frame source id v.width idBound)
      (by rw [frame]; exact value_access_in_frame source dest value.width destBound)
      (distinct_slots_disjoint id dest v.width value.width same)]
    exact loaded

/-- A destination store cannot overwrite any canonical staging slot. -/
theorem staged_store (source : Source.Function) (d : Data) (index dest : Nat)
    (w : Width) (value : UInt64) (inputs : List (Source.Phi × Source.Value))
    (frame : d.frameBytes = (planFrame source).frameBytes)
    (capacity : index + inputs.length ≤ phiCapacity source)
    (inside : dest < source.valueWidths.size) (ready : FrameReady d)
    (staged : Staged d source.valueWidths.size index inputs) :
    Staged (copied d w (8*dest) value) source.valueWidths.size index inputs := by
  induction inputs generalizing index with
  | nil => trivial
  | cons input rest ih =>
    obtain ⟨phi, v⟩ := input
    obtain ⟨head, tail⟩ := staged
    have bound : index < phiCapacity source := by simp only [List.length_cons] at capacity; omega
    refine ⟨?_, ih (index+1) (by simp only [List.length_cons] at capacity; omega) tail⟩
    rw [copied_load_disjoint d phi.width w (8*(source.valueWidths.size+index)) (8*dest) value ready
      (by rw [frame]; exact stage_access_in_frame source index phi.width bound)
      (by rw [frame]; exact value_access_in_frame source dest w inside)
      (Or.inr (value_stage_disjoint source dest index w inside))]
    exact head

/-- Defined, width-compatible phi destinations in the source environment. -/
def PhiTargets (size : Nat) : List (Source.Phi × Source.Value) → Prop
  | [] => True
  | (phi, value) :: rest =>
      phi.destination < size ∧ phi.width = value.width ∧ PhiTargets size rest

/-- Commit values which were all resolved before the first destination update. -/
def assignPhis (env : Source.Environment) : List (Source.Phi × Source.Value) → Source.Environment
  | [] => env
  | (phi, value) :: rest => assignPhis (env.set! phi.destination (some value)) rest

/-- Actual commit code establishes the frame relation for simultaneous source
    assignments. Repeated destinations have sequential last-write behavior;
    source admission separately rules those out. -/
theorem commitPhis_correct (f : StackMIR.Function) (source : Source.Function)
    (env : Source.Environment) (d : Data) (index : Nat)
    (inputs : List (Source.Phi × Source.Value))
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size)
    (capacity : index + inputs.length ≤ phiCapacity source)
    (ready : FrameReady d) (related : LocalsMatch f env d)
    (targets : PhiTargets env.size inputs) (staged : Staged d source.valueWidths.size index inputs) :
    ∃ after, executeMIRList f (StackMIR.commitPhis index (inputs.map Prod.fst)) d = .ok after ∧
      FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      LocalsMatch f (assignPhis env inputs) after := by
  induction inputs generalizing d env index with
  | nil => exact ⟨d, rfl, ready, frame, related⟩
  | cons input rest ih =>
    obtain ⟨phi, value⟩ := input
    simp only [PhiTargets] at targets
    obtain ⟨destBound, width, restTargets⟩ := targets
    obtain ⟨headStaged, tailStaged⟩ := staged
    have stageBound : index < phiCapacity source := by simp only [List.length_cons] at capacity; omega
    have valueBound : phi.destination < source.valueWidths.size := Nat.lt_of_lt_of_le destBound size
    let middle := copied d phi.width (8*phi.destination) value.toNat.toUInt64
    let updated := env.set! phi.destination (some value)
    have middleReady : FrameReady middle := copied_ready _ _ _ _ ready
    have middleFrame : middle.frameBytes = (planFrame source).frameBytes := frame
    have middleRelated : LocalsMatch f updated middle := by
      simpa only [updated, middle, width] using
        localsMatch_store f source env d phi.destination value layout frame size destBound ready related
    have restCapacity : index+1+rest.length ≤ phiCapacity source := by
      simp only [List.length_cons] at capacity
      omega
    have middleStaged : Staged middle source.valueWidths.size (index+1) rest :=
      staged_store source d (index+1) phi.destination phi.width value.toNat.toUInt64 rest
        frame restCapacity valueBound ready tailStaged
    obtain ⟨after, executed, afterReady, afterFrame, afterRelated⟩ :=
      ih updated middle (index+1) middleFrame (by simpa [updated] using size)
        restCapacity middleReady middleRelated (by simpa [updated] using restTargets) middleStaged
    have headExecuted : executeMIRList f
        [.load phi.width .r9 (.stage index), .store phi.width (.value phi.destination) .r9] d = .ok middle :=
      execute_copy f d phi.width (.stage index) (.value phi.destination) _ _ value.toNat.toUInt64 ready
        (planned_stage f source layout index stageBound) (planned_value f source layout phi.destination valueBound)
        headStaged (by rw [frame]; exact value_access_in_frame source phi.destination phi.width valueBound)
    refine ⟨after, ?_, afterReady, afterFrame, afterRelated⟩
    change executeMIRList f
      ([.load phi.width .r9 (.stage index), .store phi.width (.value phi.destination) .r9] ++
        StackMIR.commitPhis (index+1) (rest.map Prod.fst)) d = _
    rw [executeMIRList_append, headExecuted]
    exact executed

/-- Compose both actual lowering phases; the final locals represent values read
    simultaneously from the original predecessor environment. -/
theorem phi_phases_correct (f : StackMIR.Function) (source : Source.Function)
    (env : Source.Environment) (d : Data) (pred : Nat)
    (inputs : List (Source.Phi × Source.Value))
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (capacity : inputs.length ≤ phiCapacity source)
    (ready : FrameReady d) (related : LocalsMatch f env d)
    (selected : PhiInputs pred env inputs) (targets : PhiTargets env.size inputs) :
    ∃ staging after,
      StackMIR.stagePhis pred 0 (inputs.map Prod.fst) = .ok staging ∧
      executeMIRList f (staging ++ StackMIR.commitPhis 0 (inputs.map Prod.fst)) d = .ok after ∧
      FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      LocalsMatch f (assignPhis env inputs) after ∧ CopyContext d after := by
  obtain ⟨staging, middle, lowered, stagedRun, middleReady, middleFrame, middleRelated, staged, _⟩ :=
    stagePhis_correct f source env d pred 0 inputs layout frame size (by simpa using capacity) ready related selected
  obtain ⟨after, committed, afterReady, afterFrame, afterRelated⟩ :=
    commitPhis_correct f source env middle 0 inputs layout middleFrame size (by simpa using capacity)
      middleReady middleRelated targets staged
  have executed : executeMIRList f (staging ++ StackMIR.commitPhis 0 (inputs.map Prod.fst)) d = .ok after := by
    rw [executeMIRList_append, stagedRun]
    exact committed
  exact ⟨staging, after, lowered, executed, afterReady, afterFrame, afterRelated,
    phi_context f pred (inputs.map Prod.fst) staging d after lowered executed⟩

theorem commitPhis_length (index : Nat) (phis : List Source.Phi) :
    (StackMIR.commitPhis index phis).length = 2*phis.length := by
  induction phis generalizing index with
  | nil => rfl
  | cons phi rest ih => simp [StackMIR.commitPhis, ih]; omega

theorem stagePhis_length (pred index : Nat) (phis : List Source.Phi) (code : List StackMIR.Instruction)
    (lowered : StackMIR.stagePhis pred index phis = .ok code) : code.length = 2*phis.length := by
  induction phis generalizing index code with
  | nil => simp [StackMIR.stagePhis] at lowered; subst code; rfl
  | cons phi rest ih =>
    cases found : phi.incoming.find? (·.1 == pred) with
    | none => simp [StackMIR.stagePhis, found, throw] at lowered
    | some incoming =>
      obtain ⟨predecessor, operand⟩ := incoming
      cases tail : StackMIR.stagePhis pred (index+1) rest with
      | error reason => simp [StackMIR.stagePhis, found, tail, bind, Except.bind] at lowered
      | ok tailCode =>
        simp only [StackMIR.stagePhis, found, tail, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at lowered
        subst code
        have length := ih (index+1) tailCode tail
        simp only [List.length_cons]
        omega

/-- A block-ending jump is one actual MIR step. -/
theorem mir_jump (f : StackMIR.Function) (block : StackMIR.Block) (label target : StackMIR.Label)
    (d : Data) (found : f.blocks.find? (·.label == label) = some block)
    (terminator : block.terminator = .jump target) :
    Step (stepMIR f) { label, position := block.instructions.size, data := d }
      { label := target, position := 0, data := d } := by
  simp [Step, stepMIR, found, terminator]
  rfl

/-- The emitted edge, including its jump, executes in exactly four instructions
    per phi plus one terminator and establishes the simultaneous-value relation.
    Membership in the enclosing lowered function is an explicit premise. -/
theorem lowerEdge_steps (f : StackMIR.Function) (source : Source.Function) (block : Source.Block)
    (env : Source.Environment) (d : Data) (pred target : Nat)
    (inputs : List (Source.Phi × Source.Value))
    (found : source.blocks[target]? = some block) (phis : block.phis.toList = inputs.map Prod.fst)
    (present : ∀ edge, StackMIR.lowerEdge source pred target = .ok edge →
      f.blocks.find? (·.label == .edge pred target) = some edge)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (capacity : inputs.length ≤ phiCapacity source)
    (ready : FrameReady d) (related : LocalsMatch f env d)
    (selected : PhiInputs pred env inputs) (targets : PhiTargets env.size inputs) :
    ∃ after, Steps (stepMIR f) (4*inputs.length+1)
        { label := .edge pred target, data := d } { label := .body target, data := after } ∧
      FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      LocalsMatch f (assignPhis env inputs) after ∧ CopyContext d after := by
  obtain ⟨staging, after, staged, executed, afterReady, afterFrame, afterRelated, context⟩ :=
    phi_phases_correct f source env d pred inputs layout frame size capacity ready related selected targets
  let code := staging ++ StackMIR.commitPhis 0 (inputs.map Prod.fst)
  let edge : StackMIR.Block := {
    label := .edge pred target, instructions := code.toArray, terminator := .jump (.body target) }
  have lowered : StackMIR.lowerEdge source pred target = .ok edge := by
    simp [StackMIR.lowerEdge, found, phis, staged, edge, code, bind, Except.bind, pure, Except.pure]
  have member := present edge lowered
  have length : code.length = 4*inputs.length := by
    have stageLength := stagePhis_length pred 0 (inputs.map Prod.fst) staging staged
    simp only [List.length_map] at stageLength
    simp only [code, List.length_append, commitPhis_length, List.length_map]
    omega
  have body : Steps (stepMIR f) code.length { label := .edge pred target, data := d }
      { label := .edge pred target, position := code.length, data := after } := by
    simpa only [Nat.zero_add] using executeMIRList_steps f edge (.edge pred target) 0 code d after member (by
      intro i _
      simp [edge]) executed
  have jump : Steps (stepMIR f) 1
      { label := .edge pred target, position := code.length, data := after }
      { label := .body target, data := after } :=
    .succ (by simpa only [edge, List.size_toArray] using
      mir_jump f edge (.edge pred target) (.body target) after member rfl) (.zero _)
  refine ⟨after, ?_, afterReady, afterFrame, afterRelated, context⟩
  simpa only [length] using steps_append _ body jump

end LeanCompilerBackend.Verified.Machine
