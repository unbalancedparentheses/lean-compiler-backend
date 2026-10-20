/-
  Executable source contract for the first verified-path profile (F01).
  See docs/research/first-verified-path.md. The namespace names the intended
  workstream; admission and compilation preservation are NOT yet proved.
-/
import LeanCompilerBackend.IR

namespace LeanCompilerBackend.Verified.Source

inductive Value where
  | word (bits : BitVec 32)
  | long (bits : BitVec 64)
  deriving DecidableEq, Repr

def Value.width : Value → Width
  | .word _ => .word
  | .long _ => .long

def Value.toNat : Value → Nat
  | .word bits => bits.toNat
  | .long bits => bits.toNat

def Value.constant (width : Width) (n : Int) : Value :=
  match width with
  | .word => .word (BitVec.ofInt 32 n)
  | .long => .long (BitVec.ofInt 64 n)

inductive Binary where
  | add | sub | mul | andBits | orBits | xorBits
  deriving DecidableEq, Repr

inductive Comparison where
  | eq | unsignedLT
  deriving DecidableEq, Repr

abbrev ValueId := Nat
abbrev BlockId := Nat

inductive Operand where
  | local (id : ValueId)
  | literal (value : Value)
  deriving DecidableEq, Repr

inductive Operation where
  | copy (value : Operand)
  | binary (op : Binary) (lhs rhs : Operand)
  | compare (op : Comparison) (operandWidth : Width) (lhs rhs : Operand)
  deriving DecidableEq, Repr

structure Instruction where
  destination : ValueId
  width : Width
  operation : Operation
  deriving DecidableEq, Repr

structure Phi where
  destination : ValueId
  width : Width
  incoming : Array (BlockId × Operand)
  deriving DecidableEq, Repr

inductive Terminator where
  | ret (value : Operand)
  | jump (target : BlockId)
  | branch (condition : Operand) (yes no : BlockId)
  deriving DecidableEq, Repr

structure Block where
  phis : Array Phi
  instructions : Array Instruction
  terminator : Terminator
  deriving DecidableEq, Repr

/-- Raw numbered syntax, not a proof-carrying CheckedSSA. Parameters have IDs
    0..parameters.size-1; other IDs follow block/phi/instruction order. -/
structure Function where
  resultWidth : Width
  parameters : Array Width
  valueWidths : Array Width
  blocks : Array Block
  deriving DecidableEq, Repr

abbrev Environment := Array (Option Value)

structure State where
  block : BlockId
  /-- Positions below the instruction count execute the body; equality executes
      the terminator. Phis are executed atomically by the incoming edge. -/
  position : Nat
  environment : Environment
  deriving DecidableEq, Repr

inductive Fault where
  | arity | widthMismatch | missingValue (id : ValueId)
  | invalidBlock (id : BlockId) | invalidPosition
  | invalidDestination (id : ValueId) | invalidPhi (block : BlockId)
  deriving DecidableEq, Repr

def read (env : Environment) (width : Width) (operand : Operand)
    : Except Fault Value := do
  let value ← match operand with
    | .literal value => pure value
    | .local id => match env[id]? with
      | some (some value) => pure value
      | _ => throw (.missingValue id)
  if value.width != width then throw .widthMismatch
  pure value

private def write (f : Function) (env : Environment) (id : ValueId) (value : Value)
    : Except Fault Environment := do
  let some width := f.valueWidths[id]? | throw (.invalidDestination id)
  if id >= env.size then throw (.invalidDestination id)
  if width != value.width then throw .widthMismatch
  pure (env.set! id (some value))

def binaryBits {n : Nat} (op : Binary) (a b : BitVec n) : BitVec n :=
  match op with
  | .add => a + b | .sub => a - b | .mul => a * b
  | .andBits => a &&& b | .orBits => a ||| b | .xorBits => a ^^^ b

def evaluateBinary (op : Binary) : Value → Value → Except Fault Value
  | .word a, .word b => .ok (.word (binaryBits op a b))
  | .long a, .long b => .ok (.long (binaryBits op a b))
  | _, _ => .error .widthMismatch

def evaluateComparison (op : Comparison) (a b : Value) : Except Fault Value := do
  if a.width != b.width then throw .widthMismatch
  let result := match op with
    | .eq => a.toNat == b.toNat
    | .unsignedLT => a.toNat < b.toNat
  pure (.word (if result then 1 else 0))

private def evaluate (env : Environment) (i : Instruction) : Except Fault Value := do
  match i.operation with
  | .copy operand => read env i.width operand
  | .binary op lhs rhs =>
    evaluateBinary op (← read env i.width lhs) (← read env i.width rhs)
  | .compare op width lhs rhs =>
    if i.width != .word then throw .widthMismatch
    evaluateComparison op (← read env width lhs) (← read env width rhs)

/-- Every operand is read from the old environment before any phi destination
    changes. Missing and duplicate predecessor entries fail explicitly. -/
def transfer (f : Function) (predecessor target : BlockId) (env : Environment)
    : Except Fault State := do
  let some block := f.blocks[target]? | throw (.invalidBlock target)
  let mut pending : Array (ValueId × Value) := #[]
  for phi in block.phis do
    let incoming := phi.incoming.filter (·.1 == predecessor)
    if incoming.size != 1 || pending.any (·.1 == phi.destination) then
      throw (.invalidPhi target)
    let some (_, operand) := incoming[0]? | throw (.invalidPhi target)
    pending := pending.push (phi.destination, ← read env phi.width operand)
  let mut updated := env
  for (id, value) in pending do
    updated ← write f updated id value
  pure { block := target, position := 0, environment := updated }

inductive Transition where
  | next (state : State)
  | returned (value : Value)
  deriving DecidableEq, Repr

def initial (f : Function) (arguments : Array Value) : Except Fault State := do
  if arguments.size != f.parameters.size then throw .arity
  let some entry := f.blocks[0]? | throw (.invalidBlock 0)
  if !entry.phis.isEmpty then throw (.invalidPhi 0)
  let mut env : Environment := Array.replicate f.valueWidths.size none
  for i in [:arguments.size] do
    let some argument := arguments[i]? | throw .arity
    let some width := f.parameters[i]? | throw .arity
    if argument.width != width then throw .widthMismatch
    env ← write f env i argument
  pure { block := 0, position := 0, environment := env }

def step (f : Function) (state : State) : Except Fault Transition := do
  let some block := f.blocks[state.block]? | throw (.invalidBlock state.block)
  if state.position < block.instructions.size then
    let some inst := block.instructions[state.position]? | throw .invalidPosition
    let value ← evaluate state.environment inst
    let env ← write f state.environment inst.destination value
    pure (.next { state with position := state.position + 1, environment := env })
  else if state.position == block.instructions.size then
    match block.terminator with
    | .ret operand => pure (.returned (← read state.environment f.resultWidth operand))
    | .jump target => .next <$> transfer f state.block target state.environment
    | .branch operand yes no =>
      let condition ← read state.environment .word operand
      .next <$> transfer f state.block (if condition.toNat != 0 then yes else no) state.environment
  else throw .invalidPosition

/-- Small steps do not contain an interpreter fuel counter. -/
def Step (f : Function) (s t : State) : Prop := step f s = .ok (.next t)

inductive Steps (f : Function) : Nat → State → State → Prop where
  | zero (s) : Steps f 0 s s
  | succ : Step f s t → Steps f n t u → Steps f (n + 1) s u

def Returns (f : Function) (s : State) (value : Value) : Prop :=
  ∃ n t, Steps f n s t ∧ step f t = .ok (.returned value)

/-- Arbitrarily long finite nonreturning prefixes in a deterministic transition
    system. This predicate is not inferred from any finite test budget. -/
def Diverges (f : Function) (s : State) : Prop :=
  ∀ n, ∃ t, Steps f n s t

inductive Behavior where
  | returned (value : Value)
  | diverges
  deriving DecidableEq, Repr

def HasBehavior (f : Function) (arguments : Array Value) (behavior : Behavior) : Prop :=
  ∃ s, initial f arguments = .ok s ∧ match behavior with
    | .returned value => Returns f s value
    | .diverges => Diverges f s

inductive RunResult where
  | returned (value : Value)
  | exhausted (state : State)
  | stuck (fault : Fault)
  deriving DecidableEq, Repr

/-- Fuel counts individual body/terminator steps, unlike the compatibility
    interpreter's block budget. Exhaustion is inconclusive, not divergence. -/
def run (f : Function) : Nat → State → RunResult
  | 0, state => .exhausted state
  | fuel + 1, state => match step f state with
    | .error fault => .stuck fault
    | .ok (.returned value) => .returned value
    | .ok (.next next) => run f fuel next

def evaluateFunction (f : Function) (arguments : Array Value) (fuel : Nat) : RunResult :=
  match initial f arguments with
  | .error fault => .stuck fault
  | .ok state => run f fuel state

/-- A successful bounded evaluation witnesses a return in the unbounded
    small-step semantics. This does not prove admission or compilation sound. -/
theorem run_return_sound (f : Function) (fuel : Nat) (s : State) (v : Value)
    (h : run f fuel s = .returned v) : Returns f s v := by
  induction fuel generalizing s with
  | zero => simp [run] at h
  | succ fuel ih =>
    cases hs : step f s with
    | error fault => simp [run, hs] at h
    | ok transition =>
      cases transition with
      | returned value =>
        have hv : value = v := by simpa [run, hs] using h
        subst value
        exact ⟨0, s, .zero s, hs⟩
      | next t =>
        have ht : run f fuel t = .returned v := by simpa [run, hs] using h
        obtain ⟨n, u, steps, result⟩ := ih t ht
        exact ⟨n + 1, u, .succ hs steps, result⟩

theorem step_deterministic (f : Function) (s t u : State)
    (ht : Step f s t) (hu : Step f s u) : t = u := by
  unfold Step at ht hu
  have h := ht.symm.trans hu
  cases h
  rfl

end LeanCompilerBackend.Verified.Source
