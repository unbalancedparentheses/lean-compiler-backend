/- The bounded synchronous closure and its frontier implementation. -/
import LeanCompilerBackend.NameIndex

namespace LeanCompilerBackend.Verified.Reachability

open Std

private abbrev Edges := List (String × List String)

private def add (reached : Array String) (targets : List String) : Array String :=
  targets.foldl (fun seen target => if seen.contains target then seen else seen.push target) reached

private def round (edges : Edges) (reached : Array String) : Array String :=
  edges.foldl (fun seen (source, targets) =>
    if reached.contains source then add seen targets else seen) reached

private def closure (edges : Edges) (start : String) (rounds : Nat) : Array String :=
  Nat.repeat (round edges) rounds #[start]

/-- The original synchronous successor closure counts each reached label once. -/
def count (edges : Edges) (start : String) (rounds : Nat) : Nat :=
  (closure edges start rounds).size

private def outgoing (edges : Edges) (source : String) : List String :=
  edges.flatMap fun (name, targets) => if name == source then targets else []

private def buildOutgoing (edges : Edges) : TreeMap String (List String) :=
  edges.foldr (fun (name, targets) index =>
    index.insert name (targets ++ index[name]?.getD [])) {}

private theorem get_outgoing (edges : Edges) (source : String) :
    (buildOutgoing edges)[source]?.getD [] = outgoing edges source := by
  induction edges with
  | nil => simp [buildOutgoing, outgoing]
  | cons pair rest ih =>
    rcases pair with ⟨name, targets⟩
    change ((buildOutgoing rest).insert name (targets ++ (buildOutgoing rest)[name]?.getD []))[source]?.getD [] =
      (if name == source then targets else []) ++ outgoing rest source
    rw [TreeMap.getElem?_insert]
    by_cases h : name = source
    · simp [h, ih]
    · simp [h, ih]

private structure Frontier where
  seen : TreeSet String
  pending : List String

private def discover (state : Frontier) (target : String) : Frontier :=
  if state.seen.contains target then state else
    ⟨state.seen.insert target, target :: state.pending⟩

private def expand (index : TreeMap String (List String)) (state : Frontier) : Frontier :=
  state.pending.foldl (fun next source => (index[source]?.getD []).foldl discover next)
    { state with pending := [] }

private def countFrontier (edges : Edges) (start : String) (rounds : Nat) : Nat :=
  let index := buildOutgoing edges
  let initial : Frontier := ⟨(∅ : TreeSet String).insert start, [start]⟩
  (Nat.repeat (expand index) rounds initial).seen.size

private theorem mem_add (targets : List String) (reached : Array String) (name : String) :
    name ∈ add reached targets ↔ name ∈ reached ∨ name ∈ targets := by
  induction targets generalizing reached with
  | nil => simp [add]
  | cons target rest ih =>
    simp only [add, List.foldl_cons]
    rw [show List.foldl (fun seen (target : String) =>
      if seen.contains target then seen else seen.push target)
          (if reached.contains target then reached else reached.push target) rest =
        add (if reached.contains target then reached else reached.push target) rest from rfl, ih]
    by_cases h : target ∈ reached
    · have ht : reached.contains target = true := Array.contains_iff_mem.mpr h
      simp only [ht, ↓reduceIte, List.mem_cons]
      constructor
      · rintro (hn | hn)
        · exact Or.inl hn
        · exact Or.inr (Or.inr hn)
      · rintro (hn | rfl | hn)
        · exact Or.inl hn
        · exact Or.inl h
        · exact Or.inr hn
    · simp [h, or_assoc]

private theorem mem_roundAux (edges : Edges) (old seen : Array String) (name : String) :
    name ∈ edges.foldl (fun acc (source, targets) =>
      if old.contains source then add acc targets else acc) seen ↔
      name ∈ seen ∨ ∃ source, source ∈ old ∧ name ∈ outgoing edges source := by
  induction edges generalizing seen with
  | nil => simp [outgoing]
  | cons pair rest ih =>
    rcases pair with ⟨source, targets⟩
    have hout (s : String) : name ∈ outgoing ((source, targets) :: rest) s ↔
        (source = s ∧ name ∈ targets) ∨ name ∈ outgoing rest s := by
      by_cases h : source = s <;> simp [outgoing, h]
    simp only [List.foldl_cons, hout]
    rw [ih]
    simp only [Array.contains_iff_mem]
    by_cases hs : source ∈ old
    · simp only [ite_eq_left hs, mem_add]
      constructor
      · rintro ((h | h) | ⟨s, h, ht⟩)
        · exact Or.inl h
        · exact Or.inr ⟨source, hs, Or.inl ⟨rfl, h⟩⟩
        · exact Or.inr ⟨s, h, Or.inr ht⟩
      · rintro (h | ⟨s, _, ⟨_, h⟩ | ht⟩)
        · exact Or.inl (Or.inl h)
        · exact Or.inl (Or.inr h)
        · exact Or.inr ⟨s, by assumption, ht⟩
    · simp only [ite_eq_right hs]
      constructor
      · rintro (h | ⟨s, hm, hr⟩)
        · exact Or.inl h
        · exact Or.inr ⟨s, hm, Or.inr hr⟩
      · rintro (h | ⟨s, hm, ⟨rfl, _⟩ | h⟩)
        · exact Or.inl h
        · exact (hs hm).elim
        · exact Or.inr ⟨s, hm, h⟩

private theorem mem_round (edges : Edges) (reached : Array String) (name : String) :
    name ∈ round edges reached ↔
      name ∈ reached ∨ ∃ source, source ∈ reached ∧ name ∈ outgoing edges source :=
  mem_roundAux edges reached reached name

private theorem discover_mem (state : Frontier) (target name : String) :
    (name ∈ (discover state target).seen ↔ name ∈ state.seen ∨ name = target) ∧
    (name ∈ (discover state target).pending ↔
      name ∈ state.pending ∨ (name = target ∧ name ∉ state.seen)) := by
  unfold discover
  simp only [TreeSet.contains_iff_mem]
  split <;> rename_i h
  · grind
  · simp only [TreeSet.mem_insert, LawfulEqOrd.compare_eq_iff_eq, List.mem_cons]
    grind

private theorem discover_all_mem (targets : List String) (state : Frontier) (name : String) :
    (name ∈ (targets.foldl discover state).seen ↔ name ∈ state.seen ∨ name ∈ targets) ∧
    (name ∈ (targets.foldl discover state).pending ↔
      name ∈ state.pending ∨ (name ∈ targets ∧ name ∉ state.seen)) := by
  induction targets generalizing state with
  | nil => simp
  | cons target rest ih =>
    simp only [List.foldl_cons, List.mem_cons, (ih (discover state target)).1,
      (ih (discover state target)).2, (discover_mem state target name).1,
      (discover_mem state target name).2]
    grind

private theorem expand_mem (edges : Edges) (state : Frontier) (name : String) :
    let found := ∃ source, source ∈ state.pending ∧ name ∈ outgoing edges source
    (name ∈ (expand (buildOutgoing edges) state).seen ↔ name ∈ state.seen ∨ found) ∧
    (name ∈ (expand (buildOutgoing edges) state).pending ↔ found ∧ name ∉ state.seen) := by
  unfold expand
  simp only [get_outgoing, ← List.foldl_flatMap]
  simpa using discover_all_mem (state.pending.flatMap (outgoing edges))
    { state with pending := [] } name

private def Agrees (edges : Edges) (state : Frontier) (reached : Array String) : Prop :=
  (∀ name, name ∈ state.seen ↔ name ∈ reached) ∧
  (∀ name, name ∈ state.pending → name ∈ reached) ∧
  ∀ source, source ∈ reached → source ∉ state.pending →
    ∀ target, target ∈ outgoing edges source → target ∈ reached

private theorem expand_agrees (edges : Edges) (state : Frontier) (reached : Array String)
    (h : Agrees edges state reached) :
    Agrees edges (expand (buildOutgoing edges) state) (round edges reached) := by
  rcases h with ⟨seen, pending, expanded⟩
  have same name : name ∈ (expand (buildOutgoing edges) state).seen ↔
      name ∈ round edges reached := by
    rw [(expand_mem edges state name).1, mem_round, seen]
    constructor
    · rintro (h | ⟨source, hp, ht⟩)
      · exact Or.inl h
      · exact Or.inr ⟨source, pending _ hp, ht⟩
    · rintro (h | ⟨source, hr, ht⟩)
      · exact Or.inl h
      · by_cases hp : source ∈ state.pending
        · exact Or.inr ⟨source, hp, ht⟩
        · exact Or.inl (expanded _ hr hp _ ht)
  refine ⟨same, ?_, ?_⟩
  · intro name hp
    obtain ⟨found, _⟩ := (expand_mem edges state name).2.mp hp
    exact (same _).mp ((expand_mem edges state name).1.mpr (Or.inr found))
  · intro source hs hn target ht
    apply (mem_round edges reached target).mpr
    refine Or.inr ⟨source, ?_, ht⟩
    have hs' := (expand_mem edges state source).1.mp ((same _).mpr hs)
    rcases hs' with seenSource | found
    · exact (seen _).mp seenSource
    · by_cases old : source ∈ state.seen
      · exact (seen _).mp old
      · exact (hn ((expand_mem edges state source).2.mpr ⟨found, old⟩)).elim

private theorem add_nodup (targets : List String) (reached : Array String)
    (h : reached.toList.Nodup) : (add reached targets).toList.Nodup := by
  induction targets generalizing reached with
  | nil => exact h
  | cons target rest ih =>
    apply ih
    by_cases ht : target ∈ reached
    · simpa [ht] using h
    · simp [ht, List.nodup_append, h]
      exact fun name hn he => ht (he ▸ hn)

private theorem round_nodup (edges : Edges) (reached : Array String)
    (h : reached.toList.Nodup) : (round edges reached).toList.Nodup := by
  have go (edges : Edges) (seen : Array String) (h : seen.toList.Nodup) :
      (edges.foldl (fun acc (source, targets) =>
        if reached.contains source then add acc targets else acc) seen).toList.Nodup := by
    induction edges generalizing seen with
    | nil => exact h
    | cons pair rest ih =>
      rcases pair with ⟨source, targets⟩
      apply ih
      change (if reached.contains source then add seen targets else seen).toList.Nodup
      split
      · exact add_nodup targets seen h
      · exact h
  exact go edges reached h

private theorem repeat_agrees (edges : Edges) (rounds : Nat) (state : Frontier)
    (reached : Array String) (h : Agrees edges state reached) :
    Agrees edges (Nat.repeat (expand (buildOutgoing edges)) rounds state)
      (Nat.repeat (round edges) rounds reached) := by
  induction rounds with
  | zero => exact h
  | succ rounds ih => exact expand_agrees _ _ _ ih

private theorem repeat_nodup (edges : Edges) (rounds : Nat) (reached : Array String)
    (h : reached.toList.Nodup) : (Nat.repeat (round edges) rounds reached).toList.Nodup := by
  induction rounds with
  | zero => exact h
  | succ rounds ih => exact round_nodup _ _ ih

@[csimp] theorem count_eq_frontier : count = countFrontier := by
  funext edges start rounds
  let initial : Frontier := ⟨(∅ : TreeSet String).insert start, [start]⟩
  have init : Agrees edges initial #[start] := by
    simp [Agrees, initial, TreeSet.mem_insert]
    intro name
    exact eq_comm
  let closed := closure edges start rounds
  let final := Nat.repeat (expand (buildOutgoing edges)) rounds initial
  have agrees : Agrees edges final closed := repeat_agrees _ _ _ _ init
  have hclosed : closed.toList.Nodup := repeat_nodup _ _ _ (by simp)
  have hfinal : final.seen.toList.Nodup := by
    simpa [List.Nodup] using TreeSet.distinct_toList (t := final.seen)
  have perm : closed.toList.Perm final.seen.toList :=
    (List.perm_ext_iff_of_nodup hclosed hfinal).mpr (fun name => by
      simpa using (agrees.1 name).symm)
  simpa [count, countFrontier, closed, final, initial] using perm.length_eq

end LeanCompilerBackend.Verified.Reachability
