/- Source operands and their actual MIR lowering under a frame-value relation. -/
import LeanCompilerBackend.Verified.TransferProofs

namespace LeanCompilerBackend.Verified

namespace Source

/-- A successful source read has the requested width and the selected value. -/
theorem read_ok (env : Environment) (w : Width) (operand : Operand) (v : Value)
    (h : read env w operand = .ok v) :
    v.width = w ∧ (match operand with
      | .literal value => value = v
      | .local id => env[id]? = some (some v)) := by
  have widthCheck (a b : Width) : (a != b) = decide (a ≠ b) := by
    cases a <;> cases b <;> rfl
  cases operand with
  | literal value =>
    simp only [read, bind, Except.bind, pure, Except.pure, widthCheck] at h
    split at h
    · cases h
    · cases h
      simp_all
  | «local» id =>
    cases lookup : env[id]? with
    | none => simp [read, lookup, bind, Except.bind, throw] at h
    | some found =>
      cases found with
      | none => simp [read, lookup, bind, Except.bind, throw] at h
      | some value =>
        simp only [read, lookup, bind, Except.bind, pure, Except.pure, widthCheck] at h
        split at h
        · cases h
        · cases h
          simp_all

end Source

namespace Machine

/-- Every defined SSA value is represented in its own frame slot. Undefined
    values impose no obligation; successful source reads establish availability. -/
def LocalsMatch (f : StackMIR.Function) (env : Source.Environment) (d : Data) : Prop :=
  ∀ id value, env[id]? = some (some value) →
    ∃ offset, StackMIR.offset f (.value id) = .ok offset ∧
      load d value.width offset = .ok value.toNat.toUInt64

/-- Lowering an available, well-typed operand performs exactly the corresponding
    register write. Register validity is left to the shared write operation. -/
theorem loadOperand_correct (f : StackMIR.Function) (env : Source.Environment) (d : Data)
    (w : Width) (reg : StackMIR.Register) (operand : Source.Operand) (v : Source.Value)
    (related : LocalsMatch f env d) (read : Source.read env w operand = .ok v) :
    executeMIR f d (StackMIR.loadOperand w reg operand) =
      writeReg d w reg.index v.toNat.toUInt64 := by
  obtain ⟨width, value⟩ := Source.read_ok env w operand v read
  cases operand with
  | literal constant =>
    cases value
    simp only [StackMIR.loadOperand, executeMIR, width]
  | «local» id =>
    obtain ⟨offset, found, loaded⟩ := related id v value
    rw [width] at loaded
    simp only [StackMIR.loadOperand, executeMIR, found, loaded, bind, Except.bind]

/-- Register-only updates do not change the meaning of any source local. -/
theorem localsMatch_registers (f : StackMIR.Function) (env : Source.Environment) (d : Data)
    (registers : Array UInt64) (related : LocalsMatch f env d) :
    LocalsMatch f env { d with registers } := by
  exact related

theorem value_normalized (v : Source.Value) :
    normalize v.width v.toNat.toUInt64 = v.toNat.toUInt64 := by
  cases v with
  | word bits =>
    change bits.toNat.toUInt64.toUInt32.toUInt64 = bits.toNat.toUInt64
    apply UInt64.toNat_inj.mp
    simp
  | long bits => rfl

/-- Both literal and local copies use the actual operand lowering and store. -/
theorem operand_copy (f : StackMIR.Function) (env : Source.Environment) (d : Data)
    (w : Width) (operand : Source.Operand) (v : Source.Value) (dst : StackMIR.Slot) (offset : Nat)
    (ready : FrameReady d) (related : LocalsMatch f env d)
    (read : Source.read env w operand = .ok v)
    (target : StackMIR.offset f dst = .ok offset) (access : offset + w.bytes ≤ d.frameBytes) :
    executeMIRList f [StackMIR.loadOperand w .r9 operand, .store w dst .r9] d =
      .ok (copied d w offset v.toNat.toUInt64) := by
  have reg : 9 < d.registers.size := by rw [ready.registers]; decide
  let written := { d with registers := d.registers.set! 9 (normalize w v.toNat.toUInt64) }
  have stored := store_in_frame written w offset (normalize w v.toNat.toUInt64)
    ready.active ready.space ready.sp ready.memory access ready.nowrap
  rw [executeMIRList, loadOperand_correct f env d w .r9 operand v related read]
  simp only [writeReg, show ¬9 ≥ 31 by decide, Nat.not_le.mpr reg,
    decide_false, Bool.false_or, Bool.false_eq_true, ↓reduceIte, pure, Except.pure,
    bind, Except.bind, executeMIRList, executeMIR, target, StackMIR.Register.index,
    readReg, Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_self_of_lt reg,
    normalize_idempotent]
  change (store written w offset (normalize w v.toNat.toUInt64) >>= Except.ok) = _
  rw [stored]
  rfl

/-- Canonical layout lookup, shared by the value relation and staging proof. -/
theorem planned_value (f : StackMIR.Function) (source : Source.Function)
    (layout : f.layout = planFrame source) (id : Nat) (inside : id < source.valueWidths.size) :
    StackMIR.offset f (.value id) = .ok (8*id) := by
  simp only [StackMIR.offset, layout, value_offset source id inside]

theorem planned_stage (f : StackMIR.Function) (source : Source.Function)
    (layout : f.layout = planFrame source) (id : Nat) (inside : id < phiCapacity source) :
    StackMIR.offset f (.stage id) = .ok (8*(source.valueWidths.size+id)) := by
  simp only [StackMIR.offset, layout, stage_offset source id inside]

/-- Every staging write preserves every defined source local, at either width. -/
theorem localsMatch_stage (f : StackMIR.Function) (source : Source.Function)
    (env : Source.Environment) (d : Data) (index : Nat) (w : Width) (value : UInt64)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : index < phiCapacity source)
    (ready : FrameReady d) (related : LocalsMatch f env d) :
    LocalsMatch f env (copied d w (8*(source.valueWidths.size+index)) value) := by
  intro id v found
  have bound : id < source.valueWidths.size := by
    have h := Array.getElem?_eq_some_iff.mp found |>.1
    omega
  obtain ⟨offset, lookup, loaded⟩ := related id v found
  have canonical := planned_value f source layout id bound
  rw [canonical] at lookup
  cases lookup
  refine ⟨8*id, canonical, ?_⟩
  rw [copied_load_disjoint d v.width w (8*id) (8*(source.valueWidths.size+index)) value ready
    (by rw [frame]; exact value_access_in_frame source id v.width bound)
    (by rw [frame]; exact stage_access_in_frame source index w inside)
    (Or.inl (value_stage_disjoint source id index v.width bound))]
  exact loaded

end Machine
end LeanCompilerBackend.Verified
