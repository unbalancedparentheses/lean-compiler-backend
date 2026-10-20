/- A cyclic two-phi transfer through the actual staging/commit instructions. -/
import LeanCompilerBackend.Verified.TransferProofs

namespace LeanCompilerBackend.Verified.Machine

def swapCode (w : Width) : List StackMIR.Instruction := [
  .load w .r9 (.value 1), .store w (.stage 0) .r9,
  .load w .r9 (.value 0), .store w (.stage 1) .r9,
  .load w .r9 (.stage 0), .store w (.value 0) .r9,
  .load w .r9 (.stage 1), .store w (.value 1) .r9]

/-- Staging preserves both old values, so a cyclic phi swap works for arbitrary
    data, either width, and arbitrary unrelated initialized/uninitialized bytes. -/
theorem phi_swap_exec (f : StackMIR.Function) (d : Data) (w : Width) (a b : UInt64)
    (ready : FrameReady d) (space : 32 ≤ d.frameBytes)
    (value0 : StackMIR.offset f (.value 0) = .ok 0)
    (value1 : StackMIR.offset f (.value 1) = .ok 8)
    (stage0 : StackMIR.offset f (.stage 0) = .ok 16)
    (stage1 : StackMIR.offset f (.stage 1) = .ok 24)
    (read0 : load d w 0 = .ok a) (read1 : load d w 8 = .ok b) :
    ∃ after, executeMIRList f (swapCode w) d = .ok after ∧
      load after w 0 = .ok (normalize w b) ∧
      load after w 8 = .ok (normalize w a) ∧ FrameReady after ∧
      ∀ reg, reg ≠ 9 → after.registers[reg]? = d.registers[reg]? := by
  have bytes : w.bytes ≤ 8 := by cases w <;> decide
  let d1 := copied d w 16 b
  let d2 := copied d1 w 24 a
  let d3 := copied d2 w 0 (normalize w b)
  let d4 := copied d3 w 8 (normalize w a)
  have r1 := copied_ready d w 16 b ready
  have r2 := copied_ready d1 w 24 a r1
  have r3 := copied_ready d2 w 0 (normalize w b) r2
  have r4 := copied_ready d3 w 8 (normalize w a) r3
  have readA : load d1 w 0 = .ok a := by
    rw [copied_load_disjoint d w w 0 16 b ready (by omega) (by omega) (Or.inl (by omega))]
    exact read0
  have readBStage : load d2 w 16 = .ok (normalize w b) := by
    rw [copied_load_disjoint d1 w w 16 24 a r1 (by change 16+w.bytes ≤ d.frameBytes; omega)
      (by change 24+w.bytes ≤ d.frameBytes; omega) (Or.inl (by omega))]
    exact copied_load_same d w 16 b ready (by omega)
  have readAStage : load d3 w 24 = .ok (normalize w a) := by
    rw [copied_load_disjoint d2 w w 24 0 (normalize w b) r2
      (by change 24+w.bytes ≤ d.frameBytes; omega)
      (by change 0+w.bytes ≤ d.frameBytes; omega) (Or.inr (by omega))]
    exact copied_load_same d1 w 24 a r1 (by change 24+w.bytes ≤ d.frameBytes; omega)
  have h1 := execute_copy f d w (.value 1) (.stage 0) 8 16 b ready value1 stage0 read1 (by omega)
  have h2 := execute_copy f d1 w (.value 0) (.stage 1) 0 24 a r1 value0 stage1 readA
    (by change 24+w.bytes ≤ d.frameBytes; omega)
  have h3 := execute_copy f d2 w (.stage 0) (.value 0) 16 0 (normalize w b) r2 stage0 value0 readBStage
    (by change 0+w.bytes ≤ d.frameBytes; omega)
  have h4 := execute_copy f d3 w (.stage 1) (.value 1) 24 8 (normalize w a) r3 stage1 value1 readAStage
    (by change 8+w.bytes ≤ d.frameBytes; omega)
  refine ⟨d4, ?_, ?_, ?_, r4, ?_⟩
  · change executeMIRList f
      ([.load w .r9 (.value 1), .store w (.stage 0) .r9] ++
       [.load w .r9 (.value 0), .store w (.stage 1) .r9] ++
       [.load w .r9 (.stage 0), .store w (.value 0) .r9] ++
       [.load w .r9 (.stage 1), .store w (.value 1) .r9]) d = _
    simp only [List.append_assoc]
    rw [executeMIRList_append, h1]
    simp only [bind, Except.bind]
    rw [executeMIRList_append, h2]
    simp only [bind, Except.bind]
    rw [executeMIRList_append, h3]
    simp only [bind, Except.bind]
    exact h4
  · rw [copied_load_disjoint d3 w w 0 8 (normalize w a) r3
      (by change 0+w.bytes ≤ d.frameBytes; omega)
      (by change 8+w.bytes ≤ d.frameBytes; omega) (Or.inl (by omega))]
    simpa only [normalize_idempotent] using copied_load_same d2 w 0 (normalize w b) r2
      (by change 0+w.bytes ≤ d.frameBytes; omega)
  · simpa only [normalize_idempotent] using copied_load_same d3 w 8 (normalize w a) r3
      (by change 8+w.bytes ≤ d.frameBytes; omega)
  · intro reg other
    simp only [d4, d3, d2, d1, copied_other_reg _ _ _ _ reg other]

def swapPhis (w : Width) (incoming0 incoming1 : Array (Nat × Source.Operand)) : Array Source.Phi := #[
  { destination := 0, width := w, incoming := incoming0 },
  { destination := 1, width := w, incoming := incoming1 }]

/-- The instruction sequence proved above is exactly what lowerEdge emits for
    this cycle. Other predecessor entries, such as the loop initializer, remain
    unrestricted; only the selected edge's operands are constrained. -/
theorem lowerEdge_swap (f : Source.Function) (block : Source.Block) (pred target : Nat)
    (w : Width) (incoming0 incoming1 : Array (Nat × Source.Operand))
    (found : f.blocks[target]? = some block) (phis : block.phis = swapPhis w incoming0 incoming1)
    (first : incoming0.find? (·.1 == pred) = some (pred, .local 1))
    (second : incoming1.find? (·.1 == pred) = some (pred, .local 0)) :
    StackMIR.lowerEdge f pred target = .ok {
      label := .edge pred target, instructions := (swapCode w).toArray,
      terminator := .jump (.body target) } := by
  simp [StackMIR.lowerEdge, found, phis, swapPhis, StackMIR.stagePhis, first, second,
    StackMIR.commitPhis, StackMIR.loadOperand, swapCode, bind, Except.bind]
  rfl

/-- The emitted cyclic-transfer block takes eight actual MIR small steps and
    exchanges both values. Its jump terminator and source relation are separate. -/
theorem phi_swap_steps (f : StackMIR.Function) (d : Data) (w : Width) (a b : UInt64)
    (pred target : Nat) (ready : FrameReady d) (space : 32 ≤ d.frameBytes)
    (value0 : StackMIR.offset f (.value 0) = .ok 0)
    (value1 : StackMIR.offset f (.value 1) = .ok 8)
    (stage0 : StackMIR.offset f (.stage 0) = .ok 16)
    (stage1 : StackMIR.offset f (.stage 1) = .ok 24)
    (read0 : load d w 0 = .ok a) (read1 : load d w 8 = .ok b)
    (found : f.blocks.find? (·.label == .edge pred target) = some {
      label := .edge pred target, instructions := (swapCode w).toArray,
      terminator := .jump (.body target) }) :
    ∃ after, Steps (stepMIR f) 8 { label := .edge pred target, data := d }
        { label := .edge pred target, position := 8, data := after } ∧
      load after w 0 = .ok (normalize w b) ∧
      load after w 8 = .ok (normalize w a) ∧ FrameReady after ∧
      ∀ reg, reg ≠ 9 → after.registers[reg]? = d.registers[reg]? := by
  obtain ⟨after, executed, a', b', ready', saved⟩ :=
    phi_swap_exec f d w a b ready space value0 value1 stage0 stage1 read0 read1
  refine ⟨after, ?_, a', b', ready', saved⟩
  have steps := executeMIRList_steps f _ (.edge pred target) 0 (swapCode w) d after found
    (by intro i hi; simp) executed
  exact steps

end LeanCompilerBackend.Verified.Machine
