/- Uniform simulation of every source body instruction. -/
import LeanCompilerBackend.Verified.ComparisonProofs

namespace LeanCompilerBackend.Verified

/-- Source writes cannot silently resize, change type, or ignore the destination. -/
theorem source_write_sound (source : Source.Function) (env updated : Source.Environment)
    (id : Nat) (value : Source.Value) (written : Source.write source env id value = .ok updated) :
    id < env.size ∧ source.valueWidths[id]? = some value.width ∧ updated = env.set! id (some value) := by
  have widthCheck (a b : Width) : (a != b) = decide (a ≠ b) := by cases a <;> cases b <;> rfl
  cases lookup : source.valueWidths[id]? with
  | none => simp [Source.write, lookup, throw] at written
  | some width =>
    simp only [Source.write, lookup, widthCheck, bind, Except.bind, pure, Except.pure] at written
    split at written
    · cases written
    · split at written
      · cases written
      · cases written
        simp_all

/-- All supported body operations preserve the updated source/frame relation.
    Successful source evaluation supplies operand availability and operation typing. -/
theorem instruction_correct (f : StackMIR.Function) (source : Source.Function)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction) (value : Source.Value)
    (evaluated : Source.evaluate env inst = .ok value)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (inside : inst.destination < env.size)
    (ready : Machine.FrameReady d) (related : Machine.LocalsMatch f env d) :
    ∃ after, value.width = inst.width ∧
      Machine.executeMIRList f (StackMIR.lowerInstruction inst).toList d = .ok after ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f (env.set! inst.destination (some value)) after := by
  cases operation : inst.operation with
  | copy operand =>
    have read : Source.read env inst.width operand = .ok value := by
      simpa [Source.evaluate, operation] using evaluated
    obtain ⟨after, _, executed, afterReady, afterFrame, afterRelated⟩ :=
      copy_instruction f source env d inst operand value operation read layout frame size inside ready related
    exact ⟨after, (Source.read_ok env inst.width operand value read).1, executed, afterReady, afterFrame, afterRelated⟩
  | binary op lhs rhs =>
    cases left : Source.read env inst.width lhs with
    | error fault => simp [Source.evaluate, operation, left, bind, Except.bind] at evaluated
    | ok a =>
      cases right : Source.read env inst.width rhs with
      | error fault => simp [Source.evaluate, operation, left, right, bind, Except.bind] at evaluated
      | ok b =>
        obtain ⟨result, after, computed, width, executed, afterReady, afterFrame, afterRelated⟩ :=
          binary_instruction f source env d inst op lhs rhs a b operation left right layout frame size inside ready related
        rw [evaluated] at computed
        cases computed
        exact ⟨after, width, executed, afterReady, afterFrame, afterRelated⟩
  | compare op w lhs rhs =>
    have resultWidth : inst.width = .word := by
      cases width : inst.width with
      | word => rfl
      | long =>
        simp [Source.evaluate, operation, width, show (Width.long != Width.word) = true from rfl,
          bind, Except.bind, throw] at evaluated
    cases left : Source.read env w lhs with
    | error fault =>
      simp [Source.evaluate, operation, resultWidth, show (Width.word != Width.word) = false from rfl,
        left, bind, Except.bind] at evaluated
    | ok a =>
      cases right : Source.read env w rhs with
      | error fault =>
        simp [Source.evaluate, operation, resultWidth, show (Width.word != Width.word) = false from rfl,
          left, right, bind, Except.bind] at evaluated
      | ok b =>
        obtain ⟨result, after, computed, width, executed, afterReady, afterFrame, afterRelated⟩ :=
          comparison_instruction f source env d inst op w lhs rhs a b operation resultWidth left right
            layout frame size inside ready related
        rw [evaluated] at computed
        cases computed
        exact ⟨after, width, executed, afterReady, afterFrame, afterRelated⟩

def instructionSteps (inst : Source.Instruction) : Nat :=
  match inst.operation with | .copy _ => 2 | .binary .. | .compare .. => 4

theorem instruction_length (inst : Source.Instruction) :
    (StackMIR.lowerInstruction inst).toList.length = instructionSteps inst := by
  cases operation : inst.operation <;> simp [StackMIR.lowerInstruction, instructionSteps, operation]

/-- Invert an actual successful source body step, retaining its precise update. -/
theorem source_instruction_invert (source : Source.Function) (block : Source.Block)
    (blockId position : Nat) (env : Source.Environment) (inst : Source.Instruction) (next : Source.State)
    (found : source.blocks[blockId]? = some block) (instruction : block.instructions[position]? = some inst)
    (stepped : Source.Step source { block := blockId, position, environment := env } next) :
    ∃ value, Source.evaluate env inst = .ok value ∧ inst.destination < env.size ∧
      source.valueWidths[inst.destination]? = some value.width ∧
      next = { block := blockId, position := position+1, environment := env.set! inst.destination (some value) } := by
  obtain ⟨bound, _⟩ := Array.getElem?_eq_some_iff.mp instruction
  simp only [Source.Step, Source.step, found, bound, ↓reduceIte, instruction, bind, Except.bind] at stepped
  cases evaluated : Source.evaluate env inst with
  | error fault => simp [evaluated] at stepped
  | ok value =>
    cases written : Source.write source env inst.destination value with
    | error fault => simp [evaluated, written] at stepped
    | ok updated =>
      obtain ⟨inside, width, update⟩ := source_write_sound source env updated inst.destination value written
      refine ⟨value, rfl, inside, width, ?_⟩
      simpa [evaluated, written, bind, Except.bind, pure, Except.pure, update] using stepped.symm

/-- Every successful source body step is simulated by its actual MIR expansion.
    Operand availability and destination typing are consequences of that step. -/
theorem simulate_instruction (f : StackMIR.Function) (source : Source.Function)
    (sourceBlock : Source.Block) (targetBlock : StackMIR.Block)
    (blockId sourcePosition : Nat) (label : StackMIR.Label) (targetPosition : Nat)
    (env : Source.Environment) (d : Machine.Data) (inst : Source.Instruction) (next : Source.State)
    (sourceFound : source.blocks[blockId]? = some sourceBlock)
    (sourceInst : sourceBlock.instructions[sourcePosition]? = some inst)
    (targetFound : f.blocks.find? (·.label == label) = some targetBlock)
    (targetInst : ∀ i, i < instructionSteps inst →
      targetBlock.instructions[targetPosition+i]? = (StackMIR.lowerInstruction inst).toList[i]?)
    (stepped : Source.Step source { block := blockId, position := sourcePosition, environment := env } next)
    (layout : f.layout = planFrame source) (frame : d.frameBytes = (planFrame source).frameBytes)
    (size : env.size ≤ source.valueWidths.size) (ready : Machine.FrameReady d)
    (related : Machine.LocalsMatch f env d) :
    ∃ after, next.block = blockId ∧ next.position = sourcePosition+1 ∧
      Machine.Steps (Machine.stepMIR f) (instructionSteps inst)
        { label, position := targetPosition, data := d }
        { label, position := targetPosition+instructionSteps inst, data := after } ∧
      Machine.FrameReady after ∧ after.frameBytes = (planFrame source).frameBytes ∧
      Machine.LocalsMatch f next.environment after := by
  obtain ⟨value, evaluated, inside, _, nextState⟩ :=
    source_instruction_invert source sourceBlock blockId sourcePosition env inst next sourceFound sourceInst stepped
  obtain ⟨after, _, executed, afterReady, afterFrame, afterRelated⟩ :=
    instruction_correct f source env d inst value evaluated layout frame size inside ready related
  subst next
  refine ⟨after, rfl, rfl, ?_, afterReady, afterFrame, afterRelated⟩
  have steps := Machine.executeMIRList_steps f targetBlock label targetPosition (StackMIR.lowerInstruction inst).toList
    d after targetFound (by intro i bound; exact targetInst i (by simpa only [instruction_length] using bound)) executed
  simpa only [instruction_length] using steps

end LeanCompilerBackend.Verified
