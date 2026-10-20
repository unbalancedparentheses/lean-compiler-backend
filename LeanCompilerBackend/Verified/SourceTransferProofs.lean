/- Connect simultaneous-value assignments to the source interpreter's actual loops. -/
import LeanCompilerBackend.Verified.CommitProofs

namespace LeanCompilerBackend.Verified.Source

/-- The body of the source transfer's first loop, kept definitionally identical. -/
def collectPhi (pred target : Nat) (env : Environment) (phi : Phi)
    (pending : Array (ValueId × Value)) : Except Fault (ForInStep (Array (ValueId × Value))) := do
  let incoming := phi.incoming.filter (·.1 == pred)
  if incoming.size != 1 || pending.any (·.1 == phi.destination) then throw (.invalidPhi target)
  let some (_, operand) := incoming[0]? | throw (.invalidPhi target)
  let value ← read env phi.width operand
  pure (.yield (pending.push (phi.destination, value)))

def commitPhi (f : Function) (item : ValueId × Value) (env : Environment) : Except Fault (ForInStep Environment) := do
  let updated ← write f env item.1 item.2
  pure (.yield updated)

/-- No alternate source transfer semantics: these are the actual interpreter loops. -/
theorem transfer_loops (f : Function) (pred target : Nat) (env : Environment) (block : Block)
    (found : f.blocks[target]? = some block) :
    transfer f pred target env = (do
      let pending ← forIn block.phis #[] (collectPhi pred target env)
      let updated ← forIn pending env (commitPhi f)
      pure { block := target, position := 0, environment := updated }) := by
  simp only [transfer, found]
  rfl

/-- Exact source-loop preconditions: one incoming predecessor, no duplicate
    destinations accumulated so far, and successful reads in the old environment. -/
def TransferInputs (pred : Nat) (env : Environment) (pending : Array (ValueId × Value)) :
    List (Phi × Value) → Prop
  | [] => True
  | (phi, value) :: rest => ∃ operand,
      phi.incoming.filter (·.1 == pred) = #[(pred, operand)] ∧
      pending.any (·.1 == phi.destination) = false ∧
      read env phi.width operand = .ok value ∧
      TransferInputs pred env (pending.push (phi.destination, value)) rest

def pendingPairs (inputs : List (Phi × Value)) : List (ValueId × Value) :=
  inputs.map (fun (phi, value) => (phi.destination, value))

theorem transferInputs_selected (pred : Nat) (env : Environment) (pending : Array (ValueId × Value))
    (inputs : List (Phi × Value)) (valid : TransferInputs pred env pending inputs) :
    Machine.PhiInputs pred env inputs := by
  induction inputs generalizing pending with
  | nil => trivial
  | cons input rest ih =>
    obtain ⟨phi, value⟩ := input
    obtain ⟨operand, incoming, _, read, tail⟩ := valid
    refine ⟨operand, ?_, read, ih _ tail⟩
    rw [← Array.getElem?_zero_filter, incoming]
    rfl

theorem collectPhi_ok (pred target : Nat) (env : Environment) (pending : Array (ValueId × Value))
    (phi : Phi) (value : Value) (operand : Operand)
    (incoming : phi.incoming.filter (·.1 == pred) = #[(pred, operand)])
    (fresh : pending.any (·.1 == phi.destination) = false) (read : Source.read env phi.width operand = .ok value) :
    collectPhi pred target env phi pending = .ok (.yield (pending.push (phi.destination, value))) := by
  simp [collectPhi, incoming, fresh, read, bind, Except.bind, pure, Except.pure]

theorem collectPhis_ok (pred target : Nat) (env : Environment) (pending : Array (ValueId × Value))
    (inputs : List (Phi × Value)) (valid : TransferInputs pred env pending inputs) :
    forIn (inputs.map Prod.fst) pending (collectPhi pred target env) =
      .ok (pending ++ (pendingPairs inputs).toArray) := by
  induction inputs generalizing pending with
  | nil => simp [pendingPairs, pure, Except.pure]
  | cons input rest ih =>
    obtain ⟨phi, value⟩ := input
    obtain ⟨operand, incoming, fresh, read, tail⟩ := valid
    simp only [List.map_cons, List.forIn_cons, collectPhi_ok pred target env pending phi value operand incoming fresh read,
      bind, Except.bind]
    rw [ih _ tail]
    simp [pendingPairs, Array.push_eq_append, Array.append_assoc, -Array.append_singleton]

/-- Bounds and declared widths required by the source environment writer. -/
def TransferTargets (f : Function) (size : Nat) : List (Phi × Value) → Prop
  | [] => True
  | (phi, value) :: rest => phi.destination < size ∧
      f.valueWidths[phi.destination]? = some value.width ∧ TransferTargets f size rest

theorem write_ok (f : Function) (env : Environment) (id : ValueId) (value : Value)
    (inside : id < env.size) (width : f.valueWidths[id]? = some value.width) :
    write f env id value = .ok (env.set! id (some value)) := by
  have same : (value.width != value.width) = false := by cases value <;> rfl
  simp [write, width, Nat.not_le.mpr inside, same, pure, Except.pure]

theorem transferTargets_valid (f : Function) (pred : Nat) (env : Environment)
    (pending : Array (ValueId × Value)) (inputs : List (Phi × Value))
    (selected : TransferInputs pred env pending inputs) (targets : TransferTargets f env.size inputs) :
    Machine.PhiTargets env.size inputs := by
  induction inputs generalizing pending with
  | nil => trivial
  | cons input rest ih =>
    obtain ⟨phi, value⟩ := input
    obtain ⟨operand, _, _, read, tail⟩ := selected
    obtain ⟨inside, _, targets⟩ := targets
    exact ⟨inside, (read_ok env phi.width operand value read).1.symm, ih _ tail targets⟩

theorem commitPhis_ok (f : Function) (env : Environment) (inputs : List (Phi × Value))
    (targets : TransferTargets f env.size inputs) :
    forIn (pendingPairs inputs) env (commitPhi f) = .ok (Machine.assignPhis env inputs) := by
  induction inputs generalizing env with
  | nil => rfl
  | cons input rest ih =>
    obtain ⟨phi, value⟩ := input
    obtain ⟨inside, width, tail⟩ := targets
    simp only [pendingPairs, List.map_cons, List.forIn_cons, commitPhi,
      write_ok f env phi.destination value inside width, bind, Except.bind, pure, Except.pure]
    exact ih _ (by simpa using tail)

/-- Simultaneous assignments in the target proof equal the source interpreter's
    actual checked transfer, including both of its original array loops. -/
theorem transfer_assigns (f : Function) (pred target : Nat) (env : Environment) (block : Block)
    (inputs : List (Phi × Value)) (found : f.blocks[target]? = some block)
    (phis : block.phis.toList = inputs.map Prod.fst)
    (selected : TransferInputs pred env #[] inputs) (targets : TransferTargets f env.size inputs) :
    transfer f pred target env = .ok { block := target, position := 0, environment := Machine.assignPhis env inputs } := by
  rw [transfer_loops f pred target env block found]
  rw [← Array.forIn_toList, phis, collectPhis_ok pred target env #[] inputs selected]
  simp only [Array.empty_append, bind, Except.bind]
  rw [← Array.forIn_toList]
  rw [commitPhis_ok f env inputs targets]
  rfl

/-- Actual source transfer and actual emitted MIR edge execute related states.
    Admission soundness and enclosing-function edge membership remain premises. -/
theorem transfer_correct (f : StackMIR.Function) (source : Function) (block : Block)
    (env : Environment) (d : Machine.Data) (pred target : Nat) (inputs : List (Phi × Value))
    (found : source.blocks[target]? = some block) (phis : block.phis.toList = inputs.map Prod.fst)
    (present : ∀ edge, StackMIR.lowerEdge source pred target = .ok edge →
      f.blocks.find? (·.label == .edge pred target) = some edge)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (capacity : inputs.length ≤ phiCapacity source)
    (ready : Machine.FrameReady d) (related : Machine.LocalsMatch f env d)
    (selected : TransferInputs pred env #[] inputs) (targets : TransferTargets source env.size inputs) :
    ∃ after updated,
      transfer source pred target env = .ok { block := target, position := 0, environment := updated } ∧
      Machine.Steps (Machine.stepMIR f) (4*inputs.length+1)
        { label := .edge pred target, data := d } { label := .body target, data := after } ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f updated after ∧ Machine.CopyContext d after := by
  obtain ⟨after, steps, afterReady, afterFrame, afterRelated, context⟩ :=
    Machine.lowerEdge_steps f source block env d pred target inputs found phis present layout frame size capacity
      ready related (transferInputs_selected pred env #[] inputs selected)
      (transferTargets_valid source pred env #[] inputs selected targets)
  exact ⟨after, Machine.assignPhis env inputs,
    transfer_assigns source pred target env block inputs found phis selected targets,
    steps, afterReady, afterFrame, afterRelated, context⟩

end LeanCompilerBackend.Verified.Source
