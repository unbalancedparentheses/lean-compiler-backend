/- A fully admitted loop whose backedge instantiates the cyclic-transfer proof. -/
import LeanCompilerBackend.Verified.PhiSwapProof
import LeanCompilerBackend.Verified.DivergenceProofs
import LeanCompilerBackend.Verified.EntryProofs
import LeanCompilerBackend.Verified.SourceTransferProofs

set_option maxRecDepth 10000

namespace LeanCompilerBackend.Verified.PhiExamples

private def exceptDecidable [DecidableEq ε] [DecidableEq α] : (a b : Except ε α) → Decidable (a = b)
  | .error a, .error b => if h : a = b then .isTrue (congrArg Except.error h)
      else .isFalse (fun eq => h (Except.error.inj eq))
  | .ok a, .ok b => if h : a = b then .isTrue (congrArg Except.ok h)
      else .isFalse (fun eq => h (Except.ok.inj eq))
  | .error _, .ok _ => .isFalse (by intro eq; cases eq)
  | .ok _, .error _ => .isFalse (by intro eq; cases eq)

local instance [DecidableEq ε] [DecidableEq α] : DecidableEq (Except ε α) := exceptDecidable


/-- Initialization supplies 11/22; the self backedge exchanges the two values. -/
def cycleSource (w : Width) : Source.Function := {
  resultWidth := w, parameters := #[], valueWidths := #[w, w],
  blocks := #[
    { phis := #[], instructions := #[], terminator := .jump 1 },
    { phis := Machine.swapPhis w
        #[(0, .literal (Source.Value.constant w 11)), (1, .local 1)]
        #[(0, .literal (Source.Value.constant w 22)), (1, .local 0)],
      instructions := #[], terminator := .jump 1 }] }

def cycleMIR (w : Width) : StackMIR.Function :=
  match StackMIR.lower (cycleSource w) (planFrame (cycleSource w)) with
  | .ok f => f
  | .error _ => { parameters := #[], resultWidth := w, valueWidths := #[],
                  layout := { valueOffsets := #[], stageOffsets := #[], frameBytes := 0 }, blocks := #[] }

theorem cycle_admitted (w : Width) : validateSource (cycleSource w) = .ok () := by
  cases w <;> decide +kernel

theorem cycle_lowered (w : Width) :
    StackMIR.lower (cycleSource w) (planFrame (cycleSource w)) = .ok (cycleMIR w) := by
  cases w <;> decide +kernel

theorem cycle_legal (w : Width) : StackMIR.validate (cycleMIR w) = .ok () := by
  cases w <;> decide +kernel

theorem cycle_layout (w : Width) :
    StackMIR.offset (cycleMIR w) (.value 0) = .ok 0 ∧
    StackMIR.offset (cycleMIR w) (.value 1) = .ok 8 ∧
    StackMIR.offset (cycleMIR w) (.stage 0) = .ok 16 ∧
    StackMIR.offset (cycleMIR w) (.stage 1) = .ok 24 ∧
    (cycleMIR w).layout.frameBytes = 32 := by
  cases w <;> decide +kernel

theorem cycle_edge (w : Width) :
    (cycleMIR w).blocks.find? (·.label == .edge 1 1) = some {
      label := .edge 1 1, instructions := (Machine.swapCode w).toArray,
      terminator := .jump (.body 1) } := by
  cases w <;> decide +kernel

/-- A universally quantified execution result for the admitted fixture, not a
    computation on just its 11/22 sample values. -/
theorem cycle_transfer (w : Width) (d : Machine.Data) (a b : UInt64)
    (ready : Machine.FrameReady d) (frame : d.frameBytes = 32)
    (read0 : Machine.load d w 0 = .ok a) (read1 : Machine.load d w 8 = .ok b) :
    ∃ after, Machine.Steps (Machine.stepMIR (cycleMIR w)) 8
        { label := .edge 1 1, data := d } { label := .edge 1 1, position := 8, data := after } ∧
      Machine.load after w 0 = .ok (Machine.normalize w b) ∧
      Machine.load after w 8 = .ok (Machine.normalize w a) ∧ Machine.FrameReady after ∧
      ∀ reg, reg ≠ 9 → after.registers[reg]? = d.registers[reg]? := by
  obtain ⟨v0, v1, s0, s1, _⟩ := cycle_layout w
  exact Machine.phi_swap_steps (cycleMIR w) d w a b 1 1 ready (by omega)
    v0 v1 s0 s1 read0 read1 (cycle_edge w)

def sourceLoop (w : Width) (a b : Nat) : Source.State :=
  { block := 1, position := 0, environment := #[some (Source.Value.constant w a), some (Source.Value.constant w b)] }

theorem source_cycle (w : Width) :
    Source.Step (cycleSource w) (sourceLoop w 11 22) (sourceLoop w 22 11) ∧
    Source.Step (cycleSource w) (sourceLoop w 22 11) (sourceLoop w 11 22) := by
  unfold Source.Step
  cases w <;> decide +kernel

theorem source_diverges (w : Width) : Source.HasBehavior (cycleSource w) #[] .diverges := by
  let entry : Source.State := { block := 0, position := 0, environment := #[none, none] }
  have init : Source.initial (cycleSource w) #[] = .ok entry := by cases w <;> decide +kernel
  have enter : Source.Step (cycleSource w) entry (sourceLoop w 11 22) := by unfold Source.Step; cases w <;> decide +kernel
  obtain ⟨ab, ba⟩ := source_cycle w
  have alternating : ∀ n,
      (∃ t, Source.Steps (cycleSource w) n (sourceLoop w 11 22) t) ∧
      (∃ t, Source.Steps (cycleSource w) n (sourceLoop w 22 11) t) := by
    intro n
    induction n with
    | zero => exact ⟨⟨_, .zero _⟩, ⟨_, .zero _⟩⟩
    | succ n ih =>
      obtain ⟨⟨a, ha⟩, ⟨b, hb⟩⟩ := ih
      exact ⟨⟨b, .succ ab hb⟩, ⟨a, .succ ba ha⟩⟩
  refine ⟨entry, init, ?_⟩
  intro n
  cases n with
  | zero => exact ⟨_, .zero _⟩
  | succ n =>
    obtain ⟨t, ht⟩ := (alternating n).1
    exact ⟨t, .succ enter ht⟩

/-- Exact live frame after initialization or a backedge, including staging slots. -/
def machineLoop (w : Width) (a b : UInt64) : Machine.State :=
  let d := (Machine.initialState #[] 32 1048576).data
  { label := .body 1, data := { d with
      registers := d.registers.set! 9 b, sp := 1048544, active := true,
      memory := Machine.writeBytes w.bytes 24 b
        (Machine.writeBytes w.bytes 16 a
          (Machine.writeBytes w.bytes 8 b (Machine.writeBytes w.bytes 0 a d.memory))) } }

theorem mir_entry_run (w : Width) :
    Machine.run (Machine.stepMIR (cycleMIR w)) 12 (Machine.initialState #[] 32 1048576) =
      .exhausted (machineLoop w 11 22) := by
  cases w <;> decide +kernel

theorem mir_cycle_run (w : Width) :
    Machine.run (Machine.stepMIR (cycleMIR w)) 10 (machineLoop w 11 22) =
      .exhausted (machineLoop w 22 11) ∧
    Machine.run (Machine.stepMIR (cycleMIR w)) 10 (machineLoop w 22 11) =
      .exhausted (machineLoop w 11 22) := by
  cases w <;> decide +kernel

theorem mir_diverges (w : Width) :
    Machine.Diverges (Machine.stepMIR (cycleMIR w)) (Machine.initialState #[] 32 1048576) := by
  obtain ⟨ab, ba⟩ := mir_cycle_run w
  have cycle := Machine.steps_append _
    (Machine.run_exhausted_prefix _ _ _ _ ab) (Machine.run_exhausted_prefix _ _ _ _ ba)
  exact Machine.prefix_diverges _ (Machine.run_exhausted_prefix _ _ _ _ (mir_entry_run w))
    (Machine.cycle_diverges _ cycle (by decide))

def cycleAssembly (w : Width) : TypedA64.Function :=
  match TypedA64.select (cycleMIR w) with
  | .ok f => f
  | .error _ => { parameters := #[], resultWidth := w, frameBytes := 0, blocks := #[] }

theorem assembly_selected (w : Width) :
    TypedA64.select (cycleMIR w) = .ok (cycleAssembly w) := by
  cases w <;> decide +kernel

theorem assembly_legal (w : Width) : TypedA64.validate (cycleAssembly w) = .ok () := by
  cases w <;> decide +kernel

theorem assembly_entry_run (w : Width) :
    Machine.run (Machine.stepAssembly (cycleAssembly w)) 12
        (Machine.assemblyEntry (Machine.initialState #[] 32 1048576)) =
      .exhausted (machineLoop w 11 22) := by
  cases w <;> decide +kernel

theorem assembly_cycle_run (w : Width) :
    Machine.run (Machine.stepAssembly (cycleAssembly w)) 10 (machineLoop w 11 22) =
      .exhausted (machineLoop w 22 11) ∧
    Machine.run (Machine.stepAssembly (cycleAssembly w)) 10 (machineLoop w 22 11) =
      .exhausted (machineLoop w 11 22) := by
  cases w <;> decide +kernel

theorem assembly_diverges (w : Width) :
    Machine.Diverges (Machine.stepAssembly (cycleAssembly w))
      (Machine.assemblyEntry (Machine.initialState #[] 32 1048576)) := by
  obtain ⟨ab, ba⟩ := assembly_cycle_run w
  have cycle := Machine.steps_append _
    (Machine.run_exhausted_prefix _ _ _ _ ab) (Machine.run_exhausted_prefix _ _ _ _ ba)
  exact Machine.prefix_diverges _ (Machine.run_exhausted_prefix _ _ _ _ (assembly_entry_run w))
    (Machine.cycle_diverges _ cycle (by decide))

/-- A non-vacuous whole-loop witness through the actual two lowering passes.
    This is one admitted family, not a theorem for all admitted programs. -/
theorem cycle_behavior (w : Width) :
    ∃ mir asm s,
      validateSource (cycleSource w) = .ok () ∧
      StackMIR.lower (cycleSource w) (planFrame (cycleSource w)) = .ok mir ∧
      TypedA64.select mir = .ok asm ∧
      Machine.initial mir.parameters #[] mir.layout.frameBytes = .ok s ∧
      Machine.EntryState mir.parameters #[] mir.layout.frameBytes false s ∧
      Machine.EntryState mir.parameters #[] mir.layout.frameBytes true (Machine.assemblyEntry s) ∧
      Source.HasBehavior (cycleSource w) #[] .diverges ∧
      Machine.HasBehavior (Machine.stepMIR mir) s .diverges ∧
      Machine.HasBehavior (Machine.stepAssembly asm) (Machine.assemblyEntry s) .diverges := by
  have init : Machine.initial (cycleMIR w).parameters #[] (cycleMIR w).layout.frameBytes =
      .ok (Machine.initialState #[] 32 1048576) := by cases w <;> decide +kernel
  have entry := Machine.initial_sound _ _ _ _ _ init
  exact ⟨cycleMIR w, cycleAssembly w, Machine.initialState #[] 32 1048576,
    cycle_admitted w, cycle_lowered w, assembly_selected w, init, entry,
    Machine.assemblyEntry_sound _ _ _ _ entry, source_diverges w, mir_diverges w,
    assembly_diverges w⟩

/-- The backedge values are arbitrary; initialization literals only belong to
    the other incoming edge. -/
def swapInputs (w : Width) (a b : Source.Value) : List (Source.Phi × Source.Value) := [
  ({ destination := 0, width := w,
      incoming := #[(0, .literal (Source.Value.constant w 11)), (1, .local 1)] }, b),
  ({ destination := 1, width := w,
      incoming := #[(0, .literal (Source.Value.constant w 22)), (1, .local 0)] }, a)]

theorem swap_inputs (w : Width) (a b : Source.Value) (ha : a.width = w) (hb : b.width = w) :
    Source.TransferInputs 1 #[some a, some b] #[] (swapInputs w a b) := by
  have same : (w != w) = false := by cases w <;> rfl
  have read0 : Source.read #[some a, some b] w (.local 0) = .ok a := by
    simp [Source.read, ha, same, bind, Except.bind, pure, Except.pure]
  have read1 : Source.read #[some a, some b] w (.local 1) = .ok b := by
    simp [Source.read, hb, same, bind, Except.bind, pure, Except.pure]
  refine ⟨.local 1, ?_, by simp, read1, .local 0, ?_, ?_, read0, trivial⟩
  · cases w <;> decide +kernel
  · cases w <;> decide +kernel
  · simp

theorem swap_targets (w : Width) (a b : Source.Value) (ha : a.width = w) (hb : b.width = w) :
    Source.TransferTargets (cycleSource w) 2 (swapInputs w a b) := by
  simp [Source.TransferTargets, cycleSource, swapInputs, ha, hb]

/-- The general source/MIR transfer theorem applies to an actually admitted,
    lowered loop for arbitrary source values and compatible machine data. -/
theorem swap_simulation (w : Width) (a b : Source.Value) (d : Machine.Data)
    (ha : a.width = w) (hb : b.width = w) (ready : Machine.FrameReady d) (frame : d.frameBytes = 32)
    (related : Machine.LocalsMatch (cycleMIR w) #[some a, some b] d) :
    ∃ after updated,
      Source.transfer (cycleSource w) 1 1 #[some a, some b] =
        .ok { block := 1, position := 0, environment := updated } ∧
      Machine.Steps (Machine.stepMIR (cycleMIR w)) 9
        { label := .edge 1 1, data := d } { label := .body 1, data := after } ∧
      Machine.FrameReady after ∧ after.frameBytes = 32 ∧
      Machine.LocalsMatch (cycleMIR w) updated after ∧ Machine.CopyContext d after := by
  let block : Source.Block := {
    phis := ((swapInputs w a b).map Prod.fst).toArray
    instructions := #[], terminator := .jump 1 }
  have sourceBlock : (cycleSource w).blocks[1]? = some block := by rfl
  have phis : block.phis.toList = (swapInputs w a b).map Prod.fst := by simp [block]
  have layout : (cycleMIR w).layout = planFrame (cycleSource w) := by cases w <;> decide +kernel
  have frameSize : (planFrame (cycleSource w)).frameBytes = 32 := by cases w <;> decide +kernel
  have capacity : (swapInputs w a b).length ≤ phiCapacity (cycleSource w) := by
    change 2 ≤ phiCapacity (cycleSource w)
    cases w <;> decide +kernel
  have lower : StackMIR.lowerEdge (cycleSource w) 1 1 = .ok {
      label := .edge 1 1, instructions := (Machine.swapCode w).toArray,
      terminator := .jump (.body 1) } := by cases w <;> decide +kernel
  have present : ∀ edge, StackMIR.lowerEdge (cycleSource w) 1 1 = .ok edge →
      (cycleMIR w).blocks.find? (·.label == .edge 1 1) = some edge := by
    intro edge h
    rw [lower] at h
    cases h
    exact cycle_edge w
  have result := Source.transfer_correct (cycleMIR w) (cycleSource w) block #[some a, some b] d 1 1
    (swapInputs w a b) sourceBlock phis present layout (by simpa [frameSize] using frame)
    (by simp [cycleSource]) capacity ready related (swap_inputs w a b ha hb) (swap_targets w a b ha hb)
  simpa only [swapInputs, List.length_cons, List.length_nil, frameSize] using result

/-- A concrete live frame satisfies the general theorem's value relation. -/
theorem loop_related (w : Width) :
    Machine.LocalsMatch (cycleMIR w) (sourceLoop w 11 22).environment (machineLoop w 11 22).data := by
  intro id value found
  cases id with
  | zero =>
    have same : Source.Value.constant w 11 = value := by simpa [sourceLoop] using found
    subst value
    refine ⟨0, ?_, ?_⟩ <;> cases w <;> decide +kernel
  | succ id =>
    cases id with
    | zero =>
      have same : Source.Value.constant w 22 = value := by simpa [sourceLoop] using found
      subst value
      refine ⟨8, ?_, ?_⟩ <;> cases w <;> decide +kernel
    | succ id => simp [sourceLoop] at found

theorem loop_ready (w : Width) : Machine.FrameReady (machineLoop w 11 22).data := by
  constructor <;> cases w <;> decide +kernel

end LeanCompilerBackend.Verified.PhiExamples
