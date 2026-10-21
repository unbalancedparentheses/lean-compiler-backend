/- Indexed compatibility CFG and bit-set dominance. No preservation proof is
   claimed here; the restricted first-path analyses retain their own limits. -/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend.CFG

structure Graph where
  indices : Std.HashMap String Nat := {}
  predecessors : Array (Array Nat) := #[]
  successors : Array (Array Nat) := #[]
  deriving Inhabited

def build (f : Function) : Except String Graph := do
  let mut indices : Std.HashMap String Nat := {}
  for i in [:f.blocks.size] do
    let label := f.blocks[i]!.label
    if indices.contains label then throw "duplicate block label"
    indices := indices.insert label i
  let mut predecessors := Array.replicate f.blocks.size #[]
  let mut successors := Array.replicate f.blocks.size #[]
  for i in [:f.blocks.size] do
    for label in f.blocks[i]!.terminator.successors do
      let some target := indices[label]? | throw s!"unknown block @{label}"
      if target == 0 then throw "QBE entry block must not be a jump target"
      if !(successors[i]!.contains target) then
        successors := successors.set! i (successors[i]!.push target)
        predecessors := predecessors.set! target (predecessors[target]!.push i)
  pure { indices, predecessors, successors }

/-- Remove blocks with no path from entry before compatibility SSA construction.
    An unreachable predecessor must not constrain a reachable join's values.
    Keep malformed incoming labels from reachable regions for validation to reject. -/
def pruneUnreachable (f : Function) : Except String Function := do
  let graph ← build f
  if f.blocks.isEmpty then return f
  let mut reachable := (Array.replicate f.blocks.size false).set! 0 true
  let mut pending := #[0]
  for next in [:f.blocks.size] do
    if next >= pending.size then break
    for successor in graph.successors[pending[next]!]! do
      if !reachable[successor]! then
        reachable := reachable.set! successor true
        pending := pending.push successor
  let mut blocks := #[]
  for i in [:f.blocks.size] do
    if reachable[i]! then
      let b := f.blocks[i]!
      blocks := blocks.push {b with phis := b.phis.map fun p => {p with
        incoming := p.incoming.filter fun (label, _) =>
          match graph.indices[label]? with
          | some source => reachable[source]!
          | none => true}}
  return {f with blocks}

structure Dominators where
  graph : Graph
  sets : Array Nat

/-- Work-list fixed point over packed finite sets. Preserves the previous
    validator's treatment of disconnected regions: predecessor-free nodes have
    only themselves, while a closed unreachable SCC retains vacuous dominators. -/
def dominators (graph : Graph) : Except String Dominators := do
  let count := graph.successors.size
  if count == 0 then throw "function has no entry block"
  let all := (1 <<< count) - 1
  let mut sets := (Array.replicate count all).set! 0 1
  let mut pending := (List.range count).toArray
  let mut queued := Array.replicate count true
  let mut next := 0
  for _ in [:count * count * 4 + count + 1] do
    if next == pending.size then return { graph, sets }
    let node := pending[next]!
    next := next + 1
    queued := queued.set! node false
    if node != 0 then
      let preds := graph.predecessors[node]!
      let mut members := if preds.isEmpty then 0 else all
      for pred in preds do members := members &&& sets[pred]!
      members := members ||| (1 <<< node)
      if members != sets[node]! then
        sets := sets.set! node members
        for target in graph.successors[node]! do
          if !queued[target]! then
            queued := queued.set! target true
            pending := pending.push target
    if next >= 4096 then
      pending := pending.extract next pending.size
      next := 0
  throw "dominance iteration resource limit exceeded"

def Dominators.contains (doms : Dominators) (useBlock definitionBlock : String) : Bool :=
  match doms.graph.indices[useBlock]?, doms.graph.indices[definitionBlock]? with
  | some useIndex, some definitionIndex => ((doms.sets[useIndex]! >>> definitionIndex) &&& 1) == 1
  | _, _ => false

end LeanCompilerBackend.CFG
