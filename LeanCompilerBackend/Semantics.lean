/-
  Executable semantics for the admitted integer QBE subset.
  QBE 1.3 doc/il.txt and ops.h define word/long modular arithmetic.
  See docs/UPSTREAM.md and third_party/qbe/LICENSE.
-/
import LeanCompilerBackend.Validate

namespace LeanCompilerBackend.Semantics

def normalize (width : Width) (value : UInt64) : UInt64 :=
  match width with
  | .word => value.toUInt32.toUInt64
  | .long => value

def constant (width : Width) (value : Int) : UInt64 :=
  (BitVec.ofInt width.bits value).toNat.toUInt64

def binary (width : Width) (op : Binary) (a b : UInt64) : UInt64 :=
  normalize width <| match op with
  | .add => a + b
  | .sub => a - b
  | .mul => a * b
  | .andBits => a &&& b
  | .orBits => a ||| b
  | .xorBits => a ^^^ b

private def operand (locals : List (String × UInt64)) (width : Width)
    (value : Operand) : Except String UInt64 := do
  match value with
  | .constant n => return constant width n
  | .temporary name =>
    match locals.lookup name with
    | some v => return normalize width v
    | none => throw s!"undefined temporary %{name}"

def evaluate (f : Function) (arguments : Array UInt64) : Except String UInt64 := do
  validateFunction f
  if arguments.size != f.parameters.size then
    throw s!"function ${f.name} expects {f.parameters.size} arguments, got {arguments.size}"
  let mut locals : List (String × UInt64) := []
  for i in [:f.parameters.size] do
    let p := f.parameters[i]!
    locals := (p.name, normalize p.width arguments[i]!) :: locals
  for inst in f.instructions do
    let value ← match inst.operation with
      | .copy v => operand locals inst.width v
      | .binary op a b => do
        let lhs ← operand locals inst.width a
        let rhs ← operand locals inst.width b
        pure (binary inst.width op lhs rhs)
    locals := (inst.destination, value) :: locals
  operand locals f.resultWidth f.result

end LeanCompilerBackend.Semantics
