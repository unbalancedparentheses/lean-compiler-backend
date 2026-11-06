/- Division and remainder simulation through the actual MIR lowering. The target
   operation is total, like AArch64 UDIV/SDIV/MSUB; a source step exists only for
   a defined divisor, so only defined operations carry a simulation obligation. -/
import LeanCompilerBackend.Verified.ComparisonProofs

namespace LeanCompilerBackend.Verified.Machine

/-- MSUB of the unsigned quotient forms the unsigned remainder (no wrap occurs). -/
theorem udiv_msub {n : Nat} (x y : BitVec n) : x - (x / y) * y = x % y := by
  apply BitVec.eq_of_toNat_eq
  have le : (x / y).toNat * y.toNat ≤ x.toNat := by
    rw [BitVec.toNat_udiv]; exact Nat.div_mul_le_self _ _
  have product : ((x / y) * y).toNat = (x / y).toNat * y.toNat := by
    rw [BitVec.toNat_mul]; exact Nat.mod_eq_of_lt (Nat.lt_of_le_of_lt le x.isLt)
  have ordered : (x / y) * y ≤ x := by
    rw [BitVec.le_def, product]; exact le
  rw [BitVec.toNat_sub_of_le ordered, product, BitVec.toNat_umod, BitVec.toNat_udiv, Nat.mod_def, Nat.mul_comm]

/-- Truncating integer division of the two's-complement values, reduced to the
    width, is `sdiv` for every input, including a zero divisor and MIN / -1. -/
theorem sdiv_ofInt {n : Nat} (x y : BitVec n) :
    BitVec.ofInt n (x.toInt.tdiv y.toInt) = x.sdiv y := by
  apply BitVec.eq_of_toInt_eq
  rw [BitVec.toInt_ofInt, BitVec.toInt_sdiv]

/-- MSUB of the signed quotient forms the signed remainder, for every input. -/
theorem sdiv_msub {n : Nat} (x y : BitVec n) : x - x.sdiv y * y = x.srem y := by
  rw [← sdiv_ofInt]
  apply BitVec.eq_of_toInt_eq
  rw [← BitVec.toInt_bmod_cancel (x.srem y), BitVec.toInt_srem, Int.tmod_def,
    BitVec.toInt_sub, BitVec.toInt_mul, BitVec.toInt_ofInt, Int.bmod_mul_bmod, Int.sub_bmod_bmod,
    Int.mul_comm]

/-- The target division sequence computes the source bit-vector operation at the
    selected width for all register contents. Only the source adds faults. -/
theorem divide_bits (w : Width) (op : Source.Division) (a b : UInt64) :
    sourceView w (divide w op a b) = match w with
      | .word => .word (Source.divisionBits op a.toUInt32.toBitVec b.toUInt32.toBitVec)
      | .long => .long (Source.divisionBits op a.toBitVec b.toBitVec) := by
  cases w
  · cases op <;> simp only [sourceView, divide, quotient, multiplySubtract, normalize, Source.divisionBits,
      UInt32.toUInt32_toUInt64, UInt64.toUInt32_sub, UInt64.toUInt32_mul, UInt32.toBitVec_sub,
      UInt32.toBitVec_mul, UInt32.toBitVec_div, UInt64.toBitVec_toUInt32, ofInt_bits, word_ofInt,
      signedValue_word, sdiv_ofInt, udiv_msub, sdiv_msub]
  · cases op <;> simp only [sourceView, divide, quotient, multiplySubtract, normalize, Source.divisionBits,
      UInt64.toBitVec_sub, UInt64.toBitVec_mul, UInt64.toBitVec_div, ofInt_bits,
      signedValue_long, sdiv_ofInt, udiv_msub, sdiv_msub]

/-- Wherever the source division is defined, the target computes its value. -/
theorem divide_preserves (w : Width) (op : Source.Division) (a b : UInt64) (value : Source.Value)
    (defined : Source.evaluateDivision op (sourceView w a) (sourceView w b) = .ok value) :
    value = sourceView w (divide w op a b) := by
  rw [divide_bits]
  cases w <;> simp only [sourceView, Source.evaluateDivision] at defined <;> split at defined <;>
    first | (cases defined; rfl) | cases defined

theorem division_expansion (f : StackMIR.Function) (env : Source.Environment) (d : Data)
    (w : Width) (op : Source.Division) (lhs rhs : Source.Operand) (a b : Source.Value)
    (dest : StackMIR.Slot) (offset : Nat) (ready : FrameReady d) (related : LocalsMatch f env d)
    (left : Source.read env w lhs = .ok a) (right : Source.read env w rhs = .ok b)
    (target : StackMIR.offset f dest = .ok offset) (access : offset + w.bytes ≤ d.frameBytes) :
    let second := assignedReg (assignedReg d w 0 a.toNat.toUInt64) w 10 b.toNat.toUInt64
    let result := divide w op a.toNat.toUInt64 b.toNat.toUInt64
    executeMIRList f [StackMIR.loadOperand w .r0 lhs, StackMIR.loadOperand w .r10 rhs,
      .divide w op .r9 .r0 .r10, .store w dest .r9] d = .ok (copied second w offset result) := by
  dsimp only
  let second := assignedReg (assignedReg d w 0 a.toNat.toUInt64) w 10 b.toNat.toUInt64
  let result := divide w op a.toNat.toUInt64 b.toNat.toUInt64
  let third := assignedReg second w 9 result
  obtain ⟨loaded, secondReady, _, readLeft, readRight⟩ := load_operands_into .r0 (by decide) f env d w lhs rhs a b ready related left right
  change readReg second w 0 = .ok a.toNat.toUInt64 at readLeft
  change readReg second w 10 = .ok b.toNat.toUInt64 at readRight
  change executeMIRList f [StackMIR.loadOperand w .r0 lhs, StackMIR.loadOperand w .r10 rhs] d = .ok second at loaded
  have thirdReady : FrameReady third := assignedReg_ready _ _ _ _ secondReady
  have calculate : executeMIR f second (.divide w op .r9 .r0 .r10) = .ok third := by
    simp only [executeMIR, StackMIR.Register.index, readLeft, readRight, bind, Except.bind]
    exact writeReg_assigned second w 9 result secondReady (by decide)
  have thirdRead : readReg third w 9 = .ok (normalize w result) :=
    assignedReg_same second w 9 result secondReady (by decide)
  have written : executeMIR f third (.store w dest .r9) = .ok (copied second w offset result) := by
    simp only [executeMIR, target, StackMIR.Register.index, bind, Except.bind, thirdRead]
    simpa only [third, assignedReg, copied] using store_in_frame third w offset (normalize w result)
      thirdReady.active thirdReady.space thirdReady.sp thirdReady.memory access thirdReady.nowrap
  change executeMIRList f
    ([StackMIR.loadOperand w .r0 lhs, StackMIR.loadOperand w .r10 rhs] ++
      [.divide w op .r9 .r0 .r10, .store w dest .r9]) d = _
  rw [executeMIRList_append, loaded]
  simp only [bind, Except.bind, executeMIRList, calculate, written]
  rfl

end LeanCompilerBackend.Verified.Machine

namespace LeanCompilerBackend.Verified

/-- A defined source division or remainder preserves the updated source/frame
    relation through its actual four-instruction MIR lowering. -/
theorem division_instruction (f : StackMIR.Function) (source : Source.Function)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction)
    (op : Source.Division) (lhs rhs : Source.Operand) (a b value : Source.Value)
    (operation : inst.operation = .divide op lhs rhs)
    (left : Source.read env inst.width lhs = .ok a) (right : Source.read env inst.width rhs = .ok b)
    (defined : Source.evaluateDivision op a b = .ok value)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : inst.destination < env.size)
    (ready : Machine.FrameReady d) (related : Machine.LocalsMatch f env d) :
    ∃ after, Source.evaluate env inst = .ok value ∧ value.width = inst.width ∧
      Machine.executeMIRList f (StackMIR.lowerInstruction inst).toList d = .ok after ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f (env.set! inst.destination (some value)) after := by
  let second := Machine.assignedReg (Machine.assignedReg d inst.width 0 a.toNat.toUInt64) inst.width 10 b.toNat.toUInt64
  let result := Machine.divide inst.width op a.toNat.toUInt64 b.toNat.toUInt64
  let after := Machine.copied second inst.width (8*inst.destination) result
  obtain ⟨_, secondReady, secondRelated, _, _⟩ :=
    Machine.load_operands_into .r0 (by decide) f env d inst.width lhs rhs a b ready related left right
  have bound := Nat.lt_of_lt_of_le inside size
  have aWidth := (Source.read_ok env inst.width lhs a left).1
  have bWidth := (Source.read_ok env inst.width rhs b right).1
  have target : value = Machine.sourceView inst.width result := by
    apply Machine.divide_preserves inst.width op _ _ value
    rw [← aWidth, Machine.sourceView_value, aWidth, ← bWidth, Machine.sourceView_value]
    exact defined
  refine ⟨after, ?_, by rw [target]; exact Machine.sourceView_width _ _, ?_,
    Machine.copied_ready _ _ _ _ secondReady, frame, ?_⟩
  · simp [Source.evaluate, operation, left, right, defined, bind, Except.bind]
  · have h := Machine.division_expansion f env d inst.width op lhs rhs a b (.value inst.destination) _ ready
      related left right (Machine.planned_value f source layout inst.destination bound)
      (by rw [frame]; exact value_access_in_frame source inst.destination inst.width bound)
    simpa [StackMIR.lowerInstruction, operation] using h
  · have h := Machine.localsMatch_store f source env second inst.destination value layout frame size inside
      secondReady secondRelated
    rw [target] at h ⊢
    simpa only [after, Machine.sourceView_width, Machine.sourceView_bits, Machine.copied,
      Machine.normalize_idempotent] using h

/-- One defined source division step is simulated by its four emitted MIR steps. -/
theorem division_steps (f : StackMIR.Function) (source : Source.Function)
    (sourceBlock : Source.Block) (targetBlock : StackMIR.Block)
    (blockId sourcePosition : Nat) (label : StackMIR.Label) (targetPosition : Nat)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction)
    (op : Source.Division) (lhs rhs : Source.Operand) (a b value : Source.Value)
    (sourceFound : source.blocks[blockId]? = some sourceBlock)
    (sourceInst : sourceBlock.instructions[sourcePosition]? = some inst)
    (targetFound : f.blocks.find? (·.label == label) = some targetBlock)
    (targetInst : ∀ i, i < 4 → targetBlock.instructions[targetPosition+i]? = (StackMIR.lowerInstruction inst).toList[i]?)
    (operation : inst.operation = .divide op lhs rhs)
    (left : Source.read env inst.width lhs = .ok a) (right : Source.read env inst.width rhs = .ok b)
    (defined : Source.evaluateDivision op a b = .ok value)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : inst.destination < env.size)
    (declared : source.valueWidths[inst.destination]? = some inst.width)
    (ready : Machine.FrameReady d) (related : Machine.LocalsMatch f env d) :
    ∃ after,
      Source.Step source { block := blockId, position := sourcePosition, environment := env }
        { block := blockId, position := sourcePosition+1, environment := env.set! inst.destination (some value) } ∧
      Machine.Steps (Machine.stepMIR f) 4 { label, position := targetPosition, data := d }
        { label, position := targetPosition+4, data := after } ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f (env.set! inst.destination (some value)) after := by
  obtain ⟨after, evaluated, width, executed, afterReady, afterFrame, afterRelated⟩ :=
    division_instruction f source env d inst op lhs rhs a b value operation left right defined layout frame
      size inside ready related
  have length : (StackMIR.lowerInstruction inst).toList.length = 4 := by
    simp [StackMIR.lowerInstruction, operation]
  refine ⟨after, source_instruction_step source sourceBlock blockId sourcePosition env inst value sourceFound
    sourceInst evaluated inside (by simpa [width] using declared), ?_, afterReady, afterFrame, afterRelated⟩
  have steps := Machine.executeMIRList_steps f targetBlock label targetPosition (StackMIR.lowerInstruction inst).toList
    d after targetFound (by intro i bound; exact targetInst i (by simpa [length] using bound)) executed
  simpa only [length] using steps

end LeanCompilerBackend.Verified
