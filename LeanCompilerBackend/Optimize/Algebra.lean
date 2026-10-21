/- Width-aware integer identities for the optional compatibility optimizer. -/
import LeanCompilerBackend.Semantics

namespace LeanCompilerBackend.Optimize.Algebra

private def constant (width : Width) : Operand → Option UInt64
  | .constant n => some (Semantics.constant width n)
  | _ => none

/-- Preserve the result-width copy: a word identity still truncates a long input.
    This pass neither folds floating operations nor removes effectful definitions.
    Multiplication is modular, so every single-bit multiplier is a left shift,
    including the signed high bit. Shift counts have QBE's modulo-width meaning. -/
def operation (width : Width) (operation : Operation) : Operation := Id.run do
  let .binary op a b := operation | return operation
  let ca := constant width a
  let cb := constant (op.rhsWidth width) b
  let all := Semantics.constant width (-1)
  match op with
  | .add | .orBits | .xorBits =>
    if ca == some 0 then return .copy b
    if cb == some 0 then return .copy a
  | .sub => if cb == some 0 then return .copy a
  | .andBits =>
    if ca == some 0 || cb == some 0 then return .copy (.constant 0)
    if ca == some all then return .copy b
    if cb == some all then return .copy a
  | .mul =>
    if ca == some 0 || cb == some 0 then return .copy (.constant 0)
    let (value, factor) := if let some n := cb then (a, some n) else (b, ca)
    if let some n := factor then
      if n == 1 then return .copy value
      for bit in [1:width.bits] do
        if n == (1 : UInt64) <<< bit.toUInt64 then
          return .binary .shiftLeft value (.constant bit)
  | .shiftLeft | .logicalRight | .arithmeticRight =>
    if let some n := cb then
      if n.toNat % width.bits == 0 then return .copy a
  return operation

end LeanCompilerBackend.Optimize.Algebra
