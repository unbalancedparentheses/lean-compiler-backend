/- Phi edges only change owned memory and R9; preserve the caller context. -/
import LeanCompilerBackend.Verified.StagingProofs

namespace LeanCompilerBackend.Verified.Machine

structure CopyContext (before after : Data) : Prop where
  entryRegisters : after.entryRegisters = before.entryRegisters
  entrySP : after.entrySP = before.entrySP
  sp : after.sp = before.sp
  frameBytes : after.frameBytes = before.frameBytes
  active : after.active = before.active
  flags : after.flags = before.flags
  registers : ∀ reg, reg ≠ 9 → after.registers[reg]? = before.registers[reg]?

theorem copyContext_refl (d : Data) : CopyContext d d :=
  ⟨rfl, rfl, rfl, rfl, rfl, rfl, fun _ _ => rfl⟩

theorem copyContext_trans (first : CopyContext a b) (second : CopyContext b c) : CopyContext a c :=
  ⟨second.entryRegisters.trans first.entryRegisters, second.entrySP.trans first.entrySP,
    second.sp.trans first.sp, second.frameBytes.trans first.frameBytes,
    second.active.trans first.active, second.flags.trans first.flags,
    fun reg different => (second.registers reg different).trans (first.registers reg different)⟩

private theorem write_scratch_context (d after : Data) (w : Width) (value : UInt64)
    (written : writeReg d w 9 value = .ok after) : CopyContext d after := by
  simp only [writeReg] at written
  split at written
  · cases written
  · simp only [pure, Except.pure, Except.ok.injEq] at written
    subst after
    refine ⟨rfl, rfl, rfl, rfl, rfl, rfl, ?_⟩
    intro reg different
    simp [Array.getElem?_setIfInBounds_ne (Ne.symm different)]

private theorem store_context (d after : Data) (w : Width) (offset : Nat) (value : UInt64)
    (stored : store d w offset value = .ok after) : CopyContext d after := by
  cases addr : address d w offset with
  | error reason => simp [store, addr, bind, Except.bind] at stored
  | ok start =>
    simp [store, addr, bind, Except.bind, pure, Except.pure] at stored
    subst after
    exact ⟨rfl, rfl, rfl, rfl, rfl, rfl, fun _ _ => rfl⟩

inductive CopyInstruction : StackMIR.Instruction → Prop where
  | constant (value) : CopyInstruction (.constant .r9 value)
  | load (w slot) : CopyInstruction (.load w .r9 slot)
  | store (w slot) : CopyInstruction (.store w slot .r9)

theorem copyInstruction_context (f : StackMIR.Function) (d after : Data) (inst : StackMIR.Instruction)
    (allowed : CopyInstruction inst) (executed : executeMIR f d inst = .ok after) : CopyContext d after := by
  cases allowed with
  | constant value => exact write_scratch_context d after value.width value.toNat.toUInt64 executed
  | load w slot =>
    cases offset : StackMIR.offset f slot with
    | error reason => simp [executeMIR, offset, bind, Except.bind] at executed
    | ok address =>
      cases loaded : load d w address with
      | error reason => simp [executeMIR, offset, loaded, bind, Except.bind] at executed
      | ok value =>
        apply write_scratch_context d after w value
        simpa [executeMIR, offset, loaded, bind, Except.bind, StackMIR.Register.index] using executed
  | store w slot =>
    cases offset : StackMIR.offset f slot with
    | error reason => simp [executeMIR, offset, bind, Except.bind] at executed
    | ok address =>
      cases read : readReg d w 9 with
      | error reason => simp [executeMIR, offset, read, bind, Except.bind, StackMIR.Register.index] at executed
      | ok value =>
        apply store_context d after w address value
        simpa [executeMIR, offset, read, bind, Except.bind, StackMIR.Register.index] using executed

theorem copyList_context (f : StackMIR.Function) (d after : Data) (code : List StackMIR.Instruction)
    (allowed : ∀ inst ∈ code, CopyInstruction inst)
    (executed : executeMIRList f code d = .ok after) : CopyContext d after := by
  induction code generalizing d with
  | nil =>
    simp only [executeMIRList, Except.ok.injEq] at executed
    subst after
    exact copyContext_refl d
  | cons inst rest ih =>
    cases head : executeMIR f d inst with
    | error reason => simp [executeMIRList, head, bind, Except.bind] at executed
    | ok middle =>
      have first := copyInstruction_context f d middle inst (allowed inst (by simp)) head
      have tail : executeMIRList f rest middle = .ok after := by
        simpa [executeMIRList, head, bind, Except.bind] using executed
      exact copyContext_trans first (ih middle (fun i hi => allowed i (by simp [hi])) tail)

theorem loadOperand_copy (w : Width) (operand : Source.Operand) :
    CopyInstruction (StackMIR.loadOperand w .r9 operand) := by
  cases operand <;> constructor

theorem commitPhis_copy (index : Nat) (phis : List Source.Phi) :
    ∀ inst ∈ StackMIR.commitPhis index phis, CopyInstruction inst := by
  induction phis generalizing index with
  | nil => simp [StackMIR.commitPhis]
  | cons phi rest ih =>
    intro inst member
    simp only [StackMIR.commitPhis, List.mem_cons] at member
    rcases member with rfl | rfl | tail
    · constructor
    · constructor
    · exact ih (index+1) inst tail

theorem stagePhis_copy (pred index : Nat) (phis : List Source.Phi) (code : List StackMIR.Instruction)
    (lowered : StackMIR.stagePhis pred index phis = .ok code) :
    ∀ inst ∈ code, CopyInstruction inst := by
  induction phis generalizing index code with
  | nil => simp [StackMIR.stagePhis] at lowered; subst code; simp
  | cons phi rest ih =>
    cases found : phi.incoming.find? (·.1 == pred) with
    | none => simp [StackMIR.stagePhis, found, throw] at lowered
    | some incoming =>
      obtain ⟨predecessor, operand⟩ := incoming
      cases tail : StackMIR.stagePhis pred (index+1) rest with
      | error reason => simp [StackMIR.stagePhis, found, tail, bind, Except.bind] at lowered
      | ok tailCode =>
        simp only [StackMIR.stagePhis, found, tail, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at lowered
        subst code
        intro inst member
        simp only [List.mem_cons] at member
        rcases member with rfl | rfl | tailMember
        · exact loadOperand_copy phi.width operand
        · constructor
        · exact ih (index+1) tailCode tail inst tailMember

/-- No successful phi transfer can change the caller context outside R9 and
    owned memory, regardless of source values, widths or transfer length. -/
theorem phi_context (f : StackMIR.Function) (pred : Nat) (phis : List Source.Phi)
    (staging : List StackMIR.Instruction) (d after : Data)
    (lowered : StackMIR.stagePhis pred 0 phis = .ok staging)
    (executed : executeMIRList f (staging ++ StackMIR.commitPhis 0 phis) d = .ok after) :
    CopyContext d after := by
  apply copyList_context f d after _ _ executed
  intro inst member
  rcases List.mem_append.mp member with stage | commit
  · exact stagePhis_copy pred 0 phis staging lowered inst stage
  · exact commitPhis_copy 0 phis inst commit

/-- The context guarantee is tied to the actual emitted edge block. -/
theorem lowerEdge_context (f : StackMIR.Function) (source : Source.Function) (pred target : Nat)
    (edge : StackMIR.Block) (d after : Data)
    (lowered : StackMIR.lowerEdge source pred target = .ok edge)
    (executed : executeMIRList f edge.instructions.toList d = .ok after) : CopyContext d after := by
  cases found : source.blocks[target]? with
  | none => simp [StackMIR.lowerEdge, found, throw] at lowered
  | some block =>
    cases stages : StackMIR.stagePhis pred 0 block.phis.toList with
    | error reason => simp [StackMIR.lowerEdge, found, stages, bind, Except.bind] at lowered
    | ok staging =>
      simp only [StackMIR.lowerEdge, found, stages, bind, Except.bind, pure, Except.pure, Except.ok.injEq] at lowered
      subst edge
      exact phi_context f pred block.phis.toList staging d after stages (by simpa using executed)

end LeanCompilerBackend.Verified.Machine
