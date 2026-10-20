/- Arithmetic instruction simulation for the actual stack lowering. -/
import LeanCompilerBackend.Verified.InstructionProofs

namespace LeanCompilerBackend.Verified.Machine

theorem sourceView_width (w : Width) (bits : UInt64) : (sourceView w bits).width = w := by
  cases w <;> rfl

theorem sourceView_bits (w : Width) (bits : UInt64) :
    (sourceView w bits).toNat.toUInt64 = normalize w bits := by
  cases w <;> apply UInt64.toNat_inj.mp <;> simp [sourceView, Source.Value.toNat, normalize]
  omega

theorem sourceView_value (v : Source.Value) : sourceView v.width v.toNat.toUInt64 = v := by
  cases v with
  | word bits =>
    simp [sourceView, Source.Value.width, Source.Value.toNat]
  | long bits =>
    simp [sourceView, Source.Value.width, Source.Value.toNat]

/-- Register writes leave the source/frame relation intact. -/
def assignedReg (d : Data) (w : Width) (reg : Nat) (value : UInt64) : Data :=
  { d with registers := d.registers.set! reg (normalize w value) }

theorem assignedReg_ready (d : Data) (w : Width) (reg : Nat) (value : UInt64)
    (ready : FrameReady d) : FrameReady (assignedReg d w reg value) := by
  exact ⟨ready.active, ready.space, ready.sp, ready.memory, ready.nowrap, by simp [assignedReg, ready.registers]⟩

theorem assignedReg_locals (f : StackMIR.Function) (env : Source.Environment) (d : Data)
    (w : Width) (reg : Nat) (value : UInt64) (related : LocalsMatch f env d) :
    LocalsMatch f env (assignedReg d w reg value) := related

theorem writeReg_assigned (d : Data) (w : Width) (reg : Nat) (value : UInt64)
    (ready : FrameReady d) (inside : reg < 31) :
    writeReg d w reg value = .ok (assignedReg d w reg value) := by
  simp [writeReg, assignedReg, ready.registers, Nat.not_le.mpr inside, pure, Except.pure]

theorem assignedReg_same (d : Data) (w : Width) (reg : Nat) (value : UInt64)
    (ready : FrameReady d) (inside : reg < 31) :
    readReg (assignedReg d w reg value) w reg = .ok (normalize w value) := by
  have bound : reg < d.registers.size := by rw [ready.registers]; exact inside
  simp [readReg, assignedReg, Array.getElem?_setIfInBounds_self_of_lt bound, normalize_idempotent]
  rfl

theorem assignedReg_other (d : Data) (writeWidth readWidth : Width) (reg other : Nat) (value : UInt64)
    (different : reg ≠ other) :
    readReg (assignedReg d writeWidth reg value) readWidth other = readReg d readWidth other := by
  simp [readReg, assignedReg, Array.getElem?_setIfInBounds_ne different]

/-- Execute the actual two operand loads, arithmetic operation and destination
    store, for any of the six supported arithmetic/bitwise operations. -/
theorem binary_expansion (f : StackMIR.Function) (env : Source.Environment) (d : Data)
    (w : Width) (op : Source.Binary) (lhs rhs : Source.Operand) (a b : Source.Value)
    (dest : StackMIR.Slot) (offset : Nat) (ready : FrameReady d) (related : LocalsMatch f env d)
    (left : Source.read env w lhs = .ok a) (right : Source.read env w rhs = .ok b)
    (target : StackMIR.offset f dest = .ok offset) (access : offset + w.bytes ≤ d.frameBytes) :
    let first := assignedReg d w 9 a.toNat.toUInt64
    let second := assignedReg first w 10 b.toNat.toUInt64
    let result := alu w op a.toNat.toUInt64 b.toNat.toUInt64
    executeMIRList f [StackMIR.loadOperand w .r9 lhs, StackMIR.loadOperand w .r10 rhs,
      .alu w op .r9 .r9 .r10, .store w dest .r9] d = .ok (copied second w offset result) := by
  dsimp only
  let first := assignedReg d w 9 a.toNat.toUInt64
  let second := assignedReg first w 10 b.toNat.toUInt64
  let result := alu w op a.toNat.toUInt64 b.toNat.toUInt64
  let third := assignedReg second w 9 result
  have firstReady : FrameReady first := assignedReg_ready _ _ _ _ ready
  have secondReady : FrameReady second := assignedReg_ready _ _ _ _ firstReady
  have thirdReady : FrameReady third := assignedReg_ready _ _ _ _ secondReady
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
  have readLeft : readReg second w 9 = .ok a.toNat.toUInt64 := by
    rw [assignedReg_other first w w 10 9 b.toNat.toUInt64 (by decide),
      assignedReg_same d w 9 a.toNat.toUInt64 ready (by decide), aNorm]
  have readRight : readReg second w 10 = .ok b.toNat.toUInt64 := by
    rw [assignedReg_same first w 10 b.toNat.toUInt64 firstReady (by decide), bNorm]
  have calculate : executeMIR f second (.alu w op .r9 .r9 .r10) = .ok third := by
    simp only [executeMIR, StackMIR.Register.index, readLeft, readRight, bind, Except.bind]
    exact writeReg_assigned second w 9 result secondReady (by decide)
  have thirdRead : readReg third w 9 = .ok (normalize w result) :=
    assignedReg_same second w 9 result secondReady (by decide)
  have writeResult : executeMIR f third (.store w dest .r9) = .ok (copied second w offset result) := by
    simp only [executeMIR, target, StackMIR.Register.index, bind, Except.bind,
      thirdRead]
    simpa only [third, assignedReg, copied] using store_in_frame third w offset (normalize w result) thirdReady.active thirdReady.space thirdReady.sp
      thirdReady.memory access thirdReady.nowrap
  simp only [executeMIRList, loadLeft, loadRight, calculate, writeResult, bind, Except.bind]
  rfl

end LeanCompilerBackend.Verified.Machine

namespace LeanCompilerBackend.Verified

/-- Arithmetic lowering preserves the updated source/frame relation. Its result
    is tied to source bitvector arithmetic, not just target numeric tests. -/
theorem binary_instruction (f : StackMIR.Function) (source : Source.Function)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction)
    (op : Source.Binary) (lhs rhs : Source.Operand) (a b : Source.Value)
    (operation : inst.operation = .binary op lhs rhs)
    (left : Source.read env inst.width lhs = .ok a) (right : Source.read env inst.width rhs = .ok b)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : inst.destination < env.size)
    (ready : Machine.FrameReady d) (related : Machine.LocalsMatch f env d) :
    ∃ value after, Source.evaluate env inst = .ok value ∧ value.width = inst.width ∧
      Machine.executeMIRList f (StackMIR.lowerInstruction inst).toList d = .ok after ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f (env.set! inst.destination (some value)) after := by
  let first := Machine.assignedReg d inst.width 9 a.toNat.toUInt64
  let second := Machine.assignedReg first inst.width 10 b.toNat.toUInt64
  let result := Machine.alu inst.width op a.toNat.toUInt64 b.toNat.toUInt64
  let value := Machine.sourceView inst.width result
  let after := Machine.copied second inst.width (8*inst.destination) result
  have firstReady : Machine.FrameReady first := Machine.assignedReg_ready _ _ _ _ ready
  have secondReady : Machine.FrameReady second := Machine.assignedReg_ready _ _ _ _ firstReady
  have secondRelated : Machine.LocalsMatch f env second :=
    Machine.assignedReg_locals _ _ _ _ _ _ (Machine.assignedReg_locals _ _ _ _ _ _ related)
  have bound := Nat.lt_of_lt_of_le inside size
  have aWidth := (Source.read_ok env inst.width lhs a left).1
  have bWidth := (Source.read_ok env inst.width rhs b right).1
  have arithmetic : Source.evaluateBinary op a b = .ok value := by
    have h := Machine.alu_preserves inst.width op a.toNat.toUInt64 b.toNat.toUInt64
    rw [← aWidth, Machine.sourceView_value] at h
    rw [aWidth, ← bWidth, Machine.sourceView_value] at h
    simpa only [bWidth] using h
  refine ⟨value, after, ?_, Machine.sourceView_width _ _, ?_, Machine.copied_ready _ _ _ _ secondReady, frame, ?_⟩
  · simp [Source.evaluate, operation, left, right, arithmetic, bind, Except.bind]
  · have h := Machine.binary_expansion f env d inst.width op lhs rhs a b (.value inst.destination) _ ready related left right
      (Machine.planned_value f source layout inst.destination bound)
      (by rw [frame]; exact value_access_in_frame source inst.destination inst.width bound)
    simpa [StackMIR.lowerInstruction, operation] using h
  · have h := Machine.localsMatch_store f source env second inst.destination value layout frame size inside secondReady secondRelated
    simpa only [value, after, Machine.sourceView_width, Machine.sourceView_bits, Machine.copied,
      Machine.normalize_idempotent] using h

/-- One source arithmetic instruction is simulated by its four emitted MIR steps. -/
theorem binary_steps (f : StackMIR.Function) (source : Source.Function)
    (sourceBlock : Source.Block) (targetBlock : StackMIR.Block)
    (blockId sourcePosition : Nat) (label : StackMIR.Label) (targetPosition : Nat)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction)
    (op : Source.Binary) (lhs rhs : Source.Operand) (a b : Source.Value)
    (sourceFound : source.blocks[blockId]? = some sourceBlock)
    (sourceInst : sourceBlock.instructions[sourcePosition]? = some inst)
    (targetFound : f.blocks.find? (·.label == label) = some targetBlock)
    (targetInst : ∀ i, i < 4 → targetBlock.instructions[targetPosition+i]? = (StackMIR.lowerInstruction inst).toList[i]?)
    (operation : inst.operation = .binary op lhs rhs)
    (left : Source.read env inst.width lhs = .ok a) (right : Source.read env inst.width rhs = .ok b)
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
    binary_instruction f source env d inst op lhs rhs a b operation left right layout frame size inside ready related
  have length : (StackMIR.lowerInstruction inst).toList.length = 4 := by
    simp [StackMIR.lowerInstruction, operation]
  refine ⟨value, after, source_instruction_step source sourceBlock blockId sourcePosition env inst value sourceFound
    sourceInst evaluated inside (by simpa [width] using declared), ?_, afterReady, afterFrame, afterRelated⟩
  have steps := Machine.executeMIRList_steps f targetBlock label targetPosition (StackMIR.lowerInstruction inst).toList
    d after targetFound (by intro i bound; exact targetInst i (by simpa [length] using bound)) executed
  simpa only [length] using steps

end LeanCompilerBackend.Verified
