/-
  Restricted profile admission and local numbering for F01.
  This is an executable, fail-closed importer, NOT a proved CheckedSSA checker.
-/
import LeanCompilerBackend.Validate
import LeanCompilerBackend.Verified.Source

namespace LeanCompilerBackend.Verified

inductive AdmissionError where
  | invalidInput (reason : String)
  | unsupported (feature : String)
  | resourceLimit (resource : String) (measured limit : Nat)
  deriving DecidableEq, Repr

private def limit (resource : String) (measured maximum : Nat) : Except AdmissionError Unit :=
  if measured > maximum then .error (.resourceLimit resource measured maximum) else .ok ()

private def valueId (locals : Array (String × Width)) (name : String)
    : Except AdmissionError Nat := do
  let some i := locals.findIdx? (·.1 == name)
    | throw (.invalidInput s!"unknown temporary %{name}")
  pure i

private def blockId (f : Function) (name : String) : Except AdmissionError Nat := do
  let some i := f.blocks.findIdx? (·.label == name)
    | throw (.invalidInput s!"unknown block @{name}")
  pure i

private def operand (locals : Array (String × Width)) (width : Width)
    : Operand → Except AdmissionError Source.Operand
  | .constant n => .ok (.literal (Source.Value.constant width n))
  | .threadSymbol _ => .error (.unsupported "thread-local symbol addresses")
  | .symbol _ => .error (.unsupported "global symbol addresses")
  | .temporary name => do
    let id ← valueId locals name
    let some (_, actual) := locals[id]? | throw (.invalidInput "missing local width")
    if actual != width then
      throw (.unsupported s!"implicit width conversion of %{name}; first profile requires exact widths")
    pure (.local id)

private def binary : Binary → Except AdmissionError Source.Binary
  | .add => .ok .add | .sub => .ok .sub | .mul => .ok .mul
  | .andBits => .ok .andBits | .orBits => .ok .orBits | .xorBits => .ok .xorBits
  | _ => .error (.unsupported "shifts")

private def comparison : Comparison → Except AdmissionError Source.Comparison
  | .eq => .ok .eq | .unsignedLT => .ok .unsignedLT
  | _ => .error (.unsupported "comparison other than eq/unsignedLT")

private def instruction (locals : Array (String × Width)) (inst : Instruction)
    : Except AdmissionError Source.Instruction := do
  if inst.floating then throw (.unsupported "floating values")
  let destination ← valueId locals inst.destination
  let op ← match inst.operation with
    | .copy value => Source.Operation.copy <$> operand locals inst.width value
    | .binary op lhs rhs => do
      pure (.binary (← binary op) (← operand locals inst.width lhs) (← operand locals inst.width rhs))
    | .compare op width lhs rhs => do
      if inst.width != .word then throw (.unsupported "non-word comparison result")
      pure (.compare (← comparison op) width (← operand locals width lhs) (← operand locals width rhs))
    | .convert .. | .floatBinary .. | .floatNegate .. | .floatCompare .. | .cast .. => throw (.unsupported "floating operations/casts")
    | .unary .. => throw (.unsupported "unary operations")
    | .divide .. => throw (.unsupported "division/remainder")
    | .allocate .. => throw (.unsupported "source stack allocations")
    | .load .. => throw (.unsupported "source memory loads")
    | .vaArg .. => throw (.unsupported "variadic argument access")
    | .call .. => throw (.unsupported "calls")
  pure { destination, width := inst.width, operation := op }

/-- With B blocks, B successor-closure rounds include every reachable vertex.
    This executable bound still needs its checker-soundness proof. -/
private def reachable (f : Function) : Array String := Id.run do
  let mut reached := #[f.blocks[0]!.label]
  for _ in [:f.blocks.size] do
    let old := reached
    for block in f.blocks do
      if old.contains block.label then
        for target in block.terminator.successors do
          if !reached.contains target then reached := reached.push target
  return reached

/-- Import only the v1 profile into raw locally numbered syntax. The result is
    not proof-carrying and must not satisfy a certification request. -/
def admit (f : Function) : Except AdmissionError Source.Function := do
  if f.customSection.isSome then throw (.unsupported "custom sections")
  if f.resultAggregate.isSome || f.parameters.any (·.aggregate.isSome) then throw (.unsupported "aggregate function signatures")
  if f.resultSubword.isSome || f.parameters.any (·.subword.isSome) then throw (.unsupported "subword function signatures")
  if f.resultFloating || f.parameters.any (·.floating) then throw (.unsupported "floating function signatures")
  if f.variadic then throw (.unsupported "variadic functions")
  if f.parameters.any (·.environment) then throw (.unsupported "environment parameters")
  limit "parameters" f.parameters.size 8
  limit "blocks" f.blocks.size 64
  let definitions := f.blocks.foldl (fun n b => n + b.phis.size + b.instructions.size) 0
  limit "definitions" definitions 480
  let some resultWidth := f.resultWidth | throw (.unsupported "void result")
  match validateFunction f with
  | .error error => throw (.invalidInput error)
  | .ok () => pure ()
  if !(f.blocks[0]!.phis.isEmpty) then throw (.invalidInput "entry phis")
  let reached := reachable f
  if reached.size != f.blocks.size then throw (.unsupported "unreachable blocks")
  let locals := f.locals
  let maxPhis := f.blocks.foldl (fun n block => max n block.phis.size) 0
  let frame := ((8 * (locals.size + maxPhis) + 15) / 16) * 16
  limit "frame bytes" frame 4080
  let mut blocks := #[]
  for block in f.blocks do
    let mut phis := #[]
    for phi in block.phis do
      if phi.floating then throw (.unsupported "floating phi values")
      -- Resolve in block order, independent of textual incoming-list order.
      let mut incoming := #[]
      for pred in f.blocks do
        if let some (_, value) := phi.incoming.find? (·.1 == pred.label) then
          incoming := incoming.push (← blockId f pred.label, ← operand locals phi.width value)
      let destination ← valueId locals phi.destination
      phis := phis.push ({ destination, width := phi.width, incoming } : Source.Phi)
    let mut instructions := #[]
    for statement in block.instructions do
      match statement with
      | .assign inst => instructions := instructions.push (← instruction locals inst)
      | .storeFloat .. => throw (.unsupported "floating stores")
      | .store .. => throw (.unsupported "source memory stores")
      | .callVoid .. => throw (.unsupported "calls")
      | .vaStart .. => throw (.unsupported "variadic argument access")
      | .blit .. => throw (.unsupported "source memory blits")
    let terminator ← match block.terminator with
      | .ret (some value) => Source.Terminator.ret <$> operand locals resultWidth value
      | .ret none => throw (.invalidInput "missing integer return")
      | .jump target => Source.Terminator.jump <$> blockId f target
      | .branch condition yes no => do
        pure (.branch (← operand locals .word condition) (← blockId f yes) (← blockId f no))
      | .halt => throw (.unsupported "halt/traps")
    blocks := blocks.push ({ phis, instructions, terminator } : Source.Block)
  pure { resultWidth, parameters := f.parameters.map (·.width),
         valueWidths := locals.map (·.2), blocks }

end LeanCompilerBackend.Verified
