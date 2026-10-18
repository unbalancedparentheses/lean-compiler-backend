/-
  Lean Compiler Backend — initial QBE integer-IR subset.
  Adapted from QBE 1.3's class/operand/instruction discipline (all.h, ops.h).
  See docs/UPSTREAM.md and third_party/qbe/LICENSE for provenance and copyright.
  Zig's AIR/target separation is an architectural reference, not an API dependency.
-/
import Std

namespace LeanCompilerBackend

inductive Width where
  | word | long
  deriving BEq, DecidableEq, Repr, Inhabited

def Width.bits : Width → Nat
  | .word => 32
  | .long => 64

def Width.spelling : Width → String
  | .word => "w"
  | .long => "l"

inductive Operand where
  | temporary (name : String)
  | constant (value : Int)
  deriving Repr, Inhabited

inductive Binary where
  | add | sub | mul | andBits | orBits | xorBits
  deriving BEq, DecidableEq, Repr, Inhabited

inductive Operation where
  | copy (value : Operand)
  | binary (op : Binary) (lhs rhs : Operand)
  deriving Repr, Inhabited

structure Instruction where
  destination : String
  width : Width
  operation : Operation
  deriving Repr, Inhabited

structure Parameter where
  name : String
  width : Width
  deriving Repr, Inhabited

structure Function where
  name : String
  exported : Bool
  resultWidth : Width
  parameters : Array Parameter
  entryLabel : String
  instructions : Array Instruction
  result : Operand
  deriving Repr, Inhabited

abbrev Program := Array Function

end LeanCompilerBackend
