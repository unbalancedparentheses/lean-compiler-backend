/- Compatibility-only SSA copy propagation and conservative dead definitions. -/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend.Optimize.Cleanup

private def mapTarget (map : Operand → Operand) : CallTarget → CallTarget
  | .direct name => .direct name | .indirect v => .indirect (map v)
private def mapOperation (map : Operand → Operand) : Operation → Operation
  | .copy v => .copy (map v) | .cast v => .cast (map v)
  | .unary op v => .unary op (map v)
  | .binary op a b => .binary op (map a) (map b)
  | .divide op a b => .divide op (map a) (map b)
  | .compare op w a b => .compare op w (map a) (map b)
  | .floatBinary op a b => .floatBinary op (map a) (map b)
  | .floatNegate v => .floatNegate (map v)
  | .floatCompare op w a b => .floatCompare op w (map a) (map b)
  | .convert op v => .convert op (map v)
  | .allocate a v => .allocate a (map v)
  | .load k v => .load k (map v)
  | .vaArg v => .vaArg (map v)
  | .call target args => .call (mapTarget map target) (args.map fun a => {a with value := map a.value})
private def mapStatement (map : Operand → Operand) : Statement → Statement
  | .assign i => .assign {i with operation := mapOperation map i.operation}
  | .store w v p => .store w (map v) (map p)
  | .storeFloat w v p => .storeFloat w (map v) (map p)
  | .callVoid target args => .callVoid (mapTarget map target) (args.map fun a => {a with value := map a.value})
  | .vaStart v => .vaStart (map v)
  | .blit a b n => .blit (map a) (map b) n
private def mapTerminator (map : Operand → Operand) : Terminator → Terminator
  | .ret v => .ret (v.map map) | .branch v a b => .branch (map v) a b | other => other

private def resolve (aliases : Std.HashMap String String) (v : Operand) : Operand := Id.run do
  let .temporary original := v | return v
  let mut name := original
  -- Bounded traversal also handles disconnected, cyclic input defensively.
  for _ in [:128] do
    let some next := aliases[name]? | break
    if next == name then break
    name := next
  return .temporary name

/-- Same-width/class temporary copies only: never drop a narrowing conversion or
    turn a runtime allocation into a statically bounded constant allocation. -/
def copies (f : Function) : Function := Id.run do
  let mut types : Std.HashMap String (Width × Bool) := {}
  for p in f.parameters do types := types.insert p.name (p.width,p.floating)
  for b in f.blocks do
    for p in b.phis do types := types.insert p.destination (p.width,p.floating)
    for s in b.instructions do
      if let .assign i := s then types := types.insert i.destination (i.width,i.floating)
  let mut aliases : Std.HashMap String String := {}
  for b in f.blocks do
    for s in b.instructions do
      if let .assign i := s then
        if let .copy (.temporary source) := i.operation then
          if types[source]? == some (i.width,i.floating) then aliases := aliases.insert i.destination source
  let map := resolve aliases
  return {f with blocks := f.blocks.map fun b => {b with
    phis := b.phis.map (fun p => {p with incoming := p.incoming.map (fun (label,v) => (label,map v))})
    instructions := b.instructions.map (mapStatement map)
    terminator := mapTerminator map b.terminator}}

private def temporary : Operand → List String
  | .temporary name => [name] | _ => []
private def symbols (op : Operation) : Bool := op.operands.any fun v =>
  match v with | .symbol _ | .threadSymbol _ => true | _ => false
private def removable (i : Instruction) : Bool :=
  !symbols i.operation && match i.operation with
  | .copy _ | .cast _ | .unary .. | .binary .. | .compare .. => true
  | _ => false
private def terminatorUses : Terminator → List String
  | .ret (some v) | .branch v .. => temporary v
  | _ => []

/-- Mark from effects/returns, then sweep pure dead definitions. Potentially
    trapping division, loads, conversions, allocation, vaarg, calls, floating
    operations and symbol/TLS materialization are deliberately retained. -/
def deadDefinitions (f : Function) : Function := Id.run do
  let mut dependencies : Std.HashMap String (List String) := {}
  let mut pending : List String := []
  for b in f.blocks do
    pending := terminatorUses b.terminator ++ pending
    for p in b.phis do
      dependencies := dependencies.insert p.destination (p.incoming.toList.flatMap fun (_,v) => temporary v)
      if p.incoming.any (fun (_,v) => match v with | .symbol _ | .threadSymbol _ => true | _ => false) then
        pending := p.destination :: pending
    for s in b.instructions do
      match s with
      | .assign i =>
        dependencies := dependencies.insert i.destination (i.operation.operands.flatMap temporary)
        if !removable i then pending := i.destination :: pending
      | _ => pending := s.operands.flatMap temporary ++ pending
  let mut live : Std.HashSet String := {}
  -- Each definition expands at most once. Parameters need no expansion.
  while !pending.isEmpty do
    let name := pending.head!
    pending := pending.tail
    if live.contains name then continue
    live := live.insert name
    pending := (dependencies[name]?).getD [] ++ pending
  let blocks := f.blocks.map fun b => Id.run do
    let mut instructions := #[]
    let mut before : Array Nat := #[0]
    for s in b.instructions do
      let keep := match s with | .assign i => live.contains i.destination | _ => true
      if keep then instructions := instructions.push s
      before := before.push instructions.size
    return {b with
      phis := b.phis.filter (fun p => live.contains p.destination)
      instructions
      debugLocations := b.debugLocations.map (fun loc => {loc with instruction := before[loc.instruction]!})}
  return {f with blocks}

end LeanCompilerBackend.Optimize.Cleanup
