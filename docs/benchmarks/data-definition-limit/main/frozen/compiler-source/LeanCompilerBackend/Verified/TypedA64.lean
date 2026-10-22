/- Typed AArch64 leaf assembly. Rendering follows legality checks; this is not
   an encoder or a proof of conformity to the ARM architectural specification. -/
import LeanCompilerBackend.Verified.StackMIR

namespace LeanCompilerBackend.Verified.TypedA64

abbrev Label := StackMIR.Label

inductive Condition where
  | eq | lo
  deriving DecidableEq, Repr

inductive Instruction where
  | subSP (bytes : Nat)
  | addSP (bytes : Nat)
  | load (width : Width) (reg offset : Nat)
  | store (width : Width) (reg offset : Nat)
  | movz (width : Width) (reg chunk shift : Nat)
  | movk (width : Width) (reg chunk shift : Nat)
  | alu (width : Width) (op : Source.Binary) (dst lhs rhs : Nat)
  | cmp (width : Width) (lhs rhs : Nat)
  | cset (reg : Nat) (condition : Condition)
  | cbnz (reg : Nat) (target : Label)
  | jump (target : Label)
  | ret
  deriving DecidableEq, Repr

structure Block where
  label : Label
  instructions : Array Instruction
  deriving DecidableEq, Repr

structure Function where
  parameters : Array Width
  resultWidth : Width
  frameBytes : Nat
  blocks : Array Block
  deriving DecidableEq, Repr

private def immediate (reg : Nat) (value : Source.Value) : Array Instruction := Id.run do
  let width := value.width
  let bits := value.toNat
  let mut code := #[Instruction.movz width reg (bits % 65536) 0]
  for shift in [16:width.bits:16] do
    let chunk := (bits / 2 ^ shift) % 65536
    if chunk != 0 then code := code.push (.movk width reg chunk shift)
  return code

private def selectInstruction (f : StackMIR.Function) : StackMIR.Instruction → Except String (Array Instruction)
  | .enterFrame bytes => pure (if bytes == 0 then #[] else #[.subSP bytes])
  | .leaveFrame bytes => pure (if bytes == 0 then #[] else #[.addSP bytes])
  | .readArg width index slot => do pure #[.store width index (← StackMIR.offset f slot)]
  | .constant reg value => pure (immediate reg.index value)
  | .load width reg slot => do pure #[.load width reg.index (← StackMIR.offset f slot)]
  | .store width slot reg => do pure #[.store width reg.index (← StackMIR.offset f slot)]
  | .alu width op dst lhs rhs => pure #[.alu width op dst.index lhs.index rhs.index]
  | .compare width op dst lhs rhs =>
    pure #[.cmp width lhs.index rhs.index, .cset dst.index (match op with | .eq => .eq | .unsignedLT => .lo)]

def select (f : StackMIR.Function) : Except String Function := do
  StackMIR.validate f
  let mut blocks := #[]
  for block in f.blocks do
    let mut instructions := #[]
    for inst in block.instructions do instructions := instructions ++ (← selectInstruction f inst)
    instructions := instructions ++ (match block.terminator with
      | .jump target => #[.jump target]
      | .branch reg yes no => #[.cbnz reg.index yes, .jump no]
      | .ret _ => #[.ret])
    blocks := blocks.push { label := block.label, instructions }
  pure { parameters := f.parameters, resultWidth := f.resultWidth, frameBytes := f.layout.frameBytes, blocks }

private def writable (reg : Nat) : Bool := reg == 0 || reg == 9 || reg == 10
private def readable (reg : Nat) : Bool := reg < 8 || reg == 9 || reg == 10

private def checkAccess (f : Function) (width : Width) (offset : Nat) : Except String Unit := do
  if offset % width.bytes != 0 || offset / width.bytes >= 4096 || offset + width.bytes > f.frameBytes then
    throw "assembly frame access is out of bounds, misaligned or unencodable"

/-- Validates legal forms and frame/control structure, not semantic value flow. -/
def validate (f : Function) : Except String Unit := do
  if f.frameBytes > 4080 || f.frameBytes % 16 != 0 || f.parameters.size > 8 then
    throw "invalid assembly frame/signature"
  if (f.blocks[0]?).map (·.label) != some .entry then throw "missing assembly entry"
  let mut labels : Array Label := #[]
  for block in f.blocks do
    if labels.contains block.label then throw "duplicate assembly label"
    labels := labels.push block.label
  for block in f.blocks do
    if block.instructions.isEmpty then throw "empty assembly block"
    let mut active := block.label != .entry || f.frameBytes == 0
    let mut left := false
    let mut flagsReady := false
    for index in [:block.instructions.size] do
      let some inst := block.instructions[index]? | throw "missing assembly instruction"
      let last := index + 1 == block.instructions.size
      match inst with
      | .subSP bytes =>
        if block.label != .entry || index != 0 || active || bytes == 0 || bytes != f.frameBytes then
          throw "invalid assembly prologue"
        active := true
      | .addSP bytes =>
        if !active || block.label == .entry || left || bytes == 0 || bytes != f.frameBytes ||
            index + 2 != block.instructions.size then throw "invalid assembly epilogue"
        active := false
        left := true
      | .load width reg offset =>
        if !active || left || !writable reg then throw "illegal load destination/frame phase"
        checkAccess f width offset
      | .store width reg offset =>
        if !active || left || !readable reg then throw "illegal store source/frame phase"
        checkAccess f width offset
      | .movz width reg chunk shift | .movk width reg chunk shift =>
        if !active || left || !writable reg || chunk >= 65536 || shift % 16 != 0 || shift >= width.bits then
          throw "illegal constant materialization"
      | .alu _ _ dst lhs rhs =>
        if !active || left || !writable dst || !readable lhs || !readable rhs then throw "illegal ALU operands"
      | .cmp _ lhs rhs =>
        if !active || left || !readable lhs || !readable rhs then throw "illegal comparison operands"
        flagsReady := true
      | .cset reg _ =>
        if !active || left || !writable reg || !flagsReady then throw "cset without local flags or illegal destination"
      | .cbnz reg target =>
        if !active || left || !readable reg || index + 2 != block.instructions.size ||
            target == .entry || !labels.contains target then throw "illegal conditional branch"
        let some (.jump _) := block.instructions[index + 1]? | throw "conditional branch must precede a jump"
      | .jump target =>
        if !last || !active || left || target == .entry || !labels.contains target then throw "illegal jump"
      | .ret =>
        if !last || block.label == .entry || (f.frameBytes != 0 && (!left || active)) then
          throw "return without frame restoration"
      if last then
        match inst with
        | .jump _ | .ret => pure ()
        | _ => throw "assembly block has no terminal branch/return"

def labelName (symbol : String) : Label → String
  | .entry => s!"L_lcb_{symbol.length}_{symbol}_entry"
  | .body id => s!"L_lcb_{symbol.length}_{symbol}_body_{id}"
  | .edge pred target => s!"L_lcb_{symbol.length}_{symbol}_edge_{pred}_{target}"

private def register (width : Width) (index : Nat) : String :=
  (if width == .word then "w" else "x") ++ toString index

private def mnemonic : Source.Binary → String
  | .add => "add" | .sub => "sub" | .mul => "mul"
  | .andBits => "and" | .orBits => "orr" | .xorBits => "eor"

private def renderInstruction (symbol : String) : Instruction → String
  | .subSP bytes => s!"\tsub sp, sp, #{bytes}"
  | .addSP bytes => s!"\tadd sp, sp, #{bytes}"
  | .load width reg offset => s!"\tldr {register width reg}, [sp, #{offset}]"
  | .store width reg offset => s!"\tstr {register width reg}, [sp, #{offset}]"
  | .movz width reg chunk shift => s!"\tmovz {register width reg}, #{chunk}, lsl #{shift}"
  | .movk width reg chunk shift => s!"\tmovk {register width reg}, #{chunk}, lsl #{shift}"
  | .alu width op dst lhs rhs => s!"\t{mnemonic op} {register width dst}, {register width lhs}, {register width rhs}"
  | .cmp width lhs rhs => s!"\tcmp {register width lhs}, {register width rhs}"
  | .cset reg condition => s!"\tcset w{reg}, {if condition == .eq then "eq" else "lo"}"
  | .cbnz reg target => s!"\tcbnz w{reg}, {labelName symbol target}"
  | .jump target => s!"\tb {labelName symbol target}"
  | .ret => "\tret"

def render (f : Function) (symbol : Symbol) : Except String String := do
  validate f
  let validName := !symbol.name.isEmpty && symbol.name.toList.all (fun c =>
    c.toNat < 128 && (c.isAlphanum || c == '_')) &&
    (symbol.name.toList.head!.isAlpha || symbol.name.toList.head! == '_')
  if !validName then throw "invalid assembly symbol"
  let mut lines := [s!"; function {symbol.name}; uncertified typed stack baseline"]
  if symbol.exported then lines := lines ++ [s!".globl _{symbol.name}"]
  lines := lines ++ [".p2align 2", s!"_{symbol.name}:"]
  for block in f.blocks do
    lines := lines ++ [labelName symbol.name block.label ++ ":"]
    lines := lines ++ block.instructions.toList.map (renderInstruction symbol.name)
  pure (String.intercalate "\n" (lines ++ [""]))

end LeanCompilerBackend.Verified.TypedA64
