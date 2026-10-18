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
  | shiftLeft | logicalRight | arithmeticRight
  deriving BEq, DecidableEq, Repr, Inhabited

def Binary.rhsWidth (width : Width) : Binary → Width
  | .shiftLeft | .logicalRight | .arithmeticRight => .word
  | _ => width

inductive Unary where
  | negate | signedByte | unsignedByte | signedHalf | unsignedHalf | signedWord | unsignedWord
  deriving BEq, DecidableEq, Repr, Inhabited

def Unary.inputWidth (width : Width) : Unary → Width
  | .negate => width
  | _ => .word

inductive Division where
  | signedDiv | unsignedDiv | signedRem | unsignedRem
  deriving BEq, DecidableEq, Repr, Inhabited

inductive Comparison where
  | eq | ne | signedLE | signedLT | signedGE | signedGT
  | unsignedLE | unsignedLT | unsignedGE | unsignedGT
  deriving BEq, DecidableEq, Repr, Inhabited

inductive Operation where
  | copy (value : Operand)
  | binary (op : Binary) (lhs rhs : Operand)
  | unary (op : Unary) (value : Operand)
  | divide (op : Division) (lhs rhs : Operand)
  | compare (op : Comparison) (operandWidth : Width) (lhs rhs : Operand)
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

structure Phi where
  destination : String
  width : Width
  incoming : Array (String × Operand)
  deriving Repr, Inhabited

inductive Terminator where
  | ret (value : Operand)
  | jump (label : String)
  | branch (condition : Operand) (ifTrue ifFalse : String)
  | halt
  deriving Repr, Inhabited

def Terminator.successors : Terminator → List String
  | .jump label => [label]
  | .branch _ yes no => [yes, no]
  | _ => []

structure Block where
  label : String
  phis : Array Phi
  instructions : Array Instruction
  terminator : Terminator
  deriving Repr, Inhabited

structure Function where
  name : String
  exported : Bool
  resultWidth : Width
  parameters : Array Parameter
  blocks : Array Block
  deriving Repr, Inhabited

def Function.locals (f : Function) : Array (String × Width) :=
  f.blocks.foldl (fun result block => result
    ++ block.phis.map (fun phi => (phi.destination, phi.width))
    ++ block.instructions.map (fun inst => (inst.destination, inst.width)))
    (f.parameters.map (fun p => (p.name, p.width)))

abbrev Program := Array Function

end LeanCompilerBackend
