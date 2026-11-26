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
  -- `modify` takes each inner array out before pushing, so pushes are in place.
  -- Predecessors are filled in a second pass over the (deduplicated) successors:
  -- the same order as filling both together, without a loop-state pair.
  let mut successors := Array.replicate f.blocks.size #[]
  for i in [:f.blocks.size] do
    for label in f.blocks[i]!.terminator.successors do
      let some target := indices[label]? | throw s!"unknown block @{label}"
      if target == 0 then throw "QBE entry block must not be a jump target"
      if !(successors[i]!.contains target) then
        successors := successors.modify i (·.push target)
  let predecessors := Id.run do
    let mut predecessors := Array.replicate f.blocks.size #[]
    for i in [:successors.size] do
      for target in successors[i]! do
        predecessors := predecessors.modify target (·.push i)
    return predecessors
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


/-- A dominator-tree interval for each block reachable from a dominance root.
    Blocks without an interval have vacuous dominators. -/
structure DominatorTree where
  intervals : Array (Option (Nat × Nat))
  indices : Std.HashMap String Nat

def DominatorTree.contains (tree : DominatorTree) (useBlock definitionBlock : String) : Bool :=
  match tree.indices[useBlock]?, tree.indices[definitionBlock]? with
  | some useIndex, some definitionIndex =>
    match tree.intervals[useIndex]!, tree.intervals[definitionIndex]! with
    | none, _ => true
    | some (start, _), some (first, last) => first <= start && start < last
    | _, _ => false
  | _, _ => false

private structure LinkForest where
  ancestor : Array Nat
  label : Array Nat

-- Lengauer–Tarjan eval with iterative path compression. Indices are DFS
-- numbers, with zero reserved as the sentinel for an unlinked vertex.
private def LinkForest.eval (forest : LinkForest) (semi : Array Nat) (vertex : Nat) :
    Nat × LinkForest := Id.run do
  let mut ancestor := forest.ancestor
  let mut label := forest.label
  let mut pending := []
  let mut current := vertex
  while ancestor[ancestor[current]!]! != 0 do
    pending := current :: pending
    current := ancestor[current]!
  for node in pending do
    let parent := ancestor[node]!
    if semi[label[parent]!]! < semi[label[node]!]! then
      label := label.set! node label[parent]!
    ancestor := ancestor.set! node ancestor[parent]!
  return (label[vertex]!, ⟨ancestor, label⟩)

/-- Simple Lengauer–Tarjan, with path compression and DFS-parent links.
    The link/eval phase takes O((V + E) log V) time and O(V + E) space.

    The builder's edge tables must agree. A synthetic root connects the
    entry and every predecessor-free vertex, reflecting the fixed-point
    boundary conditions for disconnected regions. Edges from a region that
    the synthetic root cannot reach contribute the universal set. -/
def dominatorTree (graph : Graph) : DominatorTree := Id.run do
  let count := graph.successors.size
  let root := count
  let roots := (Array.range count).filter fun node => node == 0 || graph.predecessors[node]!.isEmpty
  let mut number := Array.replicate (count + 1) 0
  let mut vertices := #[root]
  let mut parents := #[0]
  let mut stack := [(root, 0)]
  while let (node, parent) :: rest := stack do
    stack := rest
    if number[node]! == 0 then
      let index := vertices.size
      number := number.set! node index
      vertices := vertices.push node
      parents := parents.push parent
      let children := if node == root then roots else graph.successors[node]!
      stack := children.foldr (fun child tail => (child, index) :: tail) stack
  let size := vertices.size
  let mut semi := Array.range size
  let mut forest : LinkForest := ⟨Array.replicate size 0, Array.range size⟩
  let mut immediate := Array.replicate size 0
  let mut buckets : Array (List Nat) := Array.replicate size []
  for offset in [:size - 2] do
    let vertex := size - offset - 1
    let node := vertices[vertex]!
    let preds := graph.predecessors[node]!
    let mut best := if node == 0 || preds.isEmpty then 1 else vertex
    if node != 0 then
      for pred in preds do
        let index := number[pred]!
        if index != 0 then
          let (candidate, updated) := forest.eval semi index
          forest := updated
          best := min best semi[candidate]!
    semi := semi.set! vertex best
    buckets := buckets.modify best (vertex :: ·)
    let parent := parents[vertex]!
    forest := { forest with ancestor := forest.ancestor.set! vertex parent }
    let pending := buckets[parent]!
    buckets := buckets.set! parent []
    for pendingVertex in pending do
      let (candidate, updated) := forest.eval semi pendingVertex
      forest := updated
      immediate := immediate.set! pendingVertex
        (if semi[candidate]! < semi[pendingVertex]! then candidate else parent)
  let mut children : Array (List Nat) := Array.replicate size []
  for vertex in [2:size] do
    let parent := immediate[vertex]!
    let parent := if parent == semi[vertex]! then parent else immediate[parent]!
    immediate := immediate.set! vertex parent
    children := children.modify parent (vertex :: ·)
  let mut positions := Array.replicate size 0
  let mut intervals := Array.replicate count none
  let mut pending := [(1, false)]
  let mut next := 0
  while let (vertex, exiting) :: rest := pending do
    pending := rest
    if exiting then
      if vertex != 1 then
        intervals := intervals.set! vertices[vertex]! (some (positions[vertex]!, next))
    else
      positions := positions.set! vertex next
      next := next + 1
      pending := children[vertex]!.foldr
        (fun child tail => (child, false) :: tail) ((vertex, true) :: pending)
  return { intervals, indices := graph.indices }

end LeanCompilerBackend.CFG
