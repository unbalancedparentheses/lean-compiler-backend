/- Kernel-checked naming guarantees for the executable shared prefix helper.
   This file does not prove preservation by SSA, memory promotion, or symbol materialization. -/
import LeanCompilerBackend.SSA
import Init.Data.String.Lemmas.Pattern.TakeDrop.String

namespace LeanCompilerBackend.SSA

private def requiredDepth (base name : String) : Nat :=
  if name.startsWith base then
    ((name.toList.drop base.length).takeWhile (· == '_')).length + 1
  else 0

private theorem freshNamePrefix_eq (base : String) (names : Array String) :
    freshNamePrefix base names = base ++ String.ofList
      (List.replicate (names.toList.foldl (fun n name => max n (requiredDepth base name)) 0) '_') := by
  have step : (fun (name : String) (n : Nat) =>
      if name.startsWith base then
        pure (ForInStep.yield (max n
          (((name.toList.drop base.length).takeWhile (· == '_')).length + 1)))
      else pure (ForInStep.yield n)) =
      (fun name n => (pure (ForInStep.yield (max n (requiredDepth base name))) : Id (ForInStep Nat))) := by
    funext name n
    simp only [requiredDepth]
    split <;> simp_all
  simp only [freshNamePrefix, step]
  simp

private theorem foldDepth_ge_acc (base : String) (names : List String) (n : Nat) :
    n ≤ names.foldl (fun n name => max n (requiredDepth base name)) n := by
  induction names generalizing n with
  | nil => simp
  | cons a as ih =>
    exact Nat.le_trans (Nat.le_max_left _ _) (ih _)

private theorem foldDepth_ge_mem (base name : String) (names : List String) (n : Nat)
    (h : name ∈ names) :
    requiredDepth base name ≤ names.foldl (fun n name => max n (requiredDepth base name)) n := by
  induction names generalizing n with
  | nil => simp at h
  | cons a as ih =>
    simp only [List.mem_cons] at h
    rcases h with rfl | h
    · exact Nat.le_trans (Nat.le_max_right _ _) (foldDepth_ge_acc base as _)
    · exact ih _ h

/-- The actual prefix generator excludes every existing name, even after an arbitrary suffix
    is appended. This is a naming guarantee, not correctness of SSA or optimization. -/
theorem freshNamePrefix_append_ne (base suffix name : String) (names : Array String)
    (hmem : name ∈ names) : freshNamePrefix base names ++ suffix ≠ name := by
  intro heq
  rw [freshNamePrefix_eq] at heq
  let count := names.toList.foldl (fun n name => max n (requiredDepth base name)) 0
  have hlist : name.toList = base.toList ++ List.replicate count '_' ++ suffix.toList := by
    rw [← heq]
    simp [count]
  have hstarts : name.startsWith base := by
    rw [String.startsWith_string_iff, hlist]
    exact ⟨List.replicate count '_' ++ suffix.toList, (List.append_assoc ..).symm⟩
  have hbound := foldDepth_ge_mem base name names.toList 0 (by simpa using hmem)
  simp only [requiredDepth, hstarts, ↓reduceIte] at hbound
  have hdrop : name.toList.drop base.length = List.replicate count '_' ++ suffix.toList := by
    rw [hlist, List.append_assoc]
    simp only [← String.length_toList, List.drop_left]
  rw [hdrop] at hbound
  have htake : (List.replicate count '_' ++ suffix.toList).takeWhile (· == '_') =
      List.replicate count '_' ++ suffix.toList.takeWhile (· == '_') := by
    apply List.takeWhile_append_of_pos
    intro a ha
    have : a = '_' := by simpa using (List.eq_of_mem_replicate ha)
    simp [this]
  rw [htake] at hbound
  simp only [List.length_append, List.length_replicate] at hbound
  change count + _ + 1 ≤ count at hbound
  omega

/-- No input identifier starts with the generated prefix. -/
theorem freshNamePrefix_not_prefix (base name : String) (names : Array String)
    (hmem : name ∈ names) : name.startsWith (freshNamePrefix base names) = false := by
  rw [String.startsWith_string_eq_false_iff]
  rintro ⟨suffix, hsuffix⟩
  apply freshNamePrefix_append_ne base (String.ofList suffix) name names hmem
  apply String.toList_injective
  simpa using hsuffix

/-- In particular, decimal counter names used by SSA, memory promotion, and symbol
    materialization cannot collide with any identifier supplied to the prefix scan. -/
theorem freshNamePrefix_counter_ne (base name : String) (names : Array String) (counter : Nat)
    (hmem : name ∈ names) : freshNamePrefix base names ++ toString counter ≠ name :=
  freshNamePrefix_append_ne base (toString counter) name names hmem

end LeanCompilerBackend.SSA
