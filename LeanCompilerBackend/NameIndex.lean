/- First-match name indexes, with the scan retained as the logical specification. -/
import Std.Data.TreeMap.Lemmas
import Std.Data.TreeSet.Lemmas

namespace LeanCompilerBackend.NameIndex

open Std

/-- Compare names lexicographically by their Unicode scalar values. This order
    is local to the compiler's ordered indexes. -/
scoped instance (priority := 1100) nameOrd : Ord String where
  compare := compareOn String.toList

scoped instance : TransOrd String :=
  inferInstanceAs (TransCmp (compareOn String.toList))

scoped instance : LawfulEqOrd String where
  eq_of_compare h := String.toList_injective (LawfulEqOrd.eq_of_compare (α := List Char) h)

variable {κ : Type v}

def build [Ord κ] (key : α → κ) (entries : List α) : Std.TreeMap κ α :=
  entries.foldr (fun entry index => index.insert (key entry) entry) {}

theorem build_get? [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ] (key : α → κ) (entries : List α) (name : κ) :
    (build key entries)[name]? = entries.find? (fun entry => key entry == name) := by
  induction entries with
  | nil => simp [build]
  | cons entry rest ih =>
    change ((build key rest).insert (key entry) entry)[name]? = _
    rw [Std.TreeMap.getElem?_insert, List.find?_cons, ih]
    by_cases h : key entry = name
    · simp [h]
    · have hn : (key entry == name) = false := beq_eq_false_iff_ne.mpr h
      simp [h, hn]

structure Lookup (κ : Type v) (α : Type u) where
  get : κ → Option α

private def firstSpec [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ] (key : α → κ) (entries : Array α) : Lookup κ α :=
  ⟨fun name => entries.find? (fun entry => key entry == name)⟩

private def firstIndexed [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ] (key : α → κ) (entries : Array α) : Lookup κ α :=
  let index := build key entries.toList
  ⟨fun name => index[name]?⟩

/-- Look up the first entry with the given key, even in the presence of duplicates.
    Build one tree when constructing the lookup function. -/
def first [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ] (key : α → κ) (entries : Array α) : Lookup κ α :=
  firstIndexed key entries

theorem first_eq_indexed : @first = @firstIndexed := rfl

theorem first_eq_indexed_spec : @firstSpec = @firstIndexed := by
  funext κ _ _ _ _ _ α key entries
  apply congrArg Lookup.mk
  funext name
  simp [build_get?]

private def positionSpec [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ] (key : α → κ) (entries : Array α) : Lookup κ Nat :=
  ⟨fun name => entries.findIdx? (fun entry => key entry == name)⟩

private def positionIndexed [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ] (key : α → κ) (entries : Array α) : Lookup κ Nat :=
  let index := build (fun entry : α × Nat => key entry.1) entries.zipIdx.toList
  ⟨fun name => (index[name]?).map (·.2)⟩

/-- Return the position of the first entry with the given key. -/
def position [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ] (key : α → κ) (entries : Array α) : Lookup κ Nat :=
  positionIndexed key entries

theorem position_eq_indexed : @position = @positionIndexed := rfl

theorem position_eq_indexed_spec : @positionSpec = @positionIndexed := by
  funext κ _ _ _ _ _ α key entries
  apply congrArg Lookup.mk
  funext name
  simp only [build_get?, Array.find?_toList]
  exact Array.findIdx?_eq_fst_find?_zipIdx

variable [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ]

structure Membership (κ : Type v) where
  contains : κ → Bool

private def membersSpec [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ]
    (entries : List κ) : Membership κ :=
  ⟨entries.contains⟩

private def membersIndexed [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ]
    (entries : List κ) : Membership κ :=
  let index := build id entries
  ⟨fun key => index[key]?.isSome⟩

/-- Build a reusable membership predicate from a list. -/
def members [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ]
    (entries : List κ) : Membership κ :=
  membersIndexed entries

theorem members_eq_indexed : @members = @membersIndexed := rfl

theorem members_eq_indexed_spec : @membersSpec = @membersIndexed := by
  funext κ _ _ _ _ _ entries
  apply congrArg Membership.mk
  funext key
  apply Bool.eq_iff_iff.mpr
  simp [build_get?]

private def dedupSpec [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ] (entries : List κ) : List κ :=
  entries.eraseDups

private def dedupLoop : List κ → List κ → TreeSet κ → List κ
  | [], accepted, _ => accepted.reverse
  | item :: rest, accepted, seen =>
    if seen.contains item then dedupLoop rest accepted seen
    else dedupLoop rest (item :: accepted) (seen.insert item)

private def dedupIndexed [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ] (entries : List κ) : List κ :=
  dedupLoop entries [] {}

private theorem dedupLoop_eq (entries accepted : List κ) (seen : TreeSet κ)
    (h : ∀ item, seen.contains item = accepted.contains item) :
    dedupLoop entries accepted seen = List.eraseDupsBy.loop (· == ·) entries accepted := by
  induction entries generalizing accepted seen with
  | nil => rfl
  | cons item rest ih =>
    have hseen := h item
    rw [List.contains_eq_any_beq] at hseen
    simp only [dedupLoop, List.eraseDupsBy.loop, ← hseen]
    cases hit : seen.contains item
    · simp only [Bool.false_eq_true, ↓reduceIte]
      apply ih
      intro key
      rw [TreeSet.contains_insert, List.contains_cons, h]
      by_cases eq : item = key
      · simp [eq]
      · have hcmp : (compare item key == .eq) = false :=
          beq_eq_false_iff_ne.mpr (fun e => eq (LawfulEqOrd.compare_eq_iff_eq.mp e))
        rw [hcmp, beq_eq_false_iff_ne.mpr (Ne.symm eq)]
    · exact ih _ _ h

/-- Stable deduplication, using an ordered membership index. -/
def dedup [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ] (entries : List κ) : List κ :=
  dedupIndexed entries

theorem dedup_eq_indexed : @dedup = @dedupIndexed := rfl

theorem dedup_eq_indexed_spec : @dedupSpec = @dedupIndexed := by
  funext κ _ _ _ _ _ entries
  exact (dedupLoop_eq entries [] {} (by simp)).symm

theorem first_get
    (key : α → κ) (entries : Array α) (name : κ) :
    (first key entries).get name = entries.find? (fun entry => key entry == name) := by
  change (firstIndexed key entries).get name = (firstSpec key entries).get name
  rw [first_eq_indexed_spec]

theorem position_get
    (key : α → κ) (entries : Array α) (name : κ) :
    (position key entries).get name = entries.findIdx? (fun entry => key entry == name) := by
  change (positionIndexed key entries).get name = (positionSpec key entries).get name
  rw [position_eq_indexed_spec]

theorem members_contains (entries : List κ) (name : κ) :
    (members entries).contains name = entries.contains name := by
  change (membersIndexed entries).contains name = (membersSpec entries).contains name
  rw [members_eq_indexed_spec]

theorem dedup_eq_eraseDups (entries : List κ) : dedup entries = entries.eraseDups := by
  change dedupIndexed entries = dedupSpec entries
  rw [dedup_eq_indexed_spec]

end LeanCompilerBackend.NameIndex
