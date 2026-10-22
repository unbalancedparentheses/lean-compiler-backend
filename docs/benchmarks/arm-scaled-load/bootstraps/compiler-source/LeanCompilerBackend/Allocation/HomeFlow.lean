/- Symbolic value flow for stable SSA homes. Independent of liveness/coloring.
   This checks the home assignment contract, not assembly bytes or a proof. -/
import LeanCompilerBackend.Validate

namespace LeanCompilerBackend.Allocation.HomeFlow

private abbrev State := Array Nat

/-- An unknown home holds no provable SSA identity. A missing block state means
    no entry-reachable predecessor has been processed yet. -/
def check (f : Function) (names : Array String) (colors : Array Nat) (count : Nat) : Except String Unit := do
  validateFunction f true
  if names != f.locals.map (·.1) || colors.size != names.size || count > names.size then
    throw "home-flow inventory mismatch"
  if colors.any (· >= count) then throw "home-flow color out of bounds"
  let indices := names.foldl (fun (s : Std.HashMap String Nat × Nat) name =>
    (s.1.insert name s.2, s.2+1)) ({}, 0) |>.1
  let unknown := names.size
  let write := fun (state : State) (name : String) =>
    let index := indices[name]!
    state.set! colors[index]! index
  let transfer := fun (state : State) (b : Block) =>
    b.instructions.foldl (fun state s => match s.definition with
      | some (name, _) => write state name | none => state) state
  let meet := fun (a b : State) => (a.zip b).map fun (x,y) => if x == y then x else unknown
  let graph ← CFG.build f
  let mut initial := Array.replicate count unknown
  for p in f.parameters do initial := write initial p.name
  let mut incoming : Array (Option State) := (Array.replicate f.blocks.size none).set! 0 (some initial)
  let mut queue := #[0]
  let mut queued := (Array.replicate f.blocks.size false).set! 0 true
  let mut next := 0
  let mut converged := false
  let edges := graph.successors.foldl (fun n xs => n+xs.size) 0
  -- A reachable block is discovered once. Each color can subsequently lose its
  -- known identity once; overwrites have fixed identities and cannot add facts.
  for _ in [:f.blocks.size + edges*(count+2)+2] do
    if next == queue.size then
      converged := true
      break
    let node := queue[next]!
    next := next+1
    queued := queued.set! node false
    let some state := incoming[node]! | throw "home-flow missing worklist state"
    let outgoing := transfer state f.blocks[node]!
    for target in graph.successors[node]! do
      let candidate := f.blocks[target]!.phis.foldl (fun state p => write state p.destination) outgoing
      let merged := (incoming[target]!).map (meet candidate) |>.getD candidate
      if incoming[target]! != some merged then
        incoming := incoming.set! target (some merged)
        if !queued[target]! then
          queue := queue.push target
          queued := queued.set! target true
    if next >= 4096 then
      queue := queue.extract next queue.size
      next := 0
  if !converged then throw "home-flow iteration resource limit exceeded"
  let read := fun (state : State) (operand : Operand) => do
    if let .temporary name := operand then
      let some index := indices[name]? | throw "home-flow unknown temporary"
      if state[colors[index]!]! != index then
        throw s!"home-flow lost value %{name}"
  for node in [:f.blocks.size] do
    if let some entry := incoming[node]! then
      let mut state := entry
      let b := f.blocks[node]!
      for statement in b.instructions do
        for operand in statement.operands do read state operand
        if let some (name, _) := statement.definition then state := write state name
      match b.terminator with
      | .ret (some value) | .branch value .. => read state value
      | _ => pure ()
      -- Check all phi sources in the old state, before parallel destinations.
      for target in graph.successors[node]! do
        for phi in f.blocks[target]!.phis do
          let some (_, value) := phi.incoming.find? (·.1 == b.label) |
            throw "home-flow missing phi edge"
          read state value
  return ()

end LeanCompilerBackend.Allocation.HomeFlow
