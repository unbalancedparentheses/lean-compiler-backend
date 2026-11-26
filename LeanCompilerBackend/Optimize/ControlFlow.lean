/- Compatibility-only constant branches and unreachable-block removal. -/
import LeanCompilerBackend.CFG
import LeanCompilerBackend.Semantics
import Std.Data.HashSet.Lemmas

namespace LeanCompilerBackend.Optimize.ControlFlow

private def visit (graph : CFG.Graph) :
    Nat → List Nat → Std.HashSet Nat → Except String (Std.HashSet Nat)
  | _, [], seen => .ok seen
  | 0, _ :: _, _ => .error "control-flow reachability budget exhausted"
  | fuel + 1, node :: pending, seen =>
    if seen.contains node then visit graph fuel pending seen
    else visit graph fuel (graph.successors[node]!.toList.appendTR pending) (seen.insert node)

private def Covered (seen : Std.HashSet Nat) (pending : List Nat) (node : Nat) : Prop :=
  node ∈ seen ∨ node ∈ pending

private theorem visit_complete (graph : CFG.Graph) (fuel : Nat) (pending : List Nat)
    (seen result : Std.HashSet Nat)
    (closed : ∀ node ∈ seen, ∀ next ∈ graph.successors[node]!.toList, Covered seen pending next)
    (ok : visit graph fuel pending seen = .ok result) :
    (∀ node, Covered seen pending node → node ∈ result) ∧
      (∀ node ∈ result, ∀ next ∈ graph.successors[node]!.toList, next ∈ result) := by
  induction fuel generalizing pending seen with
  | zero =>
    cases pending with
    | nil =>
      have eq : seen = result := Except.ok.inj ok
      subst result
      exact ⟨fun node h => h.resolve_right (List.not_mem_nil), fun node hn next hx =>
        (closed node hn next hx).resolve_right List.not_mem_nil⟩
    | cons => contradiction
  | succ fuel ih =>
    cases pending with
    | nil =>
      have eq : seen = result := Except.ok.inj ok
      subst result
      exact ⟨fun node h => h.resolve_right List.not_mem_nil, fun node hn next hx =>
        (closed node hn next hx).resolve_right List.not_mem_nil⟩
    | cons node pending =>
      rw [visit] at ok
      split at ok
      · rename_i hit
        have covered (next : Nat) :
            Covered seen (node :: pending) next → Covered seen pending next := by
          simp only [Covered, List.mem_cons]
          rintro (h | rfl | h)
          · exact Or.inl h
          · exact Or.inl (by simpa using hit)
          · exact Or.inr h
        obtain ⟨contains, stable⟩ := ih pending seen
          (fun n hn next hx => covered next (closed n hn next hx)) ok
        exact ⟨fun n h => contains n (covered n h), stable⟩
      · rw [← List.append_eq_appendTR] at ok
        have covered (next : Nat) : Covered seen (node :: pending) next →
            Covered (seen.insert node) (graph.successors[node]!.toList ++ pending) next := by
          simp only [Covered, List.mem_cons, List.mem_append, Std.HashSet.mem_insert]
          grind
        obtain ⟨contains, stable⟩ := ih _ _ (by
          intro n hn next hx
          rw [Std.HashSet.mem_insert, beq_iff_eq] at hn
          rcases hn with rfl | hn
          · exact Or.inr (List.mem_append_left _ hx)
          · exact covered next (closed n hn next hx)) ok
        exact ⟨fun n h => contains n (covered n h), stable⟩

/-- A path from the entry, expressed as successive edges of the rebuilt graph. -/
inductive Reachable (graph : CFG.Graph) : Nat → Prop
  | entry : Reachable graph 0
  | step : Reachable graph node → next ∈ graph.successors[node]!.toList → Reachable graph next

private theorem visit_retains_reachable (graph : CFG.Graph) (fuel : Nat)
    (result : Std.HashSet Nat) (ok : visit graph fuel [0] {} = .ok result)
    (path : Reachable graph node) : node ∈ result := by
  have ⟨entry, closed⟩ := visit_complete graph fuel [0] {} result (by simp) ok
  induction path with
  | entry => exact entry 0 (Or.inr (by simp))
  | step _ edge ih => exact closed _ ih _ edge

private def retained (f : Function) (reachable : Std.HashSet Nat) : List Nat :=
  (List.range f.blocks.size).filterTR reachable.contains

private theorem retained_reachable (f : Function) (graph : CFG.Graph) (fuel : Nat)
    (result : Std.HashSet Nat) (ok : visit graph fuel [0] {} = .ok result)
    (inBounds : node < f.blocks.size) (path : Reachable graph node) :
    node ∈ retained f result := by
  simp [retained, ← List.filter_eq_filterTR, inBounds, visit_retains_reachable graph fuel result ok path]

private def reachableFromEntry (graph : CFG.Graph) : Except String (Std.HashSet Nat) :=
  -- Each visited node contributes its outgoing edges at most once.
  let edges := graph.successors.foldl (fun n row => n + row.size) 0
  visit graph (1 + edges) [0] {}

-- This graph requires exactly two work items. Both the calculated budget
-- and the refusal with one unit removed are checked.
private def twoBlocks : CFG.Graph := { successors := #[#[1], #[]] }

example : (reachableFromEntry twoBlocks).isOk = true := by
  simp [reachableFromEntry, twoBlocks, visit, ← List.append_eq_appendTR, Except.isOk, Except.toBool]

example : visit twoBlocks 1 [0] {} = .error "control-flow reachability budget exhausted" := by
  simp [twoBlocks, visit, ← List.append_eq_appendTR]

/-- Rewrite a constant condition using QBE word semantics. -/
def foldTerminator : Terminator → Terminator
  | .branch (.constant n) yes no =>
    .jump (if Semantics.constant .word n == 0 then no else yes)
  | other => other

private def foldBranches (f : Function) : Function :=
  {f with blocks := f.blocks.map fun b => {b with terminator := foldTerminator b.terminator}}

/-- Reachability is relative to the graph after folding constant branches. -/
def RebuiltGraph (input : Function) (graph : CFG.Graph) : Prop :=
  CFG.build (foldBranches input) = .ok graph

private def prunePhis (graph : CFG.Graph) (reachable : Std.HashSet Nat)
    (index : Nat) (b : Block) : Block :=
  {b with phis := b.phis.map fun p => {p with incoming := p.incoming.filter fun (label, _) =>
    match graph.indices[label]? with
    | some source => reachable.contains source && graph.predecessors[index]!.contains source
    | none => false}}

private def keptBlock (f : Function) (graph : CFG.Graph) (reachable : Std.HashSet Nat)
    (index : Nat) : Block :=
  prunePhis graph reachable index f.blocks[index]!

/-- Branch conditions use QBE word semantics. Rebuild the graph after rewriting
    edges, retain entry order, then remove obsolete phi incoming edges. -/
def simplify (input : Function) : Except String Function := do
  let f := foldBranches input
  let graph ← CFG.build f
  let reachable ← reachableFromEntry graph
  let blocks := (retained f reachable).toArray.map (keptBlock f graph reachable)
  pure {f with blocks}

/-- Every reachable input block survives in a successful result, with its
    original label, instructions, and debug locations, and its folded terminator. -/
theorem simplify_retains_reachable (input output : Function) (graph : CFG.Graph)
    (rebuilt : RebuiltGraph input graph) (ok : simplify input = .ok output)
    (index : Nat) (bound : index < input.blocks.size) (path : Reachable graph index) :
    ∃ block ∈ output.blocks.toList,
      block.label = input.blocks[index].label ∧
      block.instructions = input.blocks[index].instructions ∧
      block.debugLocations = input.blocks[index].debugLocations ∧
      block.terminator = foldTerminator input.blocks[index].terminator := by
  unfold RebuiltGraph at rebuilt
  simp only [simplify, rebuilt, bind, Except.bind] at ok
  cases reach : reachableFromEntry graph with
  | error error => simp [reach] at ok
  | ok seen =>
    simp only [reach, pure, Except.pure, Except.ok.injEq] at ok
    subst output
    have foldedBound : index < (foldBranches input).blocks.size := by
      simpa [foldBranches] using bound
    have member := retained_reachable (foldBranches input) graph _ seen reach foldedBound path
    refine ⟨keptBlock (foldBranches input) graph seen index, ?_, ?_⟩
    · simpa only [Array.toList_map, List.toList_toArray] using
        List.mem_map_of_mem (f := keptBlock (foldBranches input) graph seen) member
    · simp only [keptBlock, prunePhis, getElem!_pos (foldBranches input).blocks index foldedBound]
      simp [foldBranches]

end LeanCompilerBackend.Optimize.ControlFlow
