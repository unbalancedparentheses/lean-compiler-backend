/- Optional compatibility-only constant/copy/CFG/common-expression optimization.
   No floating folding, memory reordering or certified-path use. -/
import LeanCompilerBackend.Semantics
import LeanCompilerBackend.Optimize.Cleanup
import LeanCompilerBackend.Optimize.ControlFlow
import LeanCompilerBackend.Optimize.Common
import LeanCompilerBackend.Optimize.Memory

namespace LeanCompilerBackend.Optimize

private abbrev Facts := Std.HashMap String UInt64
private def value (facts : Facts) (w : Width) : Operand → Option UInt64
  | .constant n => some (Semantics.constant w n)
  | .temporary name => (facts[name]?).map (Semantics.normalize w)
  | _ => none
private def operand (facts : Facts) : Operand → Operand
  | .temporary name => match facts[name]? with
    | some n => .constant n.toNat
    | none => .temporary name
  | other => other
private def target (facts : Facts) : CallTarget → CallTarget
  | .indirect v => .indirect (operand facts v)
  | other => other
private def operation (facts : Facts) : Operation → Operation
  | .copy v => .copy (operand facts v)
  | .cast v => .cast (operand facts v)
  | .unary op v => .unary op (operand facts v)
  | .binary op a b => .binary op (operand facts a) (operand facts b)
  | .divide op a b => .divide op (operand facts a) (operand facts b)
  | .compare op w a b => .compare op w (operand facts a) (operand facts b)
  | .floatBinary op a b => .floatBinary op (operand facts a) (operand facts b)
  | .floatNegate v => .floatNegate (operand facts v)
  | .floatCompare op w a b => .floatCompare op w (operand facts a) (operand facts b)
  | .convert op v => .convert op (operand facts v)
  | .load kind v => .load kind (operand facts v)
  | .vaArg v => .vaArg (operand facts v)
  | .call fn args => .call (target facts fn) (args.map fun a => {a with value := operand facts a.value})
  -- Retain the runtime-size admission boundary even when its value is known.
  | .allocate a v => .allocate a v
private def constantResult (facts : Facts) (i : Instruction) : Option UInt64 := do
  let w := i.width
  match i.operation with
  | .copy v | .cast v => value facts w v
  | .unary op v => return Semantics.unary w op (← value facts (op.inputWidth w) v)
  | .binary op a b => return Semantics.binary w op (← value facts w a) (← value facts (op.rhsWidth w) b)
  | .divide op a b => (Semantics.divide w op (← value facts w a) (← value facts w b)).toOption
  | .compare op ow a b => return Semantics.compare ow op (← value facts ow a) (← value facts ow b)
  | _ => none
private def statement (facts : Facts) : Statement → Statement
  | .assign i =>
    let op := (constantResult facts i).map (fun n => Operation.copy (.constant n.toNat))
    .assign {i with operation := op.getD (operation facts i.operation)}
  | .store w v p => .store w (operand facts v) (operand facts p)
  | .storeFloat w v p => .storeFloat w (operand facts v) (operand facts p)
  | .callVoid fn args => .callVoid (target facts fn) (args.map fun a => {a with value := operand facts a.value})
  | .vaStart v => .vaStart (operand facts v)
  | .blit a b n => .blit (operand facts a) (operand facts b) n
private def terminator (facts : Facts) : Terminator → Terminator
  | .ret v => .ret (v.map (operand facts))
  | .branch v a b => .branch (operand facts v) a b
  | other => other

/-- Bounded monotone discovery; an unfinished chain simply stays unoptimized.
    Keep all statements/phis and debug indices, including effects and traps. -/
def function (f : Function) : Function := Id.run do
  let mut facts : Facts := {}
  for _ in [:8] do
    let before := facts.size
    for b in f.blocks do
      for phi in b.phis do
        let values := phi.incoming.map (fun (_,v) => value facts phi.width v)
        if let some (some n) := values[0]? then
          if values.all (· == some n) then facts := facts.insert phi.destination n
      for s in b.instructions do
        if let .assign i := s then
          if let some n := constantResult facts i then facts := facts.insert i.destination n
    if before == facts.size then break
  return {f with blocks := f.blocks.map fun b => {b with
    phis := b.phis.map (fun p => {p with incoming := p.incoming.map (fun (label,v) => (label,operand facts v))})
    instructions := b.instructions.map (statement facts)
    terminator := terminator facts b.terminator}}

def module (m : Module) : Except String Module := do
  validateModule m
  let functions ← m.functions.mapM fun f => do
    let mut result := Memory.promote (Cleanup.copies f)
    result := Cleanup.copies result
    -- Expose constants from pruned phis in subsequent bounded rounds.
    for _ in [:4] do
      result ← ControlFlow.simplify (function result)
      result := Cleanup.copies result
    result ← Common.eliminate (function result)
    pure (Cleanup.deadDefinitions (Cleanup.copies result))
  let result := {m with functions}
  validateModule result
  pure result

end LeanCompilerBackend.Optimize
