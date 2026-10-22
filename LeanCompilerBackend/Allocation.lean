/- Compatibility-only allocation of stable SSA homes. Not a proof certificate. -/
import LeanCompilerBackend.Liveness
import LeanCompilerBackend.Allocation.HomeFlow

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

/-- Greedy coloring visits names in index order, so only edges from a larger
    index to a smaller index can intersect already occupied homes. Keep exactly
    that half of the undirected relation; the independent boundary checker still
    checks every definition, parameter group and parallel phi group. -/
private def connect (graph : Array Nat) (node : Nat) (others : Nat) : Array Nat := Id.run do
  let nodeBit := 1 <<< node
  let lower := others &&& (nodeBit - 1)
  let mut graph := graph.set! node (graph[node]! ||| lower)
  for above in indices (others >>> (node+1)) do
    let other := above + node + 1
    graph := graph.set! other (graph[other]! ||| nodeBit)
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

/-- Bounded natural-loop frequency heuristic. Multiple backedges to one header
    count as one loop; nesting saturates at three levels. Disconnected regions
    and irreducible cycles without a dominating header get no inferred weight.
    Large graphs or unavailable dominance fall back to uniform static counts. -/
def loopWeights (graph : CFG.Graph) : Array Nat := Id.run do
  let count := graph.successors.size
  let uniform := Array.replicate count 1
  if count == 0 || count > 512 then return uniform
  let .ok doms := CFG.dominators graph | return uniform
  let mut reachable := (Array.replicate count false).set! 0 true
  let mut pending := #[0]
  for next in [:count] do
    if next >= pending.size then break
    for successor in graph.successors[pending[next]!]! do
      if !reachable[successor]! then
        reachable := reachable.set! successor true
        pending := pending.push successor
  let mut depth := Array.replicate count 0
  for header in [:count] do
    if !reachable[header]! then continue
    let tails := graph.predecessors[header]!.filter fun tail =>
      reachable[tail]! && (doms.sets[tail]! >>> header) &&& 1 == 1
    if tails.isEmpty then continue
    let mut members := (Array.replicate count false).set! header true
    let mut membersPending := #[]
    for tail in tails do
      if !members[tail]! then
        members := members.set! tail true
        membersPending := membersPending.push tail
    for next in [:count] do
      if next >= membersPending.size then break
      for predecessor in graph.predecessors[membersPending[next]!]! do
        if reachable[predecessor]! && !members[predecessor]! then
          members := members.set! predecessor true
          membersPending := membersPending.push predecessor
    for node in [:count] do
      if members[node]! then depth := depth.set! node (min 3 (depth[node]!+1))
  return depth.map fun d => 8^d


/-- Prefer frequently accessed color groups for the finite register bank.
    This only permutes existing colors; interference and home-flow checks still
    validate the resulting assignment independently. Natural loops get bounded
    static frequency weights, not runtime profiles or live-range splitting. -/
private def prioritize (f : Function) (live : Liveness.Result) (colors : Array Nat)
    (count : Nat) : Array Nat := Id.run do
  let weights := loopWeights live.graph
  let mut scores := Array.replicate count 0
  let bump := fun (scores : Array Nat) (weight : Nat) (name : String) =>
    match live.indices[name]? with
    | some i => let c := colors[i]!; scores.set! c (scores[c]!+weight)
    | none => scores
  let read := fun (scores : Array Nat) (weight : Nat) (value : Operand) =>
    match value with | .temporary name => bump scores weight name | _ => scores
  for p in f.parameters do scores := bump scores 1 p.name
  for blockIndex in [:f.blocks.size] do
    let block := f.blocks[blockIndex]!
    let weight := weights[blockIndex]!
    for phi in block.phis do
      scores := bump scores weight phi.destination
      for (predecessor,value) in phi.incoming do
        let edgeWeight := (live.graph.indices[predecessor]?).map (fun i => weights[i]!) |>.getD 1
        scores := read scores edgeWeight value
    for statement in block.instructions do
      for value in statement.operands do scores := read scores weight value
      if let some (name,_) := statement.definition then scores := bump scores weight name
    for value in Liveness.terminatorOperands block.terminator do scores := read scores weight value
  let order := (List.range count).toArray.qsort fun a b =>
    scores[a]! > scores[b]! || (scores[a]! == scores[b]! && a < b)
  let mut rank := Array.replicate count 0
  for i in [:order.size] do rank := rank.set! order[i]! i
  return colors.map (fun c => rank[c]!)

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
  colors := if registerCount > 0 && occupants.size > registerCount then
    prioritize f live colors occupants.size else colors
  let result := {names := live.names, colors, colorCount := occupants.size, registerCount : Plan}
  check f live result
  HomeFlow.check f result.names result.colors result.colorCount
  return result

/-- Identity homes preserve the original baseline and certified entry points. -/
def baseline (f : Function) : Plan :=
  { names := f.locals.map (·.1), colors := (List.range f.locals.size).toArray,
    colorCount := f.locals.size, registerCount := 0 }

end LeanCompilerBackend.Allocation
