/-
  Admission and dominance checks for the QBE SSA subset.
  References: QBE 1.3 parse.c, cfg.c, ssa.c and doc/il.txt.
  This implements only the currently admitted subset, not QBE's full SSA
  construction or complete type system. See docs/UPSTREAM.md.
-/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend

private def validName := validIdentifier

private def predecessors (f : Function) (label : String) : List String :=
  f.blocks.toList.filterMap fun block =>
    if block.terminator.successors.contains label then some block.label else none

private abbrev Dominators := List (String × List String)

/-- Finite-set iteration; unsupported/nonconverging cases fail closed. -/
private def dominators (f : Function) : Except String Dominators := do
  let names := f.blocks.toList.map (·.label)
  let entry := f.blocks[0]!.label
  let initial := names.map fun name => (name, if name == entry then [entry] else names)
  let rec iterate : Nat → Dominators → Except String Dominators
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

private structure Definition where
  name : String
  width : Width
  block : Option String
  position : Nat
  floating : Bool := false

private def addDefinition (definitions : List Definition) (definition : Definition)
    : Except String (List Definition) := do
  if !validName definition.name then throw "unsupported temporary/parameter name"
  if definitions.any (·.name == definition.name) then
    throw s!"duplicate SSA definition or duplicate parameter %{definition.name}"
  pure (definition :: definitions)

private def checkOperand (definitions : List Definition) (doms : Dominators)
    (useBlock : String) (position : Nat) (width : Width) (operand : Operand) (floating : Bool := false)
    : Except String Unit := do
  match operand with
  | .constant _ => pure ()
  | .symbol name =>
    if floating then throw "symbol address cannot have floating type"
    if !validName name then throw "unsupported symbol name"
  | .temporary name =>
    let some definition := definitions.find? (·.name == name)
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
      else if !((doms.lookup useBlock).getD []).contains block then
        throw s!"%{name}: definition in @{block} does not dominate use in @{useBlock}"

private def checkCallArguments (check : Width → Operand → Except String Unit)
    (checkFloat : Width → Operand → Except String Unit)
    (target : CallTarget) (arguments : Array CallArgument) : Except String Unit := do
  match target with
  | .direct name => if !validName name then throw "unsupported direct call target"
  | .indirect address => check .long address
  if arguments.size > maxIntegerArguments then
    throw s!"call exceeds the {maxIntegerArguments}-integer-argument resource limit"
  let mut seenVariadic := false
  for i in [:arguments.size] do
    let argument := arguments[i]!
    if argument.environment && (i != 0 || argument.variadic || argument.width != .long || argument.floating) then
      throw "environment argument must be first, named and long"
    if seenVariadic && !argument.variadic then throw "fixed argument follows variadic argument"
    seenVariadic := seenVariadic || argument.variadic
    (if argument.floating then checkFloat else check) argument.width argument.value

def validateFunction (f : Function) : Except String Unit := do
  if f.resultFloating && f.resultWidth.isNone then throw "void result cannot have floating type"
  if !validName f.name then throw "unsupported function name"
  if f.parameters.size > maxIntegerArguments then
    throw s!"function exceeds the {maxIntegerArguments}-integer-parameter resource limit"
  for i in [:f.parameters.size] do
    if f.parameters[i]!.environment && (i != 0 || f.parameters[i]!.width != .long || f.parameters[i]!.floating) then
      throw "environment parameter must be first and long"
  if f.blocks.isEmpty then throw "function has no entry block"
  if f.blocks.size > 64 then throw "function exceeds initial 64-block limit"
  let count := f.blocks.foldl (fun n block => n + block.instructions.size + block.phis.size) 0
  if count > 480 then throw "function exceeds initial 480-instruction/phi limit"
  let names := f.blocks.toList.map (·.label)
  if names.any (!validName ·) then throw "unsupported block name"
  if names.eraseDups.length != names.length then throw "duplicate block label"
  let entry := f.blocks[0]!.label
  for block in f.blocks do
    for target in block.terminator.successors do
      if !names.contains target then throw s!"unknown block @{target}"
      if target == entry then throw "QBE entry block must not be a jump target"
  let mut definitions := []
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
  let doms ← dominators f
  for block in f.blocks do
    let preds := predecessors f block.label
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
        if bytes > 4096 then throw "blit byte count exceeds the 4096-byte resource limit"
      | .assign inst =>
        let floatingOperation := match inst.operation with
          | .copy .. | .cast .. | .load .plain _ | .floatBinary .. | .floatNegate .. | .call .. | .vaArg .. => true
          | _ => false
        if inst.floating && !floatingOperation then throw "operation does not support a floating result"
        match inst.operation with
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
            if bytes <= 0 || bytes > 4096 then
              throw "stack allocation currently requires a constant size in 1..4096"
          | .temporary _ | .symbol _ => check .long size
    let check := fun width value => checkOperand definitions doms block.label (block.instructions.size + 1) width value false
    match block.terminator with
    | .ret value =>
      match f.resultWidth, value with
      | some width, some value => checkOperand definitions doms block.label (block.instructions.size + 1) width value f.resultFloating
      | none, none => pure ()
      | _, _ => throw "return value disagrees with function result type"
    | .branch value _ _ => check .word value
    | .jump _ | .halt => pure ()

/-- QBE permits an extra environment argument when the callee ignores it. -/
def effectiveCallArguments (callee : Function) (arguments : Array CallArgument)
    : Except String (Array CallArgument) := do
  let expectsEnvironment := (callee.parameters[0]?).any (·.environment)
  let suppliedEnvironment := (arguments[0]?).any (·.environment)
  if expectsEnvironment && !suppliedEnvironment then throw "missing environment argument"
  if suppliedEnvironment && !expectsEnvironment then return arguments.extract 1 arguments.size
  return arguments

def validate (program : Program) : Except String Unit := do
  if program.isEmpty then throw "program contains no functions"
  if program.size > 64 then throw "program exceeds initial 64-function limit"
  let mut names : List String := []
  for f in program do
    if names.contains f.name then throw ("duplicate function $" ++ f.name)
    names := f.name :: names
    match validateFunction f with
    | .ok () => pure ()
    | .error message => throw s!"function ${f.name}: {message}"
  -- External symbols have no declaration in QBE IL. Their ABI is an explicit
  -- link-time assumption; check exact signatures when the definition is present.
  for f in program do
    for block in f.blocks do
      for statement in block.instructions do
        if let some (.direct target, arguments, resultWidth) := statement.callSite then
          if let some callee := program.find? (·.name == target) then
            let arguments ← effectiveCallArguments callee arguments
            if resultWidth != callee.resultWidth || statement.resultFloating != callee.resultFloating then
              throw s!"call ${target}: result type disagrees with its definition"
            let fixed := (arguments.findIdx? (·.variadic)).getD arguments.size
            if fixed != callee.parameters.size || (!callee.variadic && arguments.size != fixed) then
              throw s!"call ${target}: argument count/variadic boundary disagrees with its definition"
            for i in [:callee.parameters.size] do
              if arguments[i]!.width != callee.parameters[i]!.width || arguments[i]!.floating != callee.parameters[i]!.floating then
                throw s!"call ${target}: argument type disagrees with its definition"

def validateModule (module : Module) : Except String Unit := do
  if module.functions.isEmpty && module.data.isEmpty then throw "module contains no definitions"
  if !module.functions.isEmpty then validate module.functions
  if module.data.size > 1024 then throw "module exceeds the 1024-data-definition resource limit"
  let mut names := module.functions.toList.map (·.name)
  let mut total := 0
  for data in module.data do
    if !validName data.name then throw "unsupported data symbol name"
    if names.contains data.name then throw s!"duplicate module symbol ${data.name}"
    names := data.name :: names
    if data.alignment == 0 || data.alignment > 64 ||
        (data.alignment &&& (data.alignment - 1)) != 0 then
      throw "data alignment must be a power of two in 1..64"
    total := total + data.byteSize
    if total > 1024 * 1024 then throw "module data exceeds the 1 MiB resource limit"
    for item in data.items do
      if let .address name _ := item then
        if !validName name then throw "unsupported data relocation symbol"
  for f in module.functions do
    for block in f.blocks do
      for statement in block.instructions do
        if let some (.direct target, _, _) := statement.callSite then
          if module.data.any (·.name == target) then
            throw s!"call ${target}: symbol is defined as data"

end LeanCompilerBackend
