/-
  Admission and dominance checks for the QBE SSA subset.
  References: QBE 1.3 parse.c, cfg.c, ssa.c and doc/il.txt.
  This implements only the currently admitted subset, not QBE's full SSA
  construction or complete type system. See docs/UPSTREAM.md.
-/
import LeanCompilerBackend.Aggregate
import LeanCompilerBackend.CFG
import LeanCompilerBackend.BoundedDominance
import LeanCompilerBackend.Section

namespace LeanCompilerBackend

private def validName := validIdentifier

private def predecessors (f : Function) (label : String) : List String :=
  f.blocks.toList.filterMap fun block =>
    if block.terminator.successors.contains label then some block.label else none

structure PredecessorLookup where
  get : String → List String

def predecessorLookup (f : Function) : PredecessorLookup :=
  ⟨predecessors f⟩

private abbrev PredecessorIndex := Std.TreeMap String (List String)

private def addPredecessor (index : PredecessorIndex) (source target : String) :
    PredecessorIndex :=
  index.insert target (source :: index[target]?.getD [])

private def addPredecessors (block : Block) (index : PredecessorIndex) :
    PredecessorIndex :=
  match block.terminator with
  | .jump target => addPredecessor index block.label target
  | .branch _ yes no =>
    let next := addPredecessor index block.label yes
    if yes == no then next else addPredecessor next block.label no
  | _ => index

private theorem addPredecessor_get (index : PredecessorIndex) (source target name : String) :
    (addPredecessor index source target)[name]?.getD [] =
      if target = name then source :: index[name]?.getD [] else index[name]?.getD [] := by
  by_cases h : target = name <;> simp [addPredecessor, Std.TreeMap.getElem?_insert, h]

private theorem addPredecessors_get (block : Block) (index : PredecessorIndex) (name : String) :
    (addPredecessors block index)[name]?.getD [] =
      if block.terminator.successors.contains name then block.label :: index[name]?.getD []
      else index[name]?.getD [] := by
  cases block with
  | mk label phis instructions terminator locations =>
    cases terminator with
    | ret | halt => rfl
    | jump target =>
      by_cases h : target = name
      · simp [addPredecessors, addPredecessor_get, Terminator.successors, h]
      · simp [addPredecessors, addPredecessor_get, Terminator.successors, h, Ne.symm h]
    | branch cond yes no =>
      by_cases same : yes = no
      · subst no
        by_cases h : yes = name
        · simp [addPredecessors, addPredecessor_get, Terminator.successors, h]
        · simp [addPredecessors, addPredecessor_get, Terminator.successors, h, Ne.symm h]
      · by_cases hy : yes = name <;> by_cases hn : no = name
        · exact (same (hy.trans hn.symm)).elim
        · simp [addPredecessors, addPredecessor_get, Terminator.successors, hy, hn, Ne.symm hn]
        · simp [addPredecessors, addPredecessor_get, Terminator.successors, hy, hn]
        · simp [addPredecessors, addPredecessor_get, Terminator.successors,
            same, hy, hn, Ne.symm hy, Ne.symm hn]

private theorem predecessors_fold (blocks : List Block) (name : String) :
    (blocks.foldr addPredecessors {})[name]?.getD [] =
      blocks.filterMap (fun block =>
        if block.terminator.successors.contains name then some block.label else none) := by
  induction blocks with
  | nil => simp
  | cons block rest ih =>
    simp only [List.foldr_cons, addPredecessors_get, ih, List.filterMap_cons]
    split <;> rfl

private def predecessorLookupIndexed (f : Function) : PredecessorLookup :=
  let index := f.blocks.toList.foldr addPredecessors {}
  ⟨fun name => index[name]?.getD []⟩

@[csimp] theorem predecessorLookup_eq_indexed :
    predecessorLookup = predecessorLookupIndexed := by
  funext f
  apply congrArg PredecessorLookup.mk
  funext name
  exact (predecessors_fold f.blocks.toList name).symm

private def compatibilityDominance (graph : CFG.Graph) : Except String (String → String → Bool) :=
  (CFG.dominators graph).map CFG.Dominators.contains

-- This checks the entire fallible solver call, including its error result.
private theorem compatibilityDominance_eq (graph : CFG.Graph) :
    compatibilityDominance graph = (CFG.dominators graph).map CFG.Dominators.contains := rfl

private structure Definition where
  name : String
  width : Width
  block : Option String
  position : Nat
  floating : Bool := false

private def addDefinition (find : δ → String → Option Definition) (insert : δ → Definition → δ)
    (definitions : δ) (definition : Definition) : Except String δ :=
  if !validName definition.name then .error "unsupported temporary/parameter name"
  else if (find definitions definition.name).isSome then
    .error s!"duplicate SSA definition or duplicate parameter %{definition.name}"
  else .ok (insert definitions definition)

private def parameterDefinition (parameter : Parameter) : Definition :=
  { name := parameter.name, width := parameter.width, floating := parameter.floating
    block := none, position := 0 }

private def phiDefinition (block : Block) (phi : Phi) : Definition :=
  { name := phi.destination, width := phi.width, floating := phi.floating
    block := some block.label, position := 0 }

private def statementDefinition (block : Block) (item : Statement × Nat) : Option Definition :=
  let (statement, i) := item
  statement.definition.map fun (name, width) =>
    { name, width, floating := match statement with | .assign inst => inst.floating | _ => false
      block := some block.label, position := i + 1 }

private def blockDefinitions (block : Block) : Array Definition :=
  block.phis.map (phiDefinition block) ++ block.instructions.zipIdx.filterMap (statementDefinition block)

private def declarations (f : Function) : Array Definition :=
  f.parameters.map parameterDefinition ++ f.blocks.flatMap blockDefinitions

private theorem instructionIndices_eq (instructions : Array Statement) :
    ((Array.range instructions.size).map fun i => (instructions[i]!, i)) =
      instructions.zipIdx := by
  apply Array.ext
  · simp
  · intro i hi hj
    have inside : i < instructions.size := by simpa using hi
    simp [getElem!_pos, inside]

-- The original collection order: parameters, then each block's phis and
-- instruction definitions. A failed insertion stops the enclosing traversal.
private def collectInOrder (add : δ → Definition → Except String δ)
    (f : Function) (initial : δ) : Except String δ := do
  let entries ← f.parameters.foldlM (fun es parameter => add es (parameterDefinition parameter)) initial
  f.blocks.foldlM (fun entries block => do
    let entries ← block.phis.foldlM (fun es phi => add es (phiDefinition block phi)) entries
    ((Array.range block.instructions.size).map fun i => (block.instructions[i]!, i)).foldlM (fun es item =>
      match statementDefinition block item with
      | some defn => add es defn
      | none => pure es) entries) entries

private theorem collectInOrder_eq (add : δ → Definition → Except String δ)
    (f : Function) (initial : δ) :
    collectInOrder add f initial = (declarations f).foldlM add initial := by
  have blocks_eq (blocks : List Block) (entries : δ) :
      blocks.foldlM (fun entries block => do
        let entries ← block.phis.toList.foldlM (fun es phi => add es (phiDefinition block phi)) entries
        block.instructions.zipIdx.toList.foldlM (fun es item =>
          match statementDefinition block item with
          | some defn => add es defn
          | none => pure es) entries) entries =
      (blocks.flatMap (fun block => (blockDefinitions block).toList)).foldlM add entries := by
    induction blocks generalizing entries with
    | nil => rfl
    | cons block rest ih =>
      simp only [List.foldlM_cons, List.flatMap_cons, List.foldlM_append, bind_assoc, ih]
      simp only [blockDefinitions, Array.toList_append, Array.toList_map, Array.toList_filterMap,
        List.foldlM_append, List.foldlM_map, List.foldlM_filterMap, bind_assoc]
      congr 1
      funext es
      congr 1
      apply congrArg (fun step => block.instructions.zipIdx.toList.foldlM step es)
      funext acc item
      cases statementDefinition block item <;> rfl
  simp only [collectInOrder, instructionIndices_eq, declarations, ← Array.foldlM_toList, Array.toList_append,
    Array.toList_map, Array.toList_flatMap, List.foldlM_append, List.foldlM_map, blocks_eq]

private def scanDefinition (entries : List Definition) (name : String) : Option Definition :=
  entries.find? (·.name == name)

private def consDefinition (entries : List Definition) (entry : Definition) : List Definition :=
  entry :: entries

private def collectReference (f : Function) : Except String (NameIndex.Lookup String Definition) := do
  let entries ← collectInOrder (addDefinition scanDefinition consDefinition) f []
  pure ⟨scanDefinition entries⟩

private abbrev DefinitionIndex := Std.TreeMap String Definition

private def indexDefinition (entries : DefinitionIndex) (name : String) : Option Definition :=
  entries[name]?

private def insertDefinition (entries : DefinitionIndex) (entry : Definition) : DefinitionIndex :=
  entries.insert entry.name entry

private def collectIndexed (f : Function) : Except String (NameIndex.Lookup String Definition) :=
  ((declarations f).foldlM (addDefinition indexDefinition insertDefinition) {}).map
    (fun index => ⟨indexDefinition index⟩)

private theorem collect_fold_eq (defs entries : List Definition) :
    (defs.foldlM (addDefinition indexDefinition insertDefinition)
      (NameIndex.build Definition.name entries)).map
        (fun index => (⟨indexDefinition index⟩ : NameIndex.Lookup String Definition)) =
    (defs.foldlM (addDefinition scanDefinition consDefinition) entries).map
        (fun entries => ⟨scanDefinition entries⟩) := by
  induction defs generalizing entries with
  | nil =>
    apply congrArg Except.ok
    apply congrArg NameIndex.Lookup.mk
    funext name
    exact NameIndex.build_get? Definition.name entries name
  | cons defn rest ih =>
    rw [List.foldlM_cons, List.foldlM_cons]
    simp only [addDefinition]
    rw [show indexDefinition (NameIndex.build Definition.name entries) defn.name =
        scanDefinition entries defn.name from NameIndex.build_get? _ _ _]
    by_cases invalid : (!validName defn.name) = true
    · simp only [ite_eq_left invalid]
      rfl
    · simp only [ite_eq_right invalid]
      by_cases duplicate : (scanDefinition entries defn.name).isSome = true
      · simp only [ite_eq_left duplicate]
        rfl
      · simp only [ite_eq_right duplicate]
        exact ih (defn :: entries)

@[csimp] theorem collectReference_eq_indexed : collectReference = collectIndexed := by
  funext f
  have h := collect_fold_eq (declarations f).toList []
  rw [← List.foldlM_toArray, ← List.foldlM_toArray, Array.toArray_toList] at h
  unfold collectReference collectIndexed
  rw [collectInOrder_eq]
  exact h.symm

private def collectCompatibility (f : Function) : Except String (NameIndex.Lookup String Definition) := do
  let definitions ← (declarations f).foldlM
    (addDefinition (fun (entries : Std.HashMap String Definition) name => entries[name]?)
      (fun entries entry => entries.insert entry.name entry)) {}
  pure ⟨fun name => definitions[name]?⟩

private def checkOperand (definitions : NameIndex.Lookup String Definition) (dominates : String → String → Bool)
    (useBlock : String) (position : Nat) (width : Width) (operand : Operand) (floating : Bool := false)
    : Except String Unit := do
  match operand with
  | .constant _ => pure ()
  | .symbol name | .threadSymbol name =>
    if floating then throw "symbol address cannot have floating type"
    if !validGlobalName name then throw "unsupported symbol name"
  | .temporary name =>
    let some definition := definitions.get name
      | throw s!"undefined temporary %{name}"
    if definition.floating != floating then throw s!"%{name}: integer/floating type mismatch; use cast"
    if floating && definition.width != width then throw s!"%{name}: floating precision mismatch"
    if definition.width == .word && width == .long then
      throw s!"%{name}: implicit w-to-l extension is unsupported; use an explicit conversion"
    match definition.block with
    | none => pure ()
    | some block =>
      if block == useBlock then
        if definition.position >= position then throw s!"%{name}: definition does not precede use"
      else if !dominates useBlock block then
        throw s!"%{name}: definition in @{block} does not dominate use in @{useBlock}"

private def checkSubword (width : Width) (floating : Bool) (subword : Option Subword) : Except String Unit := do
  if subword.isSome && (width != .word || floating) then throw "subword ABI class requires integer word storage"

private def checkAggregate (width : Width) (floating : Bool) (subword : Option Subword)
    (aggregate : Option String) : Except String Unit := do
  if aggregate.isSome && (width != .long || floating || subword.isSome) then
    throw "aggregate ABI class requires integer long pointer storage"

private def checkCallArguments (check : Width → Operand → Except String Unit)
    (checkFloat : Width → Operand → Except String Unit)
    (target : CallTarget) (arguments : Array CallArgument) : Except String Unit := do
  match target with
  | .direct name => if !validGlobalName name then throw "unsupported direct call target"
  | .indirect address => check .long address
  if arguments.size > maxIntegerArguments then
    throw s!"call exceeds the {maxIntegerArguments}-integer-argument resource limit"
  let mut seenVariadic := false
  for i in [:arguments.size] do
    let argument := arguments[i]!
    checkSubword argument.width argument.floating argument.subword
    checkAggregate argument.width argument.floating argument.subword argument.aggregate
    if argument.environment && (i != 0 || argument.variadic || argument.width != .long || argument.floating || argument.subword.isSome || argument.aggregate.isSome) then
      throw "environment argument must be first, named and long"
    if seenVariadic && !argument.variadic then throw "fixed argument follows variadic argument"
    seenVariadic := seenVariadic || argument.variadic
    (if argument.floating then checkFloat else check) argument.width argument.value

private def checkSection := Section.checkAny

@[noinline] private def validationBlockLookup (blocks : Array Block) (graph : Option CFG.Graph) :
    NameIndex.Lookup String Block :=
  match graph with
  | some graph => ⟨fun label => (graph.indices[label]?).bind (fun i => blocks[i]?)⟩
  | none => NameIndex.first Block.label blocks

private def validateFunctionGraphUsing
    (collect : Function → Except String (NameIndex.Lookup String Definition))
    (f : Function) (scalable : Bool) : Except String (Option CFG.Graph) := do
  checkSection f.customSection
  if f.debugFile.any (·.contains '\x00') then throw "debug filename must not contain NUL"
  for block in f.blocks do
    let mut previous := 0
    for location in block.debugLocations do
      if f.debugFile.isNone then throw "debug location requires a filename"
      if location.instruction < previous || location.instruction > block.instructions.size then
        throw "debug location instruction index is invalid"
      if location.line >= 2^29 || location.column >= 2^29 then throw "debug location exceeds 29-bit QBE limit"
      previous := location.instruction
  if f.resultAggregate.isSome && f.resultWidth.isNone then throw "void result cannot have aggregate type"
  if let some width := f.resultWidth then checkAggregate width f.resultFloating f.resultSubword f.resultAggregate
  if f.resultSubword.isSome && f.resultWidth.isNone then throw "void result cannot have subword type"
  if let some width := f.resultWidth then checkSubword width f.resultFloating f.resultSubword
  if f.resultFloating && f.resultWidth.isNone then throw "void result cannot have floating type"
  if !validGlobalName f.name then throw "unsupported function name"
  if f.parameters.size > maxIntegerArguments then
    throw s!"function exceeds the {maxIntegerArguments}-integer-parameter resource limit"
  for i in [:f.parameters.size] do
    checkAggregate f.parameters[i]!.width f.parameters[i]!.floating f.parameters[i]!.subword f.parameters[i]!.aggregate
    checkSubword f.parameters[i]!.width f.parameters[i]!.floating f.parameters[i]!.subword
    if f.parameters[i]!.environment && (i != 0 || f.parameters[i]!.width != .long || f.parameters[i]!.floating || f.parameters[i]!.subword.isSome || f.parameters[i]!.aggregate.isSome) then
      throw "environment parameter must be first and long"
  if f.blocks.isEmpty then throw "function has no entry block"
  let blockLimit := if scalable then maxCompatibilityBlocks else 64
  if f.blocks.size > blockLimit then throw s!"function exceeds {blockLimit}-block limit"
  let count := f.blocks.foldl (fun n block => n + block.instructions.size + block.phis.size) 0
  let instructionLimit := if scalable then maxCompatibilityInstructions else 480
  if count > instructionLimit then throw s!"function exceeds {instructionLimit}-instruction/phi limit"
  let names := f.blocks.toList.map (·.label)
  if names.any (!validName ·) then throw "unsupported block name"
  -- The scalable path builds the indexed CFG here: `CFG.build` makes the same
  -- duplicate-label, unknown-target and entry-target checks, in the same order and
  -- with the same messages, without the quadratic list scans below.
  let graph ← if scalable then some <$> CFG.build f else pure none
  if !scalable then
    if (NameIndex.dedup names).length != names.length then throw "duplicate block label"
    let known := NameIndex.members names
    let entry := f.blocks[0]!.label
    for block in f.blocks do
      for target in block.terminator.successors do
        if !known.contains target then throw s!"unknown block @{target}"
        if target == entry then throw "QBE entry block must not be a jump target"
  let definitions ← if scalable then collectCompatibility f else collect f
  let predsByName := if scalable then ⟨fun _ => []⟩ else predecessorLookup f
  let doms ← match graph with
    | some graph => compatibilityDominance graph
    | none => (fun members useBlock definitionBlock => members.contains (useBlock, definitionBlock)) <$> (BoundedDominance.oracle names f.blocks[0]!.label
        predsByName.get (f.blocks.size * f.blocks.size + 1))
  let blockByName := if f.blocks.all (·.phis.isEmpty) then ⟨fun _ => none⟩
    else validationBlockLookup f.blocks graph
  for block in f.blocks do
    if !block.phis.isEmpty then
      let preds := match graph with
        | some graph =>
          let blockIndex := (graph.indices[block.label]?).getD 0
          graph.predecessors[blockIndex]!.toList.map (fun (index : Nat) => (f.blocks[index]! : Block).label)
        | none => predsByName.get block.label
      let predSet := NameIndex.members preds
      for phi in block.phis do
        let incoming := phi.incoming.toList.map (·.1)
        if incoming.isEmpty || (NameIndex.dedup incoming).length != incoming.length
            || incoming.length != preds.length || !incoming.all predSet.contains then
          throw s!"phi %{phi.destination}: incoming labels must match block predecessors exactly"
        for (label, value) in phi.incoming do
          let some pred := blockByName.get label
            | throw s!"unknown phi predecessor @{label}"
          checkOperand definitions doms label (pred.instructions.size + 1) phi.width value phi.floating
    for i in [:block.instructions.size] do
      let check := fun width value => checkOperand definitions doms block.label (i + 1) width value false
      let checkFloat := fun width value => checkOperand definitions doms block.label (i + 1) width value true
      match block.instructions[i]! with
      | .storeFloat width value address =>
        checkFloat width value
        check .long address
      | .store width value address =>
        check width.valueWidth value
        check .long address
      | .callVoid target arguments _ => checkCallArguments check checkFloat target arguments
      | .vaStart list =>
        if !f.variadic then throw "vastart requires a variadic function"
        check .long list
      | .blit source destination bytes =>
        check .long source
        check .long destination
        if bytes > 1024 * 1024 then throw "blit byte count exceeds the 1 MiB resource limit"
      | .assign inst =>
        checkAggregate inst.width inst.floating inst.callSubword inst.callAggregate
        if inst.callAggregate.isSome then
          match inst.operation with
          | .call .. => pure ()
          | _ => throw "aggregate result type is only valid for calls"
        checkSubword inst.width inst.floating inst.callSubword
        if inst.callSubword.isSome then
          match inst.operation with
          | .call .. => pure ()
          | _ => throw "subword result type is only valid for calls"
        let floatingOperation := match inst.operation with
          | .convert .. | .copy .. | .cast .. | .load .plain _ | .floatBinary .. | .floatNegate .. | .call .. | .vaArg .. => true
          | _ => false
        if inst.floating && !floatingOperation then throw "operation does not support a floating result"
        match inst.operation with
        | .convert op value =>
          if inst.floating != op.resultFloating then throw "conversion result has wrong integer/floating class"
          if op == .extendSingle && inst.width != .long then throw "exts requires a double result"
          if op == .truncateDouble && inst.width != .word then throw "truncd requires a single result"
          checkOperand definitions doms block.label (i + 1) op.inputWidth value op.inputFloating
        | .floatBinary _ a b =>
          if !inst.floating then throw "floating arithmetic requires a floating result"
          checkFloat inst.width a
          checkFloat inst.width b
        | .floatNegate value =>
          if !inst.floating then throw "floating negation requires a floating result"
          checkFloat inst.width value
        | .floatCompare _ width a b =>
          checkFloat width a
          checkFloat width b
        | .cast value => checkOperand definitions doms block.label (i + 1) inst.width value (!inst.floating)
        | .copy value => checkOperand definitions doms block.label (i + 1) inst.width value inst.floating
        | .binary op a b =>
          check inst.width a
          check (op.rhsWidth inst.width) b
        | .unary op value =>
          if (op == .signedWord || op == .unsignedWord) && inst.width != .long then
            throw "extsw/extuw require a long result"
          check (op.inputWidth inst.width) value
        | .divide _ a b =>
          check inst.width a
          check inst.width b
        | .compare _ width a b =>
          check width a
          check width b
        | .load _ address => check .long address
        | .vaArg list => check .long list
        | .call target arguments _ =>
          checkCallArguments check checkFloat target arguments
        | .allocate _ size =>
          if inst.width != .long then throw "stack allocation requires a long result"
          match size with
          | .constant bytes =>
            let limit := if scalable then 1024 * 1024 else 4096
            if bytes < 0 || bytes > limit then
              throw s!"stack allocation currently requires a constant size in 0..{limit}"
          | .temporary _ | .symbol _ | .threadSymbol _ => check .long size
    let check := fun width value => checkOperand definitions doms block.label (block.instructions.size + 1) width value false
    match block.terminator with
    | .ret value =>
      match f.resultWidth, value with
      | some width, some value => checkOperand definitions doms block.label (block.instructions.size + 1) width value f.resultFloating
      | none, none => pure ()
      | some _, none =>
        if !scalable then throw "bare return in typed function is outside the first-path profile"
      | _, _ => throw "return value disagrees with function result type"
    | .branch value _ _ => check .word value
    | .jump _ | .halt => pure ()
  pure graph

/-- `validateFunction`, also returning the indexed CFG it builds on the scalable path. -/
def validateFunctionGraph (f : Function) (scalable : Bool := false) :
    Except String (Option CFG.Graph) :=
  validateFunctionGraphUsing collectReference f scalable

/-- Replacing the original declaration loops preserves the entire validation result. -/
theorem validateFunctionGraph_eq_indexedDeclarations (f : Function) (scalable : Bool) :
    validateFunctionGraph f scalable = validateFunctionGraphUsing collectIndexed f scalable :=
  congrArg (fun collect => validateFunctionGraphUsing collect f scalable) collectReference_eq_indexed

def validateFunction (f : Function) (scalable : Bool := false) : Except String Unit := do
  discard (validateFunctionGraph f scalable)

/-- An omitted environment has no value. Conservatively require that the incoming
    parameter is absent from every operand, including phi edges and dead blocks. -/
def calleeForEnvironment (callee : Function) (suppliedEnvironment : Bool)
    : Except String Function := do
  let some parameter := callee.parameters[0]? | return callee
  if !parameter.environment || suppliedEnvironment then return callee
  let reads := fun operand => match operand with
    | .temporary name => name == parameter.name
    | _ => false
  let used := callee.blocks.any fun block =>
    block.phis.any (fun phi => phi.incoming.any (fun (_, value) => reads value)) ||
    block.instructions.any (fun statement => statement.operands.any reads) ||
    (match block.terminator with
      | .ret value => value.any reads
      | .branch value _ _ => reads value
      | _ => false)
  if used then throw "missing environment argument: callee reads its environment parameter"
  -- Remove only the unused binding for signature checks/interpreter activation.
  -- Native emission retains the original definition and its ordinary ABI layout.
  return { callee with parameters := callee.parameters.extract 1 callee.parameters.size }

/-- QBE allows an extra ignored environment argument, and omission of an unused
    environment parameter. No dummy value is introduced for an omitted parameter. -/
def effectiveCallSignature (callee : Function) (arguments : Array CallArgument)
    : Except String (Function × Array CallArgument) := do
  let suppliedEnvironment := (arguments[0]?).any (·.environment)
  let callee ← calleeForEnvironment callee suppliedEnvironment
  if suppliedEnvironment && !((callee.parameters[0]?).any (·.environment)) then
    return (callee, arguments.extract 1 arguments.size)
  return (callee, arguments)

/-- Internal Apple ARM64 w results clear the upper half of x0, allowing a caller
    to consume the result as l. Used floating/subword/void signatures remain
    exact; effect-only calls may discard scalar results, never aggregates. -/
def callResultMatches (callee : Function) (width : Option Width) (floating : Bool)
    (subword : Option Subword) (aggregate : Option String := none) (aliases : Array (String × String) := #[]) : Bool :=
  -- An effect-only call may ignore any scalar return register. Aggregate
  -- returns can require caller-provided storage, so they remain exact.
  (width.isNone && !floating && subword.isNone && aggregate.isNone && callee.resultAggregate.isNone) ||
    (Aggregate.signatureMatches aliases aggregate callee.resultAggregate && floating == callee.resultFloating && subword == callee.resultSubword &&
      (width == callee.resultWidth ||
        (!floating && subword.isNone && aggregate.isNone && callee.resultWidth == some .word && width == some .long)))

def validate (program : Program) (aliases : Array (String × String) := #[]) : Except String Unit := do
  if program.isEmpty then throw "program contains no functions"
  if program.size > maxCompatibilityFunctions then throw s!"program exceeds {maxCompatibilityFunctions}-function limit"
  let mut definitions : Std.HashMap String Function := {}
  for f in program do
    if definitions.contains f.name then throw ("duplicate function $" ++ f.name)
    definitions := definitions.insert f.name f
    match validateFunction f true with
    | .ok () => pure ()
    | .error message => throw s!"function ${f.name}: {message}"
  -- External symbols have no declaration in QBE IL. Their ABI is an explicit
  -- link-time assumption; check exact signatures when the definition is present.
  for f in program do
    for block in f.blocks do
      for statement in block.instructions do
        if let some (.direct target, arguments, resultWidth) := statement.callSite then
          if let some callee := definitions[target]? then
            let (callee, arguments) ← effectiveCallSignature callee arguments
            if !callResultMatches callee resultWidth statement.resultFloating statement.resultSubword statement.resultAggregate aliases then
              throw s!"call ${target}: result type disagrees with its definition"
            let fixed := (arguments.findIdx? (·.variadic)).getD arguments.size
            if fixed != callee.parameters.size || (!callee.variadic && arguments.size != fixed) then
              throw s!"call ${target}: argument count/variadic boundary disagrees with its definition"
            for i in [:callee.parameters.size] do
              if arguments[i]!.width != callee.parameters[i]!.width || arguments[i]!.floating != callee.parameters[i]!.floating || arguments[i]!.subword != callee.parameters[i]!.subword || !Aggregate.signatureMatches aliases arguments[i]!.aggregate callee.parameters[i]!.aggregate then
                throw s!"call ${target}: argument type disagrees with its definition"

def validateModule (module : Module) : Except String Unit := do
  discard (Aggregate.layouts module.types)
  let checkType := fun name => do
    if let some name := name then
      if !(module.types.any (·.name == name)) then throw s!"undefined aggregate type :{name}"
  for f in module.functions do
    checkType f.resultAggregate
    for parameter in f.parameters do checkType parameter.aggregate
    for block in f.blocks do
      for statement in block.instructions do
        checkType statement.resultAggregate
        if let some (_, arguments, _) := statement.callSite then
          for argument in arguments do checkType argument.aggregate
  if module.functions.isEmpty && module.data.isEmpty && module.types.isEmpty then
    throw "module contains no definitions"
  if !module.functions.isEmpty then validate module.functions (Aggregate.signatureAliases module.types)
  if module.data.size > maxCompatibilityDataDefinitions then
    throw s!"module exceeds the {maxCompatibilityDataDefinitions}-data-definition resource limit"
  let mut names := module.functions.toList.map (·.name)
  let mut total := 0
  for data in module.data do
    if !validGlobalName data.name then throw "unsupported data symbol name"
    if names.contains data.name then throw s!"duplicate module symbol ${data.name}"
    names := data.name :: names
    Section.checkDataAny data.threadLocal data.customSection
    if data.threadLocal && data.common then
      throw "thread data cannot have common linkage"
    if data.common then
      if data.customSection.isSome then throw "common data cannot have custom section"
      if !data.items.all (fun item => match item with | .zeroes _ => true | _ => false) then
        throw "common data requires only zero-fill initializers"
    if data.alignment == 0 || data.alignment > 64 ||
        (data.alignment &&& (data.alignment - 1)) != 0 then
      throw "data alignment must be a power of two in 1..64"
    total := total + data.byteSize
    if total > 256 * 1024 * 1024 then throw "module data exceeds the 256 MiB resource limit"
    for item in data.items do
      if let .address _ name _ := item then
        if !validGlobalName name then throw "unsupported data relocation symbol"
        if module.data.any (fun d => d.name == name && d.threadLocal) then
          throw "thread-local address cannot be a static data initializer"
  for data in module.data do
    if data.threadLocal && names.contains (data.name ++ "$tlv$init") then
      throw "TLS initializer symbol conflicts with a module symbol"
  let checkSymbol := fun operand => do
    let tagged ← match operand with
      | .symbol name => pure (some (name, false))
      | .threadSymbol name => pure (some (name, true))
      | _ => pure none
    if let some (name, threadLocal) := tagged then
      if threadLocal && module.functions.any (·.name == name) then throw "thread symbol names a function"
      if let some data := module.data.find? (·.name == name) then
        if data.threadLocal != threadLocal then throw s!"symbol ${name}: thread-local access annotation mismatch"
  for f in module.functions do
    for block in f.blocks do
      for phi in block.phis do
        for (_, value) in phi.incoming do checkSymbol value
      let finalOperands := match block.terminator with
        | .ret value => value.toList | .branch value _ _ => [value] | _ => []
      for value in finalOperands do checkSymbol value
      for statement in block.instructions do
        for value in statement.operands do checkSymbol value
        if let some (.direct target, _, _) := statement.callSite then
          if module.data.any (·.name == target) then
            throw s!"call ${target}: symbol is defined as data"

end LeanCompilerBackend
