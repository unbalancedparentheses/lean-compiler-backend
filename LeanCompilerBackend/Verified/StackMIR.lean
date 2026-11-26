/- Typed stack-baseline MIR and lowering. Structural checks are executable only;
   the preservation/checker-soundness proofs remain separate obligations. -/
import LeanCompilerBackend.Verified.Plans

namespace LeanCompilerBackend.Verified.StackMIR

inductive Register where
  | r0 | r9 | r10
  deriving DecidableEq, Repr

def Register.index : Register → Nat
  | .r0 => 0 | .r9 => 9 | .r10 => 10

inductive Slot where
  | value (id : Nat)
  | stage (id : Nat)
  deriving DecidableEq, Repr

inductive Label where
  | entry
  | body (block : Nat)
  | edge (predecessor target : Nat)
  deriving DecidableEq, Repr

private abbrev LabelKey := List Nat

private def Label.key : Label → LabelKey
  | .entry => [0]
  | .body block => [1, block]
  | .edge pred target => [2, pred, target]

private theorem Label.key_eq_iff (left right : Label) : left.key = right.key ↔ left = right := by
  cases left <;> cases right <;> simp [Label.key]

private def labelSetUsingSpec (labels : List Label) (duplicate : String) :
    Except String (NameIndex.Membership Label) := do
  let entries ← labels.foldlM (fun (seen : List Label) (label : Label) =>
    if seen.contains label then Except.error duplicate else Except.ok (label :: seen)) []
  pure ⟨entries.contains⟩

-- A separate constructor keeps the complete index outside the query closure.
@[noinline] private def keyedLabels (index : Std.TreeSet LabelKey) : NameIndex.Membership Label :=
  ⟨fun label => index.contains label.key⟩

private def labelSetIndexed (labels : List Label) (duplicate : String) :
    Except String (NameIndex.Membership Label) :=
  (labels.foldlM (fun (seen : Std.TreeSet LabelKey) (label : Label) =>
    if seen.contains label.key then Except.error duplicate else Except.ok (seen.insert label.key)) {}).map keyedLabels

private theorem labelFold_eq (labels seen : List Label) (index : Std.TreeSet LabelKey)
    (duplicate : String) (agrees : ∀ label : Label, index.contains label.key = seen.contains label) :
    (labels.foldlM (fun (seen : List Label) (label : Label) =>
      if seen.contains label then Except.error duplicate else Except.ok (label :: seen)) seen).map
        (fun entries => (⟨entries.contains⟩ : NameIndex.Membership Label)) =
      (labels.foldlM (fun (seen : Std.TreeSet LabelKey) (label : Label) =>
        if seen.contains label.key then Except.error duplicate else Except.ok (seen.insert label.key)) index).map
          keyedLabels := by
  induction labels generalizing seen index with
  | nil =>
    apply congrArg Except.ok
    apply congrArg NameIndex.Membership.mk
    funext label
    exact (agrees label).symm
  | cons label rest ih =>
    simp only [List.foldlM_cons, agrees label]
    split
    · rfl
    · apply ih
      intro query
      rw [Std.TreeSet.contains_insert, List.contains_cons, agrees query]
      by_cases h : label = query
      · subst query
        simp
      · have cmp : (compare label.key query.key == .eq) = false :=
          beq_eq_false_iff_ne.mpr (fun hc => h ((Label.key_eq_iff _ _).mp
            (Std.LawfulEqOrd.compare_eq_iff_eq.mp hc)))
        rw [cmp, beq_eq_false_iff_ne.mpr (Ne.symm h)]

private def labelSetUsing (labels : List Label) (duplicate : String) :
    Except String (NameIndex.Membership Label) :=
  labelSetIndexed labels duplicate

theorem labelSetUsing_eq_indexed : labelSetUsing = labelSetIndexed := rfl

theorem labelSetUsing_eq_indexed_spec : labelSetUsingSpec = labelSetIndexed := by
  funext labels duplicate
  exact labelFold_eq labels [] {} duplicate (by simp)

/-- Check label uniqueness before any target or instruction checks. -/
def labelSet (labels : Array Label) (duplicate : String) : Except String (NameIndex.Membership Label) :=
  labelSetUsing labels.toList duplicate

inductive Instruction where
  | enterFrame (bytes : Nat)
  | leaveFrame (bytes : Nat)
  | readArg (width : Width) (index : Nat) (slot : Slot)
  | constant (reg : Register) (value : Source.Value)
  | load (width : Width) (reg : Register) (slot : Slot)
  | store (width : Width) (slot : Slot) (reg : Register)
  | alu (width : Width) (op : Source.Binary) (dst lhs rhs : Register)
  | compare (width : Width) (op : Source.Comparison) (dst lhs rhs : Register)
  | divide (width : Width) (op : Source.Division) (dst lhs rhs : Register)
  deriving DecidableEq, Repr

inductive Terminator where
  | jump (label : Label)
  | branch (condition : Register) (yes no : Label)
  | ret (width : Width)
  deriving DecidableEq, Repr

structure Block where
  label : Label
  instructions : Array Instruction
  terminator : Terminator
  deriving DecidableEq, Repr

structure Function where
  parameters : Array Width
  resultWidth : Width
  valueWidths : Array Width
  layout : FrameLayout
  blocks : Array Block
  deriving DecidableEq, Repr

def loadOperand (width : Width) (reg : Register) : Source.Operand → Instruction
  | .local id => .load width reg (.value id)
  | .literal value => .constant reg value

def lowerInstruction (i : Source.Instruction) : Array Instruction := Id.run do
  let code := match i.operation with
    | .copy value => #[loadOperand i.width .r9 value]
    | .binary op lhs rhs => #[loadOperand i.width .r9 lhs, loadOperand i.width .r10 rhs,
        .alu i.width op .r9 .r9 .r10]
    | .compare op width lhs rhs => #[loadOperand width .r9 lhs, loadOperand width .r10 rhs,
        .compare width op .r9 .r9 .r10]
    -- The dividend goes to R0 so the result register R9 is distinct from both
    -- operands: a remainder then forms its quotient in R9 itself (see select).
    | .divide op lhs rhs => #[loadOperand i.width .r0 lhs, loadOperand i.width .r10 rhs,
        .divide i.width op .r9 .r0 .r10]
  return code.push (.store i.width (.value i.destination) .r9)

/-- Read every incoming value into its own staging slot before committing any
    destination. List recursion exposes the two phases for semantic proofs. -/
def stagePhis (pred index : Nat) : List Source.Phi → Except String (List Instruction)
  | [] => .ok []
  | phi :: rest => do
    let some (_, operand) := phi.incoming.find? (·.1 == pred) | throw "missing phi predecessor"
    let tail ← stagePhis pred (index+1) rest
    pure (loadOperand phi.width .r9 operand :: .store phi.width (.stage index) .r9 :: tail)

def commitPhis (index : Nat) : List Source.Phi → List Instruction
  | [] => []
  | phi :: rest => .load phi.width .r9 (.stage index) ::
      .store phi.width (.value phi.destination) .r9 :: commitPhis (index+1) rest

def lowerEdge (f : Source.Function) (pred target : Nat) : Except String Block := do
  let some block := f.blocks[target]? | throw "edge target is missing"
  let stages ← stagePhis pred 0 block.phis.toList
  pure { label := .edge pred target,
         instructions := (stages ++ commitPhis 0 block.phis.toList).toArray,
         terminator := .jump (.body target) }

private structure IndexedPhi where
  phi : Source.Phi
  incoming : NameIndex.Lookup Nat (Nat × Source.Operand)

private def indexPhi (phi : Source.Phi) : IndexedPhi :=
  ⟨phi, NameIndex.first Prod.fst phi.incoming⟩

private def stageIndexedPhis (pred index : Nat) : List IndexedPhi → Except String (List Instruction)
  | [] => .ok []
  | indexed :: rest => do
    let some (_, operand) := indexed.incoming.get pred | throw "missing phi predecessor"
    let tail ← stageIndexedPhis pred (index+1) rest
    pure (loadOperand indexed.phi.width .r9 operand :: .store indexed.phi.width (.stage index) .r9 :: tail)

private theorem stageIndexedPhis_eq (pred index : Nat) (phis : List Source.Phi) :
    stageIndexedPhis pred index (phis.map indexPhi) = stagePhis pred index phis := by
  induction phis generalizing index with
  | nil => rfl
  | cons phi rest ih =>
    simp only [List.map_cons, stageIndexedPhis, stagePhis, indexPhi, NameIndex.first_get, ih, eq_comm]
    rfl

private structure EdgeLowerer where
  lower : Nat → Nat → Except String Block

private def edgeLowerersSpec (source : Source.Function) : EdgeLowerer :=
  ⟨lowerEdge source⟩

private structure TargetPhis where
  indexed : List IndexedPhi
  commits : List Instruction

private def prepareTarget (block : Source.Block) : TargetPhis :=
  let phis := block.phis.toList
  ⟨phis.map indexPhi, commitPhis 0 phis⟩

private def lowerPreparedTarget (prepared : Array TargetPhis) (pred target : Nat) :
    Except String Block := do
  let some block := prepared[target]? | throw "edge target is missing"
  let stages ← stageIndexedPhis pred 0 block.indexed
  pure { label := .edge pred target, instructions := (stages ++ block.commits).toArray,
         terminator := .jump (.body target) }

private def edgeLowerersIndexed (source : Source.Function) : EdgeLowerer :=
  ⟨lowerPreparedTarget (source.blocks.map prepareTarget)⟩

private def edgeLowerers (source : Source.Function) : EdgeLowerer :=
  edgeLowerersIndexed source

theorem edgeLowerers_eq_indexed : edgeLowerers = edgeLowerersIndexed := rfl

theorem edgeLowerers_eq_indexed_spec : edgeLowerersSpec = edgeLowerersIndexed := by
  funext source
  apply congrArg EdgeLowerer.mk
  funext pred target
  unfold lowerEdge lowerPreparedTarget
  rw [Array.getElem?_map]
  cases source.blocks[target]? with
  | none => rfl
  | some block => simp [prepareTarget, stageIndexedPhis_eq]

/-- Layout is supplied explicitly, then checked against the source contract. -/
def lower (source : Source.Function) (layout : FrameLayout) : Except String Function := do
  match validateSource source with
  | .error e => throw s!"source admission: {repr e}"
  | .ok () => pure ()
  if layout != planFrame source then throw "frame layout mismatch"
  let mut entry := #[Instruction.enterFrame layout.frameBytes]
  for i in [:source.parameters.size] do
    let some width := source.parameters[i]? | throw "missing parameter"
    entry := entry.push (.readArg width i (.value i))
  let edges := edgeLowerers source
  let mut blocks := #[{ label := .entry, instructions := entry, terminator := .jump (.body 0) : Block }]
  for id in [:source.blocks.size] do
    let some block := source.blocks[id]? | throw "missing source block"
    let mut instructions := block.instructions.foldl (fun code i => code ++ lowerInstruction i) #[]
    let (terminator, successors) ← match block.terminator with
      | .ret value => do
        instructions := instructions ++ #[loadOperand source.resultWidth .r0 value, .leaveFrame layout.frameBytes]
        pure (Terminator.ret source.resultWidth, #[])
      | .jump target => pure (.jump (.edge id target), #[target])
      | .branch condition yes no => do
        instructions := instructions.push (loadOperand .word .r9 condition)
        pure (.branch .r9 (.edge id yes) (.edge id no), if yes == no then #[yes] else #[yes, no])
    blocks := blocks.push { label := .body id, instructions, terminator }
    for target in successors do blocks := blocks.push (← edges.lower id target)
  pure { parameters := source.parameters, resultWidth := source.resultWidth,
         valueWidths := source.valueWidths, layout, blocks }

def offset (f : Function) (slot : Slot) : Except String Nat :=
  match slot with
  | .value i => match f.layout.valueOffsets[i]? with | some offset => .ok offset | none => .error "value slot does not exist"
  | .stage i => match f.layout.stageOffsets[i]? with | some offset => .ok offset | none => .error "stage slot does not exist"

private def checkAccess (f : Function) (width : Width) (slot : Slot) : Except String Unit := do
  let o ← offset f slot
  if o % width.bytes != 0 || o + width.bytes > f.layout.frameBytes then throw "invalid frame access"
  if let .value id := slot then
    if f.valueWidths[id]? != some width then throw "value slot width mismatch"

private def stageReadsUsing (initial : σ) (write : σ → Nat → Width → σ)
    (read : σ → Nat → Width → Bool) (code : Array Instruction) : Array Bool :=
  (code.foldl (fun (state, checks) inst =>
    match inst with
    | .store width (.stage id) _ => (write state id width, checks.push true)
    | .load width _ (.stage id) => (state, checks.push (read state id width))
    | _ => (state, checks.push true)) (initial, #[])).2

private def writeStage (stages : Array (Nat × Width)) (id : Nat) (width : Width) :
    Array (Nat × Width) :=
  (stages.filter (·.1 != id)).push (id, width)

private def readStage (stages : Array (Nat × Width)) (id : Nat) (width : Width) : Bool :=
  stages.contains (id, width)

private def stageReadsSpec : Array Instruction → Array Bool :=
  stageReadsUsing #[] writeStage readStage

private def writeStageIndexed (stages : Std.TreeMap Nat Width) (id : Nat) (width : Width) :
    Std.TreeMap Nat Width :=
  stages.insert id width

private def readStageIndexed (stages : Std.TreeMap Nat Width) (id : Nat) (width : Width) : Bool :=
  stages[id]? == some width

private def stageReadsIndexed : Array Instruction → Array Bool :=
  stageReadsUsing {} writeStageIndexed readStageIndexed

private theorem readStage_write (stages : Array (Nat × Width)) (written id : Nat) (new width : Width) :
    readStage (writeStage stages written new) id width =
      if written = id then new == width else readStage stages id width := by
  have hl : ∀ a b : Width, (a == b) = decide (a = b) := by intro a b; cases a <;> cases b <;> rfl
  letI : LawfulBEq Width :=
    { eq_of_beq := fun h => by simpa only [hl, decide_eq_true_eq] using h
      rfl := by intro; simp [hl] }
  apply Bool.eq_iff_iff.mpr
  by_cases h : written = id
  · subst written
    simp [readStage, writeStage, Array.mem_push, hl, eq_comm]
  · simp [readStage, writeStage, Array.mem_push, h, Ne.symm h]

private theorem readStageIndexed_write (stages : Std.TreeMap Nat Width)
    (written id : Nat) (new width : Width) :
    readStageIndexed (writeStageIndexed stages written new) id width =
      if written = id then new == width else readStageIndexed stages id width := by
  by_cases h : written = id <;>
    simp [readStageIndexed, writeStageIndexed, Std.TreeMap.getElem?_insert, h]

private def stageReads : Array Instruction → Array Bool :=
  stageReadsIndexed

theorem stageReads_eq_indexed : stageReads = stageReadsIndexed := rfl

theorem stageReads_eq_indexed_spec : stageReadsSpec = stageReadsIndexed := by
  funext code
  let relation (old : Array (Nat × Width) × Array Bool)
      (new : Std.TreeMap Nat Width × Array Bool) :=
    old.2 = new.2 ∧ ∀ id width, readStage old.1 id width = readStageIndexed new.1 id width
  unfold stageReadsSpec stageReadsIndexed stageReadsUsing
  apply And.left (a := _)
  apply Array.foldl_rel (r := relation)
  · exact ⟨rfl, fun id width => by simp [readStage, readStageIndexed]⟩
  · intro inst _ old new h
    rcases h with ⟨checks, reads⟩
    cases inst with
    | store width slot reg =>
      cases slot <;> simp [relation, checks, reads, readStage_write, readStageIndexed_write]
    | load width reg slot =>
      cases slot <;> simp [relation, checks, reads]
    | _ => simp [relation, checks, reads]

/-- Structural legality, including per-edge stage initialization and frame phase.
    It does not prove that a selected source value is the right value. -/
def validate (f : Function) : Except String Unit := do
  if f.parameters.size > 8 || f.blocks.isEmpty || f.layout.frameBytes > 4080 ||
      f.layout.frameBytes % 16 != 0 then throw "invalid MIR signature/frame"
  let n := f.valueWidths.size
  if f.layout.version != 1 || f.layout.valueOffsets != (Array.range n).map (8 * ·) ||
      f.layout.stageOffsets != (Array.range f.layout.stageOffsets.size).map (fun i => 8 * (n+i)) ||
      f.layout.frameBytes != ((8 * (n + f.layout.stageOffsets.size) + 15) / 16) * 16 then
    throw "MIR frame regions overlap or differ from canonical layout"
  if (f.blocks[0]?).map (·.label) != some .entry then throw "entry must be first"
  let labels ← labelSet (f.blocks.map (·.label)) "duplicate MIR label"
  for block in f.blocks do
    let mut active := block.label != .entry
    let mut entered := false
    let mut left := false
    let reads := stageReads block.instructions
    let mut arguments : Array Nat := #[]
    for index in [:block.instructions.size] do
      let some inst := block.instructions[index]? | throw "missing MIR instruction"
      if left then throw "instruction after frame leave"
      match inst with
      | .enterFrame bytes =>
        if block.label != .entry || index != 0 || entered || bytes != f.layout.frameBytes then
          throw "invalid frame entry"
        active := true
        entered := true
      | .leaveFrame bytes =>
        if !active || block.label == .entry || bytes != f.layout.frameBytes then throw "invalid frame leave"
        active := false
        left := true
      | .readArg width arg slot =>
        if !active || block.label != .entry || f.parameters[arg]? != some width || slot != .value arg then
          throw "invalid incoming argument store"
        if arguments.contains arg then throw "duplicate incoming argument"
        arguments := arguments.push arg
        checkAccess f width slot
      | .load width _ slot =>
        if !active then throw "load outside frame lifetime"
        checkAccess f width slot
        if !reads[index]! then throw "stage read before same-width write"
      | .store width slot _ =>
        if !active then throw "store outside frame lifetime"
        checkAccess f width slot
        if let .stage _ := slot then
          if !(match block.label with | .edge .. => true | _ => false) then throw "stage write outside edge"
      | _ => if !active then throw "operation outside frame lifetime"
    if block.label == .entry && (!entered || arguments.size != f.parameters.size) then
      throw "incomplete MIR prologue"
    let targets := match block.terminator with
      | .jump target => #[target]
      | .branch _ yes no => #[yes, no]
      | .ret _ => #[]
    for target in targets do
      if target == .entry || !labels.contains target then throw "invalid MIR branch target"
    match block.terminator with
    | .ret width => if !left || active || width != f.resultWidth then throw "invalid MIR return/frame state"
    | _ => if !active || left then throw "branch after frame teardown"

end LeanCompilerBackend.Verified.StackMIR
