/-
  Executable semantics for the admitted integer QBE subset.
  QBE 1.3 doc/il.txt and ops.h define word/long modular arithmetic.
  See docs/UPSTREAM.md and third_party/qbe/LICENSE.
-/
import LeanCompilerBackend.Validate
import LeanCompilerBackend.Memory
import LeanCompilerBackend.Floating

namespace LeanCompilerBackend.Semantics

def normalize (width : Width) (value : UInt64) : UInt64 :=
  match width with
  | .word => value.toUInt32.toUInt64
  | .long => value

def constant (width : Width) (value : Int) : UInt64 :=
  (BitVec.ofInt width.bits value).toNat.toUInt64

def signedBits (bits : Nat) (value : UInt64) : Int :=
  let n := value.toNat % 2 ^ bits
  if n >= 2 ^ (bits - 1) then (n : Int) - 2 ^ bits else (n : Int)

def binary (width : Width) (op : Binary) (a b : UInt64) : UInt64 :=
  normalize width <| match op with
  | .add => a + b
  | .sub => a - b
  | .mul => a * b
  | .andBits => a &&& b
  | .orBits => a ||| b
  | .xorBits => a ^^^ b
  | .shiftLeft => a <<< (b &&& (width.bits - 1).toUInt64)
  | .logicalRight => a >>> (b &&& (width.bits - 1).toUInt64)
  | .arithmeticRight => constant width (signedBits width.bits a / (2 ^ (b.toNat % width.bits) : Int))

def unary (width : Width) (op : Unary) (value : UInt64) : UInt64 :=
  normalize width <| match op with
  | .negate => 0 - value
  | .signedByte => constant width (signedBits 8 value)
  | .unsignedByte => value &&& 255
  | .signedHalf => constant width (signedBits 16 value)
  | .unsignedHalf => value &&& 65535
  | .signedWord => constant width (signedBits 32 value)
  | .unsignedWord => normalize .word value

def divide (width : Width) (op : Division) (a b : UInt64) : Except String UInt64 := do
  let a := normalize width a
  let b := normalize width b
  if b == 0 then throw "undefined QBE integer division/remainder by zero"
  match op with
  | .unsignedDiv => pure (a / b)
  | .unsignedRem => pure (a % b)
  | .signedDiv | .signedRem =>
    let sa := signedBits width.bits a
    let sb := signedBits width.bits b
    if sa == -(2 ^ (width.bits - 1) : Int) && sb == -1 then
      throw "undefined QBE signed division/remainder overflow"
    let value := if op == .signedDiv then sa.tdiv sb else sa.tmod sb
    pure (constant width value)

def compare (width : Width) (op : Comparison) (a b : UInt64) : UInt64 :=
  let a := normalize width a
  let b := normalize width b
  let sa := signedBits width.bits a
  let sb := signedBits width.bits b
  let result := match op with
    | .eq => a == b
    | .ne => a != b
    | .signedLE => sa <= sb
    | .signedLT => sa < sb
    | .signedGE => sa >= sb
    | .signedGT => sa > sb
    | .unsignedLE => a <= b
    | .unsignedLT => a < b
    | .unsignedGE => a >= b
    | .unsignedGT => a > b
  if result then 1 else 0

private def operand (symbols locals : List (String × UInt64)) (width : Width)
    (value : Operand) : Except String UInt64 := do
  match value with
  | .constant n => return constant width n
  | .symbol name =>
    match symbols.lookup name with
    | some address => pure (normalize width address)
    | none => throw s!"external symbol ${name} has no interpreter model; result not evaluated"
  | .temporary name =>
    match locals.lookup name with
    | some v => return normalize width v
    | none => throw s!"undefined temporary %{name}"

private def resolveCallTarget (functions : Program) (symbols locals : List (String × UInt64))
    (target : CallTarget) (arguments : Array CallArgument) (resultWidth : Option Width) (resultFloating : Bool) (resultSubword : Option Subword) : Except String String := do
  match target with
  | .direct name => pure name
  | .indirect value =>
    let address ← operand symbols locals .long value
    let some (name, _) := symbols.find? (·.2 == address)
      | throw "indirect call address has no interpreter model; result not evaluated"
    let some callee := functions.find? (·.name == name)
      | throw "indirect call target is not a defined function; result not evaluated"
    let arguments ← effectiveCallArguments callee arguments
    let fixed := (arguments.findIdx? (·.variadic)).getD arguments.size
    if callee.resultWidth != resultWidth || callee.resultFloating != resultFloating || callee.resultSubword != resultSubword || callee.parameters.size != fixed ||
        (!callee.variadic && arguments.size != fixed) ||
        (callee.parameters.zip arguments).any (fun (p, a) => p.width != a.width || p.floating != a.floating || p.subword != a.subword) then
      throw "indirect call signature disagrees with target definition; result not evaluated"
    pure name

private def updateLocal (locals : List (String × UInt64)) (name : String) (value : UInt64)
    : List (String × UInt64) :=
  (name, value) :: locals.filter (fun pair => pair.1 != name)

/-- A shared budget bounds blocks across the entire interpreted call tree. -/
private structure ExecutionState where
  memory : Memory := {}
  symbols : List (String × UInt64) := []
  functions : Program := #[]
  variadicStart : Option UInt64 := none
  remainingBlocks : Nat := 100000

private abbrev CallHandler := String → Array UInt64 → Array Width → Bool → ExecutionState →
  Except String (Option UInt64 × ExecutionState)

private def evaluateOperation (call : CallHandler) (inst : Instruction)
    (locals : List (String × UInt64)) (state : ExecutionState)
    : Except String (UInt64 × ExecutionState) := do
  match inst.operation with
  | .convert op value =>
    let input ← operand state.symbols locals op.inputWidth value
    pure (← Floating.convert inst.width op input, state)
  | .floatBinary op a b =>
    let lhs ← operand state.symbols locals inst.width a
    let rhs ← operand state.symbols locals inst.width b
    pure (Floating.binary inst.width op lhs rhs, state)
  | .floatNegate value =>
    let input ← operand state.symbols locals inst.width value
    pure (input ^^^ (1 <<< (inst.width.bits - 1).toUInt64), state)
  | .floatCompare op width a b =>
    let lhs ← operand state.symbols locals width a
    let rhs ← operand state.symbols locals width b
    pure (Floating.compare width op lhs rhs, state)
  | .cast v => pure (← operand state.symbols locals inst.width v, state)
  | .copy v => pure (← operand state.symbols locals inst.width v, state)
  | .binary op a b =>
    let lhs ← operand state.symbols locals inst.width a
    let rhs ← operand state.symbols locals (op.rhsWidth inst.width) b
    pure (binary inst.width op lhs rhs, state)
  | .unary op value =>
    let input ← operand state.symbols locals (op.inputWidth inst.width) value
    pure (unary inst.width op input, state)
  | .divide op a b =>
    let lhs ← operand state.symbols locals inst.width a
    let rhs ← operand state.symbols locals inst.width b
    pure (← divide inst.width op lhs rhs, state)
  | .compare op width a b =>
    let lhs ← operand state.symbols locals width a
    let rhs ← operand state.symbols locals width b
    pure (compare width op lhs rhs, state)
  | .allocate alignment size =>
    let size ← operand state.symbols locals .long size
    if size == 0 then throw "zero-sized stack allocation is outside the interpreted domain"
    let (address, memory) ← state.memory.allocate alignment size.toNat
    pure (address, { state with memory })
  | .vaArg list =>
    let list ← operand state.symbols locals .long list
    let cursor ← state.memory.read list 8
    let value ← state.memory.read cursor inst.width.bytes
    let memory ← state.memory.write list 8 (cursor + 8)
    pure (normalize inst.width value, { state with memory })
  | .load kind address =>
    let address ← operand state.symbols locals .long address
    let value ← state.memory.read address (kind.bytes inst.width)
    let extended := match kind.signedBits with
      | some bits => constant inst.width (signedBits bits value)
      | none => normalize inst.width value
    pure (extended, state)
  | .call target arguments =>
    let target ← resolveCallTarget state.functions state.symbols locals target arguments (some inst.width) inst.floating inst.callSubword
    let values ← arguments.mapM fun argument => do
      let value ← operand state.symbols locals argument.width argument.value
      pure (match argument.subword with | some kind => unary .word kind.extension value | none => value)
    let (result, updated) ← call target values (arguments.map (·.width)) ((arguments[0]?).any (·.environment)) state
    let some value := result | throw "void call cannot define an integer result"
    pure (normalize inst.width value, updated)

private def evaluateInstructions (call : CallHandler) (instructions : Array Statement)
    (environment : List (String × UInt64)) (initialState : ExecutionState)
    : Except String (List (String × UInt64) × ExecutionState) := do
  let mut locals := environment
  let mut state := initialState
  for statement in instructions do
    match statement with
    | .assign inst =>
      let (value, updated) ← evaluateOperation call inst locals state
      locals := updateLocal locals inst.destination value
      state := updated
    | .storeFloat width value address =>
      let value ← operand state.symbols locals width value
      let address ← operand state.symbols locals .long address
      let memory ← state.memory.write address width.bytes value
      state := { state with memory }
    | .store width value address =>
      let value ← operand state.symbols locals width.valueWidth value
      let address ← operand state.symbols locals .long address
      let memory ← state.memory.write address width.bytes value
      state := { state with memory }
    | .callVoid target arguments =>
      let target ← resolveCallTarget state.functions state.symbols locals target arguments none false none
      let values ← arguments.mapM fun argument => do
        let value ← operand state.symbols locals argument.width argument.value
        pure (match argument.subword with | some kind => unary .word kind.extension value | none => value)
      let (result, updated) ← call target values (arguments.map (·.width)) ((arguments[0]?).any (·.environment)) state
      if result.isSome then throw "non-void call requires a return temporary"
      state := updated
    | .vaStart list =>
      let list ← operand state.symbols locals .long list
      let some cursor := state.variadicStart | throw "vastart outside a variadic invocation"
      let memory ← state.memory.write list 8 cursor
      state := { state with memory }
    | .blit source destination bytes =>
      let source ← operand state.symbols locals .long source
      let destination ← operand state.symbols locals .long destination
      let memory ← state.memory.blit source destination bytes
      state := { state with memory }
  pure (locals, state)

private def execute (call : CallHandler) (f : Function) : Nat → String → Option String →
    List (String × UInt64) → ExecutionState → Except String (Option UInt64 × ExecutionState)
  | 0, _, _, _, _ => .error "interpreter block-step budget exhausted; result not evaluated"
  | fuel + 1, label, predecessor, environment, state => do
    if state.remainingBlocks == 0 then
      throw "interpreter block-step budget exhausted; result not evaluated"
    let state := { state with remainingBlocks := state.remainingBlocks - 1 }
    let some block := f.blocks.find? (·.label == label) | throw s!"unknown block @{label}"
    -- Read every incoming value before changing any phi destination.
    let updates ← block.phis.mapM fun phi => do
      let some pred := predecessor | throw "entry block cannot execute phi definitions"
      let some (_, value) := phi.incoming.find? (·.1 == pred)
        | throw s!"phi %{phi.destination} has no incoming edge from @{pred}"
      let result ← operand state.symbols environment phi.width value
      pure (phi.destination, result)
    let mut locals := environment
    for (name, value) in updates do locals := updateLocal locals name value
    let (executed, state) ← evaluateInstructions call block.instructions locals state
    match block.terminator with
    | .ret value =>
      let result ← value.mapM fun value => do
        let some width := f.resultWidth | throw "void function cannot return an integer"
        let result ← operand state.symbols executed width value
        pure (match f.resultSubword with | some kind => unary .word kind.extension result | none => result)
      pure (result, state)
    | .halt => throw "QBE hlt reached: target-dependent program termination"
    | .jump target => execute call f fuel target (some label) executed state
    | .branch condition yes no => do
      let value ← operand state.symbols executed .word condition
      execute call f fuel (if value != 0 then yes else no) (some label) executed state

private def invoke (program : Program) : Nat → Function → Array UInt64 → Array Width → ExecutionState →
    Except String (Option UInt64 × ExecutionState)
  | 0, _, _, _, _ => .error "interpreter call-depth budget exhausted; result not evaluated"
  | depth + 1, f, arguments, argumentWidths, state => do
    if arguments.size < f.parameters.size || (!f.variadic && arguments.size != f.parameters.size) ||
        argumentWidths.size != arguments.size then
      throw s!"function ${f.name} expects {f.parameters.size} arguments, got {arguments.size}"
    let mut locals : List (String × UInt64) := []
    for i in [:f.parameters.size] do
      let p := f.parameters[i]!
      let value := normalize p.width arguments[i]!
      let value := match p.subword with | some kind => unary .word kind.extension value | none => value
      locals := (p.name, value) :: locals
    let call : CallHandler := fun target values widths environment current => do
      let some callee := program.find? (·.name == target)
        | throw s!"external call ${target} has no interpreter model; result not evaluated"
      if environment && !((callee.parameters[0]?).any (·.environment)) then
        invoke program depth callee (values.extract 1 values.size) (widths.extract 1 widths.size) current
      else invoke program depth callee values widths current
    let objectCount := state.memory.objects.size
    let allocatedBytes := state.memory.allocatedBytes
    let mut initial := { state with variadicStart := none }
    if f.variadic then
      let count := arguments.size - f.parameters.size
      let (base, memory) ← state.memory.allocate .eight (count * 8)
      let mut memory := memory
      for i in [:count] do
        let index := f.parameters.size + i
        memory ← memory.write (base + (i * 8).toUInt64) argumentWidths[index]!.bytes arguments[index]!
      initial := { state with memory, variadicStart := some base }
    let (value, updated) ← execute call f 100000 f.blocks[0]!.label none locals initial
    -- Preserve writes to caller-owned objects, but invalidate this activation's
    -- stack objects. Addresses are never reused, so a dangling pointer stays invalid.
    let memory := { updated.memory with
      objects := updated.memory.objects.extract 0 objectCount, allocatedBytes }
    pure (value, { updated with memory, variadicStart := state.variadicStart })

/-- Allocate all objects before resolving initializers, allowing forward/self references. -/
private def initializeModule (module : Module) : Except String ExecutionState := do
  let mut memory : Memory := {}
  let mut symbols : List (String × UInt64) := []
  -- Function identities are opaque non-memory addresses in this interpreter.
  for i in [:module.functions.size] do
    symbols := (module.functions[i]!.name, (4096 + 16 * i).toUInt64) :: symbols
  for data in module.data do
    let base := alignUp memory.nextAddress data.alignment
    let object := { base, bytes := Array.replicate data.byteSize (some 0) : MemoryObject }
    memory := { memory with
      objects := memory.objects.push object
      nextAddress := base + data.byteSize + 16
      allocatedBytes := memory.allocatedBytes + data.byteSize }
    symbols := (data.name, base.toUInt64) :: symbols
  for data in module.data do
    let some base := symbols.lookup data.name | throw "missing initialized data symbol"
    let mut offset := 0
    for item in data.items do
      match item with
      | .integer width value =>
        memory ← memory.write (base + offset.toUInt64) width.bytes (constant .long value)
      | .zeroes _ => pure ()
      | .byteString values =>
        for i in [:values.size] do
          memory ← memory.write (base + (offset + i).toUInt64) 1 values[i]!.toUInt64
      | .address name addend =>
        let some address := symbols.lookup name
          | throw s!"external symbol ${name} has no interpreter model; result not evaluated"
        memory ← memory.write (base + offset.toUInt64) 8 (address + constant .long addend)
      offset := offset + item.byteSize
  return { memory, symbols, functions := module.functions }

def evaluateModule (module : Module) (name : String) (arguments : Array UInt64)
    : Except String (Option UInt64) := do
  validateModule module
  let some f := module.functions.find? (·.name == name) | throw s!"unknown function ${name}"
  let initial ← initializeModule module
  -- CLI arguments describe the named parameters; variadic tails need typed IL calls.
  if arguments.size != f.parameters.size then throw "CLI argument count must match named parameters"
  let (value, _) ← invoke module.functions 128 f arguments (f.parameters.map (·.width)) initial
  pure value

def evaluateProgram (program : Program) (name : String) (arguments : Array UInt64)
    : Except String (Option UInt64) :=
  evaluateModule { functions := program } name arguments

def evaluate (f : Function) (arguments : Array UInt64) : Except String UInt64 := do
  let some value ← evaluateProgram #[f] f.name arguments
    | throw "function returns void; no integer result"
  pure value

end LeanCompilerBackend.Semantics
