/- Equality and unsigned-comparison simulation through actual MIR lowering. -/
import LeanCompilerBackend.Verified.ArithmeticProofs

namespace LeanCompilerBackend.Verified.Machine

theorem value_bits_toNat (value : Source.Value) : value.toNat.toUInt64.toNat = value.toNat := by
  cases value with
  | word bits =>
    have bound := bits.isLt
    simp [Source.Value.toNat]
    omega
  | long bits => simp [Source.Value.toNat]

def compareBool (op : Source.Comparison) (a b : UInt64) : Bool :=
  match op with | .eq => a == b | .unsignedLT => a < b

def boolValue (yes : Bool) : Source.Value := .word (if yes then 1 else 0)
def boolBits (yes : Bool) : UInt64 := if yes then 1 else 0

theorem boolValue_width (yes : Bool) : (boolValue yes).width = .word := rfl

theorem boolValue_bits (yes : Bool) : (boolValue yes).toNat.toUInt64 = boolBits yes := by
  cases yes <;> rfl

theorem comparison_source (op : Source.Comparison) (a b : Source.Value) (width : a.width = b.width) :
    Source.evaluateComparison op a b = .ok (boolValue (compareBool op a.toNat.toUInt64 b.toNat.toUInt64)) := by
  have same : (a.width != b.width) = false := by rw [width]; cases b.width <;> rfl
  have eqBits : (a.toNat == b.toNat) = (a.toNat.toUInt64 == b.toNat.toUInt64) := by
    apply Bool.eq_iff_iff.mpr
    simp only [beq_iff_eq]
    rw [← UInt64.toNat_inj, value_bits_toNat, value_bits_toNat]
  have ltBits : decide (a.toNat < b.toNat) = decide (a.toNat.toUInt64 < b.toNat.toUInt64) := by
    simp only [UInt64.lt_iff_toNat_lt, value_bits_toNat]
  cases op <;> simp [Source.evaluateComparison, same, compareBool, boolValue, eqBits, ltBits, pure, Except.pure]

/-- The shared prefix loads both operands without changing frame values. -/
theorem load_operands (f : StackMIR.Function) (env : Source.Environment) (d : Data)
    (w : Width) (lhs rhs : Source.Operand) (a b : Source.Value)
    (ready : FrameReady d) (related : LocalsMatch f env d)
    (left : Source.read env w lhs = .ok a) (right : Source.read env w rhs = .ok b) :
    let first := assignedReg d w 9 a.toNat.toUInt64
    let second := assignedReg first w 10 b.toNat.toUInt64
    executeMIRList f [StackMIR.loadOperand w .r9 lhs, StackMIR.loadOperand w .r10 rhs] d = .ok second ∧
      FrameReady second ∧ LocalsMatch f env second ∧
      readReg second w 9 = .ok a.toNat.toUInt64 ∧ readReg second w 10 = .ok b.toNat.toUInt64 := by
  dsimp only
  let first := assignedReg d w 9 a.toNat.toUInt64
  let second := assignedReg first w 10 b.toNat.toUInt64
  have firstReady : FrameReady first := assignedReg_ready _ _ _ _ ready
  have firstRelated : LocalsMatch f env first := assignedReg_locals _ _ _ _ _ _ related
  have aWidth := (Source.read_ok env w lhs a left).1
  have bWidth := (Source.read_ok env w rhs b right).1
  have aNorm : normalize w a.toNat.toUInt64 = a.toNat.toUInt64 := by rw [← aWidth]; exact value_normalized a
  have bNorm : normalize w b.toNat.toUInt64 = b.toNat.toUInt64 := by rw [← bWidth]; exact value_normalized b
  have loadLeft : executeMIR f d (StackMIR.loadOperand w .r9 lhs) = .ok first := by
    rw [loadOperand_correct f env d w .r9 lhs a related left]
    exact writeReg_assigned d w 9 a.toNat.toUInt64 ready (by decide)
  have loadRight : executeMIR f first (StackMIR.loadOperand w .r10 rhs) = .ok second := by
    rw [loadOperand_correct f env first w .r10 rhs b firstRelated right]
    exact writeReg_assigned first w 10 b.toNat.toUInt64 firstReady (by decide)
  refine ⟨?_, assignedReg_ready _ _ _ _ firstReady, assignedReg_locals _ _ _ _ _ _ firstRelated, ?_, ?_⟩
  · simp only [executeMIRList, loadLeft, loadRight, bind, Except.bind]
    rfl
  · rw [assignedReg_other first w w 10 9 b.toNat.toUInt64 (by decide),
      assignedReg_same d w 9 a.toNat.toUInt64 ready (by decide), aNorm]
  · rw [assignedReg_same first w 10 b.toNat.toUInt64 firstReady (by decide), bNorm]

theorem comparison_expansion (f : StackMIR.Function) (env : Source.Environment) (d : Data)
    (w : Width) (op : Source.Comparison) (lhs rhs : Source.Operand) (a b : Source.Value)
    (dest : StackMIR.Slot) (offset : Nat) (ready : FrameReady d) (related : LocalsMatch f env d)
    (left : Source.read env w lhs = .ok a) (right : Source.read env w rhs = .ok b)
    (target : StackMIR.offset f dest = .ok offset) (access : offset + Width.word.bytes ≤ d.frameBytes) :
    let second := assignedReg (assignedReg d w 9 a.toNat.toUInt64) w 10 b.toNat.toUInt64
    let result := boolBits (compareBool op a.toNat.toUInt64 b.toNat.toUInt64)
    executeMIRList f [StackMIR.loadOperand w .r9 lhs, StackMIR.loadOperand w .r10 rhs,
      .compare w op .r9 .r9 .r10, .store .word dest .r9] d = .ok (copied second .word offset result) := by
  dsimp only
  let second := assignedReg (assignedReg d w 9 a.toNat.toUInt64) w 10 b.toNat.toUInt64
  let result := boolBits (compareBool op a.toNat.toUInt64 b.toNat.toUInt64)
  let third := assignedReg second .word 9 result
  obtain ⟨loaded, secondReady, _, readLeft, readRight⟩ := load_operands f env d w lhs rhs a b ready related left right
  change readReg second w 9 = .ok a.toNat.toUInt64 at readLeft
  change readReg second w 10 = .ok b.toNat.toUInt64 at readRight
  change executeMIRList f [StackMIR.loadOperand w .r9 lhs, StackMIR.loadOperand w .r10 rhs] d = .ok second at loaded
  have thirdReady : FrameReady third := assignedReg_ready _ _ _ _ secondReady
  have calculate : executeMIR f second (.compare w op .r9 .r9 .r10) = .ok third := by
    simp only [executeMIR, StackMIR.Register.index, readLeft, readRight, bind, Except.bind]
    exact writeReg_assigned second .word 9 result secondReady (by decide)
  have thirdRead : readReg third .word 9 = .ok (normalize .word result) :=
    assignedReg_same second .word 9 result secondReady (by decide)
  have written : executeMIR f third (.store .word dest .r9) = .ok (copied second .word offset result) := by
    simp only [executeMIR, target, StackMIR.Register.index, bind, Except.bind, thirdRead]
    simpa only [third, assignedReg, copied] using store_in_frame third .word offset (normalize .word result)
      thirdReady.active thirdReady.space thirdReady.sp thirdReady.memory access thirdReady.nowrap
  change executeMIRList f
    ([StackMIR.loadOperand w .r9 lhs, StackMIR.loadOperand w .r10 rhs] ++
      [.compare w op .r9 .r9 .r10, .store .word dest .r9]) d = _
  rw [executeMIRList_append, loaded]
  simp only [bind, Except.bind, executeMIRList, calculate, written]
  rfl

end LeanCompilerBackend.Verified.Machine

namespace LeanCompilerBackend.Verified

/-- Equality and unsigned comparison produce the same word result in source and
    actual MIR lowering, for either word or long operands. -/
theorem comparison_instruction (f : StackMIR.Function) (source : Source.Function)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction)
    (op : Source.Comparison) (w : Width) (lhs rhs : Source.Operand) (a b : Source.Value)
    (operation : inst.operation = .compare op w lhs rhs) (resultWidth : inst.width = .word)
    (left : Source.read env w lhs = .ok a) (right : Source.read env w rhs = .ok b)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : inst.destination < env.size)
    (ready : Machine.FrameReady d) (related : Machine.LocalsMatch f env d) :
    ∃ value after, Source.evaluate env inst = .ok value ∧ value.width = inst.width ∧
      Machine.executeMIRList f (StackMIR.lowerInstruction inst).toList d = .ok after ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f (env.set! inst.destination (some value)) after := by
  let second := Machine.assignedReg (Machine.assignedReg d w 9 a.toNat.toUInt64) w 10 b.toNat.toUInt64
  let result := Machine.compareBool op a.toNat.toUInt64 b.toNat.toUInt64
  let value := Machine.boolValue result
  let after := Machine.copied second .word (8*inst.destination) (Machine.boolBits result)
  obtain ⟨_, secondReady, secondRelated, _, _⟩ := Machine.load_operands f env d w lhs rhs a b ready related left right
  have bound := Nat.lt_of_lt_of_le inside size
  have aWidth := (Source.read_ok env w lhs a left).1
  have bWidth := (Source.read_ok env w rhs b right).1
  have comparison := Machine.comparison_source op a b (aWidth.trans bWidth.symm)
  refine ⟨value, after, ?_, (Machine.boolValue_width result).trans resultWidth.symm, ?_,
    Machine.copied_ready _ _ _ _ secondReady, frame, ?_⟩
  · simp [Source.evaluate, operation, resultWidth, show (Width.word != Width.word) = false from rfl,
      left, right, comparison, value, result, bind, Except.bind]
  · have h := Machine.comparison_expansion f env d w op lhs rhs a b (.value inst.destination) _ ready related left right
      (Machine.planned_value f source layout inst.destination bound)
      (by rw [frame]; exact value_access_in_frame source inst.destination .word bound)
    simpa [StackMIR.lowerInstruction, operation, resultWidth] using h
  · have h := Machine.localsMatch_store f source env second inst.destination value layout frame size inside secondReady secondRelated
    simpa only [value, after, Machine.boolValue_width, Machine.boolValue_bits] using h

/-- One source comparison is simulated by its four emitted MIR instructions. -/
theorem comparison_steps (f : StackMIR.Function) (source : Source.Function)
    (sourceBlock : Source.Block) (targetBlock : StackMIR.Block)
    (blockId sourcePosition : Nat) (label : StackMIR.Label) (targetPosition : Nat)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction)
    (op : Source.Comparison) (w : Width) (lhs rhs : Source.Operand) (a b : Source.Value)
    (sourceFound : source.blocks[blockId]? = some sourceBlock)
    (sourceInst : sourceBlock.instructions[sourcePosition]? = some inst)
    (targetFound : f.blocks.find? (·.label == label) = some targetBlock)
    (targetInst : ∀ i, i < 4 → targetBlock.instructions[targetPosition+i]? = (StackMIR.lowerInstruction inst).toList[i]?)
    (operation : inst.operation = .compare op w lhs rhs) (resultWidth : inst.width = .word)
    (left : Source.read env w lhs = .ok a) (right : Source.read env w rhs = .ok b)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : inst.destination < env.size)
    (declared : source.valueWidths[inst.destination]? = some inst.width)
    (ready : Machine.FrameReady d) (related : Machine.LocalsMatch f env d) :
    ∃ value after,
      Source.Step source { block := blockId, position := sourcePosition, environment := env }
        { block := blockId, position := sourcePosition+1, environment := env.set! inst.destination (some value) } ∧
      Machine.Steps (Machine.stepMIR f) 4 { label, position := targetPosition, data := d }
        { label, position := targetPosition+4, data := after } ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f (env.set! inst.destination (some value)) after := by
  obtain ⟨value, after, evaluated, width, executed, afterReady, afterFrame, afterRelated⟩ :=
    comparison_instruction f source env d inst op w lhs rhs a b operation resultWidth left right layout frame size inside ready related
  have length : (StackMIR.lowerInstruction inst).toList.length = 4 := by
    simp [StackMIR.lowerInstruction, operation, resultWidth]
  refine ⟨value, after, source_instruction_step source sourceBlock blockId sourcePosition env inst value sourceFound
    sourceInst evaluated inside (by simpa [width] using declared), ?_, afterReady, afterFrame, afterRelated⟩
  have steps := Machine.executeMIRList_steps f targetBlock label targetPosition (StackMIR.lowerInstruction inst).toList
    d after targetFound (by intro i bound; exact targetInst i (by simpa [length] using bound)) executed
  simpa only [length] using steps

end LeanCompilerBackend.Verified
