/-
  Admission and dominance checks for the QBE SSA subset.
  References: QBE 1.3 parse.c, cfg.c, ssa.c and doc/il.txt.
  This implements only the currently admitted subset, not QBE's full SSA
  construction or complete type system. See docs/UPSTREAM.md.
-/
import LeanCompilerBackend.Aggregate
import LeanCompilerBackend.CFG

namespace LeanCompilerBackend

private def validName := validIdentifier

private def predecessors (f : Function) (label : String) : List String :=
  f.blocks.toList.filterMap fun block =>
    if block.terminator.successors.contains label then some block.label else none

private abbrev ReferenceDominators := List (String × List String)

/-- Finite-set iteration; unsupported/nonconverging cases fail closed. -/
private def referenceDominators (f : Function) : Except String ReferenceDominators := do
  let names := f.blocks.toList.map (·.label)
  let entry := f.blocks[0]!.label
  let initial := names.map fun name => (name, if name == entry then [entry] else names)
  let rec iterate : Nat → ReferenceDominators → Except String ReferenceDominators
    | 0, _ => .error "dominance iteration resource limit exceeded"
    | fuel + 1, old => do
      let updated := names.map fun name =>
        if name == entry then (name, [entry])
        else
          let preds := predecessors f name
          let members := names.filter fun candidate =>
            candidate == name || (!preds.isEmpty &&
              preds.all fun pred => ((old.lookup pred).getD []).contains candidate)
          (name, members)
      if updated == old then pure updated else iterate fuel updated
  iterate (f.blocks.size * f.blocks.size + 1) initial

private inductive Dominators where
  | reference (sets : ReferenceDominators)
  | indexed (sets : CFG.Dominators)

private def Dominators.contains : Dominators → String → String → Bool
  | .reference sets, useBlock, definitionBlock => ((sets.lookup useBlock).getD []).contains definitionBlock
  | .indexed sets, useBlock, definitionBlock => sets.contains useBlock definitionBlock

private structure Definition where
  name : String
  width : Width
  block : Option String
  position : Nat
  floating : Bool := false

private inductive Definitions where
  | reference (entries : List Definition)
  | indexed (entries : Std.HashMap String Definition)

private def Definitions.find? : Definitions → String → Option Definition
  | .reference entries, name => entries.find? (·.name == name)
  | .indexed entries, name => entries[name]?

private def Definitions.insert : Definitions → Definition → Definitions
  | .reference entries, entry => .reference (entry :: entries)
  | .indexed entries, entry => .indexed (entries.insert entry.name entry)

private def addDefinition (definitions : Definitions) (definition : Definition)
    : Except String Definitions := do
  if !validName definition.name then throw "unsupported temporary/parameter name"
  if (definitions.find? definition.name).isSome then
    throw s!"duplicate SSA definition or duplicate parameter %{definition.name}"
  pure (definitions.insert definition)

private def checkOperand (definitions : Definitions) (doms : Dominators)
    (useBlock : String) (position : Nat) (width : Width) (operand : Operand) (floating : Bool := false)
    : Except String Unit := do
  match operand with
  | .constant _ => pure ()
  | .symbol name | .threadSymbol name =>
    if floating then throw "symbol address cannot have floating type"
    if !validGlobalName name then throw "unsupported symbol name"
  | .temporary name =>
    let some definition := definitions.find? name
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
      else if !doms.contains useBlock block then
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

private def checkSection (customSection : Option String) : Except String Unit := do
  let some customSection := customSection | pure ()
  let parts := customSection.splitOn ","
  if customSection.startsWith "." then
    if parts.length > 2 then throw "ELF section accepts a name and optional awx flags"
    let name := parts[0]!
    if name.utf8ByteSize > 128 || !name.toList.all (fun c =>
        c.isAlphanum && c.toNat < 128 || c == '_' || c == '.' || c == '$') then
      throw "ELF section requires at most 128 ASCII name characters"
    if let some flags := parts[1]? then
      if !flags.toList.all (fun c => c == 'a' || c == 'w' || c == 'x') then
        throw "unsupported ELF section flags (accepted: a, w, x)"
    return ()
  if parts.length < 2 || parts.length > 4 then throw "Apple section requires segment,section[,type[,attributes]]"
  for name in parts.take 2 do
    if name.isEmpty || name.utf8ByteSize > 16 || !name.toList.all (fun c =>
        c.isAlphanum && c.toNat < 128 || c == '_' || c == '.' || c == '$') then
      throw "Apple section names must contain 1..16 ASCII name characters"
  if let some kind := parts[2]? then
    if !["regular", "cstring_literals", "4byte_literals", "8byte_literals", "16byte_literals",
        "literal_pointers", "mod_init_funcs", "mod_term_funcs", "coalesced"].contains kind then
      throw "unsupported Apple section type"
  if let some attributes := parts[3]? then
    for attr in attributes.splitOn "+" do
      if !["pure_instructions", "some_instructions", "no_dead_strip", "live_support"].contains attr then
        throw "unsupported Apple section attribute"

def validateFunction (f : Function) (scalable : Bool := false) : Except String Unit := do
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
  if names.eraseDups.length != names.length then throw "duplicate block label"
  let entry := f.blocks[0]!.label
  for block in f.blocks do
    for target in block.terminator.successors do
      if !names.contains target then throw s!"unknown block @{target}"
      if target == entry then throw "QBE entry block must not be a jump target"
  let mut definitions := if scalable then Definitions.indexed {} else .reference []
  for parameter in f.parameters do
    definitions ← addDefinition definitions
      { name := parameter.name, width := parameter.width, floating := parameter.floating, block := none, position := 0 }
  for block in f.blocks do
    for phi in block.phis do
      definitions ← addDefinition definitions
        { name := phi.destination, width := phi.width, floating := phi.floating, block := some block.label, position := 0 }
    for i in [:block.instructions.size] do
      if let some (name, width) := block.instructions[i]!.definition then
        definitions ← addDefinition definitions
          { name, width, floating := match block.instructions[i]! with | .assign inst => inst.floating | _ => false, block := some block.label, position := i + 1 }
  let graph ← if scalable then some <$> CFG.build f else pure none
  let doms ← match graph with
    | some graph => Dominators.indexed <$> CFG.dominators graph
    | none => Dominators.reference <$> referenceDominators f
  for block in f.blocks do
    let preds := match graph with
      | some graph =>
        let blockIndex := (graph.indices[block.label]?).getD 0
        graph.predecessors[blockIndex]!.toList.map (fun (index : Nat) => (f.blocks[index]! : Block).label)
      | none => predecessors f block.label
    for phi in block.phis do
      let incoming := phi.incoming.toList.map (·.1)
      if incoming.isEmpty || incoming.eraseDups.length != incoming.length
          || incoming.length != preds.length || !incoming.all preds.contains then
        throw s!"phi %{phi.destination}: incoming labels must match block predecessors exactly"
      for (label, value) in phi.incoming do
        let some pred := f.blocks.find? (·.label == label)
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
      | .callVoid target arguments => checkCallArguments check checkFloat target arguments
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
        | .call target arguments =>
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
    to consume the result as l. Floating/subword/void signatures remain exact. -/
def callResultMatches (callee : Function) (width : Option Width) (floating : Bool)
    (subword : Option Subword) (aggregate : Option String := none) : Bool :=
  aggregate == callee.resultAggregate && floating == callee.resultFloating && subword == callee.resultSubword &&
    (width == callee.resultWidth ||
      (!floating && subword.isNone && aggregate.isNone && callee.resultWidth == some .word && width == some .long))

def validate (program : Program) : Except String Unit := do
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
            if !callResultMatches callee resultWidth statement.resultFloating statement.resultSubword statement.resultAggregate then
              throw s!"call ${target}: result type disagrees with its definition"
            let fixed := (arguments.findIdx? (·.variadic)).getD arguments.size
            if fixed != callee.parameters.size || (!callee.variadic && arguments.size != fixed) then
              throw s!"call ${target}: argument count/variadic boundary disagrees with its definition"
            for i in [:callee.parameters.size] do
              if arguments[i]!.width != callee.parameters[i]!.width || arguments[i]!.floating != callee.parameters[i]!.floating || arguments[i]!.subword != callee.parameters[i]!.subword || arguments[i]!.aggregate != callee.parameters[i]!.aggregate then
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
  if !module.functions.isEmpty then validate module.functions
  if module.data.size > 1024 then throw "module exceeds the 1024-data-definition resource limit"
  let mut names := module.functions.toList.map (·.name)
  let mut total := 0
  for data in module.data do
    if !validGlobalName data.name then throw "unsupported data symbol name"
    if names.contains data.name then throw s!"duplicate module symbol ${data.name}"
    names := data.name :: names
    checkSection data.customSection
    if data.threadLocal && (data.customSection.isSome || data.common) then
      throw "thread data cannot have custom section or common linkage"
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
      if let .address name _ := item then
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
