/- QBE-compatible mutable-temporary to SSA construction.
   Read a varName at a block boundary through predecessor definitions, inserting
   phis on demand. Cache join placeholders before recursion to close loop edges.
   This is an executable compatibility pass, not a proved transformation. -/
import LeanCompilerBackend.Validate

namespace LeanCompilerBackend.SSA

private abbrev Bindings := List (String × String)

private structure Plan where
  block : Block
  phiNames : Array String
  instructionNames : Array (Option String)
  outgoing : Bindings
  deriving Inhabited

private structure State where
  plans : Array Plan := #[]
  types : Std.HashMap String (Width × Bool) := {}
  indices : Std.HashMap String Nat := {}
  predecessors : Array (Array Nat) := #[]
  parameters : Bindings := []
  cache : Std.HashMap (String × String) String := {}
  visiting : Std.HashSet (String × String) := {}
  generated : List (String × Phi) := []
  namePrefix : String := "lcb.ssa."
  next : Nat := 0

private abbrev M := StateT State (Except String)

private def fresh : M String := do
  let s ← get
  set { s with next := s.next + 1 }
  pure (s.namePrefix ++ toString s.next)

private def bind (bindings : Bindings) (name value : String) : Bindings :=
  (name, value) :: bindings.filter (·.1 != name)

private def readAt : Nat → String → String → Bool → M String
  | 0, _, _, _ => throw "SSA construction recursion resource limit exceeded"
  | fuel + 1, label, varName, atEnd => do
    let s ← get
    let some index := s.indices[label]? | throw s!"SSA construction: unknown block @{label}"
    let plan := s.plans[index]!
    if atEnd then
      if let some name := plan.outgoing.lookup varName then return name
      return ← readAt fuel label varName false
    if let some name := s.cache[(label, varName)]? then return name
    if label == s.plans[0]!.block.label then
      let some name := s.parameters.lookup varName
        | throw s!"SSA construction: undefined temporary %{varName} at entry"
      return name
    let preds := s.predecessors[index]!
    if preds.isEmpty then throw s!"SSA construction: undefined temporary %{varName} in unreachable @{label}"
    if preds.size == 1 then
      if s.visiting.contains (label, varName) then
        throw s!"SSA construction: undefined temporary %{varName} in predecessor cycle"
      modify fun s => { s with visiting := s.visiting.insert (label, varName) }
      let name ← readAt fuel s.plans[preds[0]!]!.block.label varName true
      modify fun s => { s with cache := s.cache.insert (label, varName) name, visiting := s.visiting.erase (label, varName) }
      return name
    let some (width, floating) := s.types[varName]?
      | throw s!"SSA construction: undefined temporary %{varName}"
    let name ← fresh
    modify fun s => { s with cache := s.cache.insert (label, varName) name }
    let incoming ← preds.mapM fun pred => do
      let label := s.plans[pred]!.block.label
      pure (label, Operand.temporary (← readAt fuel label varName true))
    let phi : Phi := { destination := name, width, floating, incoming }
    modify fun s => { s with generated := (label, phi) :: s.generated }
    return name

private def operand (label : String) (locals : Bindings) : Operand → M Operand
  | .temporary name => do
    let renamed ← match locals.lookup name with
      | some value => pure value
      | none => readAt 32768 label name false
    pure (.temporary renamed)
  | value => pure value

private def target (map : Operand → M Operand) : CallTarget → M CallTarget
  | .direct name => pure (.direct name)
  | .indirect value => return .indirect (← map value)

private def arguments (map : Operand → M Operand) (args : Array CallArgument) : M (Array CallArgument) :=
  args.mapM fun arg => do pure { arg with value := ← map arg.value }

private def operation (map : Operand → M Operand) : Operation → M Operation
  | .copy x => return .copy (← map x)
  | .cast x => return .cast (← map x)
  | .convert op x => return .convert op (← map x)
  | .unary op x => return .unary op (← map x)
  | .floatNegate x => return .floatNegate (← map x)
  | .binary op x y => return .binary op (← map x) (← map y)
  | .floatBinary op x y => return .floatBinary op (← map x) (← map y)
  | .divide op x y => return .divide op (← map x) (← map y)
  | .compare op width x y => return .compare op width (← map x) (← map y)
  | .floatCompare op width x y => return .floatCompare op width (← map x) (← map y)
  | .allocate alignment x => return .allocate alignment (← map x)
  | .load kind x => return .load kind (← map x)
  | .vaArg x => return .vaArg (← map x)
  | .call callee args => return .call (← target map callee) (← arguments map args)

private def rewriteBlock (plan : Plan) : M Block := do
  let initial ← get
  let mut locals := if plan.block.label == initial.plans[0]!.block.label then initial.parameters else []
  let mut phis := #[]
  for i in [:plan.block.phis.size] do
    let phi := plan.block.phis[i]!
    let incoming ← phi.incoming.mapM fun (label, value) => do
      let value ← match value with
        | .temporary name => pure (.temporary (← readAt 32768 label name true))
        | _ => pure value
      pure (label, value)
    phis := phis.push { phi with destination := plan.phiNames[i]!, incoming }
    locals := bind locals phi.destination plan.phiNames[i]!
  let mut instructions := #[]
  for i in [:plan.block.instructions.size] do
    let map := operand plan.block.label locals
    let statement : Statement ← match plan.block.instructions[i]! with
      | .assign inst => do
        let some name := plan.instructionNames[i]! | throw "SSA construction: missing definition plan"
        let op ← operation map inst.operation
        locals := bind locals inst.destination name
        pure (.assign { inst with destination := name, operation := op })
      | .store width x address => pure (.store width (← map x) (← map address))
      | .storeFloat width x address => pure (.storeFloat width (← map x) (← map address))
      | .callVoid callee args => pure (.callVoid (← target map callee) (← arguments map args))
      | .vaStart x => pure (.vaStart (← map x))
      | .blit x y size => pure (.blit (← map x) (← map y) size)
    instructions := instructions.push statement
  let map := operand plan.block.label locals
  let terminator : Terminator ← match plan.block.terminator with
    | .ret value => pure (.ret (← value.mapM map))
    | .branch value yes no => pure (.branch (← map value) yes no)
    | .jump label => pure (.jump label)
    | .halt => pure .halt
  pure { plan.block with phis, instructions, terminator }

private def addType (types : Std.HashMap String (Width × Bool)) (name : String) (width : Width)
    (floating : Bool) : Except String (Std.HashMap String (Width × Bool)) := do
  if !validIdentifier name then throw "SSA construction: invalid temporary name"
  if let some (oldWidth, oldFloating) := types[name]? then
    if oldWidth != width || oldFloating != floating then
      throw s!"SSA construction: inconsistent types for mutable temporary %{name}"
    return types
  pure (types.insert name (width, floating))

/-- Leave already-SSA inputs unchanged; mutable input is renamed and validated.
    The original first-path importer does not invoke this pass. -/
def construct (f : Function) : Except String Function := do
  let names := f.locals.toList.map (·.1)
  let mut seen : Std.HashSet String := {}
  let mut duplicate := false
  for name in names do
    if seen.contains name then duplicate := true
    seen := seen.insert name
  if !duplicate then return f
  if f.blocks.isEmpty then throw "SSA construction: function has no entry block"
  let parameters := f.parameters.toList.map (·.name)
  if parameters.eraseDups.length != parameters.length then throw "duplicate parameter"
  let labels := f.blocks.toList.map (·.label)
  if labels.eraseDups.length != labels.length then throw "duplicate block label"
  let mut types : Std.HashMap String (Width × Bool) := {}
  for p in f.parameters do types ← addType types p.name p.width p.floating
  for block in f.blocks do
    if !validIdentifier block.label then throw "SSA construction: invalid block name"
    for label in block.terminator.successors do
      if !labels.contains label then throw s!"unknown block @{label}"
      if label == f.blocks[0]!.label then throw "QBE entry block must not be a jump target"
    let phiNames := block.phis.toList.map (·.destination)
    if phiNames.eraseDups.length != phiNames.length then throw "duplicate phi destination"
    for phi in block.phis do types ← addType types phi.destination phi.width phi.floating
    for statement in block.instructions do
      if let .assign inst := statement then types ← addType types inst.destination inst.width inst.floating
  let mut namePrefix := "lcb.ssa."
  for _ in [:names.length + 1] do
    if names.any (·.startsWith namePrefix) then namePrefix := namePrefix ++ "_"
  let build : M Function := do
    let parameters ← f.parameters.mapM fun p => do
      let name ← fresh
      modify fun s => { s with parameters := bind s.parameters p.name name }
      pure { p with name }
    let mut plans := #[]
    for block in f.blocks do
      let initial ← get
      let mut outgoing := if block.label == f.blocks[0]!.label then initial.parameters else []
      let mut phiNames := #[]
      for phi in block.phis do
        let name ← fresh
        phiNames := phiNames.push name
        outgoing := bind outgoing phi.destination name
      let mut instructionNames := #[]
      for statement in block.instructions do
        if let .assign inst := statement then
          let name ← fresh
          instructionNames := instructionNames.push (some name)
          outgoing := bind outgoing inst.destination name
        else instructionNames := instructionNames.push none
      plans := plans.push { block, phiNames, instructionNames, outgoing }
    modify fun s => { s with plans }
    let blocks ← plans.mapM rewriteBlock
    let generated := (← get).generated.reverse
    let blocks := blocks.map fun block => { block with
      phis := block.phis ++ (generated.filterMap fun (label, phi) => if label == block.label then some phi else none).toArray }
    pure { f with parameters, blocks }
  let graph ← CFG.build f
  let (result, _) ← build.run { types, namePrefix, indices := graph.indices, predecessors := graph.predecessors }
  match validateFunction result true with
  | .ok () => pure result
  | .error error => throw s!"constructed SSA failed validation: {error}"

/-- QBE fixtures may assign an unused scalar result from a defined void callee.
    Drop that dead result after SSA renaming; never manufacture a value that can
    be observed, and retain result-signature checks for every used temporary. -/
private def discardUnusedVoidResults (program : Program) (f : Function) : Function := Id.run do
  let mut used : List String := []
  for block in f.blocks do
    let terms := match block.terminator with
      | .ret (some value) | .branch value _ _ => [value]
      | _ => []
    let operands := block.phis.toList.flatMap (fun phi => phi.incoming.toList.map (·.2)) ++
      block.instructions.toList.flatMap Statement.operands ++ terms
    for operand in operands do
      if let .temporary name := operand then used := name :: used
  let blocks := f.blocks.map fun block =>
    { block with instructions := block.instructions.map fun statement =>
      match statement with
      | .assign inst => match inst.operation with
        | .call (.direct name) arguments =>
          if inst.callAggregate.isNone && !used.contains inst.destination &&
              (program.find? (·.name == name)).any (·.resultWidth.isNone) then
            .callVoid (.direct name) arguments
          else statement
        | _ => statement
      | _ => statement }
  return { f with blocks }

/-- Normalize only the explicitly uncertified compatibility module. -/
def constructModule (m : LeanCompilerBackend.Module) : Except String LeanCompilerBackend.Module := do
  let functions ← m.functions.mapM fun f => do
    match construct f with
    | .ok result => pure result
    | .error error => throw s!"function ${f.name}: {error}"
  let functions := functions.map (discardUnusedVoidResults functions)
  let result := { m with functions }
  validateModule result
  pure result

end LeanCompilerBackend.SSA
