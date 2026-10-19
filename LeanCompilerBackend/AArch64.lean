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

private def slotOffset (slots : List (String × Nat)) (name : String) : Except String Nat :=
  match slots.lookup name with
  | some offset => .ok offset
  | none => .error s!"missing stack slot for %{name}"

private def memoryLoad (width : Width) : LoadKind → String
  | .signedByte => s!"ldrsb {register width 9}"
  | .unsignedByte => "ldrb w9"
  | .signedHalf => s!"ldrsh {register width 9}"
  | .unsignedHalf => "ldrh w9"
  | .signedWord => if width == .long then "ldrsw x9" else "ldr w9"
  | .unsignedWord => "ldr w9"
  | .plain => s!"ldr {register width 9}"

private def emitInstruction (slots allocations : List (String × Nat)) (inst : Instruction)
    : Except String (List String) := do
  let mut lines : List String := []
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
  | .allocate _ _ =>
    let offset ← slotOffset allocations inst.destination
    lines := lines ++ [s!"\tadd x9, sp, #{offset}"]
  | .load kind address =>
    lines := lines ++ (← load slots .long 9 address)
    lines := lines ++ [s!"\t{memoryLoad inst.width kind}, [x9]"]
  | .call target arguments =>
    -- Sources are stable stack slots: argument-register permutations cannot
    -- overwrite an argument that has not yet been loaded. All other live values
    -- also survive caller-saved clobbers in their own frame slots.
    for i in [:arguments.size] do
      let argument := arguments[i]!
      lines := lines ++ (← load slots argument.width i argument.value)
    lines := lines ++ [s!"\tbl _{target}", s!"\tmov {register inst.width 9}, {register inst.width 0}"]
  let offset ← slotOffset slots inst.destination
  pure (lines ++ [s!"\tstr {register inst.width 9}, [sp, #{offset}]"])

private def emitStatement (slots allocations : List (String × Nat))
    (statement : Statement) : Except String (List String) := do
  match statement with
  | .assign inst => emitInstruction slots allocations inst
  | .store width value address =>
    let addressLines ← load slots .long 9 address
    let valueLines ← load slots width.valueWidth 10 value
    let instruction := match width with
      | .byte => "strb w10" | .half => "strh w10"
      | .word => "str w10" | .long => "str x10"
    pure (addressLines ++ valueLines ++ [s!"\t{instruction}, [x9]"])

private def blockLabel (f : Function) (label : String) : String :=
  s!"L_lcb_block_{f.name.length}_{f.name}_{label}"

private def edgeLabel (f : Function) (label : String) : String :=
  s!"L_lcb_edge_{f.name.length}_{f.name}_{label}"

/-- Phi lowering stages every source before changing any destination slot. -/
private def emitEdge (f : Function) (slots : List (String × Nat)) (stageBase : Nat)
    (predecessor target : String) : Except String (List String) := do
  let some block := f.blocks.find? (·.label == target) | throw s!"unknown block @{target}"
  let mut lines := []
  for i in [:block.phis.size] do
    let phi := block.phis[i]!
    let some (_, value) := phi.incoming.find? (·.1 == predecessor)
      | throw s!"missing phi predecessor @{predecessor}"
    lines := lines ++ (← load slots phi.width 9 value)
    lines := lines ++ [s!"\tstr {register phi.width 9}, [sp, #{stageBase + i * 8}]"]
  for i in [:block.phis.size] do
    let phi := block.phis[i]!
    let offset ← slotOffset slots phi.destination
    let r := register phi.width 9
    lines := lines ++ [s!"\tldr {r}, [sp, #{stageBase + i * 8}]", s!"\tstr {r}, [sp, #{offset}]"]
  pure lines

def emitFunction (f : Function) : Except String String := do
  validateFunction f
  let localNames := f.locals
  let slots := localNames.toList.zipIdx.map fun ((name, _), i) => (name, i * 8)
  let maxPhis := f.blocks.foldl (fun n block => max n block.phis.size) 0
  let stageBase := localNames.size * 8
  let mut frameEnd := (localNames.size + maxPhis) * 8
  let hasCalls := f.blocks.any fun block => block.instructions.any fun statement =>
    match statement with
    | .assign { operation := .call .., .. } => true
    | _ => false
  let returnAddress := frameEnd
  if hasCalls then frameEnd := frameEnd + 8
  let mut allocations : List (String × Nat) := []
  for statement in f.blocks[0]!.instructions do
    if let .assign inst := statement then
      if let .allocate alignment (.constant size) := inst.operation then
        let offset := alignUp frameEnd alignment.bytes
        allocations := (inst.destination, offset) :: allocations
        frameEnd := offset + size.toNat
  let frame := alignUp frameEnd 16
  if frame > 4080 then throw "stack frame exceeds initial AArch64 immediate limit"
  let symbol := "_" ++ f.name
  let mut lines := [s!"; function {f.name}; target aarch64-macos; QBE integer SSA subset"]
  if f.exported then lines := lines ++ [s!".globl {symbol}"]
  lines := lines ++ [".p2align 2", s!"{symbol}:"]
  if frame != 0 then lines := lines ++ [s!"\tsub sp, sp, #{frame}"]
  if hasCalls then lines := lines ++ [s!"\tstr x30, [sp, #{returnAddress}]"]
  for i in [:f.parameters.size] do
    let parameter := f.parameters[i]!
    let offset ← slotOffset slots parameter.name
    lines := lines ++ [s!"\tstr {register parameter.width i}, [sp, #{offset}]"]
  for block in f.blocks do
    lines := lines ++ [blockLabel f block.label ++ ":"]
    for statement in block.instructions do
      lines := lines ++ (← emitStatement slots allocations statement)
    match block.terminator with
    | .ret value =>
      lines := lines ++ (← load slots f.resultWidth 0 value)
      if hasCalls then lines := lines ++ [s!"\tldr x30, [sp, #{returnAddress}]"]
      if frame != 0 then lines := lines ++ [s!"\tadd sp, sp, #{frame}"]
      lines := lines ++ ["\tret"]
    | .halt => lines := lines ++ ["\tbrk #0"]
    | .jump target =>
      lines := lines ++ (← emitEdge f slots stageBase block.label target)
      lines := lines ++ [s!"\tb {blockLabel f target}"]
    | .branch condition yes no =>
      lines := lines ++ (← load slots .word 9 condition)
      let otherwise := edgeLabel f block.label
      lines := lines ++ [s!"\tcbz w9, {otherwise}"]
      lines := lines ++ (← emitEdge f slots stageBase block.label yes)
      lines := lines ++ [s!"\tb {blockLabel f yes}", otherwise ++ ":"]
      lines := lines ++ (← emitEdge f slots stageBase block.label no)
      lines := lines ++ [s!"\tb {blockLabel f no}"]
  pure (String.intercalate "\n" (lines ++ [""]))

def emit (program : Program) : Except String String := do
  validate program
  let functions ← program.toList.mapM emitFunction
  return "; Generated by Lean Compiler Backend; no Lean runtime in emitted code\n.text\n"
    ++ String.intercalate "\n" functions
    ++ ".subsections_via_symbols\n"

end LeanCompilerBackend.AArch64
