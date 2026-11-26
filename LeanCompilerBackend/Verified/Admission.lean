/-
  Restricted profile admission and local numbering for F01.
  This is an executable, fail-closed importer, NOT a proved CheckedSSA checker.
-/
import LeanCompilerBackend.Validate
import LeanCompilerBackend.Verified.Source
import LeanCompilerBackend.Verified.Reachability

namespace LeanCompilerBackend.Verified

open scoped LeanCompilerBackend.NameIndex

inductive AdmissionError where
  | invalidInput (reason : String)
  | unsupported (feature : String)
  | resourceLimit (resource : String) (measured limit : Nat)
  deriving DecidableEq, Repr

private def limit (resource : String) (measured maximum : Nat) : Except AdmissionError Unit :=
  if measured > maximum then .error (.resourceLimit resource measured maximum) else .ok ()

private def valueId (ids : NameIndex.Lookup String Nat) (name : String)
    : Except AdmissionError Nat := do
  let some i := ids.get name
    | throw (.invalidInput s!"unknown temporary %{name}")
  pure i

private def blockId (ids : NameIndex.Lookup String Nat) (name : String) : Except AdmissionError Nat := do
  let some i := ids.get name
    | throw (.invalidInput s!"unknown block @{name}")
  pure i

private def operand (locals : Array (String × Width)) (ids : NameIndex.Lookup String Nat) (width : Width)
    : Operand → Except AdmissionError Source.Operand
  | .constant n => .ok (.literal (Source.Value.constant width n))
  | .threadSymbol _ => .error (.unsupported "thread-local symbol addresses")
  | .symbol _ => .error (.unsupported "global symbol addresses")
  | .temporary name => do
    let id ← valueId ids name
    let some (_, actual) := locals[id]? | throw (.invalidInput "missing local width")
    if actual != width then
      throw (.unsupported s!"implicit width conversion of %{name}; first profile requires exact widths")
    pure (.local id)

private def binary : Binary → Except AdmissionError Source.Binary
  | .add => .ok .add | .sub => .ok .sub | .mul => .ok .mul
  | .andBits => .ok .andBits | .orBits => .ok .orBits | .xorBits => .ok .xorBits
  | .shiftLeft => .ok .shiftLeft | .logicalRight => .ok .logicalRight
  | .arithmeticRight => .ok .arithmeticRight

private def division : Division → Source.Division
  | .unsignedDiv => .unsignedDiv | .unsignedRem => .unsignedRem
  | .signedDiv => .signedDiv | .signedRem => .signedRem

private def comparison : Comparison → Except AdmissionError Source.Comparison
  | .eq => .ok .eq | .unsignedLT => .ok .unsignedLT | .unsignedLE => .ok .unsignedLE
  | .signedLT => .ok .signedLT | .signedLE => .ok .signedLE
  | _ => .error (.unsupported "comparison other than eq/unsignedLT/unsignedLE/signedLT/signedLE")

private def instruction (locals : Array (String × Width)) (ids : NameIndex.Lookup String Nat) (inst : Instruction)
    : Except AdmissionError Source.Instruction := do
  if inst.floating then throw (.unsupported "floating values")
  let destination ← valueId ids inst.destination
  let op ← match inst.operation with
    | .copy value => Source.Operation.copy <$> operand locals ids inst.width value
    | .binary op lhs rhs => do
      pure (.binary (← binary op) (← operand locals ids inst.width lhs) (← operand locals ids inst.width rhs))
    | .compare op width lhs rhs => do
      if inst.width != .word then throw (.unsupported "non-word comparison result")
      pure (.compare (← comparison op) width (← operand locals ids width lhs) (← operand locals ids width rhs))
    | .convert .. | .floatBinary .. | .floatNegate .. | .floatCompare .. | .cast .. => throw (.unsupported "floating operations/casts")
    | .unary .. => throw (.unsupported "unary operations")
    | .divide op lhs rhs =>
      pure (.divide (division op) (← operand locals ids inst.width lhs) (← operand locals ids inst.width rhs))
    | .allocate .. => throw (.unsupported "source stack allocations")
    | .load .. => throw (.unsupported "source memory loads")
    | .vaArg .. => throw (.unsupported "variadic argument access")
    | .call .. => throw (.unsupported "calls")
  pure { destination, width := inst.width, operation := op }

private def reachableCount (f : Function) : Nat :=
  Reachability.count (f.blocks.toList.map fun block =>
    (block.label, block.terminator.successors)) f.blocks[0]!.label f.blocks.size

private abbrev Incoming := String × Operand

private structure IncomingOrder where
  select : Array Incoming → List Incoming

private def selectIn (labels : List String) (entries : Array Incoming) : List Incoming :=
  let values := NameIndex.first Prod.fst entries
  labels.filterMap fun label => (values.get label).map fun (_, value) => (label, value)

private def canonicalPreds (blocks : List Block) (target : String) : List String :=
  blocks.filterMap fun block =>
    if block.terminator.successors.contains target then some block.label else none

private theorem dedup_sublist (names : List String) : List.Sublist names.eraseDups names := by
  match names with
  | [] => exact .slnil
  | label :: rest =>
    rw [List.eraseDups_cons]
    exact .cons_cons _ ((dedup_sublist _).trans List.filter_sublist)
termination_by names.length
decreasing_by
  have := List.length_filter_le (p := fun b => !(b == label)) rest
  simp only [List.length_cons]
  omega

private theorem dedup_nodup (names : List String) : names.eraseDups.Nodup := by
  match names with
  | [] => simp
  | label :: rest =>
    rw [List.eraseDups_cons, List.nodup_cons]
    refine ⟨?_, dedup_nodup _⟩
    simp [List.mem_eraseDups]
termination_by names.length
decreasing_by
  have := List.length_filter_le (p := fun b => !(b == label)) rest
  simp only [List.length_cons]
  omega

private theorem pred_subset (blocks : List Block) (target : String) :
    canonicalPreds blocks target ⊆ blocks.map (·.label) := by
  intro label h
  obtain ⟨b, hb, hlabel⟩ := List.mem_filterMap.mp h
  split at hlabel
  · injection hlabel with he
    exact List.mem_map.mpr ⟨b, hb, he⟩
  · contradiction

private theorem canonicalPreds_cons (block : Block) (rest : List Block) (target : String) :
    canonicalPreds (block :: rest) target =
      if block.terminator.successors.contains target then
        block.label :: canonicalPreds rest target else canonicalPreds rest target := by
  unfold canonicalPreds
  rw [List.filterMap_cons]
  by_cases hit : block.terminator.successors.contains target = true
  · simp only [ite_eq_left hit]
  · simp only [ite_eq_right hit]

private theorem pred_filter (blocks : List Block) (target : String)
    (distinct : (blocks.map (·.label)).Nodup) (select : String → Option α)
    (absent : ∀ label ∈ blocks.map (·.label),
      label ∉ canonicalPreds blocks target → select label = none) :
    (canonicalPreds blocks target).filterMap select = (blocks.map (·.label)).filterMap select := by
  induction blocks with
  | nil => rfl
  | cons b rest ih =>
    simp only [List.map_cons, List.nodup_cons] at distinct
    by_cases hit : b.terminator.successors.contains target = true
    · have tail := ih distinct.2 (fun label hm hn =>
        absent label (by simp [hm]) (by
          have hne : label ≠ b.label := fun he => distinct.1 (he ▸ hm)
          simpa only [canonicalPreds_cons, ite_eq_left hit, List.mem_cons, hne, false_or] using hn))
      simp only [canonicalPreds_cons, ite_eq_left hit, List.map_cons, List.filterMap_cons, tail]
    · have hrest : canonicalPreds (b :: rest) target = canonicalPreds rest target := by
        simp only [canonicalPreds_cons, ite_eq_right hit]
      have hnot : b.label ∉ canonicalPreds rest target := fun h => distinct.1 (pred_subset _ _ h)
      have ht := ih distinct.2 (fun label hm hn => absent label (by simp [hm]) (hrest ▸ hn))
      rw [hrest, ht]
      simp [absent _ (by simp) (hrest ▸ hnot)]

private structure IncomingOrders where
  forTarget : String → IncomingOrder

private def incomingOrdersSpec (f : Function) : IncomingOrders :=
  ⟨fun _ => ⟨selectIn (f.blocks.toList.map (·.label))⟩⟩

@[noinline] private def selectKnown (all preds : List String) (known : NameIndex.Membership String) :
    IncomingOrder :=
  ⟨fun entries => selectIn
    (if entries.all (fun entry => known.contains entry.1) then preds else all) entries⟩

@[noinline] private def prepareOrders (all : List String) (preds : PredecessorLookup) :
    IncomingOrders :=
  ⟨fun target =>
    let ordered := preds.get target
    selectKnown all ordered (NameIndex.members ordered)⟩

private def incomingOrdersIndexed (f : Function) : IncomingOrders :=
  if f.blocks.all (·.phis.isEmpty) then incomingOrdersSpec f else
  let all := f.blocks.toList.map (·.label)
  if (NameIndex.dedup all).length = all.length then
    prepareOrders all (predecessorLookup f)
  else incomingOrdersSpec f

private def incomingOrders (f : Function) : IncomingOrders :=
  incomingOrdersIndexed f

theorem incomingOrders_eq_indexed : incomingOrders = incomingOrdersIndexed := rfl

theorem incomingOrders_eq_indexed_spec : incomingOrdersSpec = incomingOrdersIndexed := by
  funext f
  unfold incomingOrdersIndexed
  dsimp only
  simp only [NameIndex.dedup_eq_eraseDups]
  split
  · rfl
  split <;> rename_i same
  · have allDistinct : (f.blocks.toList.map (·.label)).Nodup := by
      have equal : List.eraseDups (f.blocks.toList.map (·.label)) = f.blocks.toList.map (·.label) :=
        (dedup_sublist _).eq_of_length same
      rw [← equal]
      exact dedup_nodup _
    apply congrArg IncomingOrders.mk
    funext target
    apply congrArg IncomingOrder.mk
    funext entries
    simp only [NameIndex.members_contains]
    rw [predecessorLookup_eq_indexed, ← predecessorLookup_eq_indexed_spec]
    change selectIn (f.blocks.toList.map (·.label)) entries =
      selectIn (if entries.all (fun entry => (canonicalPreds f.blocks.toList target).contains entry.1)
        then canonicalPreds f.blocks.toList target else f.blocks.toList.map (·.label)) entries
    split <;> rename_i known
    · symm
      apply pred_filter _ _ allDistinct
      intro label _ absent
      have no : entries.find? (fun entry => entry.1 == label) = none := by
        apply Array.find?_eq_none.mpr
        intro entry hm he
        have inPreds := (Array.all_eq_true_iff_forall_mem.mp known) entry hm
        exact absent (beq_iff_eq.mp he ▸ (List.contains_iff_mem.mp inPreds))
      simp [NameIndex.first_get, no]
    · rfl
  · rfl

private structure IncomingReader where
  read : Array Incoming → Array (String × Width) → NameIndex.Lookup String Nat →
    NameIndex.Lookup String Nat → Width → Except AdmissionError (Array (Nat × Source.Operand))

private structure IncomingReaders where
  forTarget : String → IncomingReader

private def lowerIncoming (locals : Array (String × Width))
    (ids blockIds : NameIndex.Lookup String Nat) (width : Width)
    (acc : Array (Nat × Source.Operand)) (incoming : Incoming) :
    Except AdmissionError (Array (Nat × Source.Operand)) := do
  let (pred, value) := incoming
  pure (acc.push (← blockId blockIds pred, ← operand locals ids width value))

-- Reference admission visits function blocks in order, resolving a selected
-- incoming operand immediately and stopping at the first error.
private def readIncomingReference (f : Function) : IncomingReaders :=
  ⟨fun _ => ⟨fun entries locals ids blockIds width =>
    f.blocks.foldlM (fun acc pred =>
      match entries.find? (·.1 == pred.label) with
      | some (_, value) => lowerIncoming locals ids blockIds width acc (pred.label, value)
      | none => pure acc) #[]⟩⟩

-- Passing the prepared values to separate functions keeps indexing outside
-- the per-phi call after compiler arity expansion and closure optimization.
@[noinline] private def readerUsing (order : IncomingOrder) : IncomingReader :=
  ⟨fun entries locals ids blockIds width =>
    (order.select entries).foldlM (lowerIncoming locals ids blockIds width) #[]⟩

@[noinline] private def readersUsing (orders : IncomingOrders) : IncomingReaders :=
  ⟨fun target => readerUsing (orders.forTarget target)⟩

private def readIncomingUsing (ordersFor : Function → IncomingOrders) (f : Function) :
    IncomingReaders :=
  readersUsing (ordersFor f)

private theorem readIncomingReference_eq_spec :
    readIncomingReference = readIncomingUsing incomingOrdersSpec := by
  funext f
  apply congrArg IncomingReaders.mk
  funext target
  apply congrArg IncomingReader.mk
  funext entries locals ids blockIds width
  simp only [incomingOrdersSpec, selectIn,
    NameIndex.first_get, List.foldlM_filterMap, List.foldlM_map, ← Array.foldlM_toList]
  apply congrArg (fun step => f.blocks.toList.foldlM step #[])
  funext acc pred
  cases entries.find? (fun entry => entry.1 == pred.label) with
  | none => simp
  | some pair => cases pair; simp

private theorem readIncomingReference_eq :
    readIncomingReference = readIncomingUsing incomingOrders := by
  rw [incomingOrders_eq_indexed, ← incomingOrders_eq_indexed_spec]
  exact readIncomingReference_eq_spec

@[inline] private def admitUsing (prepareIncoming : Function → IncomingReaders) (f : Function) :
    Except AdmissionError (Source.Function × Nat) := do
  if !validIdentifier f.name then throw (.unsupported "quoted global names")
  if f.customSection.isSome then throw (.unsupported "custom sections")
  if f.resultAggregate.isSome || f.parameters.any (·.aggregate.isSome) then throw (.unsupported "aggregate function signatures")
  if f.resultSubword.isSome || f.parameters.any (·.subword.isSome) then throw (.unsupported "subword function signatures")
  if f.resultFloating || f.parameters.any (·.floating) then throw (.unsupported "floating function signatures")
  if f.variadic then throw (.unsupported "variadic functions")
  if f.parameters.any (·.environment) then throw (.unsupported "environment parameters")
  limit "parameters" f.parameters.size 8
  limit "blocks" f.blocks.size 64
  let definitions := f.blocks.foldl (fun n b => n + b.phis.size + b.instructions.size) 0
  limit "definitions" definitions 480
  let some resultWidth := f.resultWidth | throw (.unsupported "void result")
  let work ← (validateFunctionWithWork f).mapError AdmissionError.invalidInput
  if !(f.blocks[0]!.phis.isEmpty) then throw (.invalidInput "entry phis")
  if reachableCount f != f.blocks.size then throw (.unsupported "unreachable blocks")
  let locals := f.locals
  let maxPhis := f.blocks.foldl (fun n block => max n block.phis.size) 0
  let frame := ((8 * (locals.size + maxPhis) + 15) / 16) * 16
  limit "frame bytes" frame 4080
  let ids := NameIndex.position Prod.fst locals
  let blockIds := NameIndex.position Block.label f.blocks
  let readIncoming := prepareIncoming f
  let mut blocks := #[]
  for block in f.blocks do
    let mut phis := #[]
    if !block.phis.isEmpty then
      let reader := readIncoming.forTarget block.label
      for phi in block.phis do
        if phi.floating then throw (.unsupported "floating phi values")
        -- Resolve in block order, independent of textual incoming-list order.
        let incoming ← reader.read phi.incoming locals ids blockIds phi.width
        let destination ← valueId ids phi.destination
        phis := phis.push ({ destination, width := phi.width, incoming } : Source.Phi)
    let mut instructions := #[]
    for statement in block.instructions do
      match statement with
      | .assign inst => instructions := instructions.push (← instruction locals ids inst)
      | .storeFloat .. => throw (.unsupported "floating stores")
      | .store .. => throw (.unsupported "source memory stores")
      | .callVoid .. => throw (.unsupported "calls")
      | .vaStart .. => throw (.unsupported "variadic argument access")
      | .blit .. => throw (.unsupported "source memory blits")
    let terminator ← match block.terminator with
      | .ret (some value) => Source.Terminator.ret <$> operand locals ids resultWidth value
      | .ret none => throw (.invalidInput "missing integer return")
      | .jump target => Source.Terminator.jump <$> blockId blockIds target
      | .branch condition yes no => do
        pure (.branch (← operand locals ids .word condition) (← blockId blockIds yes) (← blockId blockIds no))
      | .halt => throw (.unsupported "halt/traps")
    blocks := blocks.push ({ phis, instructions, terminator } : Source.Block)
  pure ({ resultWidth, parameters := f.parameters.map (·.width),
          valueWidths := locals.map (·.2), blocks }, work)

private def admitWithWorkSpec (f : Function) : Except AdmissionError (Source.Function × Nat) :=
  admitUsing readIncomingReference f

private def admitWithWorkIndexed (f : Function) : Except AdmissionError (Source.Function × Nat) :=
  admitUsing (readIncomingUsing incomingOrdersIndexed) f

/-- Import only the current first-path profile into raw locally numbered syntax. The result is
    not proof-carrying and must not satisfy a certification request. -/
def admitWithWork (f : Function) : Except AdmissionError (Source.Function × Nat) :=
  admitWithWorkIndexed f

theorem admitWithWork_eq_indexed : admitWithWork = admitWithWorkIndexed := rfl

theorem admitWithWork_eq_indexed_spec : admitWithWorkSpec = admitWithWorkIndexed := by
  funext f
  unfold admitWithWorkSpec admitWithWorkIndexed
  rw [readIncomingReference_eq_spec, incomingOrders_eq_indexed_spec]

def admit (f : Function) : Except AdmissionError Source.Function :=
  (admitWithWork f).map Prod.fst

private def admitIndexed (f : Function) : Except AdmissionError Source.Function :=
  (admitWithWorkIndexed f).map Prod.fst

/-- The effectful admission loop preserves the whole result, including the
    first error raised while resolving a predecessor or its operand. -/
theorem admit_eq_indexedIncoming : admit = admitIndexed := rfl

theorem admit_eq_indexedIncoming_spec :
    (fun f => (admitWithWorkSpec f).map Prod.fst) = admitIndexed := by
  funext f
  unfold admitIndexed
  rw [admitWithWork_eq_indexed_spec]

end LeanCompilerBackend.Verified
