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

/-- Branch conditions use QBE word semantics. Rebuild the graph after rewriting
    edges, retain entry order, then remove obsolete phi incoming edges. -/
def simplify (f : Function) : Except String Function := do
  let f := {f with blocks := f.blocks.map fun b => {b with terminator :=
    match b.terminator with
    | .branch (.constant n) yes no =>
      .jump (if Semantics.constant .word n == 0 then no else yes)
    | other => other}}
  let graph ← CFG.build f
  let reachable ← reachableFromEntry graph
  let mut blocks := #[]
  for index in retained f reachable do
    let b := f.blocks[index]!
    let phis := b.phis.map fun p => {p with incoming := p.incoming.filter fun (label, _) =>
      match graph.indices[label]? with
      | some source => reachable.contains source && graph.predecessors[index]!.contains source
      | none => false}
    blocks := blocks.push {b with phis}
  pure {f with blocks}

end LeanCompilerBackend.Optimize.ControlFlow
