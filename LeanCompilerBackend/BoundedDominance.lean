/- Indexed bit sets for the restricted validator's synchronous dominance solver. -/
import LeanCompilerBackend.NameIndex

namespace LeanCompilerBackend.BoundedDominance

private abbrev Rows (α : Type) := List (String × α)

private def solve [BEq α] (step : α → α) : Nat → α → Except String α
  | 0, _ => .error "dominance iteration resource limit exceeded"
  | fuel + 1, old =>
    let next := step old
    if next == old then .ok next else solve step fuel next

private def listStep (names : List String) (entry : String) (preds : String → List String)
    (old : Rows (List String)) : Rows (List String) :=
  names.map fun name =>
    (name, if name == entry then [entry] else
      names.filter fun candidate =>
        candidate == name || (!(preds name).isEmpty &&
          (preds name).all fun pred => ((old.lookup pred).getD []).contains candidate))

private def initial (names : List String) (entry : String) : Rows (List String) :=
  names.map fun name => (name, if name == entry then [entry] else names)

/-- The original finite-set recurrence, including its fuel and treatment of disconnected SCCs. -/
def oracle (names : List String) (entry : String) (preds : String → List String)
    (fuel : Nat) : Except String (NameIndex.Membership (String × String)) := do
  let final ← solve (listStep names entry preds) fuel (initial names entry)
  pure ⟨fun (useBlock, definitionBlock) => ((final.lookup useBlock).getD []).contains definitionBlock⟩

-- Bits correspond to occurrences in the input list. This representation also
-- refines the reference recurrence for lists containing duplicate labels.
private def pack (predicate : String → Bool) : List String → Nat
  | [] => 0
  | name :: rest => (if predicate name then 1 else 0) ||| (pack predicate rest <<< 1)

private theorem testBit_pack (names : List String) (predicate : String → Bool) (i : Nat) :
    (pack predicate names).testBit i = (names[i]?).any predicate := by
  induction names generalizing i with
  | nil => simp [pack]
  | cons name rest ih =>
    cases i with
    | zero => cases h : predicate name <;> simp [pack, h]
    | succ i =>
      have hz (b : Bool) : (if b then 1 else 0 : Nat).testBit (i + 1) = false := by
        cases b <;> simp [Nat.testBit_succ]
      simp [pack, hz, ih, Nat.testBit_shiftLeft]

private theorem pack_congr (names : List String) (p q : String → Bool)
    (h : ∀ x ∈ names, p x = q x) : pack p names = pack q names := by
  induction names with
  | nil => rfl
  | cons head tail ih =>
    simp [pack, h head (by simp), ih (fun x hx => h x (by simp [hx]))]

private theorem pack_eq_bool (names : List String) (p q : String → Bool) :
    pack p names = pack q names ↔ ∀ x ∈ names, p x = q x := by
  refine ⟨?_, pack_congr names p q⟩
  intro eq x hx
  obtain ⟨i, hi, rfl⟩ := List.mem_iff_getElem.mp hx
  have h := congrArg (fun n => n.testBit i) eq
  simpa [testBit_pack, List.getElem?_eq_getElem hi] using h

private def encode (names members : List String) : Nat :=
  pack members.contains names

private theorem contains_filter (names : List String) (p : String → Bool) (x : String)
    (hx : x ∈ names) : (names.filter p).contains x = p x := by
  apply Bool.eq_iff_iff.mpr
  simp [hx]

private theorem encode_filter (names : List String) (p : String → Bool) :
    encode names (names.filter p) = pack p names :=
  pack_congr _ _ _ (contains_filter names p)

private def encodeRows (names : List String) (rows : Rows (List String)) : Rows Nat :=
  rows.map fun (name, members) => (name, encode names members)

private theorem lookup_encodeRows (names : List String) (rows : Rows (List String))
    (name : String) :
    (encodeRows names rows).lookup name = (rows.lookup name).map (encode names) := by
  induction rows with
  | nil => rfl
  | cons head tail ih =>
    rcases head with ⟨key, members⟩
    by_cases h : name = key
    · simp [encodeRows, List.lookup, h]
    · have hn : (name == key) = false := beq_eq_false_iff_ne.mpr h
      change (List.lookup name ((key, encode names members) :: encodeRows names tail)) =
        (List.lookup name ((key, members) :: tail)).map (encode names)
      simpa [List.lookup, hn] using ih

private theorem lookup_encodeRows_default (names : List String) (rows : Rows (List String))
    (name : String) :
    ((encodeRows names rows).lookup name).getD 0 =
      encode names ((rows.lookup name).getD []) := by
  rw [lookup_encodeRows]
  cases rows.lookup name with
  | none =>
    change 0 = pack (fun _ => false) names
    apply Nat.eq_of_testBit_eq
    intro i
    simp [testBit_pack]
  | some members => rfl

private def indexedRows (rows : Rows Nat) : NameIndex.Lookup String Nat :=
  ⟨fun name => rows.lookup name⟩

private def indexedRowsFast (rows : Rows Nat) : NameIndex.Lookup String Nat :=
  let index := NameIndex.build Prod.fst rows
  ⟨fun name => (index[name]?).map Prod.snd⟩

private theorem lookup_find (rows : Rows α) (name : String) :
    rows.lookup name = (rows.find? fun row => row.1 == name).map Prod.snd := by
  induction rows with
  | nil => rfl
  | cons head tail ih =>
    rcases head with ⟨key, value⟩
    by_cases h : key = name
    · simp [List.lookup, h]
    · have h' : (key == name) = false := beq_eq_false_iff_ne.mpr h
      have hn : (name == key) = false := beq_eq_false_iff_ne.mpr (Ne.symm h)
      simp [List.lookup, h', hn, ih]

@[csimp] theorem indexedRows_eq_fast : indexedRows = indexedRowsFast := by
  funext rows
  apply congrArg NameIndex.Lookup.mk
  funext name
  simp [NameIndex.build_get?, lookup_find]

private def intersect (values : NameIndex.Lookup String Nat) (all : Nat) (preds : List String) :
    Nat :=
  if preds.isEmpty then 0
  else preds.foldl (fun members pred => members &&& (values.get pred).getD 0) all

private theorem testBit_intersectFold (values : NameIndex.Lookup String Nat) (preds : List String)
    (acc i : Nat) :
    (preds.foldl (fun members pred => members &&& (values.get pred).getD 0) acc).testBit i =
      (acc.testBit i && preds.all (fun p => ((values.get p).getD 0).testBit i)) := by
  induction preds generalizing acc with
  | nil => simp
  | cons pred rest ih => simp [ih, Bool.and_assoc]

private def packedStep (blocks : List (String × Nat × List String)) (entry : String)
    (entryMask all : Nat) (old : Rows Nat) : Rows Nat :=
  let indexed := indexedRows old
  blocks.map fun (name, own, preds) =>
    (name, if name == entry then entryMask else own ||| intersect indexed all preds)

private def packedBlocks (names : List String) (preds : String → List String) :
    List (String × Nat × List String) :=
  names.map fun name => (name, pack (· == name) names, preds name)

private def maskIndex (names : List String) (start : Nat) : Std.TreeMap String Nat :=
  (names.zipIdx start).foldr (fun (name, bit) index =>
    index.insert name ((1 <<< bit) ||| index[name]?.getD 0)) {}

private theorem maskIndex_get (names : List String) (start : Nat) (name : String) :
    (maskIndex names start)[name]?.getD 0 = pack (· == name) names <<< start := by
  induction names generalizing start with
  | nil => simp [maskIndex, pack]
  | cons head rest ih =>
    change ((maskIndex rest (start+1)).insert head
      ((1 <<< start) ||| (maskIndex rest (start+1))[head]?.getD 0))[name]?.getD 0 =
        ((if head == name then 1 else 0) ||| (pack (· == name) rest <<< 1)) <<< start
    rw [Std.TreeMap.getElem?_insert, Nat.shiftLeft_or_distrib, ← Nat.shiftLeft_add,
      Nat.add_comm 1 start]
    by_cases h : head = name
    · simp [h, ih]
    · simp [h, ih]

private def packedBlocksIndexed (names : List String) (preds : String → List String) :
    List (String × Nat × List String) :=
  let masks := maskIndex names 0
  names.map fun name => (name, masks[name]?.getD 0, preds name)

@[csimp] theorem packedBlocks_eq_indexed : packedBlocks = packedBlocksIndexed := by
  funext names preds
  simp [packedBlocks, packedBlocksIndexed, maskIndex_get]

private theorem packedStep_eq (names : List String) (entry : String) (preds : String → List String)
    (old : Rows (List String)) :
    packedStep (packedBlocks names preds) entry (encode names [entry]) (pack (fun _ => true) names)
        (encodeRows names old) = encodeRows names (listStep names entry preds old) := by
  unfold packedStep packedBlocks
  conv => rhs; unfold encodeRows listStep
  simp only [List.map_map, Function.comp_def]
  apply congrArg (fun f => names.map f)
  funext name
  by_cases h : name = entry
  · simp [h]
  · simp only [beq_iff_eq, ite_eq_right h, encode_filter]
    apply congrArg (Prod.mk name)
    apply Nat.eq_of_testBit_eq
    intro i
    by_cases hi : i < names.length
    · rw [Nat.testBit_or, testBit_pack, testBit_pack, List.getElem?_eq_getElem hi]
      simp only [Option.any_some]
      unfold intersect
      by_cases he : (preds name).isEmpty = true
      · simp [he]
      · rw [ite_eq_right he, testBit_intersectFold]
        simp only [indexedRows, lookup_encodeRows_default, encode, testBit_pack,
          List.getElem?_eq_getElem hi, Option.any_some, Bool.true_and, he, Bool.not_false]
    · have hnone : names[i]? = none := List.getElem?_eq_none_iff.mpr (by omega)
      simp only [Nat.testBit_or, testBit_pack, hnone, Option.any_none, Bool.false_or]
      unfold intersect
      split
      · simp
      · simp [testBit_intersectFold, testBit_pack, hnone]

private def Canonical (names : List String) (entry : String) (rows : Rows (List String)) : Prop :=
  ∀ row ∈ rows, row.1 ∈ names ∧
    if row.1 = entry then row.2 = [entry] else ∃ p, row.2 = names.filter p

private theorem initial_canonical (names : List String) (entry : String) :
    Canonical names entry (initial names entry) := by
  intro row hr
  obtain ⟨name, hn, rfl⟩ := List.mem_map.mp hr
  refine ⟨hn, ?_⟩
  by_cases he : name = entry
  · simp [he]
  · simp only [he, beq_iff_eq, ite_false]
    exact ⟨fun _ => true, by rw [List.filter_eq_self.mpr (fun _ _ => rfl)]⟩

private theorem listStep_canonical (names : List String) (entry : String) (preds : String → List String)
    (old : Rows (List String)) : Canonical names entry (listStep names entry preds old) := by
  intro row hr
  obtain ⟨name, hn, rfl⟩ := List.mem_map.mp hr
  refine ⟨hn, ?_⟩
  by_cases he : name = entry
  · simp [he]
  · simp only [he, beq_iff_eq, ite_false]
    exact ⟨_, rfl⟩

private theorem encodeRows_inj (names : List String) (entry : String)
    (left right : Rows (List String)) (hl : Canonical names entry left)
    (hr : Canonical names entry right) (h : encodeRows names left = encodeRows names right) :
    left = right := by
  induction left generalizing right with
  | nil =>
    cases right
    · rfl
    · cases h
  | cons head tail ih =>
    cases right with
    | nil => cases h
    | cons head' tail' =>
      simp only [encodeRows, List.map_cons, List.cons.injEq, Prod.mk.injEq] at h
      rcases head with ⟨name, members⟩
      rcases head' with ⟨name', members'⟩
      obtain ⟨⟨keys, values⟩, rest⟩ := h
      change name = name' at keys
      subst name'
      have lv := (hl (name, members) (by simp)).2
      have rv := (hr (name, members') (by simp)).2
      have eq : members = members' := by
        by_cases he : name = entry
        · simp [he] at lv rv
          exact lv.trans rv.symm
        · simp only [he, ite_false] at lv rv
          obtain ⟨p, rfl⟩ := lv
          obtain ⟨q, rfl⟩ := rv
          rw [encode_filter, encode_filter] at values
          exact List.filter_congr ((pack_eq_bool names p q).mp values)
      rw [eq, ih tail' (fun row hm => hl row (List.mem_cons_of_mem _ hm))
        (fun row hm => hr row (List.mem_cons_of_mem _ hm)) rest]

private def packedInitial (names : List String) (entry : String) (entryMask all : Nat) : Rows Nat :=
  names.map fun name => (name, if name == entry then entryMask else all)

private theorem packedInitial_eq (names : List String) (entry : String) :
    packedInitial names entry (encode names [entry]) (pack (fun _ => true) names) =
      encodeRows names (initial names entry) := by
  unfold packedInitial encodeRows initial
  rw [List.map_map]
  apply List.map_congr_left
  intro name _
  by_cases he : name = entry
  · simp [he]
  · simp [he, encode]
    exact pack_congr _ _ _ (fun x hx => by simp [hx])

private theorem solve_packed_eq (names : List String) (entry : String) (preds : String → List String)
    (fuel : Nat) (old : Rows (List String)) (canonical : Canonical names entry old) :
    solve (packedStep (packedBlocks names preds) entry (encode names [entry])
        (pack (fun _ => true) names)) fuel (encodeRows names old) =
      (solve (listStep names entry preds) fuel old).map (encodeRows names) := by
  induction fuel generalizing old with
  | zero => rfl
  | succ fuel ih =>
    simp only [solve, packedStep_eq]
    have next := listStep_canonical names entry preds old
    by_cases h : listStep names entry preds old = old
    · simp [h, Except.map]
    · have hpacked : encodeRows names (listStep names entry preds old) ≠ encodeRows names old :=
        fun he => h (encodeRows_inj names entry _ _ next canonical he)
      simpa only [beq_iff_eq, ite_eq_right h, ite_eq_right hpacked] using ih _ next

private theorem solve_canonical (names : List String) (entry : String) (preds : String → List String)
    (fuel : Nat) (old final : Rows (List String))
    (h : solve (listStep names entry preds) fuel old = .ok final) :
    Canonical names entry final := by
  induction fuel generalizing old with
  | zero => cases h
  | succ fuel ih =>
    simp only [solve] at h
    split at h
    · injection h with h
      rw [← h]
      exact listStep_canonical names entry preds old
    · exact ih _ h

private theorem canonical_subset (names : List String) (entry : String) (rows : Rows (List String))
    (canonical : Canonical names entry rows) (row : String × List String) (h : row ∈ rows) :
    row.2 ⊆ names := by
  obtain ⟨known, shape⟩ := canonical row h
  split at shape <;> rename_i he
  · rw [shape]
    simpa using (he ▸ known)
  · obtain ⟨_, heq⟩ := shape
    rw [heq]
    exact fun _ hm => (List.mem_filter.mp hm).1

private theorem lookup_mem_rows (rows : Rows α) (key : String) (value : α)
    (h : rows.lookup key = some value) : (key, value) ∈ rows := by
  induction rows with
  | nil => cases h
  | cons head tail ih =>
    rcases head with ⟨name, members⟩
    by_cases he : key = name
    · simp [List.lookup, he] at h
      simp [he, h]
    · have hn : (key == name) = false := beq_eq_false_iff_ne.mpr he
      exact List.mem_cons_of_mem _ (ih (by simpa [List.lookup, hn] using h))

-- Keep table construction outside the returned query closure.
@[noinline] private def readWith (index positions : NameIndex.Lookup String Nat) :
    NameIndex.Membership (String × String) :=
  ⟨fun (useBlock, definitionBlock) =>
    match positions.get definitionBlock with
    | none => false
    | some bit => ((index.get useBlock).getD 0).testBit bit⟩

private def readPacked (names : List String) (rows : Rows Nat) :
    NameIndex.Membership (String × String) :=
  readWith (indexedRows rows) (NameIndex.position id names.toArray)

private theorem readPacked_eq (names : List String) (entry : String)
    (rows : Rows (List String)) (canonical : Canonical names entry rows) :
    readPacked names (encodeRows names rows) =
      ⟨fun (useBlock, definitionBlock) => ((rows.lookup useBlock).getD []).contains definitionBlock⟩ := by
  apply congrArg NameIndex.Membership.mk
  funext pair
  rcases pair with ⟨use, defn⟩
  simp only [NameIndex.position, List.findIdx?_toArray, indexedRows, id_eq]
  change (match names.findIdx? (fun x => x == defn) with
    | none => false
    | some bit => (((encodeRows names rows).lookup use).getD 0).testBit bit) = _
  rw [lookup_encodeRows_default]
  cases hf : names.findIdx? (fun x => x == defn) with
  | none =>
    have absent : defn ∉ names := by
      intro hn
      have impossible := List.findIdx?_eq_none_iff.mp hf defn hn
      simp at impossible
    cases hrow : rows.lookup use with
    | none => rfl
    | some members =>
      have hs := canonical_subset names entry rows canonical (use, members)
        (lookup_mem_rows rows use members hrow)
      apply Eq.symm
      apply Bool.eq_false_iff.mpr
      intro hc
      exact absent (hs (List.contains_iff_mem.mp hc))
  | some bit =>
    have atBit : names[bit]? = some defn := by
      have ⟨hi, h, _⟩ := List.findIdx?_eq_some_iff_getElem.mp hf
      exact (List.getElem?_eq_getElem hi).trans (congrArg some (by simpa using h))
    simp [encode, testBit_pack, atBit]

private abbrev Blocks := List (String × Nat × List String)

private theorem repeat_first (step : α → α) (n : Nat) (init : α) :
    Nat.repeat step n (step init) = Nat.repeat step (n + 1) init := by
  induction n with
  | zero => rfl
  | succ n ih => exact congrArg step ih

private theorem solve_of_converged [BEq α] [LawfulBEq α] (step : α → α) (n fuel : Nat)
    (init final : α) (fixed : step final = final) (settled : Nat.repeat step n init = final)
    (enough : n < fuel) : solve step fuel init = .ok final := by
  induction n generalizing init fuel with
  | zero =>
    cases fuel with
    | zero => omega
    | succ fuel =>
      change init = final at settled
      subst final
      simp [solve, fixed]
  | succ n ih =>
    cases fuel with
    | zero => omega
    | succ fuel =>
      by_cases stable : step init = init
      · have same (k : Nat) : Nat.repeat step k init = init := by
          induction k with
          | zero => rfl
          | succ k ih => exact (congrArg step ih).trans stable
        have eq : init = final := (same (n + 1)).symm.trans settled
        have known : (step init == init) = true := beq_iff_eq.mpr stable
        rw [solve, ite_eq_left known, stable, eq]
      · have unknown : ¬(step init == init) = true := fun h => stable (beq_iff_eq.mp h)
        simp only [solve, ite_eq_right unknown]
        exact ih fuel (step init) ((repeat_first _ _ _).trans settled) (by omega)

private def MaskLE (a b : Nat) : Prop :=
  ∀ bit, a.testBit bit = true → b.testBit bit = true

private theorem maskLE_refl (mask : Nat) : MaskLE mask mask := fun _ h => h

private theorem maskLE_trans {a b c : Nat} (ab : MaskLE a b) (bc : MaskLE b c) : MaskLE a c :=
  fun bit h => bc bit (ab bit h)

private theorem maskLE_antisymm {a b : Nat} (ab : MaskLE a b) (ba : MaskLE b a) : a = b := by
  apply Nat.eq_of_testBit_eq
  intro bit
  exact Bool.eq_iff_iff.mpr ⟨ab bit, ba bit⟩

private theorem maskLE_and {a b c : Nat} (ab : MaskLE a b) (ac : MaskLE a c) :
    MaskLE a (b &&& c) := by
  intro bit h
  simp [ab bit h, ac bit h]

private theorem maskLE_bitwise {a b : Nat} : MaskLE a b ↔ a &&& b = a := by
  constructor
  · intro h
    apply Nat.eq_of_testBit_eq
    intro bit
    cases e : a.testBit bit
    · simp [e]
    · simp only [Nat.testBit_and, e, Bool.true_and]
      exact h bit e
  · intro e bit ht
    have h := congrArg (fun n : Nat => n.testBit bit) e
    simpa [ht] using h

private abbrev Values := Std.TreeMap String Nat
private abbrev BlockTable := Std.TreeMap String (String × Nat × List String)

private def buildEquations (blocks : Blocks) : BlockTable :=
  NameIndex.build (·.1) blocks

private theorem buildEquations_get (blocks : Blocks) (key : String) :
    (buildEquations blocks)[key]? = blocks.find? (·.1 == key) :=
  NameIndex.build_get? _ _ _

private def Rows.below (left : Rows Nat) (right : NameIndex.Lookup String Nat) : Prop :=
  ∀ key, MaskLE ((left.lookup key).getD 0) ((right.get key).getD 0)

private def Rows.belowCheck (left : Rows Nat) (right : NameIndex.Lookup String Nat) : Bool :=
  left.all fun (key, value) => value &&& (right.get key).getD 0 == value

private theorem Rows.belowCheck_sound (left : Rows Nat) (right : NameIndex.Lookup String Nat)
    (checked : left.belowCheck right) : left.below right := by
  intro key
  cases h : left.lookup key with
  | none => simp [MaskLE]
  | some v =>
    have found := lookup_mem_rows _ _ _ h
    have checked := List.all_eq_true.mp checked (key, v) found
    exact (maskLE_bitwise.mpr (beq_iff_eq.mp checked))

private def transfer (entry : String) (entryMask all : Nat) (values : NameIndex.Lookup String Nat)
    (block : String × Nat × List String) : Nat :=
  if block.1 == entry then entryMask else block.2.1 ||| intersect values all block.2.2

private theorem transfer_mono (entry : String) (entryMask all : Nat)
    (left right : NameIndex.Lookup String Nat)
    (h : ∀ key, MaskLE ((left.get key).getD 0) ((right.get key).getD 0))
    (block : String × Nat × List String) :
    MaskLE (transfer entry entryMask all left block) (transfer entry entryMask all right block) := by
  intro bit hit
  unfold transfer at *
  split at hit <;> rename_i eq
  · simpa only [ite_eq_left eq] using hit
  · simp only [ite_eq_right eq, Nat.testBit_or] at *
    rcases Bool.or_eq_true_iff.mp hit with localBit | fromPreds
    · exact Bool.or_eq_true_iff.mpr (Or.inl localBit)
    · apply Bool.or_eq_true_iff.mpr
      right
      unfold intersect at *
      split at fromPreds <;> rename_i empty
      · simp at fromPreds
      · simp only [ite_eq_right empty, testBit_intersectFold, Bool.and_eq_true] at *
        refine ⟨fromPreds.1, List.all_eq_true.mpr ?_⟩
        intro k present
        exact h k bit (List.all_eq_true.mp fromPreds.2 k present)

private theorem step_lookup (blocks : Blocks) (entry : String) (entryMask all : Nat)
    (old : Rows Nat) (key : String) :
    (packedStep blocks entry entryMask all old).lookup key =
      (blocks.find? (·.1 == key)).map (transfer entry entryMask all (indexedRows old)) := by
  rw [lookup_find]
  simp [packedStep, List.find?_map, Function.comp_def, Option.map_map]
  congr 1
  funext block
  rcases block with ⟨name, own, preds⟩
  simp [transfer]

private theorem step_mono (blocks : Blocks) (entry : String) (entryMask all : Nat)
    (left right : Rows Nat) (h : left.below (indexedRows right)) :
    (packedStep blocks entry entryMask all left).below
      (indexedRows (packedStep blocks entry entryMask all right)) := by
  intro key
  change MaskLE ((packedStep blocks entry entryMask all left).lookup key |>.getD 0)
    ((packedStep blocks entry entryMask all right).lookup key |>.getD 0)
  rw [step_lookup, step_lookup]
  cases blocks.find? (·.1 == key) with
  | none => exact maskLE_refl _
  | some block => exact transfer_mono _ _ _ (indexedRows left) (indexedRows right) h block

private def tableValues (index : Values) : NameIndex.Lookup String Nat :=
  ⟨fun key => index[key]?⟩

private def makeValues (rows : Rows Nat) : Values :=
  rows.foldr (fun (key, value) map => map.insert key value) {}

private theorem makeValues_get (rows : Rows Nat) (key : String) :
    (makeValues rows)[key]? = rows.lookup key := by
  induction rows with
  | nil => simp [makeValues, List.lookup]
  | cons pair rest ih =>
    rcases pair with ⟨name, value⟩
    change ((makeValues rest).insert name value)[key]? = ((name, value) :: rest).lookup key
    rw [Std.TreeMap.getElem?_insert, ih]
    by_cases h : name = key
    · simp [h, List.lookup]
    · have hn : (key == name) = false := beq_eq_false_iff_ne.mpr (Ne.symm h)
      simp [h, hn, List.lookup]

private def dependents (blocks : Blocks) : Std.TreeMap String (List String) :=
  blocks.foldl (fun index (name, _, preds) =>
    preds.foldl (fun acc pred => acc.insert pred (name :: acc[pred]?.getD [])) index) {}

-- Iterative DFS, with explicit exit markers so the order is independent of
-- the source block layout. Start DFS at the entry before visiting disconnected rows.
private def reversePostorder (blocks : Blocks) (entry : String) : List String := Id.run do
  let users := dependents blocks
  let mut seen : Std.TreeSet String := {}
  let mut order := []
  for root in entry :: blocks.map (·.1) do
    let mut stack := [(root, false)]
    while let (name, exiting) :: rest := stack do
      stack := rest
      if exiting then
        order := name :: order
      else if !seen.contains name then
        seen := seen.insert name
        stack := (users[name]?.getD []).foldr
          (fun successor pending => (successor, false) :: pending) ((name, true) :: stack)
  return order

private structure WorkResult where
  values : Values
  changes : Nat
  visits : Nat

private def sweepRows (equations : BlockTable) (entry : String) (entryMask all : Nat) :
    List String → WorkResult → WorkResult
  | [], state => state
  | target :: pending, state =>
    match equations[target]? with
    | none => sweepRows equations entry entryMask all pending { state with visits := state.visits + 1 }
    | some block =>
      let previous := state.values[target]?.getD 0
      let allowed := transfer entry entryMask all (tableValues state.values) block
      let value := previous &&& allowed
      let visits := state.visits + 1 + (if target == entry then 0 else block.2.2.length)
      if value == previous then sweepRows equations entry entryMask all pending { state with visits }
      else sweepRows equations entry entryMask all pending
        ⟨state.values.insert target value, state.changes + 1, visits⟩

private theorem orbit_desc (blocks : Blocks) (entry : String) (entryMask all : Nat)
    (first : Rows Nat) (descending : (packedStep blocks entry entryMask all first).below
      (indexedRows first)) (n : Nat) :
    let step := packedStep blocks entry entryMask all
    (Nat.repeat step (n + 1) first).below (indexedRows (Nat.repeat step n first)) := by
  induction n with
  | zero => exact descending
  | succ n ih => exact step_mono _ _ _ _ _ _ ih

private theorem sweepRows_agrees (blocks : Blocks)
    (entry : String) (entryMask all : Nat) (pending : List String)
    (state : WorkResult) (first : Rows Nat)
    (descending : (packedStep blocks entry entryMask all first).below (indexedRows first))
    (initial : (Nat.repeat (packedStep blocks entry entryMask all) state.changes first).below
      (tableValues state.values)) :
    let result := sweepRows (buildEquations blocks) entry entryMask all pending state
    (Nat.repeat (packedStep blocks entry entryMask all) result.changes first).below
      (tableValues result.values) := by
  induction pending generalizing state with
  | nil => exact initial
  | cons target pending ih =>
    simp only [sweepRows]
    split <;> rename_i found
    · exact ih _ initial
    · rename_i block
      split
      · exact ih _ initial
      · apply ih
        intro query
        change MaskLE ((packedStep blocks entry entryMask all _).lookup query |>.getD 0)
          (((state.values.insert target _)[query]?).getD 0)
        rw [Std.TreeMap.getElem?_insert]
        by_cases eq : target = query
        · subst query
          simp only [Std.ReflCmp.compare_self, ↓reduceIte, Option.getD_some]
          apply maskLE_and
          · exact maskLE_trans (orbit_desc _ _ _ _ _ descending _ target) (initial target)
          · rw [step_lookup, ← buildEquations_get, found]
            exact transfer_mono _ _ _
              (indexedRows (Nat.repeat (packedStep blocks entry entryMask all) state.changes first))
              (tableValues state.values) initial block
        · simp only [Std.LawfulEqOrd.compare_eq_iff_eq, ite_eq_right eq]
          exact maskLE_trans (orbit_desc _ _ _ _ _ descending _ query) (initial query)

-- Complete equations are evaluated in reverse postorder. In a DAG, each
-- predecessor has its final value by the time its successor is evaluated.
-- Cycles can require further sweeps.
private def sweepWithVisits (equations : BlockTable) (entry : String) (entryMask all : Nat)
    (pending : List String) (settled : WorkResult → Bool) :
    Nat → WorkResult → Option { result : WorkResult // settled result } × Nat
  | 0, state => (none, state.visits)
  | rounds + 1, state =>
    let next := sweepRows equations entry entryMask all pending state
    if h : settled next then (some ⟨next, h⟩, next.visits)
    else if next.changes == state.changes then (none, next.visits)
    else sweepWithVisits equations entry entryMask all pending settled rounds next

private def sweep (equations : BlockTable) (entry : String) (entryMask all : Nat)
    (pending : List String) (settled : WorkResult → Bool) (rounds : Nat) (state : WorkResult) :
    Option { result : WorkResult // settled result } :=
  (sweepWithVisits equations entry entryMask all pending settled rounds state).1

private theorem sweep_agrees (blocks : Blocks) (entry : String) (entryMask all : Nat)
    (pending : List String) (settled : WorkResult → Bool) (rounds : Nat)
    (state : WorkResult) (result : { result : WorkResult // settled result }) (first : Rows Nat)
    (descending : (packedStep blocks entry entryMask all first).below (indexedRows first))
    (initial : (Nat.repeat (packedStep blocks entry entryMask all) state.changes first).below
      (tableValues state.values))
    (success : sweep (buildEquations blocks) entry entryMask all pending settled rounds state = some result) :
    (Nat.repeat (packedStep blocks entry entryMask all) result.val.changes first).below
      (tableValues result.val.values) := by
  induction rounds generalizing state with
  | zero => cases success
  | succ rounds ih =>
    simp only [sweep, sweepWithVisits] at success
    have bound := sweepRows_agrees blocks entry entryMask all pending state first descending initial
    split at success
    · cases success
      exact bound
    · split at success
      · cases success
      · exact ih _ bound success

private def materialize (blocks : Blocks) (values : Values) : Rows Nat :=
  blocks.map fun block => (block.1, values[block.1]?.getD 0)

private theorem materialize_lookup (blocks : Blocks) (values : Values) (key : String) :
    (materialize blocks values).lookup key =
      (blocks.find? (·.1 == key)).map (fun block => values[block.1]?.getD 0) := by
  rw [lookup_find]
  simp [materialize, List.find?_map, Function.comp_def, Option.map_map]

private theorem same_step (blocks : Blocks) (entry : String) (entryMask all : Nat)
    (left right : Rows Nat)
    (agrees : ∀ key, (left.lookup key).getD 0 = (right.lookup key).getD 0) :
    packedStep blocks entry entryMask all left = packedStep blocks entry entryMask all right := by
  unfold packedStep
  apply List.map_congr_left
  intro block _
  apply congrArg (Prod.mk block.1)
  change transfer entry entryMask all (indexedRows left) block =
    transfer entry entryMask all (indexedRows right) block
  apply maskLE_antisymm
  · apply transfer_mono
    intro key
    change MaskLE ((left.lookup key).getD 0) ((right.lookup key).getD 0)
    rw [agrees]
    exact maskLE_refl _
  · apply transfer_mono
    intro key
    change MaskLE ((right.lookup key).getD 0) ((left.lookup key).getD 0)
    rw [agrees]
    exact maskLE_refl _

private theorem worklist_converged (blocks : Blocks) (entry : String) (entryMask all : Nat)
    (first : Rows Nat) (result : WorkResult)
    (descending : (packedStep blocks entry entryMask all first).below (indexedRows first))
    (upper : (Nat.repeat (packedStep blocks entry entryMask all) result.changes first).below
      (tableValues result.values))
    (fixed : packedStep blocks entry entryMask all (materialize blocks result.values) =
      materialize blocks result.values)
    (start : (materialize blocks result.values).below (indexedRows first)) :
    Nat.repeat (packedStep blocks entry entryMask all) (result.changes + 2) first =
      materialize blocks result.values := by
  let step := packedStep blocks entry entryMask all
  let final := materialize blocks result.values
  have lower (n : Nat) : final.below (indexedRows (Nat.repeat step n first)) := by
    induction n with
    | zero => exact start
    | succ n ih =>
      have next := step_mono blocks entry entryMask all final (Nat.repeat step n first) ih
      rw [fixed] at next
      exact next
  have sameValues key : ((Nat.repeat step (result.changes + 1) first).lookup key).getD 0 =
      (final.lookup key).getD 0 := by
    apply maskLE_antisymm
    · change MaskLE ((step (Nat.repeat step result.changes first)).lookup key |>.getD 0)
        ((materialize blocks result.values).lookup key |>.getD 0)
      rw [step_lookup, materialize_lookup]
      cases found : blocks.find? (·.1 == key) with
      | none => exact maskLE_refl _
      | some block =>
        have keyEq : block.1 = key := beq_iff_eq.mp (List.find?_some (p := fun row : String × Nat × List String => row.1 == key) found)
        change MaskLE (transfer entry entryMask all
          (indexedRows (Nat.repeat step result.changes first)) block)
          (result.values[block.1]?.getD 0)
        rw [keyEq]
        have bound := maskLE_trans (orbit_desc _ _ _ _ _ descending result.changes key) (upper key)
        change MaskLE ((step (Nat.repeat step result.changes first)).lookup key |>.getD 0)
          (result.values[key]?.getD 0) at bound
        dsimp only [step] at bound
        simpa only [step_lookup, found, Option.map_some, Option.getD_some] using bound
    · exact lower _ key
  change step (Nat.repeat step (result.changes + 1) first) = final
  exact (same_step _ _ _ _ _ _ sameValues).trans fixed

private def packedSolve (blocks : Blocks) (entry : String) (entryMask all : Nat)
    (fuel : Nat) (first : Rows Nat) : Except String (Rows Nat) :=
  solve (packedStep blocks entry entryMask all) fuel first

-- The fallback uses the same step and stopping test as the reference.
private def solveWithRounds [BEq α] (step : α → α) : Nat → α → Nat → Except String (α × Nat)
  | 0, _, _ => .error "dominance iteration resource limit exceeded"
  | fuel + 1, old, rounds =>
    let next := step old
    if next == old then .ok (next, rounds + 1) else solveWithRounds step fuel next (rounds + 1)

private theorem solveWithRounds_result [BEq α] (step : α → α) (fuel : Nat) (old : α)
    (rounds : Nat) : (solveWithRounds step fuel old rounds).map Prod.fst = solve step fuel old := by
  induction fuel generalizing old rounds with
  | zero => rfl
  | succ fuel ih =>
    simp only [solveWithRounds, solve]
    split
    · rfl
    · exact ih _ _

-- Verify the fixed point and its position in the reference orbit before
-- returning it. Preserve the reference result for every fuel and input.
private def packedSolveWithWork (blocks : Blocks) (entry : String) (entryMask all : Nat)
    (fuel : Nat) (first : Rows Nat) : Except String (Rows Nat × Nat) := do
  let step := packedStep blocks entry entryMask all
  let start := indexedRows first
  let roundWork := blocks.foldl (fun n block => n + 1 + (if block.1 == entry then 0 else block.2.2.length)) 0
  let fallback := fun work => do
    let (final, rounds) ← solveWithRounds step fuel first 0
    return (final, work + rounds * roundWork)
  if 2 < fuel then
    if (step first).belowCheck start then
      let initial : WorkResult := ⟨makeValues first, 0, 0⟩
      let pending := reversePostorder blocks entry
      let settled := fun result =>
        let final := materialize blocks result.values
        result.changes + 2 < fuel && step final == final && final.belowCheck start
      let (result, visits) := sweepWithVisits (buildEquations blocks) entry entryMask all
        pending settled fuel initial
      if let some result := result then
        return (materialize blocks result.val.values, roundWork + visits)
      fallback (roundWork + visits)
    else fallback roundWork
  else fallback 0

private def packedSolveWorklist (blocks : Blocks) (entry : String) (entryMask all : Nat)
    (fuel : Nat) (first : Rows Nat) : Except String (Rows Nat) :=
  (packedSolveWithWork blocks entry entryMask all fuel first).map Prod.fst

@[csimp] theorem packedSolve_eq_worklist : packedSolve = packedSolveWorklist := by
  funext blocks entry entryMask all fuel first
  unfold packedSolveWorklist packedSolveWithWork
  dsimp only
  have fallback (work roundWork : Nat) :
      packedSolve blocks entry entryMask all fuel first =
        (do
          let result ← solveWithRounds (packedStep blocks entry entryMask all) fuel first 0
          pure (result.1, work + result.2 * roundWork) : Except String (Rows Nat × Nat)).map Prod.fst := by
    unfold packedSolve
    rw [← solveWithRounds_result _ _ _ 0]
    cases solveWithRounds (packedStep blocks entry entryMask all) fuel first 0 <;> rfl
  split
  · split
    · split
      · rename_i result h
        have checked : (result.val.changes + 2 < fuel ∧
            packedStep blocks entry entryMask all (materialize blocks result.val.values) =
              materialize blocks result.val.values) ∧
            (materialize blocks result.val.values).belowCheck (indexedRows first) = true := by
          simpa only [Bool.and_eq_true, decide_eq_true_eq, beq_iff_eq] using result.property
        rcases checked with ⟨⟨enough, fixed⟩, upper⟩
        have descending := Rows.belowCheck_sound (packedStep blocks entry entryMask all first) (indexedRows first) (by assumption)
        have initial : first.below (tableValues (makeValues first)) := by
          intro key
          change MaskLE ((first.lookup key).getD 0) ((makeValues first)[key]?.getD 0)
          rw [makeValues_get]
          exact maskLE_refl _
        have bound := sweep_agrees blocks entry entryMask all _ _ _
          ⟨makeValues first, 0, 0⟩ result first descending initial (by simpa only [sweep] using h)
        have stable := worklist_converged blocks entry entryMask all first result.val descending bound
          fixed (Rows.belowCheck_sound _ _ upper)
        exact solve_of_converged _ _ _ _ _ fixed stable enough
      · exact fallback _ _
    · exact fallback _ _
  · exact fallback _ _

private def oraclePacked (names : List String) (entry : String) (preds : String → List String)
    (fuel : Nat) : Except String (NameIndex.Membership (String × String)) := do
  let entryMask := encode names [entry]
  let all := pack (fun _ => true) names
  let final ← packedSolve (packedBlocks names preds) entry entryMask all fuel
    (packedInitial names entry entryMask all)
  pure (readPacked names final)

@[csimp] theorem oracle_eq_packed : oracle = oraclePacked := by
  funext names entry preds fuel
  unfold oracle oraclePacked packedSolve
  dsimp only
  rw [packedInitial_eq, solve_packed_eq _ _ _ _ _ (initial_canonical _ _)]
  cases h : solve (listStep names entry preds) fuel (initial names entry) with
  | error => rfl
  | ok rows =>
    change Except.ok _ = Except.ok (readPacked names (encodeRows names rows))
    rw [readPacked_eq _ _ _ (solve_canonical _ _ _ _ _ _ h)]

private def oracleCountedPacked (names : List String) (entry : String) (preds : String → List String)
    (fuel : Nat) : Except String (NameIndex.Membership (String × String) × Nat) := do
  let entryMask := encode names [entry]
  let all := pack (fun _ => true) names
  let (final, work) ← packedSolveWithWork (packedBlocks names preds) entry entryMask all fuel
    (packedInitial names entry entryMask all)
  pure (readPacked names final, work)

private theorem oracleCountedPacked_result (names : List String) (entry : String)
    (preds : String → List String) (fuel : Nat) :
    (oracleCountedPacked names entry preds fuel).map Prod.fst = oracle names entry preds fuel := by
  rw [oracle_eq_packed]
  unfold oracleCountedPacked oraclePacked
  rw [packedSolve_eq_worklist]
  unfold packedSolveWorklist
  dsimp only
  cases packedSolveWithWork (packedBlocks names preds) entry (encode names [entry])
    (pack (fun _ => true) names) fuel
    (packedInitial names entry (encode names [entry]) (pack (fun _ => true) names)) <;> rfl

/-- Count row visits and predecessor probes, including work before a fallback.
    The result component reduces through the reference oracle in proofs. -/
def oracleWithWork (names : List String) (entry : String) (preds : String → List String)
    (fuel : Nat) : Except String (NameIndex.Membership (String × String) × Nat) :=
  (oracle names entry preds fuel).map fun members =>
    let work := ((oracleCountedPacked names entry preds fuel).toOption.map Prod.snd).getD 0
    (members, work)

@[csimp] theorem oracleWithWork_eq_countedPacked : oracleWithWork = oracleCountedPacked := by
  funext names entry preds fuel
  unfold oracleWithWork
  rw [← oracleCountedPacked_result]
  cases oracleCountedPacked names entry preds fuel with
  | error => rfl
  | ok result => cases result; rfl

theorem oracleWithWork_result (names : List String) (entry : String)
    (preds : String → List String) (fuel : Nat) :
    (oracleWithWork names entry preds fuel).map Prod.fst = oracle names entry preds fuel := by
  rw [oracleWithWork_eq_countedPacked, oracleCountedPacked_result]

end LeanCompilerBackend.BoundedDominance
