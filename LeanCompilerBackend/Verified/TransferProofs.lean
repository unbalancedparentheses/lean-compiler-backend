/- Straight-line MIR and transfer facts. These are not yet a composed lowering proof. -/
import LeanCompilerBackend.Verified.FrameProofs
import LeanCompilerBackend.Verified.MachineProofs
import LeanCompilerBackend.Verified.LayoutProofs

namespace LeanCompilerBackend.Verified.Machine

structure FrameReady (d : Data) : Prop where
  active : d.active = true
  space : d.frameBytes ≤ d.entrySP
  sp : d.sp = d.entrySP - d.frameBytes
  memory : d.memory.size = d.frameBytes
  nowrap : d.entrySP < 2^64
  registers : d.registers.size = 31

/-- The concrete effect of a scratch-register copy into a frame slot. -/
def copied (d : Data) (w : Width) (offset : Nat) (value : UInt64) : Data :=
  { d with registers := d.registers.set! 9 (normalize w value),
           memory := writeBytes w.bytes offset (normalize w value) d.memory }

theorem copied_ready (d : Data) (w : Width) (offset : Nat) (value : UInt64)
    (ready : FrameReady d) : FrameReady (copied d w offset value) := by
  refine ⟨ready.active, ready.space, ready.sp, ?_, ready.nowrap, ?_⟩
  · simp [copied, writeBytes_size, ready.memory]
  · simp [copied, ready.registers]

theorem executeMIRList_append (f : StackMIR.Function) (a b : List StackMIR.Instruction) (d : Data) :
    executeMIRList f (a ++ b) d = (executeMIRList f a d >>= executeMIRList f b) := by
  induction a generalizing d with
  | nil => rfl
  | cons inst rest ih =>
    simp only [List.cons_append, executeMIRList]
    cases h : executeMIR f d inst <;> simp [bind, Except.bind, ih]

/-- A load/store pair implements a width-normalized copy in the actual MIR
    semantics. Offset lookup and successful source loading are explicit premises. -/
theorem execute_copy (f : StackMIR.Function) (d : Data) (w : Width)
    (src dst : StackMIR.Slot) (srcOffset dstOffset : Nat) (value : UInt64)
    (ready : FrameReady d) (source : StackMIR.offset f src = .ok srcOffset)
    (target : StackMIR.offset f dst = .ok dstOffset)
    (loaded : load d w srcOffset = .ok value)
    (access : dstOffset + w.bytes ≤ d.frameBytes) :
    executeMIRList f [.load w .r9 src, .store w dst .r9] d =
      .ok (copied d w dstOffset value) := by
  have reg : 9 < d.registers.size := by rw [ready.registers]; decide
  let written := { d with registers := d.registers.set! 9 (normalize w value) }
  have stored := store_in_frame written w dstOffset (normalize w value)
    ready.active ready.space ready.sp ready.memory access ready.nowrap
  simp only [executeMIRList, executeMIR, source, target, loaded, bind, Except.bind,
    StackMIR.Register.index]
  simp only [writeReg, show ¬9 ≥ 31 by decide, Nat.not_le.mpr reg,
    decide_false, Bool.false_or, Bool.false_eq_true, ↓reduceIte, pure, Except.pure,
    readReg, Array.set!_eq_setIfInBounds, Array.getElem?_setIfInBounds_self_of_lt reg, normalize_idempotent]
  change (store written w dstOffset (normalize w value) >>= Except.ok) = _
  rw [stored]
  rfl

theorem copied_load_same (d : Data) (w : Width) (offset : Nat) (value : UInt64)
    (ready : FrameReady d) (access : offset + w.bytes ≤ d.frameBytes) :
    load (copied d w offset value) w offset = .ok (normalize w value) := by
  let written := { d with registers := d.registers.set! 9 (normalize w value) }
  have stored := store_in_frame written w offset (normalize w value)
    ready.active ready.space ready.sp ready.memory access ready.nowrap
  have h := load_store_same written w offset (normalize w value)
    ready.active ready.space ready.sp ready.memory access ready.nowrap
  rw [stored] at h
  simpa only [written, copied, bind, Except.bind, normalize_idempotent] using h

theorem copied_load_disjoint (d : Data) (readWidth writeWidth : Width)
    (readOffset writeOffset : Nat) (value : UInt64) (ready : FrameReady d)
    (readAccess : readOffset + readWidth.bytes ≤ d.frameBytes)
    (writeAccess : writeOffset + writeWidth.bytes ≤ d.frameBytes)
    (disjoint : readOffset+readWidth.bytes ≤ writeOffset ∨
      writeOffset+writeWidth.bytes ≤ readOffset) :
    load (copied d writeWidth writeOffset value) readWidth readOffset = load d readWidth readOffset := by
  let written := { d with registers := d.registers.set! 9 (normalize writeWidth value) }
  have stored := store_in_frame written writeWidth writeOffset (normalize writeWidth value)
    ready.active ready.space ready.sp ready.memory writeAccess ready.nowrap
  have h := load_store_disjoint written readWidth writeWidth readOffset writeOffset
    (normalize writeWidth value) ready.active ready.space ready.sp ready.memory
    readAccess writeAccess ready.nowrap disjoint
  rw [stored] at h
  exact h

theorem copied_other_reg (d : Data) (w : Width) (offset : Nat) (value : UInt64)
    (reg : Nat) (other : reg ≠ 9) :
    (copied d w offset value).registers[reg]? = d.registers[reg]? := by
  simp [copied, Array.getElem?_setIfInBounds_ne (Ne.symm other)]

/-- Successful straight-line execution is an actual small-step MIR prefix,
    with exactly one step per instruction and no appeal to evaluator fuel. -/
theorem executeMIRList_steps (f : StackMIR.Function) (block : StackMIR.Block)
    (label : StackMIR.Label) (position : Nat) (code : List StackMIR.Instruction)
    (before after : Data)
    (found : f.blocks.find? (·.label == label) = some block)
    (instructions : ∀ i, i < code.length → block.instructions[position+i]? = code[i]?)
    (executed : executeMIRList f code before = .ok after) :
    Steps (stepMIR f) code.length { label, position, data := before }
      { label, position := position+code.length, data := after } := by
  induction code generalizing position before with
  | nil =>
    simp only [executeMIRList, Except.ok.injEq] at executed
    subst after
    exact .zero _
  | cons inst rest ih =>
    cases next : executeMIR f before inst with
    | error reason => simp [executeMIRList, next, bind, Except.bind] at executed
    | ok middle =>
      have tail : executeMIRList f rest middle = .ok after := by
        simpa [executeMIRList, next, bind, Except.bind] using executed
      have head : block.instructions[position]? = some inst := by
        simpa using instructions 0 (by simp)
      obtain ⟨inside, element⟩ := Array.getElem?_eq_some_iff.mp head
      have one : Step (stepMIR f) { label, position, data := before }
          { label, position := position+1, data := middle } := by
        simp [Step, stepMIR, found, inside, element, next]
        rfl
      have shifted : ∀ i, i < rest.length → block.instructions[position+1+i]? = rest[i]? := by
        intro i hi
        have h := instructions (i+1) (by simp; omega)
        simpa [Nat.add_assoc, Nat.add_comm 1 i] using h
      have remaining := ih (position+1) middle shifted tail
      simpa [Nat.add_assoc, Nat.add_comm, Nat.add_left_comm] using Steps.succ one remaining

end LeanCompilerBackend.Verified.Machine
