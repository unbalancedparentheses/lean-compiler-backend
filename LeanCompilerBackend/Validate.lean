/-
  Admission and dominance checks for the QBE SSA subset.
  References: QBE 1.3 parse.c, cfg.c, ssa.c and doc/il.txt.
  This implements only the currently admitted subset, not QBE's full SSA
  construction or complete type system. See docs/UPSTREAM.md.
-/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend

private def validName (name : String) : Bool :=
  !name.isEmpty && name.toList.all (fun c => c.toNat < 128 && (c.isAlphanum || c == '_'))
    && (name.toList.head!.isAlpha || name.toList.head! == '_')

private def predecessors (f : Function) (label : String) : List String :=
  f.blocks.toList.filterMap fun block =>
    if block.terminator.successors.contains label then some block.label else none

private abbrev Dominators := List (String × List String)

/-- Finite-set iteration; unsupported/nonconverging cases fail closed. -/
private def dominators (f : Function) : Except String Dominators := do
  let names := f.blocks.toList.map (·.label)
  let entry := f.blocks[0]!.label
  let initial := names.map fun name => (name, if name == entry then [entry] else names)
  let rec iterate : Nat → Dominators → Except String Dominators
    | 0, _ => .error "dominance iteration resource limit exceeded"
    | fuel + 1, old => do
      let updated := names.map fun name =>
        if name == entry then (name, [entry])
        else
          let preds := predecessors f name
          let members := names.filter fun candidate =>
            candidate == name || (!preds.isEmpty &&
              preds.all fun pred => ((old.lookup pred).getD []).contains candidate)
          (name, members)
      if updated == old then pure updated else iterate fuel updated
  iterate (f.blocks.size * f.blocks.size + 1) initial

private structure Definition where
  name : String
  width : Width
  block : Option String
  position : Nat

private def addDefinition (definitions : List Definition) (definition : Definition)
    : Except String (List Definition) := do
  if !validName definition.name then throw "unsupported temporary/parameter name"
  if definitions.any (·.name == definition.name) then
    throw s!"duplicate SSA definition or duplicate parameter %{definition.name}"
  pure (definition :: definitions)

private def checkOperand (definitions : List Definition) (doms : Dominators)
    (useBlock : String) (position : Nat) (width : Width) (operand : Operand)
    : Except String Unit := do
  match operand with
  | .constant _ => pure ()
  | .temporary name =>
    let some definition := definitions.find? (·.name == name)
      | throw s!"undefined temporary %{name}"
    if definition.width == .word && width == .long then
      throw s!"%{name}: implicit w-to-l extension is unsupported; use an explicit conversion"
    match definition.block with
    | none => pure ()
    | some block =>
      if block == useBlock then
        if definition.position >= position then throw s!"%{name}: definition does not precede use"
      else if !((doms.lookup useBlock).getD []).contains block then
        throw s!"%{name}: definition in @{block} does not dominate use in @{useBlock}"

def validateFunction (f : Function) : Except String Unit := do
  if !validName f.name then throw "unsupported function name"
  if f.parameters.size > 8 then
    throw "initial AArch64 ABI subset supports at most eight integer parameters"
  if f.blocks.isEmpty then throw "function has no entry block"
  if f.blocks.size > 64 then throw "function exceeds initial 64-block limit"
  let count := f.blocks.foldl (fun n block => n + block.instructions.size + block.phis.size) 0
  if count > 480 then throw "function exceeds initial 480-instruction/phi limit"
  let names := f.blocks.toList.map (·.label)
  if names.any (!validName ·) then throw "unsupported block name"
  if names.eraseDups.length != names.length then throw "duplicate block label"
  let entry := f.blocks[0]!.label
  for block in f.blocks do
    for target in block.terminator.successors do
      if !names.contains target then throw s!"unknown block @{target}"
      if target == entry then throw "QBE entry block must not be a jump target"
  let mut definitions := []
  for parameter in f.parameters do
    definitions ← addDefinition definitions
      { name := parameter.name, width := parameter.width, block := none, position := 0 }
  for block in f.blocks do
    for phi in block.phis do
      definitions ← addDefinition definitions
        { name := phi.destination, width := phi.width, block := some block.label, position := 0 }
    for i in [:block.instructions.size] do
      let inst := block.instructions[i]!
      definitions ← addDefinition definitions
        { name := inst.destination, width := inst.width, block := some block.label, position := i + 1 }
  let doms ← dominators f
  for block in f.blocks do
    let preds := predecessors f block.label
    for phi in block.phis do
      let incoming := phi.incoming.toList.map (·.1)
      if incoming.isEmpty || incoming.eraseDups.length != incoming.length
          || incoming.length != preds.length || !incoming.all preds.contains then
        throw s!"phi %{phi.destination}: incoming labels must match block predecessors exactly"
      for (label, value) in phi.incoming do
        let some pred := f.blocks.find? (·.label == label)
          | throw s!"unknown phi predecessor @{label}"
        checkOperand definitions doms label (pred.instructions.size + 1) phi.width value
    for i in [:block.instructions.size] do
      let inst := block.instructions[i]!
      let check := checkOperand definitions doms block.label (i + 1)
      match inst.operation with
      | .copy value => check inst.width value
      | .binary op a b =>
        check inst.width a
        check (op.rhsWidth inst.width) b
      | .unary op value =>
        if (op == .signedWord || op == .unsignedWord) && inst.width != .long then
          throw "extsw/extuw require a long result"
        check (op.inputWidth inst.width) value
      | .divide _ a b =>
        check inst.width a
        check inst.width b
      | .compare _ width a b =>
        check width a
        check width b
    let check := checkOperand definitions doms block.label (block.instructions.size + 1)
    match block.terminator with
    | .ret value => check f.resultWidth value
    | .branch value _ _ => check .word value
    | .jump _ | .halt => pure ()

def validate (program : Program) : Except String Unit := do
  if program.isEmpty then throw "program contains no functions"
  if program.size > 64 then throw "program exceeds initial 64-function limit"
  let mut names : List String := []
  for f in program do
    if names.contains f.name then throw ("duplicate function $" ++ f.name)
    names := f.name :: names
    match validateFunction f with
    | .ok () => pure ()
    | .error message => throw s!"function ${f.name}: {message}"

end LeanCompilerBackend
