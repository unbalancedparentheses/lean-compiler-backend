/- Compatibility SSA liveness. Phi operands are uses on predecessor edges,
   not uses in the successor block. This analysis has no preservation proof. -/
import LeanCompilerBackend.Validate

namespace LeanCompilerBackend.Liveness

abbrev Set := Nat

structure Result where
  names : Array String
  indices : Std.HashMap String Nat
  graph : CFG.Graph
  /-- Immediately before the block's parallel phi definitions. -/
  liveIn : Array Set
  /-- Union of successor-edge liveness, after the terminator's own uses. -/
  liveOut : Array Set
  /-- Before each ordinary instruction, with a final entry before the terminator.
      Entry zero is after the block's phi definitions. -/
  before : Array (Array Set)
  /-- Indexed by source block and its graph.successors entry. -/
  edges : Array (Array Set)

def Result.contains (r : Result) (set : Set) (name : String) : Bool :=
  (r.indices[name]?).any (fun i => (set >>> i) &&& 1 == 1)

def Result.members (r : Result) (set : Set) : Array String := Id.run do
  let mut remaining := set
  let mut result := #[]
  for i in [:r.names.size] do
    if remaining == 0 then break
    if remaining &&& 1 == 1 then result := result.push r.names[i]!
    remaining := remaining >>> 1
  return result

private def remove (set killed : Set) : Set := set ^^^ (set &&& killed)
private def bit (indices : Std.HashMap String Nat) (name : String) : Set :=
  (indices[name]?).map (fun i => 1 <<< i) |>.getD 0
private def operands (indices : Std.HashMap String Nat) (values : List Operand) : Set :=
  values.foldl (fun set v => match v with
    | .temporary name => set ||| bit indices name
    | _ => set) 0

def terminatorOperands : Terminator → List Operand
  | .ret v => v.toList | .branch v .. => [v] | _ => []

/-- Finite monotone worklist, then a backward scan for instruction boundaries.
    All supplied SSA is validated, including unreachable blocks. -/
def analyze (f : Function) : Except String Result := do
  validateFunction f true
  let graph ← CFG.build f
  let names := f.locals.map (·.1)
  let indices := names.foldl (fun (state : Std.HashMap String Nat × Nat) name =>
    (state.1.insert name state.2, state.2+1)) ({}, 0) |>.1
  let mut definitions := #[]
  let mut uses := #[]
  let mut phiUses := Array.replicate f.blocks.size (#[] : Array Set)
  for b in f.blocks do
    let mut defined := b.phis.foldl (fun set p => set ||| bit indices p.destination) 0
    let mut used := 0
    for statement in b.instructions do
      used := used ||| remove (operands indices statement.operands) defined
      if let some (name, _) := statement.definition then defined := defined ||| bit indices name
    used := used ||| remove (operands indices (terminatorOperands b.terminator)) defined
    definitions := definitions.push defined
    uses := uses.push used
  for source in [:f.blocks.size] do
    let mut edgeUses := #[]
    for target in graph.successors[source]! do
      let mut used := 0
      for p in f.blocks[target]!.phis do
        for (label, value) in p.incoming do
          if label == f.blocks[source]!.label then used := used ||| operands indices [value]
      edgeUses := edgeUses.push used
    phiUses := phiUses.set! source edgeUses
  let count := f.blocks.size
  let mut liveIn := Array.replicate count 0
  let mut liveOut := Array.replicate count 0
  let mut queue := (List.range count).reverse.toArray
  let mut queued := Array.replicate count true
  let mut next := 0
  let mut converged := false
  let edgeCount := graph.successors.foldl (fun n edges => n + edges.size) 0
  -- Each live-in bit changes once and can enqueue each incoming edge once.
  for _ in [:(names.size+1)*(edgeCount+count)+1] do
    if next == queue.size then
      converged := true
      break
    let node := queue[next]!
    next := next+1
    queued := queued.set! node false
    let outgoing := (graph.successors[node]!.zip phiUses[node]!).foldl
      (fun set (target, edgeUses) => set ||| liveIn[target]! ||| edgeUses) 0
    liveOut := liveOut.set! node outgoing
    let incoming := uses[node]! ||| remove outgoing definitions[node]!
    if incoming != liveIn[node]! then
      liveIn := liveIn.set! node incoming
      for pred in graph.predecessors[node]! do
        if !queued[pred]! then
          queue := queue.push pred
          queued := queued.set! pred true
    if next >= 4096 then
      queue := queue.extract next queue.size
      next := 0
  if !converged then throw "liveness iteration resource limit exceeded"
  let mut before := #[]
  let mut edges := #[]
  for node in [:count] do
    let b := f.blocks[node]!
    let mut live := liveOut[node]! ||| operands indices (terminatorOperands b.terminator)
    let mut points := (Array.replicate (b.instructions.size+1) 0).set! b.instructions.size live
    for step in [:b.instructions.size] do
      let i := b.instructions.size-1-step
      let statement := b.instructions[i]!
      if let some (name, _) := statement.definition then live := remove live (bit indices name)
      live := live ||| operands indices statement.operands
      points := points.set! i live
    before := before.push points
    edges := edges.push ((graph.successors[node]!.zip phiUses[node]!).map fun (target, used) => liveIn[target]! ||| used)
  pure {names, indices, graph, liveIn, liveOut, before, edges}

end LeanCompilerBackend.Liveness
