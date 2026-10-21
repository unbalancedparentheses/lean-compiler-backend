import LeanCompilerBackend.CFG

namespace LeanCompilerBackend.CFG.Tests

/-- Retain the original finite-list specification as an independent regression
    oracle, including disconnected nodes and self loops. -/
private def reference (g : Graph) : Array (List Nat) := Id.run do
  let names := List.range g.successors.size
  let mut sets := names.toArray.map (fun i => if i == 0 then [0] else names)
  for _ in [:g.successors.size * g.successors.size + 1] do
    let updated := names.toArray.map fun i =>
      if i == 0 then [0]
      else names.filter fun candidate => candidate == i ||
        (!g.predecessors[i]!.isEmpty && g.predecessors[i]!.all (fun pred => sets[pred]!.contains candidate))
    if updated == sets then return sets
    sets := updated
  return sets

private def graph (mask : Nat) : Graph := Id.run do
  let mut successors := Array.replicate 4 #[]
  let mut predecessors := Array.replicate 4 #[]
  let mut indices : Std.HashMap String Nat := {}
  for i in [:4] do
    indices := indices.insert (toString i) i
    for j in [1:4] do
      if (mask >>> (i*3+j-1)) &&& 1 != 0 then
        successors := successors.set! i (successors[i]!.push j)
        predecessors := predecessors.set! j (predecessors[j]!.push i)
  return { indices, successors, predecessors }

private def reachableWithout (g : Graph) (removed : Nat) : Array Bool := Id.run do
  let mut reached := (Array.replicate 4 false).set! 0 (removed != 0)
  for _ in [:4] do
    for i in [:4] do
      if reached[i]! then
        for next in g.successors[i]! do
          if next != removed then reached := reached.set! next true
  return reached

def run : IO Unit := do
  for mask in [:4096] do
    let g := graph mask
    let doms ← match CFG.dominators g with
      | .ok d => pure d
      | .error e => throw (IO.userError e)
    let expected := reference g
    let reachable := reachableWithout g 4
    for candidate in [:4] do
      let without := reachableWithout g candidate
      for node in [:4] do
        let actual := doms.contains (toString node) (toString candidate)
        unless actual == (expected[node]!.contains candidate) do
          throw (IO.userError s!"dominance fixed-point mismatch: {mask}/{candidate}/{node}")
        if reachable.all id then
          unless actual == !without[node]! do
            throw (IO.userError s!"dominance reachability mismatch: {mask}/{candidate}/{node}")
  IO.println "CFG dominance: all 4096 four-node graphs match list reference and node-deletion oracle on fully reachable graphs"

end LeanCompilerBackend.CFG.Tests
