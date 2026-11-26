/- Compatibility-only constant branches and unreachable-block removal. -/
import LeanCompilerBackend.CFG
import LeanCompilerBackend.Semantics

namespace LeanCompilerBackend.Optimize.ControlFlow

private def visit (graph : CFG.Graph) : Nat → List Nat → Std.HashSet Nat → Std.HashSet Nat
  | 0, _, seen | _, [], seen => seen
  | fuel + 1, node :: pending, seen =>
    if seen.contains node then visit graph fuel pending seen
    else visit graph fuel (graph.successors[node]!.toList ++ pending) (seen.insert node)

/-- Branch conditions use QBE word semantics. Rebuild the graph after rewriting
    edges, retain entry order, then remove obsolete phi incoming edges. -/
def simplify (f : Function) : Except String Function := do
  let f := {f with blocks := f.blocks.map fun b => {b with terminator :=
    match b.terminator with
    | .branch (.constant n) yes no =>
      .jump (if Semantics.constant .word n == 0 then no else yes)
    | other => other}}
  let graph ← CFG.build f
  -- Each visited node contributes its outgoing edges at most once.
  let edges := graph.successors.foldl (fun n row => n + row.size) 0
  let reachable := visit graph (1 + edges) [0] {}
  let mut blocks := #[]
  for index in [:f.blocks.size] do
    if !reachable.contains index then continue
    let b := f.blocks[index]!
    let phis := b.phis.map fun p => {p with incoming := p.incoming.filter fun (label, _) =>
      match graph.indices[label]? with
      | some source => reachable.contains source && graph.predecessors[index]!.contains source
      | none => false}
    blocks := blocks.push {b with phis}
  pure {f with blocks}

end LeanCompilerBackend.Optimize.ControlFlow
