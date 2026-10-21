/- Compatibility-only allocation of stable SSA homes. Not a proof certificate. -/
import LeanCompilerBackend.Liveness

namespace LeanCompilerBackend.Allocation

structure Plan where
  names : Array String
  /-- Colors below registerCount are callee-saved registers; the rest are slots. -/
  colors : Array Nat
  colorCount : Nat
  registerCount : Nat
  deriving Inhabited

def Plan.registers (p : Plan) : Nat := min p.colorCount p.registerCount
def Plan.spills (p : Plan) : Nat := p.colorCount - p.registerCount

def Plan.homes (p : Plan) : List (String × Nat) := p.names.toList.zip p.colors.toList

private def indices (set : Nat) : Array Nat := Id.run do
  let mut bits := set
  let mut result := #[]
  for _ in [:set.log2+1] do
    if bits == 0 then break
    let rest := bits &&& (bits-1)
    result := result.push (bits ^^^ rest).log2
    bits := rest
  return result

private def bit (live : Liveness.Result) (name : String) : Nat :=
  (live.indices[name]?).map (fun i => 1 <<< i) |>.getD 0

private def connect (graph : Array Nat) (node : Nat) (others : Nat) : Array Nat := Id.run do
  let others := others ^^^ (others &&& (1 <<< node))
  let mut graph := graph.set! node (graph[node]! ||| others)
  for other in indices others do graph := graph.set! other (graph[other]! ||| (1 <<< node))
  return graph

private def interference (f : Function) (live : Liveness.Result) : Array Nat := Id.run do
  let mut graph := Array.replicate live.names.size 0
  -- All parameter stores execute, including dead parameters.
  let parameters := f.parameters.foldl (fun s p => s ||| bit live p.name) 0
  for p in f.parameters do
    graph := connect graph live.indices[p.name]! parameters
  for b in [:f.blocks.size] do
    let block := f.blocks[b]!
    -- Phi inputs are staged before any destination is committed. All commits
    -- execute, so a dead destination must not overwrite another live phi.
    let phis := block.phis.foldl (fun s p => s ||| bit live p.destination) 0
    for phi in block.phis do
      graph := connect graph live.indices[phi.destination]! (phis ||| live.before[b]![0]!)
    for i in [:block.instructions.size] do
      if let some (name, _) := block.instructions[i]!.definition then
        graph := connect graph live.indices[name]! live.before[b]![i+1]!
  return graph

/-- Check the proposed homes directly at definition boundaries, independently of
    graph construction/coloring. All writes (even dead ones) must preserve live
    values. Parameter and phi writes are checked as parallel definition groups. -/
def check (f : Function) (live : Liveness.Result) (plan : Plan) : Except String Unit := do
  if plan.names != live.names || plan.colors.size != live.names.size then
    throw "allocation value inventory mismatch"
  if plan.colorCount > live.names.size then throw "allocation color count exceeds value count"
  let mut occupants := Array.replicate plan.colorCount (0 : Nat)
  for i in [:plan.colors.size] do
    let color := plan.colors[i]!
    if color >= plan.colorCount then throw "allocation color out of bounds"
    occupants := occupants.set! color (occupants[color]! ||| (1 <<< i))
  let safeWrite := fun (name : String) (survivors : Nat) => do
    let some index := live.indices[name]? | throw "allocation definition missing"
    let others := survivors ^^^ (survivors &&& (1 <<< index))
    if occupants[plan.colors[index]!]! &&& others != 0 then
      throw s!"allocation overwrites live value at %{name}"
  let mut parameters := 0
  for p in f.parameters do parameters := parameters ||| bit live p.name
  for p in f.parameters do safeWrite p.name parameters
  for b in [:f.blocks.size] do
    let block := f.blocks[b]!
    let mut survivors := live.before[b]![0]!
    for phi in block.phis do survivors := survivors ||| bit live phi.destination
    for phi in block.phis do safeWrite phi.destination survivors
    for i in [:block.instructions.size] do
      if let some (name, _) := block.instructions[i]!.definition then
        safeWrite name live.before[b]![i+1]!
  return ()

/-- Deterministic greedy coloring. Call-preserved homes avoid call clobbers;
    excess colors spill to reusable eight-byte slots. No live-range splitting. -/
def allocate (f : Function) (registerCount : Nat := 0) : Except String Plan := do
  let live ← Liveness.analyze f
  let graph := interference f live
  let mut colors := #[]
  let mut occupants : Array Nat := #[]
  for i in [:live.names.size] do
    let mut color := occupants.size
    for c in [:occupants.size] do
      if occupants[c]! &&& graph[i]! == 0 then
        color := c
        break
    if color == occupants.size then occupants := occupants.push 0
    occupants := occupants.set! color (occupants[color]! ||| (1 <<< i))
    colors := colors.push color
  let result := {names := live.names, colors, colorCount := occupants.size, registerCount : Plan}
  check f live result
  return result

/-- Identity homes preserve the original baseline and certified entry points. -/
def baseline (f : Function) : Plan :=
  { names := f.locals.map (·.1), colors := (List.range f.locals.size).toArray,
    colorCount := f.locals.size, registerCount := 0 }

end LeanCompilerBackend.Allocation
