/- Typed stack-baseline MIR and lowering. Structural checks are executable only;
   the preservation/checker-soundness proofs remain separate obligations. -/
import LeanCompilerBackend.Verified.Plans

namespace LeanCompilerBackend.Verified.StackMIR

inductive Register where
  | r0 | r9 | r10
  deriving DecidableEq, Repr

def Register.index : Register → Nat
  | .r0 => 0 | .r9 => 9 | .r10 => 10

inductive Slot where
  | value (id : Nat)
  | stage (id : Nat)
  deriving DecidableEq, Repr

inductive Label where
  | entry
  | body (block : Nat)
  | edge (predecessor target : Nat)
  deriving DecidableEq, Repr

inductive Instruction where
  | enterFrame (bytes : Nat)
  | leaveFrame (bytes : Nat)
  | readArg (width : Width) (index : Nat) (slot : Slot)
  | constant (reg : Register) (value : Source.Value)
  | load (width : Width) (reg : Register) (slot : Slot)
  | store (width : Width) (slot : Slot) (reg : Register)
  | alu (width : Width) (op : Source.Binary) (dst lhs rhs : Register)
  | compare (width : Width) (op : Source.Comparison) (dst lhs rhs : Register)
  deriving DecidableEq, Repr

inductive Terminator where
  | jump (label : Label)
  | branch (condition : Register) (yes no : Label)
  | ret (width : Width)
  deriving DecidableEq, Repr

structure Block where
  label : Label
  instructions : Array Instruction
  terminator : Terminator
  deriving DecidableEq, Repr

structure Function where
  parameters : Array Width
  resultWidth : Width
  valueWidths : Array Width
  layout : FrameLayout
  blocks : Array Block
  deriving DecidableEq, Repr

def loadOperand (width : Width) (reg : Register) : Source.Operand → Instruction
  | .local id => .load width reg (.value id)
  | .literal value => .constant reg value

def lowerInstruction (i : Source.Instruction) : Array Instruction := Id.run do
  let code := match i.operation with
    | .copy value => #[loadOperand i.width .r9 value]
    | .binary op lhs rhs => #[loadOperand i.width .r9 lhs, loadOperand i.width .r10 rhs,
        .alu i.width op .r9 .r9 .r10]
    | .compare op width lhs rhs => #[loadOperand width .r9 lhs, loadOperand width .r10 rhs,
        .compare width op .r9 .r9 .r10]
  return code.push (.store i.width (.value i.destination) .r9)

/-- Read every incoming value into its own staging slot before committing any
    destination. List recursion exposes the two phases for semantic proofs. -/
def stagePhis (pred index : Nat) : List Source.Phi → Except String (List Instruction)
  | [] => .ok []
  | phi :: rest => do
    let some (_, operand) := phi.incoming.find? (·.1 == pred) | throw "missing phi predecessor"
    let tail ← stagePhis pred (index+1) rest
    pure (loadOperand phi.width .r9 operand :: .store phi.width (.stage index) .r9 :: tail)

def commitPhis (index : Nat) : List Source.Phi → List Instruction
  | [] => []
  | phi :: rest => .load phi.width .r9 (.stage index) ::
      .store phi.width (.value phi.destination) .r9 :: commitPhis (index+1) rest

def lowerEdge (f : Source.Function) (pred target : Nat) : Except String Block := do
  let some block := f.blocks[target]? | throw "edge target is missing"
  let stages ← stagePhis pred 0 block.phis.toList
  pure { label := .edge pred target,
         instructions := (stages ++ commitPhis 0 block.phis.toList).toArray,
         terminator := .jump (.body target) }

/-- Layout is supplied explicitly, then checked against the source contract. -/
def lower (source : Source.Function) (layout : FrameLayout) : Except String Function := do
  match validateSource source with
  | .error e => throw s!"source admission: {repr e}"
  | .ok () => pure ()
  if layout != planFrame source then throw "frame layout mismatch"
  let mut entry := #[Instruction.enterFrame layout.frameBytes]
  for i in [:source.parameters.size] do
    let some width := source.parameters[i]? | throw "missing parameter"
    entry := entry.push (.readArg width i (.value i))
  let mut blocks := #[{ label := .entry, instructions := entry, terminator := .jump (.body 0) : Block }]
  for id in [:source.blocks.size] do
    let some block := source.blocks[id]? | throw "missing source block"
    let mut instructions := block.instructions.foldl (fun code i => code ++ lowerInstruction i) #[]
    let (terminator, successors) ← match block.terminator with
      | .ret value => do
        instructions := instructions ++ #[loadOperand source.resultWidth .r0 value, .leaveFrame layout.frameBytes]
        pure (Terminator.ret source.resultWidth, #[])
      | .jump target => pure (.jump (.edge id target), #[target])
      | .branch condition yes no => do
        instructions := instructions.push (loadOperand .word .r9 condition)
        pure (.branch .r9 (.edge id yes) (.edge id no), if yes == no then #[yes] else #[yes, no])
    blocks := blocks.push { label := .body id, instructions, terminator }
    for target in successors do blocks := blocks.push (← lowerEdge source id target)
  pure { parameters := source.parameters, resultWidth := source.resultWidth,
         valueWidths := source.valueWidths, layout, blocks }

def offset (f : Function) (slot : Slot) : Except String Nat :=
  match slot with
  | .value i => match f.layout.valueOffsets[i]? with | some offset => .ok offset | none => .error "value slot does not exist"
  | .stage i => match f.layout.stageOffsets[i]? with | some offset => .ok offset | none => .error "stage slot does not exist"

private def checkAccess (f : Function) (width : Width) (slot : Slot) : Except String Unit := do
  let o ← offset f slot
  if o % width.bytes != 0 || o + width.bytes > f.layout.frameBytes then throw "invalid frame access"
  if let .value id := slot then
    if f.valueWidths[id]? != some width then throw "value slot width mismatch"

/-- Structural legality, including per-edge stage initialization and frame phase.
    It does not prove that a selected source value is the right value. -/
def validate (f : Function) : Except String Unit := do
  if f.parameters.size > 8 || f.blocks.isEmpty || f.layout.frameBytes > 4080 ||
      f.layout.frameBytes % 16 != 0 then throw "invalid MIR signature/frame"
  let n := f.valueWidths.size
  if f.layout.version != 1 || f.layout.valueOffsets != (Array.range n).map (8 * ·) ||
      f.layout.stageOffsets != (Array.range f.layout.stageOffsets.size).map (fun i => 8 * (n+i)) ||
      f.layout.frameBytes != ((8 * (n + f.layout.stageOffsets.size) + 15) / 16) * 16 then
    throw "MIR frame regions overlap or differ from canonical layout"
  if (f.blocks[0]?).map (·.label) != some .entry then throw "entry must be first"
  let mut labels : Array Label := #[]
  for block in f.blocks do
    if labels.contains block.label then throw "duplicate MIR label"
    labels := labels.push block.label
  for block in f.blocks do
    let mut active := block.label != .entry
    let mut entered := false
    let mut left := false
    let mut stages : Array (Nat × Width) := #[]
    let mut arguments : Array Nat := #[]
    for index in [:block.instructions.size] do
      let some inst := block.instructions[index]? | throw "missing MIR instruction"
      if left then throw "instruction after frame leave"
      match inst with
      | .enterFrame bytes =>
        if block.label != .entry || index != 0 || entered || bytes != f.layout.frameBytes then
          throw "invalid frame entry"
        active := true
        entered := true
      | .leaveFrame bytes =>
        if !active || block.label == .entry || bytes != f.layout.frameBytes then throw "invalid frame leave"
        active := false
        left := true
      | .readArg width arg slot =>
        if !active || block.label != .entry || f.parameters[arg]? != some width || slot != .value arg then
          throw "invalid incoming argument store"
        if arguments.contains arg then throw "duplicate incoming argument"
        arguments := arguments.push arg
        checkAccess f width slot
      | .load width _ slot =>
        if !active then throw "load outside frame lifetime"
        checkAccess f width slot
        if let .stage id := slot then
          if !stages.contains (id, width) then throw "stage read before same-width write"
      | .store width slot _ =>
        if !active then throw "store outside frame lifetime"
        checkAccess f width slot
        if let .stage id := slot then
          if !(match block.label with | .edge .. => true | _ => false) then throw "stage write outside edge"
          stages := (stages.filter (·.1 != id)).push (id, width)
      | _ => if !active then throw "operation outside frame lifetime"
    if block.label == .entry && (!entered || arguments.size != f.parameters.size) then
      throw "incomplete MIR prologue"
    let targets := match block.terminator with
      | .jump target => #[target]
      | .branch _ yes no => #[yes, no]
      | .ret _ => #[]
    for target in targets do
      if target == .entry || !labels.contains target then throw "invalid MIR branch target"
    match block.terminator with
    | .ret width => if !left || active || width != f.resultWidth then throw "invalid MIR return/frame state"
    | _ => if !active || left then throw "branch after frame teardown"

end LeanCompilerBackend.Verified.StackMIR
