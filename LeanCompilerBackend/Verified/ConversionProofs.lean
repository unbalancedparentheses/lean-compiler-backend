/- Integer conversion simulation through the actual stack lowering. -/
import LeanCompilerBackend.Verified.ArithmeticProofs

namespace LeanCompilerBackend.Verified.Machine

theorem conversion_expansion (f : StackMIR.Function) (env : Source.Environment) (d : Data)
    (op : Source.Conversion) (operand : Source.Operand) (a : Source.Value)
    (dest : StackMIR.Slot) (offset : Nat) (ready : FrameReady d) (related : LocalsMatch f env d)
    (read : Source.read env op.inputWidth operand = .ok a)
    (target : StackMIR.offset f dest = .ok offset) (access : offset + op.outputWidth.bytes ≤ d.frameBytes) :
    let first := assignedReg d op.inputWidth 9 a.toNat.toUInt64
    let result := convert op a.toNat.toUInt64
    executeMIRList f [StackMIR.loadOperand op.inputWidth .r9 operand,
      .convert op .r9 .r9, .store op.outputWidth dest .r9] d = .ok (copied first op.outputWidth offset result) := by
  dsimp only
  let first := assignedReg d op.inputWidth 9 a.toNat.toUInt64
  let result := convert op a.toNat.toUInt64
  let third := assignedReg first op.outputWidth 9 result
  have firstReady : FrameReady first := assignedReg_ready _ _ _ _ ready
  have thirdReady : FrameReady third := assignedReg_ready _ _ _ _ firstReady
  have firstRelated : LocalsMatch f env first := assignedReg_locals _ _ _ _ _ _ related
  have aWidth := (Source.read_ok env op.inputWidth operand a read).1
  have aNorm : normalize op.inputWidth a.toNat.toUInt64 = a.toNat.toUInt64 := by rw [← aWidth]; exact value_normalized a
  have loadLeft : executeMIR f d (StackMIR.loadOperand op.inputWidth .r9 operand) = .ok first := by
    rw [loadOperand_correct f env d op.inputWidth .r9 operand a related read]
    exact writeReg_assigned d op.inputWidth 9 a.toNat.toUInt64 ready (by decide)
  have readValue : readReg first op.inputWidth 9 = .ok a.toNat.toUInt64 := by
    rw [assignedReg_same d op.inputWidth 9 a.toNat.toUInt64 ready (by decide), aNorm]
  have calculate : executeMIR f first (.convert op .r9 .r9) = .ok third := by
    simp only [executeMIR, StackMIR.Register.index, readValue, bind, Except.bind]
    exact writeReg_assigned first op.outputWidth 9 result firstReady (by decide)
  have thirdRead : readReg third op.outputWidth 9 = .ok (normalize op.outputWidth result) :=
    assignedReg_same first op.outputWidth 9 result firstReady (by decide)
  have writeResult : executeMIR f third (.store op.outputWidth dest .r9) = .ok (copied first op.outputWidth offset result) := by
    simp only [executeMIR, target, StackMIR.Register.index, bind, Except.bind,
      thirdRead]
    simpa only [third, assignedReg, copied] using store_in_frame third op.outputWidth offset (normalize op.outputWidth result) thirdReady.active thirdReady.space thirdReady.sp
      thirdReady.memory access thirdReady.nowrap
  simp only [executeMIRList, loadLeft, calculate, writeResult, bind, Except.bind]
  rfl

end LeanCompilerBackend.Verified.Machine

namespace LeanCompilerBackend.Verified

theorem conversion_instruction (f : StackMIR.Function) (source : Source.Function)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction)
    (op : Source.Conversion) (operand : Source.Operand) (a : Source.Value)
    (operation : inst.operation = .convert op operand)
    (resultWidth : inst.width = op.outputWidth)
    (read : Source.read env op.inputWidth operand = .ok a)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : inst.destination < env.size)
    (ready : Machine.FrameReady d) (related : Machine.LocalsMatch f env d) :
    ∃ value after, Source.evaluate env inst = .ok value ∧ value.width = inst.width ∧
      Machine.executeMIRList f (StackMIR.lowerInstruction inst).toList d = .ok after ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f (env.set! inst.destination (some value)) after := by
  let first := Machine.assignedReg d op.inputWidth 9 a.toNat.toUInt64
  let result := Machine.convert op a.toNat.toUInt64
  let value := Machine.sourceView op.outputWidth result
  let after := Machine.copied first inst.width (8*inst.destination) result
  have firstReady : Machine.FrameReady first := Machine.assignedReg_ready _ _ _ _ ready
  have firstRelated : Machine.LocalsMatch f env first :=
    Machine.assignedReg_locals _ _ _ _ _ _ related
  have bound := Nat.lt_of_lt_of_le inside size
  have aWidth := (Source.read_ok env op.inputWidth operand a read).1
  have arithmetic : Source.convertValue op a = value := by
    have h := Machine.convert_preserves op a.toNat.toUInt64
    rw [← aWidth, Machine.sourceView_value] at h
    exact h
  refine ⟨value, after, ?_, (by simp [value, Machine.sourceView_width, resultWidth]), ?_, Machine.copied_ready _ _ _ _ firstReady, frame, ?_⟩
  · have check : (op.outputWidth != op.outputWidth) = false := by cases op <;> rfl
    simp [Source.evaluate, operation, resultWidth, check, read, arithmetic, bind, Except.bind, pure, Except.pure]
  · have h := Machine.conversion_expansion f env d op operand a (.value inst.destination) _ ready related read
      (Machine.planned_value f source layout inst.destination bound)
      (by rw [frame]; exact value_access_in_frame source inst.destination op.outputWidth bound)
    simpa [StackMIR.lowerInstruction, operation, resultWidth, after, first, result] using h
  · have h := Machine.localsMatch_store f source env first inst.destination value layout frame size inside firstReady firstRelated
    simpa only [value, after, Machine.sourceView_width, Machine.sourceView_bits, Machine.copied,
      Machine.normalize_idempotent, resultWidth] using h


/-- One source conversion is simulated by its three emitted MIR steps. -/
theorem conversion_steps (f : StackMIR.Function) (source : Source.Function)
    (sourceBlock : Source.Block) (targetBlock : StackMIR.Block)
    (blockId sourcePosition : Nat) (label : StackMIR.Label) (targetPosition : Nat)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction)
    (op : Source.Conversion) (operand : Source.Operand) (a : Source.Value)
    (sourceFound : source.blocks[blockId]? = some sourceBlock)
    (sourceInst : sourceBlock.instructions[sourcePosition]? = some inst)
    (targetFound : f.blocks.find? (·.label == label) = some targetBlock)
    (targetInst : ∀ i, i < 3 → targetBlock.instructions[targetPosition+i]? = (StackMIR.lowerInstruction inst).toList[i]?)
    (operation : inst.operation = .convert op operand)
    (resultWidth : inst.width = op.outputWidth)
    (read : Source.read env op.inputWidth operand = .ok a)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : inst.destination < env.size)
    (declared : source.valueWidths[inst.destination]? = some inst.width)
    (ready : Machine.FrameReady d) (related : Machine.LocalsMatch f env d) :
    ∃ value after,
      Source.Step source { block := blockId, position := sourcePosition, environment := env }
        { block := blockId, position := sourcePosition+1, environment := env.set! inst.destination (some value) } ∧
      Machine.Steps (Machine.stepMIR f) 3 { label, position := targetPosition, data := d }
        { label, position := targetPosition+3, data := after } ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f (env.set! inst.destination (some value)) after := by
  obtain ⟨value, after, evaluated, width, executed, afterReady, afterFrame, afterRelated⟩ :=
    conversion_instruction f source env d inst op operand a operation resultWidth read layout frame size inside ready related
  have length : (StackMIR.lowerInstruction inst).toList.length = 3 := by
    simp [StackMIR.lowerInstruction, operation]
  refine ⟨value, after, source_instruction_step source sourceBlock blockId sourcePosition env inst value sourceFound
    sourceInst evaluated inside (by simpa [width] using declared), ?_, afterReady, afterFrame, afterRelated⟩
  have steps := Machine.executeMIRList_steps f targetBlock label targetPosition (StackMIR.lowerInstruction inst).toList
    d after targetFound (by intro i bound; exact targetInst i (by simpa [length] using bound)) executed
  simpa only [length] using steps

end LeanCompilerBackend.Verified
