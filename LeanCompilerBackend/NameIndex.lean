/- First-match name indexes, with the scan retained as the logical specification. -/
import Std.Data.TreeMap.Lemmas
import Std.Data.TreeSet.Lemmas

namespace LeanCompilerBackend.NameIndex

open Std

private def compareBytes (a b : String) :
    (fuel i : Nat) → min a.utf8ByteSize b.utf8ByteSize = i + fuel → Ordering × Nat
  | 0, i, _ => (compare a.utf8ByteSize b.utf8ByteSize, i)
  | fuel + 1, i, endAt =>
    have ha : i < a.utf8ByteSize := by omega
    have hb : i < b.utf8ByteSize := by omega
    match compare (a.getUTF8Byte ⟨i⟩ ha) (b.getUTF8Byte ⟨i⟩ hb) with
    | .eq => compareBytes a b fuel (i + 1) (by omega)
    | result => (result, i + 1)

private theorem compareBytes_order (a b : String) (fuel i : Nat)
    (enough : min a.utf8ByteSize b.utf8ByteSize = i + fuel) :
    (compareBytes a b fuel i enough).1 =
      compare (a.toByteArray.data.toList.drop i) (b.toByteArray.data.toList.drop i) := by
  have len (s : String) : s.toByteArray.data.toList.length = s.utf8ByteSize :=
    Array.length_toList
  have empty (s : String) (j : Nat) (h : s.utf8ByteSize ≤ j) :
      s.toByteArray.data.toList.drop j = [] := List.drop_eq_nil_iff.mpr (by rwa [len])
  have cons (s : String) (j : Nat) (h : j < s.utf8ByteSize) :
      s.toByteArray.data.toList.drop j =
        s.getUTF8Byte ⟨j⟩ h :: s.toByteArray.data.toList.drop (j + 1) := by
    rw [List.drop_eq_getElem_cons (by rwa [len])]
    rw [Array.getElem_toList]
    rfl
  induction fuel generalizing i with
  | zero =>
    rw [compareBytes]
    by_cases ha : i < a.utf8ByteSize
    · rw [cons _ _ ha, empty b i (by omega)]
      exact Nat.compare_eq_gt.mpr (by omega)
    · rw [empty a i (by omega)]
      by_cases hb : i < b.utf8ByteSize
      · rw [cons _ _ hb]
        exact Nat.compare_eq_lt.mpr (by omega)
      · rw [empty b i (by omega)]
        exact Nat.compare_eq_eq.mpr (by omega)
  | succ fuel ih =>
    have ha : i < a.utf8ByteSize := by omega
    have hb : i < b.utf8ByteSize := by omega
    rw [compareBytes, cons _ _ ha, cons _ _ hb, List.compare_eq_compareLex,
      List.compareLex_cons_cons]
    cases compare (a.getUTF8Byte ⟨i⟩ ha) (b.getUTF8Byte ⟨i⟩ hb) <;> simp [Ordering.then]
    exact ih _ (by omega)

/-- Compare UTF-8 bytes and count the pairs inspected before the order is known. -/
def compareWithWork (a b : String) : Ordering × Nat :=
  compareBytes a b (min a.utf8ByteSize b.utf8ByteSize) 0 (by simp)

private theorem compare_order (a b : String) :
    (compareWithWork a b).1 = compare a.toByteArray.data b.toByteArray.data := by
  rw [Array.compare_eq_compareLex, Array.compareLex_eq_compareLex_toList]
  simpa [compareWithWork, List.compare_eq_compareLex] using
    compareBytes_order a b (min a.utf8ByteSize b.utf8ByteSize) 0 (by simp)

scoped instance (priority := 1100) nameOrd : Ord String where
  compare a b := (compareWithWork a b).1

scoped instance : TransOrd String := by
  have eq : nameOrd.compare = compareOn (fun name : String => name.toByteArray.data) :=
    funext fun a => funext (compare_order a)
  change TransCmp nameOrd.compare
  rw [eq]
  infer_instance

scoped instance : LawfulEqOrd String where
  eq_of_compare h := String.toByteArray_inj.mp
    (congrArg ByteArray.mk (LawfulEqOrd.eq_of_compare (α := Array UInt8)
      ((compare_order _ _).symm ▸ h)))

variable {κ : Type v}

def build [Ord κ] (key : α → κ) (entries : List α) : Std.TreeMap κ α :=
  entries.foldrTR (fun entry index => index.insert (key entry) entry) {}

theorem build_cons [Ord κ] (key : α → κ) (entry : α) (rest : List α) :
    build key (entry :: rest) = (build key rest).insert (key entry) entry := by
  simp [build, ← List.foldr_eq_foldrTR]

theorem build_get? [Ord κ] [BEq κ] [LawfulBEq κ] [TransOrd κ] [LawfulEqOrd κ] (key : α → κ) (entries : List α) (name : κ) :
    (build key entries)[name]? = entries.find? (fun entry => key entry == name) := by
  induction entries with
  | nil => simp [build, ← List.foldr_eq_foldrTR]
  | cons entry rest ih =>
    rw [build_cons]
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
