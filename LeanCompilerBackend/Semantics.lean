/-
  Executable semantics for the admitted integer QBE subset.
  QBE 1.3 doc/il.txt and ops.h define word/long modular arithmetic.
  See docs/UPSTREAM.md and third_party/qbe/LICENSE.
-/
import LeanCompilerBackend.Validate
import LeanCompilerBackend.Memory

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

private def operand (locals : List (String × UInt64)) (width : Width)
    (value : Operand) : Except String UInt64 := do
  match value with
  | .constant n => return constant width n
  | .temporary name =>
    match locals.lookup name with
    | some v => return normalize width v
    | none => throw s!"undefined temporary %{name}"

private def updateLocal (locals : List (String × UInt64)) (name : String) (value : UInt64)
    : List (String × UInt64) :=
  (name, value) :: locals.filter (fun pair => pair.1 != name)

/-- A shared budget bounds blocks across the entire interpreted call tree. -/
private structure ExecutionState where
  memory : Memory := {}
  remainingBlocks : Nat := 100000

private abbrev CallHandler := String → Array UInt64 → ExecutionState →
  Except String (UInt64 × ExecutionState)

private def evaluateOperation (call : CallHandler) (inst : Instruction)
    (locals : List (String × UInt64)) (state : ExecutionState)
    : Except String (UInt64 × ExecutionState) := do
  match inst.operation with
  | .copy v => pure (← operand locals inst.width v, state)
  | .binary op a b =>
    let lhs ← operand locals inst.width a
    let rhs ← operand locals (op.rhsWidth inst.width) b
    pure (binary inst.width op lhs rhs, state)
  | .unary op value =>
    let input ← operand locals (op.inputWidth inst.width) value
    pure (unary inst.width op input, state)
  | .divide op a b =>
    let lhs ← operand locals inst.width a
    let rhs ← operand locals inst.width b
    pure (← divide inst.width op lhs rhs, state)
  | .compare op width a b =>
    let lhs ← operand locals width a
    let rhs ← operand locals width b
    pure (compare width op lhs rhs, state)
  | .allocate alignment size =>
    let size ← operand locals .long size
    let (address, memory) ← state.memory.allocate alignment size.toNat
    pure (address, { state with memory })
  | .load kind address =>
    let address ← operand locals .long address
    let value ← state.memory.read address (kind.bytes inst.width)
    let extended := match kind.signedBits with
      | some bits => constant inst.width (signedBits bits value)
      | none => normalize inst.width value
    pure (extended, state)
  | .call target arguments =>
    let values ← arguments.mapM fun argument => operand locals argument.width argument.value
    let (value, updated) ← call target values state
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
    | .store width value address =>
      let value ← operand locals width.valueWidth value
      let address ← operand locals .long address
      let memory ← state.memory.write address width.bytes value
      state := { state with memory }
  pure (locals, state)

private def execute (call : CallHandler) (f : Function) : Nat → String → Option String →
    List (String × UInt64) → ExecutionState → Except String (UInt64 × ExecutionState)
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
      let result ← operand environment phi.width value
      pure (phi.destination, result)
    let mut locals := environment
    for (name, value) in updates do locals := updateLocal locals name value
    let (executed, state) ← evaluateInstructions call block.instructions locals state
    match block.terminator with
    | .ret value => pure (← operand executed f.resultWidth value, state)
    | .halt => throw "QBE hlt reached: target-dependent program termination"
    | .jump target => execute call f fuel target (some label) executed state
    | .branch condition yes no => do
      let value ← operand executed .word condition
      execute call f fuel (if value != 0 then yes else no) (some label) executed state

private def invoke (program : Program) : Nat → Function → Array UInt64 → ExecutionState →
    Except String (UInt64 × ExecutionState)
  | 0, _, _, _ => .error "interpreter call-depth budget exhausted; result not evaluated"
  | depth + 1, f, arguments, state => do
    if arguments.size != f.parameters.size then
      throw s!"function ${f.name} expects {f.parameters.size} arguments, got {arguments.size}"
    let mut locals : List (String × UInt64) := []
    for i in [:f.parameters.size] do
      let p := f.parameters[i]!
      locals := (p.name, normalize p.width arguments[i]!) :: locals
    let call : CallHandler := fun target values current => do
      let some callee := program.find? (·.name == target)
        | throw s!"external call ${target} has no interpreter model; result not evaluated"
      invoke program depth callee values current
    let objectCount := state.memory.objects.size
    let allocatedBytes := state.memory.allocatedBytes
    let (value, updated) ← execute call f 100000 f.blocks[0]!.label none locals state
    -- Preserve writes to caller-owned objects, but invalidate this activation's
    -- stack objects. Addresses are never reused, so a dangling pointer stays invalid.
    let memory := { updated.memory with
      objects := updated.memory.objects.extract 0 objectCount, allocatedBytes }
    pure (value, { updated with memory })

def evaluateProgram (program : Program) (name : String) (arguments : Array UInt64)
    : Except String UInt64 := do
  validate program
  let some f := program.find? (·.name == name) | throw s!"unknown function ${name}"
  let (value, _) ← invoke program 128 f arguments {}
  pure value

def evaluate (f : Function) (arguments : Array UInt64) : Except String UInt64 :=
  evaluateProgram #[f] f.name arguments

end LeanCompilerBackend.Semantics
