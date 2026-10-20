/- Source instruction boundaries and actual stack-lowered instruction execution. -/
import LeanCompilerBackend.Verified.SourceTransferProofs

namespace LeanCompilerBackend.Verified

/-- Successful evaluation and a valid destination establish an actual source
    instruction step. Availability and typing remain explicit premises. -/
theorem source_instruction_step (source : Source.Function) (block : Source.Block)
    (blockId position : Nat) (env : Source.Environment) (inst : Source.Instruction) (value : Source.Value)
    (found : source.blocks[blockId]? = some block) (instruction : block.instructions[position]? = some inst)
    (evaluated : Source.evaluate env inst = .ok value)
    (inside : inst.destination < env.size) (width : source.valueWidths[inst.destination]? = some value.width) :
    Source.Step source { block := blockId, position, environment := env }
      { block := blockId, position := position+1, environment := env.set! inst.destination (some value) } := by
  obtain ⟨bound, element⟩ := Array.getElem?_eq_some_iff.mp instruction
  simp [Source.Step, Source.step, found, bound, element, evaluated, bind, Except.bind, pure, Except.pure,
    Source.write_ok source env inst.destination value inside width]

/-- The actual two-instruction copy lowering implements a source copy and
    preserves the relation for the complete updated environment. -/
theorem copy_instruction (f : StackMIR.Function) (source : Source.Function)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction)
    (operand : Source.Operand) (value : Source.Value)
    (operation : inst.operation = .copy operand) (read : Source.read env inst.width operand = .ok value)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : inst.destination < env.size)
    (ready : Machine.FrameReady d) (related : Machine.LocalsMatch f env d) :
    ∃ after,
      Source.evaluate env inst = .ok value ∧
      Machine.executeMIRList f (StackMIR.lowerInstruction inst).toList d = .ok after ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f (env.set! inst.destination (some value)) after := by
  have width := (Source.read_ok env inst.width operand value read).1
  have bound : inst.destination < source.valueWidths.size := Nat.lt_of_lt_of_le inside size
  let after := Machine.copied d inst.width (8*inst.destination) value.toNat.toUInt64
  have lowered : (StackMIR.lowerInstruction inst).toList =
      [StackMIR.loadOperand inst.width .r9 operand, .store inst.width (.value inst.destination) .r9] := by
    simp [StackMIR.lowerInstruction, operation]
  refine ⟨after, ?_, ?_, Machine.copied_ready _ _ _ _ ready, frame, ?_⟩
  · simpa [Source.evaluate, operation] using read
  · rw [lowered]
    exact Machine.operand_copy f env d inst.width operand value (.value inst.destination) _ ready related read
      (Machine.planned_value f source layout inst.destination bound)
      (by rw [frame]; exact value_access_in_frame source inst.destination inst.width bound)
  · simpa only [after, width] using
      Machine.localsMatch_store f source env d inst.destination value layout frame size inside ready related

/-- One actual source copy step is simulated by two actual MIR steps. The
    enclosing source/target instruction-position mapping is explicit. -/
theorem copy_steps (f : StackMIR.Function) (source : Source.Function)
    (sourceBlock : Source.Block) (targetBlock : StackMIR.Block)
    (blockId sourcePosition : Nat) (label : StackMIR.Label) (targetPosition : Nat)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction)
    (operand : Source.Operand) (value : Source.Value)
    (sourceFound : source.blocks[blockId]? = some sourceBlock)
    (sourceInst : sourceBlock.instructions[sourcePosition]? = some inst)
    (targetFound : f.blocks.find? (·.label == label) = some targetBlock)
    (targetInst : ∀ i, i < 2 →
      targetBlock.instructions[targetPosition+i]? = (StackMIR.lowerInstruction inst).toList[i]?)
    (operation : inst.operation = .copy operand) (read : Source.read env inst.width operand = .ok value)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : inst.destination < env.size)
    (declared : source.valueWidths[inst.destination]? = some value.width)
    (ready : Machine.FrameReady d) (related : Machine.LocalsMatch f env d) :
    ∃ after,
      Source.Step source { block := blockId, position := sourcePosition, environment := env }
        { block := blockId, position := sourcePosition+1, environment := env.set! inst.destination (some value) } ∧
      Machine.Steps (Machine.stepMIR f) 2 { label, position := targetPosition, data := d }
        { label, position := targetPosition+2, data := after } ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f (env.set! inst.destination (some value)) after := by
  obtain ⟨after, evaluated, executed, afterReady, afterFrame, afterRelated⟩ :=
    copy_instruction f source env d inst operand value operation read layout frame size inside ready related
  have length : (StackMIR.lowerInstruction inst).toList.length = 2 := by
    simp [StackMIR.lowerInstruction, operation]
  refine ⟨after, source_instruction_step source sourceBlock blockId sourcePosition env inst value sourceFound
    sourceInst evaluated inside declared, ?_, afterReady, afterFrame, afterRelated⟩
  have steps := Machine.executeMIRList_steps f targetBlock label targetPosition
    (StackMIR.lowerInstruction inst).toList d after targetFound
    (by intro i bound; exact targetInst i (by simpa [length] using bound)) executed
  simpa only [length] using steps

end LeanCompilerBackend.Verified
