/- Executable frame/register semantics for the first-path MIR and typed assembly.
   Owned-frame byte memory includes initialization and W/X aliases. This is a
   restricted model, not an ARM ISA formalization or a preservation proof. -/
import LeanCompilerBackend.Verified.TypedA64

namespace LeanCompilerBackend.Verified.Machine

structure Flags where
  negative : Bool := false
  zero : Bool := false
  carry : Bool := false
  overflow : Bool := false
  deriving DecidableEq, Repr

structure Data where
  registers : Array UInt64
  entryRegisters : Array UInt64
  entrySP : Nat
  sp : Nat
  frameBytes : Nat
  memory : Array (Option UInt8)
  active : Bool
  flags : Flags := {}
  deriving DecidableEq, Repr

structure State where
  label : StackMIR.Label := .entry
  position : Nat := 0
  data : Data
  deriving DecidableEq, Repr

inductive Result where
  | returned (value : Source.Value) (data : Data)
  | exhausted (state : State)
  | stuck (reason : String)
  deriving DecidableEq, Repr

inductive Transition where
  | next (state : State)
  | returned (value : Source.Value) (data : Data)
  deriving DecidableEq, Repr

def normalize (width : Width) (value : UInt64) : UInt64 :=
  match width with | .word => value.toUInt32.toUInt64 | .long => value

def readReg (d : Data) (width : Width) (reg : Nat) : Except String UInt64 := do
  let some value := d.registers[reg]? | throw "missing register"
  pure (normalize width value)

/-- All W writes zero the upper half of X; reads see only the selected width. -/
def writeReg (d : Data) (width : Width) (reg : Nat) (value : UInt64) : Except String Data := do
  if reg >= 31 || reg >= d.registers.size then throw "invalid register write"
  pure { d with registers := d.registers.set! reg (normalize width value) }

def address (d : Data) (width : Width) (offset : Nat) : Except String Nat := do
  if !d.active || d.entrySP < d.frameBytes then throw "frame is inactive or wraps"
  let base := d.entrySP - d.frameBytes
  let addr := d.sp + offset
  if addr < base || addr + width.bytes > d.entrySP || addr + width.bytes > 2^64 ||
      d.memory.size != d.frameBytes then throw "access outside owned frame"
  pure (addr - base)

/-- Reconstruct a little-endian byte span. The natural accumulator exposes
    byte reconstruction without relying on host-width arithmetic. Loads below
    request only four or eight bytes and convert the result to UInt64. -/
def readBytes : Nat → Nat → Array (Option UInt8) → Except String Nat
  | 0, _, _ => .ok 0
  | count+1, start, memory => do
    let some (some byte) := memory[start]? | throw "uninitialized frame load"
    let rest ← readBytes count (start+1) memory
    pure (byte.toNat + 256 * rest)

def load (d : Data) (width : Width) (offset : Nat) : Except String UInt64 := do
  let start ← address d width offset
  pure (← readBytes width.bytes start d.memory).toUInt64

/-- Write a little-endian byte span. Recursive form exposes the frame rule for
    proof: each step changes exactly one byte and advances within the span. -/
def writeBytes : Nat → Nat → UInt64 → Array (Option UInt8) → Array (Option UInt8)
  | 0, _, _, memory => memory
  | count+1, start, value, memory =>
    writeBytes count (start+1) (value >>> 8) (memory.set! start (some value.toUInt8))

def store (d : Data) (width : Width) (offset : Nat) (value : UInt64) : Except String Data := do
  let start ← address d width offset
  pure { d with memory := writeBytes width.bytes start value d.memory }

/-- The deterministic test caller supplies garbage in the high half of word
    arguments. The arbitrary-caller contract below only constrains low bits. -/
def argumentBits (arg : Source.Value) : UInt64 :=
  let bits := arg.toNat.toUInt64
  if arg.width == .word then bits ||| 0xfacefeed00000000 else bits

def initialRegisters (arguments : Array Source.Value) : Array UInt64 :=
  (Array.range 31).map fun i =>
    match arguments[i]? with
    | some arg => argumentBits arg
    | none => (0x1234000000000000 + i).toUInt64

def initialState (arguments : Array Source.Value) (frameBytes entrySP : Nat) : State :=
  let registers := initialRegisters arguments
  { data := { registers, entryRegisters := registers, entrySP, sp := entrySP,
              frameBytes, memory := Array.replicate frameBytes none, active := false } }

def initial (parameters : Array Width) (arguments : Array Source.Value) (frameBytes : Nat)
    (entrySP := 1048576) : Except String State := do
  if parameters.size != arguments.size || parameters.size > 8 then throw "argument count mismatch"
  if entrySP % 16 != 0 || entrySP < frameBytes || entrySP >= 2^64 || frameBytes % 16 != 0 || frameBytes > 4080 then
    throw "invalid frame entry preconditions"
  if parameters ≠ arguments.map Source.Value.width then throw "argument width mismatch"
  pure (initialState arguments frameBytes entrySP)

/-- Zero-byte frame operations are omitted from assembly; its entry phase is
    already active in that case. This adapter is used by the actual evaluator. -/
def assemblyEntry (state : State) : State :=
  { state with data.active := state.data.frameBytes == 0 }

def enter (d : Data) (bytes : Nat) : Except String Data := do
  if d.active || d.sp != d.entrySP || bytes != d.frameBytes || d.sp < bytes then throw "invalid frame entry"
  pure { d with sp := d.sp - bytes, active := true }

def leave (d : Data) (bytes : Nat) : Except String Data := do
  if !d.active || bytes != d.frameBytes || d.sp + bytes != d.entrySP then throw "invalid frame teardown"
  pure { d with sp := d.sp + bytes, active := false }

private def finish (d : Data) (width : Width) : Except String Transition := do
  if d.sp != d.entrySP then throw "return stack mismatch"
  for reg in [:31] do
    if reg != 0 && reg != 9 && reg != 10 && d.registers[reg]? != d.entryRegisters[reg]? then
      throw "preserved register changed"
  let value ← readReg d width 0
  pure (.returned (Source.Value.constant width value.toNat) d)

def alu (width : Width) (op : Source.Binary) (a b : UInt64) : UInt64 :=
  normalize width (match op with
    | .add => a + b | .sub => a - b | .mul => a * b
    | .andBits => a &&& b | .orBits => a ||| b | .xorBits => a ^^^ b)

private def executeMIR (f : StackMIR.Function) (d : Data) : StackMIR.Instruction → Except String Data
  | .enterFrame bytes => enter d bytes
  | .leaveFrame bytes => leave d bytes
  | .readArg width reg slot => do store d width (← StackMIR.offset f slot) (← readReg d width reg)
  | .constant reg value => writeReg d value.width reg.index value.toNat.toUInt64
  | .load width reg slot => do writeReg d width reg.index (← load d width (← StackMIR.offset f slot))
  | .store width slot reg => do store d width (← StackMIR.offset f slot) (← readReg d width reg.index)
  | .alu width op dst lhs rhs => do
    writeReg d width dst.index (alu width op (← readReg d width lhs.index) (← readReg d width rhs.index))
  | .compare width op dst lhs rhs => do
    let a ← readReg d width lhs.index
    let b ← readReg d width rhs.index
    let yes := match op with | .eq => a == b | .unsignedLT => a < b
    writeReg d .word dst.index (if yes then 1 else 0)

def stepMIR (f : StackMIR.Function) (s : State) : Except String Transition := do
  let some block := f.blocks.find? (·.label == s.label) | throw "missing MIR block"
  if s.position < block.instructions.size then
    let some inst := block.instructions[s.position]? | throw "missing MIR instruction"
    pure (.next { s with position := s.position+1, data := ← executeMIR f s.data inst })
  else if s.position == block.instructions.size then
    match block.terminator with
    | .jump label => pure (.next { s with label, position := 0 })
    | .branch condition yes no =>
      let value ← readReg s.data .word condition.index
      pure (.next { s with label := if value != 0 then yes else no, position := 0 })
    | .ret width =>
      if s.data.active then throw "MIR return before frame leave"
      finish s.data width
  else throw "invalid MIR PC"

/-- NZCV is computed from target subtraction, independently of source compare. -/
def subtractFlags (width : Width) (lhs rhs : UInt64) : Flags := Id.run do
  let a := normalize width lhs
  let b := normalize width rhs
  let difference := normalize width (a - b)
  let sign := (1 : UInt64) <<< (width.bits - 1).toUInt64
  let negative := difference &&& sign != 0
  let signA := a &&& sign != 0
  let signB := b &&& sign != 0
  return { negative, zero := difference == 0, carry := a >= b,
           overflow := signA != signB && negative != signA }

def stepAssembly (f : TypedA64.Function) (s : State) : Except String Transition := do
  let some block := f.blocks.find? (·.label == s.label) | throw "missing assembly block"
  let some inst := block.instructions[s.position]? | throw "assembly fell through block"
  let d := s.data
  let mut updated := d
  match inst with
  | .subSP bytes => updated ← enter d bytes
  | .addSP bytes => updated ← leave d bytes
  | .load width reg offset => updated ← writeReg d width reg (← load d width offset)
  | .store width reg offset => updated ← store d width offset (← readReg d width reg)
  | .movz width reg chunk shift => updated ← writeReg d width reg (chunk.toUInt64 <<< shift.toUInt64)
  | .movk width reg chunk shift =>
    let old ← readReg d width reg
    let mask := (65535 : UInt64) <<< shift.toUInt64
    updated ← writeReg d width reg ((old &&& ~~~mask) ||| (chunk.toUInt64 <<< shift.toUInt64))
  | .alu width op dst lhs rhs =>
    updated ← writeReg d width dst (alu width op (← readReg d width lhs) (← readReg d width rhs))
  | .cmp width lhs rhs =>
    updated := { d with flags := subtractFlags width (← readReg d width lhs) (← readReg d width rhs) }
  | .cset reg condition =>
    let yes := match condition with | .eq => d.flags.zero | .lo => !d.flags.carry
    updated ← writeReg d .word reg (if yes then 1 else 0)
  | .cbnz reg target =>
    if (← readReg d .word reg) != 0 then return .next { s with label := target, position := 0 }
  | .jump target => return .next { s with label := target, position := 0 }
  | .ret =>
    if f.frameBytes != 0 && d.active then throw "assembly return before frame leave"
    return ← finish d f.resultWidth
  pure (.next { s with position := s.position+1, data := updated })

def run (step : State → Except String Transition) : Nat → State → Result
  | 0, state => .exhausted state
  | fuel+1, state => match step state with
    | .error error => .stuck error
    | .ok (.returned value data) => .returned value data
    | .ok (.next next) => run step fuel next

/-- Relations are independent of evaluator fuel. A stuck transition has no
    behavior; proving it unreachable for admitted jobs remains a C01 obligation. -/
def Step (step : State → Except String Transition) (s t : State) : Prop :=
  step s = .ok (.next t)

inductive Steps (step : State → Except String Transition) : Nat → State → State → Prop where
  | zero (s) : Steps step 0 s s
  | succ : Step step s t → Steps step n t u → Steps step (n+1) s u

def Returns (step : State → Except String Transition) (s : State)
    (value : Source.Value) (data : Data) : Prop :=
  ∃ n t, Steps step n s t ∧ step t = .ok (.returned value data)

def Diverges (step : State → Except String Transition) (s : State) : Prop :=
  ∀ n, ∃ t, Steps step n s t

def HasBehavior (step : State → Except String Transition) (s : State) : Source.Behavior → Prop
  | .returned value => ∃ data, Returns step s value data
  | .diverges => Diverges step s

/-- Arbitrary compatible caller states, unlike the deterministic test initializer.
    Memory is only the owned frame; extension to a full-address-space ISA model
    is a separate refinement boundary. Incoming frame bytes may be arbitrary. -/
def EntryState (parameters : Array Width) (arguments : Array Source.Value)
    (frameBytes : Nat) (assembly : Bool) (s : State) : Prop :=
  s.label = .entry ∧ s.position = 0 ∧ s.data.sp = s.data.entrySP ∧
  s.data.entrySP % 16 = 0 ∧ frameBytes ≤ s.data.entrySP ∧ s.data.entrySP < 2^64 ∧
  frameBytes ≤ 4080 ∧ frameBytes % 16 = 0 ∧ s.data.frameBytes = frameBytes ∧
  s.data.memory.size = frameBytes ∧ s.data.registers.size = 31 ∧
  s.data.entryRegisters = s.data.registers ∧
  s.data.active = (assembly && frameBytes == 0) ∧
  parameters.size = arguments.size ∧ parameters.size ≤ 8 ∧
  ∀ i w v, parameters[i]? = some w → arguments[i]? = some v →
    v.width = w ∧ readReg s.data w i = .ok v.toNat.toUInt64

def evaluateMIR (f : StackMIR.Function) (args : Array Source.Value) (fuel : Nat) : Result :=
  match StackMIR.validate f *> initial f.parameters args f.layout.frameBytes with
  | .error error => .stuck error
  | .ok state => run (stepMIR f) fuel state

def evaluateAssembly (f : TypedA64.Function) (args : Array Source.Value) (fuel : Nat) : Result :=
  match TypedA64.validate f *> initial f.parameters args f.frameBytes with
  | .error error => .stuck error
  | .ok state =>
    run (stepAssembly f) fuel (assemblyEntry state)

end LeanCompilerBackend.Verified.Machine
