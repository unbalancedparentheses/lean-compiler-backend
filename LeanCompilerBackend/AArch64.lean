/-
  AArch64 instruction selection and assembly emission.
  Arithmetic mnemonic selection is adapted from QBE 1.3 arm64/emit.c; the ABI
  subset follows its arm64/abi.c. Zig 0.17.0's AIR -> target-code separation
  and width-specific registers are additional references. See docs/UPSTREAM.md
  and the retained upstream licenses in third_party/.
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

private def register (width : Width) (n : Nat) : String :=
  (if width == .word then "w" else "x") ++ toString n

private def immediate (width : Width) (destination : Nat) (value : Int) : List String := Id.run do
  let bits := Semantics.constant width value
  let r := register width destination
  let mut result := [s!"\tmovz {r}, #{bits &&& 65535}"]
  for shift in [16:width.bits:16] do
    let chunk := (bits >>> shift.toUInt64) &&& 65535
    if chunk != 0 then result := result ++ [s!"\tmovk {r}, #{chunk}, lsl #{shift}"]
  return result

private def load (slots : List (String × Nat)) (width : Width) (destination : Nat)
    (value : Operand) : Except String (List String) := do
  match value with
  | .constant n => return immediate width destination n
  | .temporary name =>
    match slots.lookup name with
    | some offset => return [s!"\tldr {register width destination}, [sp, #{offset}]"]
    | none => throw s!"missing stack slot for %{name}"

private def condition : Comparison → String
  | .eq => "eq" | .ne => "ne"
  | .signedLE => "le" | .signedLT => "lt" | .signedGE => "ge" | .signedGT => "gt"
  | .unsignedLE => "ls" | .unsignedLT => "lo" | .unsignedGE => "hs" | .unsignedGT => "hi"

private def unaryInstruction (width : Width) (op : Unary) : List String :=
  let r := register width 9
  match op with
  | .negate => [s!"\tneg {r}, {r}"]
  | .signedByte => [s!"\tsxtb {r}, w9"]
  | .unsignedByte => ["\tuxtb w9, w9"]
  | .signedHalf => [s!"\tsxth {r}, w9"]
  | .unsignedHalf => ["\tuxth w9, w9"]
  | .signedWord => ["\tsxtw x9, w9"]
  | .unsignedWord => [] -- the w9 load has already cleared x9's high bits

def emitFunction (f : Function) : Except String String := do
  validateFunction f
  -- Leaf-only subset: x9/x10/x11 are caller-clobbered; no calls or callee-saved
  -- registers are used. Frame remains 16-byte aligned, within immediate limits.
  let slotsCount := f.parameters.size + f.instructions.size
  let frame := ((slotsCount * 8 + 15) / 16) * 16
  if frame > 4080 then throw "stack frame exceeds initial AArch64 immediate limit"
  let symbol := "_" ++ f.name
  let mut lines := [s!"; function ${f.name}; target aarch64-macos; QBE-compatible integer subset"]
  if f.exported then lines := lines ++ [s!".globl {symbol}"]
  lines := lines ++ [".p2align 2", s!"{symbol}:"]
  if frame != 0 then lines := lines ++ [s!"\tsub sp, sp, #{frame}"]
  let mut slots : List (String × Nat) := []
  for i in [:f.parameters.size] do
    let p := f.parameters[i]!
    slots := (p.name, i * 8) :: slots
    lines := lines ++ [s!"\tstr {register p.width i}, [sp, #{i * 8}]"]
  for i in [:f.instructions.size] do
    let inst := f.instructions[i]!
    match inst.operation with
    | .copy value => lines := lines ++ (← load slots inst.width 9 value)
    | .binary op a b =>
      lines := lines ++ (← load slots inst.width 9 a)
      lines := lines ++ (← load slots (op.rhsWidth inst.width) 10 b)
      let r := register inst.width 9
      lines := lines ++ [s!"\t{mnemonic (select op)} {r}, {r}, {register inst.width 10}"]
    | .unary op value =>
      lines := lines ++ (← load slots (op.inputWidth inst.width) 9 value)
      lines := lines ++ unaryInstruction inst.width op
    | .divide op a b =>
      lines := lines ++ (← load slots inst.width 9 a)
      lines := lines ++ (← load slots inst.width 10 b)
      let instruction := if op == .signedDiv || op == .signedRem then "sdiv" else "udiv"
      let r9 := register inst.width 9
      let r10 := register inst.width 10
      if op == .signedRem || op == .unsignedRem then
        let r11 := register inst.width 11
        lines := lines ++ [s!"\t{instruction} {r11}, {r9}, {r10}", s!"\tmsub {r9}, {r11}, {r10}, {r9}"]
      else lines := lines ++ [s!"\t{instruction} {r9}, {r9}, {r10}"]
    | .compare op width a b =>
      lines := lines ++ (← load slots width 9 a)
      lines := lines ++ (← load slots width 10 b)
      lines := lines ++ [s!"\tcmp {register width 9}, {register width 10}", s!"\tcset w9, {condition op}"]
    let offset := (f.parameters.size + i) * 8
    lines := lines ++ [s!"\tstr {register inst.width 9}, [sp, #{offset}]"]
    slots := (inst.destination, offset) :: slots
  lines := lines ++ (← load slots f.resultWidth 0 f.result)
  if frame != 0 then lines := lines ++ [s!"\tadd sp, sp, #{frame}"]
  lines := lines ++ ["\tret", ""]
  return String.intercalate "\n" lines

def emit (program : Program) : Except String String := do
  validate program
  let functions ← program.toList.mapM emitFunction
  return "; Generated by Lean Compiler Backend; no Lean runtime in emitted code\n.text\n"
    ++ String.intercalate "\n" functions
    ++ ".subsections_via_symbols\n"

end LeanCompilerBackend.AArch64
