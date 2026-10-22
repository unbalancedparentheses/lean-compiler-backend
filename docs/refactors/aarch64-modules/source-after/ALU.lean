/-
  Abstract AArch64 ALU selection, evaluation and its primitive preservation theorem.
  Adapted from QBE 1.3 arm64; see docs/UPSTREAM.md and third_party licenses.
-/
import LeanCompilerBackend.Semantics

namespace LeanCompilerBackend.AArch64

inductive ALU where
  | add | sub | mul | and_ | orr | eor
  | lsl | lsr | asr
  deriving DecidableEq, Repr

def select (op : Binary) : ALU :=
  match op with
  | .add => .add
  | .sub => .sub
  | .mul => .mul
  | .andBits => .and_
  | .orBits => .orr
  | .xorBits => .eor
  | .shiftLeft => .lsl
  | .logicalRight => .lsr
  | .arithmeticRight => .asr

def mnemonic : ALU → String
  | .add => "add"
  | .sub => "sub"
  | .mul => "mul"
  | .and_ => "and"
  | .orr => "orr"
  | .eor => "eor"
  | .lsl => "lsl"
  | .lsr => "lsr"
  | .asr => "asr"

/-- An abstract target ALU specification; not a decoder for emitted bytes. -/
def evaluateALU (width : Width) (op : ALU) (a b : UInt64) : UInt64 :=
  Semantics.normalize width <| match op with
  | .add => a + b
  | .sub => a - b
  | .mul => a * b
  | .and_ => a &&& b
  | .orr => a ||| b
  | .eor => a ^^^ b
  | .lsl => a <<< (b &&& (width.bits - 1).toUInt64)
  | .lsr => a >>> (b &&& (width.bits - 1).toUInt64)
  | .asr => Semantics.constant width (Semantics.signedBits width.bits a / (2 ^ (b.toNat % width.bits) : Int))

/-- Only the primitive opcode-selection relation is proved here. Stack lowering,
    parsing, assembly rendering and assembler/linker behavior are separate gaps. -/
theorem select_preserves (width : Width) (op : Binary) (a b : UInt64) :
    evaluateALU width (select op) a b = Semantics.binary width op a b := by
  cases op <;> rfl

end LeanCompilerBackend.AArch64
